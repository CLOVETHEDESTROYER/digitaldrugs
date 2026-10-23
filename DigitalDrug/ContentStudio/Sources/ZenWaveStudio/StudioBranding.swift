import Foundation
import AppKit
import CoreGraphics
import ImageIO

enum StudioBrandStyle: String, Codable, CaseIterable, Identifiable {
    case logoAndWordmark = "Logo + wordmark"
    case logo = "Official logo"
    case wordmark = "Wordmark only"
    var id: String { rawValue }
    var showsLogo: Bool { self != .wordmark }
    var showsWordmark: Bool { self != .logo }
}

enum StudioBranding {
    static var logoURL: URL { StudioResources.root.appendingPathComponent("Brand/ZenWaveLogo.png") }
    static let previewImage = NSImage(contentsOf: logoURL) ?? NSImage()
    static func loadLogo() throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(logoURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw StudioError.message("The ZenWave logo is missing. Rebuild Content Studio to include its branding assets.")
        }
        return image
    }
    static func logoRect(width: CGFloat, height: CGFloat, settings: ExportSettings) -> CGRect {
        let both = settings.brandStyle == .logoAndWordmark
        let bottom = height * (both ? 0.16 : 0.14)
        let size = min(min(width, height) * min(0.20, max(0.08, settings.logoSize)), height * (both ? 0.14 : 0.16))
        if settings.style == 33 {
            let columnSize = min(size, height * 0.09)
            return CGRect(x: (width - columnSize) / 2, y: height * 0.10, width: columnSize, height: columnSize)
        }
        return CGRect(x: (width - size) / 2, y: bottom, width: size, height: size)
    }
}
