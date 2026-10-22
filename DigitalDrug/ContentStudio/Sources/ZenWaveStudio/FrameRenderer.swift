import AppKit
import Metal
import CoreText

private struct Uniforms {
    var time: Float, intensity: Float, activity: Float, aspect: Float, opacity: Float
    var level: Float, peak: Float, bass: Float, mids: Float, treble: Float
    var beatFrequency: Float, style: Float, presentation: Float, light: Float
}

/// The very same fragment shader as the iPhone app, rendered into an offscreen texture.
///
/// On Intel Macs, GPU render targets must use private storage. We blit into a shared
/// texture before `getBytes` so CPU readback sees the shader output (Apple silicon can
/// often skip this, but the blit path is correct everywhere).
final class FrameRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    /// GPU-only render target.
    private var renderTexture: MTLTexture?
    /// CPU-readable copy after blit.
    private var readbackTexture: MTLTexture?
    private var pixels: [UInt8] = []

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw StudioError.message("A Mac with Metal support is required to render these visualizers.")
        }
        self.device = device
        self.queue = queue
        // Discrete GPUs (e.g. Radeon on Intel Macs) need managed readback + synchronize;
        // unified-memory GPUs can use shared storage directly.
        let source = try String(contentsOf: StudioResources.root.appendingPathComponent("Visualizer.metal"), encoding: .utf8)
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
               envelope: AudioEnvelope, mantra: Mantra, settings: ExportSettings) throws -> CGImage {
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

        let (level, peak) = envelope.signal(at: audioTime)
        var u = Uniforms(
            time: Float(time), intensity: 0.7, activity: 1,
            aspect: Float(width) / Float(height), opacity: 1,
            level: level, peak: peak, bass: level * 0.82, mids: level, treble: peak * 0.72,
            beatFrequency: 0, style: Float(settings.style), presentation: 2, light: 0
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
            let scale = min(w / 1080, h / 1920)
            let caption = settings.captions ? mantra.cues.first(where: {
                audioTime - settings.captionOffset >= $0.start && audioTime - settings.captionOffset < $0.end
            })?.text : nil
            // Keep type inside the middle 72% width, away from social player controls.
            if let caption {
                let box = CGRect(x: w * 0.12, y: h * 0.32, width: w * 0.76, height: h * 0.32)
                context.setFillColor(CGColor(gray: 0, alpha: 0.36))
                context.addPath(CGPath(roundedRect: box.insetBy(dx: -18 * scale, dy: 0), cornerWidth: 24 * scale, cornerHeight: 24 * scale, transform: nil))
                context.fillPath()
                drawText(caption, context: context, rect: box.insetBy(dx: 18 * scale, dy: 18 * scale), size: 58 * scale, weight: .semibold, centered: true)
            }
            if !settings.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                drawText(settings.heading, context: context,
                         rect: CGRect(x: w * 0.12, y: h * 0.78, width: w * 0.76, height: h * 0.12),
                         size: 33 * scale, weight: .medium, centered: true)
            }
            if settings.branding {
                drawText("ZENWAVE", context: context,
                         rect: CGRect(x: w * 0.15, y: h * 0.14, width: w * 0.7, height: h * 0.04),
                         size: 26 * scale, weight: .medium, centered: true)
            }
            guard let image = context.makeImage() else {
                throw StudioError.message("The video frame was empty.")
            }
            return image
        }
    }

    private func ensureTextures(width: Int, height: Int) throws {
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
