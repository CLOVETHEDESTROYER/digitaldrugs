import AVFoundation

/// Matches the app's Deep Sleep Delta, 7Hz Theta, and Manifestation Visualization sessions.
enum StudioBeat: String, Codable, CaseIterable, Identifiable {
    case off, delta, theta, alpha
    var id: String { rawValue }
    var left: Double { switch self { case .off: return 0; case .delta: return 100; case .theta: return 200; case .alpha: return 400 } }
    var difference: Double { switch self { case .off: return 0; case .delta: return 3; case .theta: return 7; case .alpha: return 10 } }
    var title: String { self == .off ? "None" : "\(rawValue.capitalized) · \(Int(difference)) Hz" }
}

struct StudioNature: Identifiable {
    let id: String
    let title: String
    let file: String
    var url: URL { StudioResources.root.appendingPathComponent("Nature/\(file)") }
    static let all: [Self] = [
        .init(id: "continuous_river", title: "Continuous River", file: "continuous_river.m4a"),
        .init(id: "forest_ambience", title: "Forest Ambience", file: "forest_ambience.m4a"),
        .init(id: "river_valley", title: "River Valley", file: "river_valley.m4a"),
        .init(id: "thunderstorm", title: "Thunderstorm", file: "thunderstorm.m4a"),
        .init(id: "tropical_rain", title: "Tropical Rain", file: "tropical_rain.m4a"),
        .init(id: "underwater", title: "Underwater", file: "underwater.m4a"),
        .init(id: "ocean", title: "Ocean", file: "Ocean.wav")
    ]
}

struct StudioSoundscape: Codable, Equatable {
    var beat: StudioBeat = .off
    var beatVolume = 0.10
    var natureID: String?
    var natureVolume = 0.22
    var chakra: StudioChakraLayer?
    var active: Bool { (chakra?.active ?? false) || (beat != .off && beatVolume > 0) || (natureID != nil && natureVolume > 0) }
    var summary: String {
        let nature = StudioNature.all.first { $0.id == natureID }?.title
        return ([beat == .off ? nil : beat.title, nature, chakra?.summary.isEmpty == false ? chakra?.summary : nil].compactMap { $0 }).joined(separator: " + ")
    }
    func validate() throws {
        try chakra?.validate()
        guard beatVolume.isFinite, (0...0.25).contains(beatVolume), natureVolume.isFinite, (0...0.6).contains(natureVolume),
              natureID == nil || StudioNature.all.contains(where: { $0.id == natureID }) else {
            throw StudioError.message("Choose a bundled nature sound and valid background levels.")
        }
    }
}

enum StudioToneWriter {
    /// Chunked synthesis preserves phase across chunks and keeps long-session memory bounded.
    static func write(beat: StudioBeat, duration: Double, to url: URL) throws {
        guard beat != .off, duration.isFinite, duration > 0, duration <= 7200,
              let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            throw StudioError.message("Could not configure the stereo binaural track.")
        }
        let writer = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192000])
        let total = Int64((duration * 44100).rounded())
        var cursor: Int64 = 0
        while cursor < total {
            try Task.checkCancellation()
            let count = Int(min(4096, total - cursor)); buffer.frameLength = AVAudioFrameCount(count)
            let channels = buffer.floatChannelData!
            for i in 0..<count {
                let time = Double(cursor + Int64(i)) / 44100
                let fade = max(0, min(1, time / 0.7, (duration - time) / 0.9))
                channels[0][i] = Float(sin(2 * .pi * beat.left * time) * fade)
                channels[1][i] = Float(sin(2 * .pi * (beat.left + beat.difference) * time) * fade)
            }
            try writer.write(from: buffer); cursor += Int64(count)
        }
    }
}
