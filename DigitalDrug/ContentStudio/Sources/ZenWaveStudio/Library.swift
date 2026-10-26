import Foundation
import AVFoundation

struct Cue: Codable, Identifiable, Hashable {
    var start: Double
    var end: Double
    var text: String
    var id: Double { start }
}

struct Mantra: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let fileName: String
    let timing: String
    let category: String
    let cues: [Cue]
    var audioURL: URL { StudioResources.root.appendingPathComponent("Audio/\(fileName)") }
    var estimated: Bool { timing == "estimated" }
}

enum StudioResources {
    static var root: URL {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("StudioResources")
        if let bundled, FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        // SwiftPM’s two build engines use different layouts for copied resource directories.
        let module = Bundle.module
        let candidates = [module.resourceURL!.appendingPathComponent("Resources"),
                          module.resourceURL!, module.bundleURL.appendingPathComponent("Resources")]
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("catalog.json").path) }
            ?? module.resourceURL!
    }
    static func library() throws -> [Mantra] {
        let records = try JSONDecoder().decode([Mantra].self, from: Data(contentsOf: root.appendingPathComponent("catalog.json")))
        for record in records where !FileManager.default.fileExists(atPath: record.audioURL.path) {
            throw StudioError.message("Missing recording: \(record.fileName). Rebuild the studio with Tools/build-app.sh.")
        }
        return records
    }
}

enum StudioError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}

struct VisualStyle: Identifiable, Hashable {
    let id: Int
    let title: String
    static let all: [VisualStyle] = [
        .init(id: 3, title: "Signature Waves"), .init(id: 0, title: "Scope"),
        .init(id: 1, title: "Bloom"), .init(id: 2, title: "Tunnel"),
        .init(id: 4, title: "Deep Particles"), .init(id: 5, title: "Kaleidoscope"),
        .init(id: 6, title: "Star Drift"), .init(id: 7, title: "Nebula Flight"),
        .init(id: 8, title: "Orbital Waves"), .init(id: 9, title: "Liquid Constellations"),
        .init(id: 10, title: "Prismatic Bloom"), .init(id: 11, title: "Aurora Veil"),
        .init(id: 12, title: "Tidal Flow"), .init(id: 13, title: "Signature Mark"),
        .init(id: 14, title: "Prismatic Wormhole"), .init(id: 15, title: "Aurora Wormhole"),
        .init(id: 16, title: "Cosmic Vortex"), .init(id: 17, title: "Liquid Portal"),
        .init(id: 18, title: "Crystal Lotus"), .init(id: 19, title: "Radiant Iris"),
        .init(id: 20, title: "Merkaba"), .init(id: 21, title: "Metatron’s Cube"),
        .init(id: 22, title: "Flower of Life"), .init(id: 23, title: "Seed of Life"),
        .init(id: 24, title: "Vesica Piscis"), .init(id: 25, title: "Octahedral Halo"),
        .init(id: 26, title: "Root Chakra"),
        .init(id: 27, title: "Sacral Chakra"),
        .init(id: 28, title: "Solar Plexus Chakra"),
        .init(id: 29, title: "Heart Chakra"),
        .init(id: 30, title: "Throat Chakra"),
        .init(id: 31, title: "Third Eye Chakra"),
        .init(id: 32, title: "Crown Chakra"),
        .init(id: 33, title: "Chakra Column"),
        .init(id: 34, title: "Resonance Orb"), .init(id: 35, title: "Flowing Torus"),
        .init(id: 36, title: "Event Horizon"), .init(id: 37, title: "Aurora Slipstream"),
        .init(id: 38, title: "Crystal Stargate"), .init(id: 39, title: "Nebula Drift")
    ]
}

