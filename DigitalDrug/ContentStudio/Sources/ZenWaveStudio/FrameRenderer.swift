import AppKit
import Metal
import CoreText

private struct Uniforms {
    var time: Float, intensity: Float, activity: Float, aspect: Float, opacity: Float
    var level: Float, peak: Float, bass: Float, mids: Float, treble: Float
    var beatFrequency: Float, style: Float, presentation: Float, light: Float
    var motionAmount: Float, audioResponse: Float, palette: Float
}

/// Studio-only visualizers, rendered offscreen with consistent preview and export motion.
///
/// On Intel Macs, GPU render targets must use private storage. We blit into a shared
/// texture before `getBytes` so CPU readback sees the shader output (Apple silicon can
/// often skip this, but the blit path is correct everywhere).
final class FrameRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let brandLogo: CGImage
    private let chakras: ChakraRenderer
    /// GPU-only render target.
    private var renderTexture: MTLTexture?
    /// CPU-readable copy after blit.
    private var readbackTexture: MTLTexture?
    private var pixels: [UInt8] = []

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw StudioError.message("A Mac with Metal support is required to render these visualizers.")
        }
        self.brandLogo = try StudioBranding.loadLogo()
        self.chakras = try ChakraRenderer()
        self.device = device
        self.queue = queue
        // Discrete GPUs (e.g. Radeon on Intel Macs) need managed readback + synchronize;
        // unified-memory GPUs can use shared storage directly.
        let baseSource = try String(contentsOf: StudioResources.root.appendingPathComponent("Visualizer.metal"), encoding: .utf8)
        let sacredSource = try String(contentsOf: StudioResources.root.appendingPathComponent("SacredGeometry.metal"), encoding: .utf8)
        let resonanceSource = try String(contentsOf: StudioResources.root.appendingPathComponent("Resonance.metal"), encoding: .utf8)
        let source = baseSource.replacingOccurrences(of: "// STUDIO_SACRED_GEOMETRY", with: sacredSource).replacingOccurrences(of: "// STUDIO_RESONANCE", with: resonanceSource)
        let library = try device.makeLibrary(source: source, options: nil)
        guard let vertex = library.makeFunction(name: "zenWaveFullscreenVertex"),
              let fragment = library.makeFunction(name: "zenWaveVisualizerFragment") else {
            throw StudioError.message("Visualizer shaders failed to load.")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func frame(width: Int, height: Int, time: Double, audioTime: Double,
               envelope: AudioEnvelope, mantra: Mantra, settings: ExportSettings, includeCallToAction: Bool = true) throws -> CGImage {
        try ensureTextures(width: width, height: height)
        guard let renderTexture, let readbackTexture, let command = queue.makeCommandBuffer() else {
            throw StudioError.message("Could not start the visualizer.")
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = renderTexture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            throw StudioError.message("Could not render the visualizer.")
        }

        let signal = envelope.signal(at: audioTime)
        let response = Float(min(2, max(0, settings.audioResponse)))
        let origin = envelope.signal(at: max(0, audioTime - time)).flow
        // Integrating energy changes the rate of travel without jumping the animation phase.
        let phase = (time + (signal.flow - origin) * Double(response) * 0.65)
            * min(2, max(0.25, settings.motionSpeed)) * 1.65
        var u = Uniforms(
            time: Float(phase), intensity: 0.7, activity: 1,
            aspect: Float(width) / Float(height), opacity: 1,
            level: min(1, signal.level * response), peak: min(1, signal.peak * response),
            bass: min(1, signal.bass * response), mids: min(1, signal.mids * response), treble: min(1, signal.treble * response),
            beatFrequency: 0, style: Float(settings.style), presentation: 2, light: 0,
            motionAmount: Float(min(2, max(0, settings.motionAmount))), audioResponse: response,
            palette: Float(settings.palette)
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        // Private → CPU-visible so discrete/Intel GPUs flush shader output for getBytes.
        guard let blit = command.makeBlitCommandEncoder() else {
            throw StudioError.message("Could not copy the visualizer frame.")
        }
        blit.copy(
            from: renderTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: readbackTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        if readbackTexture.storageMode == .managed {
            blit.synchronize(resource: readbackTexture)
        }
        blit.endEncoding()

        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }

        readbackTexture.getBytes(
            &pixels,
            bytesPerRow: width * 4,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        return try pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: info
            ) else {
                throw StudioError.message("Could not compose the video frame.")
            }
            let w = CGFloat(width), h = CGFloat(height)
            chakras.draw(in: context, width: w, height: h, time: phase, audioTime: audioTime,
                         energy: Double(u.level + u.bass) * 0.5, settings: settings)
            let scale = min(w / 1080, h / 1920)
            let caption = settings.captions ? mantra.cues.first(where: {
                audioTime - settings.captionOffset >= $0.start && audioTime - settings.captionOffset < $0.end
            })?.text : nil
            // Keep type inside the middle 72% width, away from social player controls.
            if let caption {
                let box = StudioCallToAction.captionRect(width: w, height: h, settings: settings)
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                    colors: [CGColor(gray: 0, alpha: 0.42), CGColor(gray: 0, alpha: 0)] as CFArray,
                    locations: [0, 1]) {
                    context.drawRadialGradient(gradient, startCenter: CGPoint(x: w / 2, y: box.midY),
                        startRadius: 0, endCenter: CGPoint(x: w / 2, y: box.midY),
                        endRadius: w * 0.6, options: [])
                }
                drawText(caption, context: context, rect: box.insetBy(dx: 18 * scale, dy: 18 * scale), size: 58 * scale, weight: .semibold, centered: true)
            }
            if !settings.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                drawText(settings.heading, context: context,
                         rect: CGRect(x: w * 0.12, y: h * (settings.style == 33 ? 0.94 : 0.78), width: w * 0.76, height: h * (settings.style == 33 ? 0.05 : 0.12)),
                         size: 33 * scale * min(2.4, max(0.75, settings.headingEmphasis)), weight: settings.headingEmphasis > 1.2 ? .bold : .medium, centered: true)
            }
            if includeCallToAction { drawCallToAction(settings.callToAction, context: context, width: w, height: h, time: time, palette: settings.palette, style: settings.style) }
            if settings.branding {
                if settings.brandStyle.showsLogo {
                    let rect = StudioBranding.logoRect(width: w, height: h, settings: settings)
                    context.saveGState()
                    context.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.16, cornerHeight: rect.height * 0.16, transform: nil))
                    context.clip()
                    context.setAlpha(min(1, max(0.25, settings.logoOpacity)))
                    context.interpolationQuality = .high
                    context.draw(brandLogo, in: rect)
                    context.restoreGState()
                }
                if settings.brandStyle.showsWordmark {
                    drawText("ZENWAVE", context: context,
                             rect: CGRect(x: w * 0.15, y: h * (settings.style == 33 ? 0.04 : settings.brandStyle == .logoAndWordmark ? 0.10 : 0.14), width: w * 0.7, height: h * 0.04),
                             size: 26 * scale, weight: .medium, centered: true)
                }
            }
            guard let image = context.makeImage() else {
                throw StudioError.message("The video frame was empty.")
            }
            return image
        }
    }

    /// Live scenes dissolve first; the CTA is composited once to keep its text crisp.
    func overlayCallToAction(on image: CGImage, time: Double, settings: ExportSettings, rectOverride: CGRect? = nil) throws -> CGImage {
        guard settings.callToAction.opacity(at: time) > 0 else { return image }
        let w = image.width, h = image.height
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw StudioError.message("Could not compose the live call to action.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        drawCallToAction(settings.callToAction, context: context, width: CGFloat(w), height: CGFloat(h), time: time, palette: settings.palette, style: settings.style, rectOverride: rectOverride)
        guard let result = context.makeImage() else { throw StudioError.message("Could not finish the live call to action.") }
        return result
    }

    private func drawCallToAction(_ cta: StudioCallToAction, context: CGContext, width: CGFloat, height: CGFloat, time: Double, palette: Int, style: Int, rectOverride: CGRect? = nil) {
        let opacity = cta.opacity(at: time)
        guard opacity > 0 else { return }
        let rect = rectOverride ?? StudioCallToAction.rect(width: width, height: height, placement: cta.placement, style: style)
        let hex = (VisualPalette.all.first { $0.id == palette } ?? VisualPalette.all[0]).colors.last!
        let accent = CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        context.saveGState(); defer { context.restoreGState() }
        context.setAlpha(opacity)
        let radius = rect.height * (cta.style == .pill ? 0.48 : 0.18)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.setFillColor(CGColor(gray: 0.015, alpha: cta.style == .pill ? 0.82 : 0.94))
        context.addPath(path); context.fillPath()
        context.setShadow(offset: .zero, blur: rect.height * 0.10, color: accent.copy(alpha: 0.3))
        context.setStrokeColor(accent.copy(alpha: 0.8)!); context.setLineWidth(max(1, min(width, height) / 540))
        context.addPath(path); context.strokePath(); context.setShadow(offset: .zero, blur: 0, color: nil)
        let hasDetail = !cta.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let inset = rect.width * 0.05
        let headlineBox = CGRect(x: rect.minX + inset, y: rect.minY + rect.height * (hasDetail ? 0.41 : 0.13), width: rect.width - inset * 2, height: rect.height * (hasDetail ? 0.46 : 0.74))
        drawText(cta.renderedHeadline, context: context, rect: headlineBox, size: min(width, height) * 0.034, weight: .bold, centered: true)
        if hasDetail {
            drawText(cta.detail, context: context, rect: CGRect(x: rect.minX + inset, y: rect.minY + rect.height * 0.10, width: rect.width - inset * 2, height: rect.height * 0.29), size: min(width, height) * 0.022, weight: .medium, centered: true)
        }
    }

    private func ensureTextures(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= 8192, height <= 8192 else {
            throw StudioError.message("Choose a video size between 1 and 8192 pixels per side.")
        }
        if renderTexture?.width == width, renderTexture?.height == height,
           readbackTexture?.width == width, readbackTexture?.height == height {
            return
        }
        let renderDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        renderDesc.usage = [.renderTarget, .shaderRead]
        renderDesc.storageMode = .private

        let readDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        // Blit destination must allow writes; CPU reads via getBytes after sync.
        readDesc.usage = [.shaderRead, .shaderWrite]
        readDesc.storageMode = device.hasUnifiedMemory ? .shared : .managed

        guard let render = device.makeTexture(descriptor: renderDesc),
              let readback = device.makeTexture(descriptor: readDesc) else {
            throw StudioError.message("Could not allocate a video frame.")
        }
        renderTexture = render
        readbackTexture = readback
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    private func drawText(_ text: String, context: CGContext, rect: CGRect, size: CGFloat, weight: NSFont.Weight, centered: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .left
        paragraph.lineSpacing = size * 0.18
        var fontSize = size
        var attributed = NSAttributedString()
        var measured = CGSize.zero
        repeat {
            attributed = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
                .foregroundColor: NSColor.white, .paragraphStyle: paragraph
            ])
            let setter = CTFramesetterCreateWithAttributedString(attributed)
            measured = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
                CGSize(width: rect.width, height: .greatestFiniteMagnitude), nil)
            if measured.height <= rect.height || fontSize <= size * 0.48 { break }
            fontSize *= 0.9
        } while true
        let actual = CGRect(x: rect.minX, y: rect.midY - measured.height / 2, width: rect.width, height: min(rect.height, measured.height + 2))
        let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attributed), CFRange(), CGPath(rect: actual, transform: nil), nil)
        context.saveGState()
        context.textMatrix = .identity
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 10, color: CGColor(gray: 0, alpha: 0.7))
        CTFrameDraw(frame, context)
        context.restoreGState()
    }
}
