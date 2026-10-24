import AppKit
import CoreText

final class BreathRenderer {
    private var background: FrameRenderer?
    private var logo: CGImage?
    func frame(width: Int, height: Int, time: Double, envelope: AudioEnvelope, plan: BreathPlan, settings: ExportSettings) throws -> CGImage {
        if background == nil { background = try FrameRenderer(); logo = try StudioBranding.loadLogo() }
        let w = CGFloat(width), h = CGFloat(height), unit = min(w, h)
        var backdrop = settings
        backdrop.captions = false; backdrop.heading = ""; backdrop.branding = false; backdrop.callToAction.enabled = false
        // Restrict backgrounds to quiet flow/space modes. The guide itself never follows sound energy.
        if ![6, 7, 10, 11, 12, 15].contains(backdrop.style) { backdrop.style = 11 }
        let image = try background!.frame(width: width, height: height, time: time, audioTime: time, envelope: envelope, mantra: plan.mantra, settings: backdrop)
        guard let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw StudioError.message("Could not render the breathing guide.") }
        let frame = CGRect(x: 0, y: 0, width: w, height: h)
        c.draw(image, in: frame); c.setFillColor(CGColor(gray: 0.005, alpha: 0.68)); c.fill(frame)
        let moment = plan.moment(at: time), phase = moment.segment.phase
        let center = CGPoint(x: w * 0.5, y: h * 0.52)
        let guideUnit = unit * (settings.callToAction.enabled && h <= w ? 0.8 : 1)
        let maxRadius = guideUnit * 0.255, radius = guideUnit * (0.12 + 0.135 * moment.fill)
        let colors = (VisualPalette.all.first { $0.id == settings.palette } ?? VisualPalette.all[0]).colors
        func color(_ hex: UInt32, _ alpha: CGFloat) -> CGColor {
            CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
        }
        let accent = color(colors[0], 1), light = color(colors.last!, 1)
        // A fixed outer orbit makes the expansion readable; hold motion stays on the orbit.
        c.setStrokeColor(accent.copy(alpha: 0.22)!); c.setLineWidth(unit * 0.002)
        c.strokeEllipse(in: CGRect(x: center.x - maxRadius, y: center.y - maxRadius, width: maxRadius * 2, height: maxRadius * 2))
        c.saveGState()
        c.setShadow(offset: .zero, blur: unit * 0.05, color: accent.copy(alpha: 0.45))
        c.setFillColor(accent.copy(alpha: 0.2)!); c.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        c.restoreGState()
        c.saveGState()
        c.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)); c.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [light.copy(alpha: 0.7)!, accent.copy(alpha: 0.48)!, color(colors[1], 0.32)] as CFArray, locations: [0, 0.5, 1])!
        c.drawRadialGradient(gradient, startCenter: CGPoint(x: center.x - radius * 0.35, y: center.y + radius * 0.4), startRadius: 0,
            endCenter: center, endRadius: radius * 1.4, options: [.drawsAfterEndLocation])
        c.restoreGState()
        c.setLineWidth(unit * 0.003); c.setStrokeColor(light.copy(alpha: 0.9)!)
        c.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        let orbit = CGFloat(time * 0.32), point = CGPoint(x: center.x + maxRadius * cos(orbit), y: center.y + maxRadius * sin(orbit))
        c.setFillColor(light); c.fillEllipse(in: CGRect(x: point.x - unit * 0.006, y: point.y - unit * 0.006, width: unit * 0.012, height: unit * 0.012))
        let countdown = phase == .finish ? "∞" : String(moment.countdown)
        Self.drawCountdown(countdown, context: c, center: center, size: unit * 0.105)
        text(phase.title, c, CGRect(x: w * 0.1, y: center.y + maxRadius + guideUnit * 0.045, width: w * 0.8, height: guideUnit * 0.075), unit * 0.045, .medium)
        let detail = phase == .ready ? "Follow the circle • Never force the breath" : phase == .finish ? "Return to your own comfortable rhythm" : "Cycle \(moment.segment.cycle) of \(plan.cycles) • \(plan.inhale) in / \(plan.hold) hold / \(plan.exhale) out / \(plan.pause) pause"
        text(detail, c, CGRect(x: w * 0.1, y: center.y - maxRadius - guideUnit * 0.09, width: w * 0.8, height: unit * 0.045), unit * 0.022, .regular)
        if plan.voice != .off && (phase == .ready || phase == .finish) {
            text("AI-generated voice", c, CGRect(x: w * 0.1, y: center.y + maxRadius + guideUnit * 0.005, width: w * 0.8, height: guideUnit * 0.03), unit * 0.018, .regular)
        }
        if settings.branding {
            if settings.brandStyle.showsLogo, let logo {
                let size = min(unit * settings.logoSize, h * 0.075)
                c.saveGState(); c.setAlpha(settings.logoOpacity)
                c.draw(logo, in: CGRect(x: (w - size) / 2, y: h * 0.075, width: size, height: size)); c.restoreGState()
            }
            if settings.brandStyle.showsWordmark { text("ZENWAVE", c, CGRect(x: w * 0.2, y: h * 0.035, width: w * 0.6, height: h * 0.03), unit * 0.019, .medium) }
        }
        guard let result = c.makeImage() else { throw StudioError.message("The breathing frame was empty.") }
        return try background!.overlayCallToAction(on: result, time: time, settings: settings, rectOverride: Self.callToActionRect(width: w, height: h, settings: settings))
    }
    static func callToActionRect(width: CGFloat, height: CGFloat, settings: ExportSettings) -> CGRect {
        CGRect(x: width * 0.12, y: height * (settings.callToAction.placement == .upper ? 0.90 : 0.16), width: width * 0.76, height: height * 0.075)
    }
    /// Center the actual glyph outlines, rather than a top-aligned paragraph box.
    /// This keeps narrow digits, two-digit counts and the finish symbol centered on both axes.
    static func drawCountdown(_ value: String, context: CGContext, center: CGPoint, size: CGFloat) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .ultraLight),
            .foregroundColor: NSColor.white
        ]))
        let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        context.saveGState(); defer { context.restoreGState() }
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
        CTLineDraw(line, context)
    }
    private func text(_ text: String, _ c: CGContext, _ rect: CGRect, _ size: CGFloat, _ weight: NSFont.Weight) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
        let setter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let frame = CTFramesetterCreateFrame(setter, CFRange(), CGPath(rect: rect, transform: nil), nil)
        c.saveGState(); c.textMatrix = .identity; CTFrameDraw(frame, c); c.restoreGState()
    }
}
