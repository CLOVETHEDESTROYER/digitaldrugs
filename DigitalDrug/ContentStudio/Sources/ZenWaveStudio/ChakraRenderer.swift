import AppKit
import ImageIO

/// Ports the app's seven petal constructions to the shared preview/export compositor.
final class ChakraRenderer {
    private let column: CGImage
    init() throws {
        let url = StudioResources.root.appendingPathComponent("Chakra/chakra-column.png")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw StudioError.message("The chakra column artwork is missing. Rebuild Content Studio.")
        }
        column = image
    }
    func draw(in context: CGContext, width: CGFloat, height: CGFloat, time: Double, audioTime: Double,
              energy: Double, settings: ExportSettings) {
        guard settings.style >= 26 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let amount = min(2, max(0, settings.motionAmount))
        if settings.style == 33 {
            let available = CGRect(x: width * 0.04, y: height * (settings.captions ? 0.35 : 0.22), width: width * 0.92, height: height * (settings.captions ? 0.59 : 0.70))
            let fit = min(available.width / CGFloat(column.width), available.height / CGFloat(column.height))
            let w = CGFloat(column.width) * fit, h = CGFloat(column.height) * fit
            let rect = CGRect(x: available.midX - w / 2, y: available.midY - h / 2, width: w, height: h)
            context.interpolationQuality = .high
            context.draw(column, in: rect)
            let nodes = [0.775, 0.675, 0.578, 0.478, 0.378, 0.238, 0.151]
            let layer = settings.soundscape.chakra
            let active = layer?.active == true ? layer!.activeIDs(at: audioTime) : Set(StudioChakra.all.map(\.id))
            for (index, chakra) in StudioChakra.all.enumerated() where active.contains(chakra.id) {
                let center = CGPoint(x: rect.midX, y: rect.maxY - h * nodes[index])
                let breath = 0.5 - 0.5 * cos(time * 2 * .pi / chakra.cadence + Double(index) * 0.7)
                let radius = w * (0.048 + (breath * 0.018 + energy * 0.025) * amount)
                glow(in: context, at: center, radius: radius * 2.3, color: chakra.color, alpha: 0.14 + energy * 0.3)
                context.setStrokeColor(chakra.color.copy(alpha: 0.22 + 0.28 * breath)!)
                context.setLineWidth(max(0.6, w / 850))
                context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            // Gentle ascending particles continue even between layer onsets.
            for index in 0..<18 {
                let progress = (time * 0.045 + Double(index) / 18).truncatingRemainder(dividingBy: 1)
                let y = rect.minY + h * (0.15 + progress * 0.70)
                let x = rect.midX + sin(progress * .pi * 5 + time * 0.16) * w * 0.016 * amount
                context.setFillColor(CGColor(red: 1, green: 0.85, blue: 0.52, alpha: (0.25 + energy * 0.3) * sin(progress * .pi)))
                context.fillEllipse(in: CGRect(x: x, y: y, width: max(1, w * 0.003), height: max(1, w * 0.003)))
            }
            return
        }
        guard let chakra = StudioChakra.all[safe: settings.style - 26] else { return }
        let radius = min(width * 0.44, height * 0.32)
        let center = CGPoint(x: width / 2, y: height * 0.55)
        let breath = 0.5 - 0.5 * cos(time * 2 * .pi / chakra.cadence)
        glow(in: context, at: center, radius: radius * (0.8 + breath * 0.2), color: chakra.color, alpha: 0.10 + energy * 0.20)
        context.translateBy(x: center.x, y: center.y)
        let scale = 1 + (breath * 0.12 + energy * 0.10) * amount
        // The source Canvas uses a downward Y axis; preserve its symbol orientation.
        context.scaleBy(x: scale, y: -scale)
        context.setLineWidth(max(0.6, radius / 320))
        context.setStrokeColor(chakra.color.copy(alpha: 0.2)!)
        context.strokeEllipse(in: circle(radius * 0.86))
        let rotation = sin(time * .pi / 10) * (chakra.id == "crown" ? 0.19 : 0.15) * amount
        let widthFactor = chakra.id == "root" ? 0.40 + breath * 0.34 : chakra.id == "thirdEye" ? 0.42 + breath * 0.24 : 3.2 / Double(chakra.petals) * (0.72 + breath * 0.4)
        let length = radius * (0.68 + breath * 0.20 * amount)
        let glowPath = CGMutablePath()
        for ring in 0..<(chakra.id == "crown" ? 2 : 1) {
            for petal in 0..<chakra.petals {
                let flow = chakra.id == "sacral" ? sin(time * .pi / 5 + Double(petal) * .pi / 3) * 0.07 * amount : 0
                let angle = Double(petal) * 2 * .pi / Double(chakra.petals) + rotation + flow + (chakra.id == "thirdEye" ? .pi / 2 : 0) + (ring == 1 ? .pi / Double(chakra.petals) : 0)
                glowPath.addPath(petalPath(length: length * (ring == 0 ? 1 : 0.8), width: radius * widthFactor, base: radius * 0.16), transform: CGAffineTransform(rotationAngle: angle))
            }
        }
        context.setShadow(offset: .zero, blur: radius * 0.025, color: chakra.color.copy(alpha: 0.45))
        context.setStrokeColor(chakra.color.copy(alpha: 0.22)!); context.addPath(glowPath); context.strokePath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        for ring in 0..<(chakra.id == "crown" ? 2 : 1) {
            for petal in 0..<chakra.petals {
                context.saveGState()
                let flow = chakra.id == "sacral" ? sin(time * .pi / 5 + Double(petal) * .pi / 3) * 0.07 * amount : 0
                context.rotate(by: Double(petal) * 2 * .pi / Double(chakra.petals) + rotation + flow + (chakra.id == "thirdEye" ? .pi / 2 : 0) + (ring == 1 ? .pi / Double(chakra.petals) : 0))
                let petalLength = length * (ring == 0 ? 1 : 0.8)
                let path = petalPath(length: petalLength, width: radius * widthFactor, base: radius * 0.16)
                context.setFillColor(chakra.color.copy(alpha: 0.045 + energy * 0.05)!)
                context.addPath(path); context.fillPath()
                for contour in 0..<(chakra.id == "crown" ? 3 : 7) {
                    let factor = 1 - Double(contour) * (chakra.id == "crown" ? 0.08 : 0.057)
                    context.setStrokeColor(chakra.color.copy(alpha: 0.82 - Double(contour) * 0.085)!)
                    context.setLineWidth(max(0.5, radius / 320) * (contour == 0 ? 1.3 : 0.75))
                    context.addPath(petalPath(length: petalLength * factor, width: radius * widthFactor * factor, base: radius * 0.16)); context.strokePath()
                }
                context.restoreGState()
            }
        }
        if ["throat", "solar", "thirdEye"].contains(chakra.id) {
            for index in 0..<3 {
                let phase = (time / 8 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                context.setStrokeColor(chakra.color.copy(alpha: (1 - phase) * 0.22)!)
                context.strokeEllipse(in: circle(radius * (0.22 + phase * 0.64)))
            }
        }
        let core = radius * (0.18 + breath * 0.025)
        context.setFillColor(CGColor(red: 0.015, green: 0.02, blue: 0.045, alpha: 0.95)); context.fillEllipse(in: circle(core))
        context.setStrokeColor(chakra.color.copy(alpha: 0.9)!); context.strokeEllipse(in: circle(core))
        switch chakra.id {
        case "root": triangle(in: context, radius: core, inverted: true)
        case "heart": triangle(in: context, radius: core, inverted: true); triangle(in: context, radius: core, inverted: false)
        case "solar", "thirdEye": triangle(in: context, radius: core, inverted: false)
        case "sacral":
            let path = CGMutablePath(); let r = core * 0.69
            path.addArc(center: .zero, radius: r, startAngle: -.pi * 40 / 180, endAngle: .pi * 220 / 180, clockwise: false)
            path.addQuadCurve(to: CGPoint(x: r * cos(-.pi * 40 / 180), y: r * sin(-.pi * 40 / 180)), control: CGPoint(x: 0, y: core * 0.88))
            context.addPath(path); context.strokePath()
        case "throat": context.strokeEllipse(in: circle(core * 0.63))
        default: glow(in: context, at: .zero, radius: core, color: chakra.color, alpha: 0.65)
        }
    }
    private func circle(_ r: CGFloat) -> CGRect { CGRect(x: -r, y: -r, width: r * 2, height: r * 2) }
    private func petalPath(length: CGFloat, width: CGFloat, base: CGFloat) -> CGPath {
        let path = CGMutablePath(); path.move(to: CGPoint(x: 0, y: -base))
        path.addCurve(to: CGPoint(x: 0, y: -length), control1: CGPoint(x: -width, y: -length * 0.33), control2: CGPoint(x: -width * 0.54, y: -length * 0.91))
        path.addCurve(to: CGPoint(x: 0, y: -base), control1: CGPoint(x: width * 0.54, y: -length * 0.91), control2: CGPoint(x: width, y: -length * 0.33)); path.closeSubpath(); return path
    }
    private func triangle(in context: CGContext, radius: CGFloat, inverted: Bool) {
        let direction: CGFloat = inverted ? 1 : -1
        context.move(to: CGPoint(x: -radius * 0.62, y: -direction * radius * 0.36)); context.addLine(to: CGPoint(x: radius * 0.62, y: -direction * radius * 0.36)); context.addLine(to: CGPoint(x: 0, y: direction * radius * 0.7)); context.closePath(); context.strokePath()
    }
    private func glow(in context: CGContext, at point: CGPoint, radius: CGFloat, color: CGColor, alpha: CGFloat) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color.copy(alpha: alpha)!, color.copy(alpha: 0)!] as CFArray, locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: point, startRadius: 0, endCenter: point, endRadius: radius, options: [])
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