struct VisualPalette: Identifiable {
    let id: Int
    let title: String
    let colors: [UInt32]
    static let all: [VisualPalette] = [
        .init(id: 0, title: "Original", colors: [0x08CCE0, 0x803DEB, 0xD5A8F5]),
        .init(id: 1, title: "Opal Spectrum", colors: [0x58E7E2, 0xEA7FC5, 0xF8D983]),
        .init(id: 2, title: "Rose Gold", colors: [0x9D3869, 0xF39D9D, 0xFFE0A6]),
        .init(id: 3, title: "Solar Flare", colors: [0x9E174A, 0xFA5633, 0xFFCF4D]),
        .init(id: 4, title: "Emerald Tide", colors: [0x09534E, 0x1DC998, 0xC1ED87]),
        .init(id: 5, title: "Glacier", colors: [0x154C9E, 0x54CDEB, 0xDAF8FF]),
        .init(id: 6, title: "Ultraviolet", colors: [0x4924A8, 0xB536E8, 0xFBA4EB]),
        .init(id: 7, title: "Candy Nebula", colors: [0x55A1FF, 0xF24AAC, 0xFFABCE]),
        .init(id: 8, title: "Ocean Sunset", colors: [0x10ADA8, 0xB056BA, 0xFFAE67])
    ]
}

enum VideoFormat: String, CaseIterable, Identifiable, Codable {
    case portrait = "Vertical · 9:16"
    case square = "Square · 1:1"
    case landscape = "Landscape · 16:9"
    var id: String { rawValue }
    var width: Int { self == .landscape ? 1920 : 1080 }
    var height: Int { self == .portrait ? 1920 : 1080 }
}

struct ExportSettings: Codable, Equatable {
    var style = 3
    var palette = 0
    var format: VideoFormat = .portrait
    var captions = true
    var branding = true
    var brandStyle: StudioBrandStyle = .logoAndWordmark
    var logoSize = 0.14
    var logoOpacity = 0.9
    var heading = ""
    var headingEmphasis = 1.0
    var captionOffset = 0.0
    var motionSpeed = 1.0
    var motionAmount = 1.0
    var audioResponse = 1.0
    var backgroundVolume = 0.22
    var soundscape = StudioSoundscape()
    var callToAction = StudioCallToAction()

    // New controls retain their defaults when loading a preset from an older studio build.
    init() {}
    private enum CodingKeys: String, CodingKey {
        case style, palette, format, captions, branding, brandStyle, logoSize, logoOpacity, heading, headingEmphasis, captionOffset
        case motionSpeed, motionAmount, audioResponse, backgroundVolume, soundscape, callToAction
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = try c.decodeIfPresent(Int.self, forKey: .style) ?? 3
        if !VisualStyle.all.contains(where: { $0.id == style }) { style = 3 }
        palette = try c.decodeIfPresent(Int.self, forKey: .palette) ?? 0
        if !VisualPalette.all.contains(where: { $0.id == palette }) { palette = 0 }
        format = try c.decodeIfPresent(VideoFormat.self, forKey: .format) ?? .portrait
        captions = try c.decodeIfPresent(Bool.self, forKey: .captions) ?? true
        branding = try c.decodeIfPresent(Bool.self, forKey: .branding) ?? true
        brandStyle = try c.decodeIfPresent(StudioBrandStyle.self, forKey: .brandStyle) ?? .logoAndWordmark
        logoSize = min(0.20, max(0.08, try c.decodeIfPresent(Double.self, forKey: .logoSize) ?? 0.14))
        logoOpacity = min(1, max(0.25, try c.decodeIfPresent(Double.self, forKey: .logoOpacity) ?? 0.9))
        heading = try c.decodeIfPresent(String.self, forKey: .heading) ?? ""
        headingEmphasis = min(2.4, max(0.75, try c.decodeIfPresent(Double.self, forKey: .headingEmphasis) ?? 1))
        captionOffset = try c.decodeIfPresent(Double.self, forKey: .captionOffset) ?? 0
        motionSpeed = try c.decodeIfPresent(Double.self, forKey: .motionSpeed) ?? 1
        motionAmount = try c.decodeIfPresent(Double.self, forKey: .motionAmount) ?? 1
        audioResponse = try c.decodeIfPresent(Double.self, forKey: .audioResponse) ?? 1
        backgroundVolume = try c.decodeIfPresent(Double.self, forKey: .backgroundVolume) ?? 0.22
        soundscape = try c.decodeIfPresent(StudioSoundscape.self, forKey: .soundscape) ?? StudioSoundscape()
        callToAction = try c.decodeIfPresent(StudioCallToAction.self, forKey: .callToAction) ?? StudioCallToAction()
    }
    static func load() -> ExportSettings {
        guard let data = UserDefaults.standard.data(forKey: "exportSettings"),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "exportSettings") }
    }
}
