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
        .init(id: 10, title: "Prismatic Bloom"), .init(id: 11, title: "Aurora Veil")
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
    var format: VideoFormat = .portrait
    var captions = true
    var branding = true
    var heading = ""
    var captionOffset = 0.0
    static func load() -> ExportSettings {
        guard let data = UserDefaults.standard.data(forKey: "exportSettings"),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "exportSettings") }
    }
}

/// Analyze the original recording once. Export and preview use the same frame-indexed envelope.
struct AudioEnvelope {
    let duration: Double
    let levels: [Float]
    let peaks: [Float]
    init(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        duration = Double(file.length) / format.sampleRate
        guard duration.isFinite, duration > 0 else { throw StudioError.message("This recording is empty.") }
        let hop = AVAudioFrameCount(max(1, Int(format.sampleRate / 30)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: hop) else {
            throw StudioError.message("Could not allocate audio analysis buffer.")
        }
        var levels: [Float] = [], peaks: [Float] = []
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: hop)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            var sum: Float = 0, peak: Float = 0
            for frame in 0..<Int(buffer.frameLength) {
                var value: Float = 0
                for channel in 0..<Int(format.channelCount) { value += channels[channel][frame] }
                value /= Float(format.channelCount)
                sum += value * value
                peak = max(peak, abs(value))
            }
            func normalize(_ value: Float) -> Float { min(1, max(0, (20 * log10(max(value, 0.000001)) + 60) / 60)) }
            levels.append(normalize(sqrt(sum / Float(buffer.frameLength))))
            peaks.append(normalize(peak))
        }
        self.levels = levels; self.peaks = peaks
    }
    func signal(at time: Double) -> (Float, Float) {
        guard !levels.isEmpty else { return (0, 0) }
        let i = min(levels.count - 1, max(0, Int(time * 30)))
        return (levels[i], peaks[i])
    }
}
