import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class VisualLabTests: XCTestCase {
    func testBackgroundPCMRetainsStereoAndPadsEndWithSilence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zenwave-pcm-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("background.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
        buffer.frameLength = 4800
        for i in 0..<4800 {
            let value = Float(sin(Double(i) / 48000 * 200 * .pi * 2) * 0.3)
            buffer.floatChannelData![0][i] = value; buffer.floatChannelData![1][i] = -value
        }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        let reader = try VisualLabPCM(backgroundURL: url)
        let samples = try reader.samples(at: 0)
        XCTAssertEqual(samples.mono.count, 1024); XCTAssertEqual(samples.left.count, 1024)
        XCTAssertGreaterThan(Set(samples.mono).count, 20, "Opposite-phase backgrounds must retain motion")
        XCTAssertNotEqual(samples.left, samples.right)
        let end = try reader.samples(at: 1)
        XCTAssertTrue(end.mono.allSatisfy { $0 == 128 }); XCTAssertTrue(end.left.allSatisfy { $0 == 128 })
    }

    func testShortComparisonMixExcludesVoiceFromBackgroundSamples() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zenwave-lab-mix-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func tone(_ name: String, _ frequency: Double) throws -> URL {
            let url = root.appendingPathComponent(name + ".wav")
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 3)!
            pcm.frameLength = pcm.frameCapacity
            for i in 0..<Int(pcm.frameLength) {
                let value = Float(sin(Double(i) / 44100 * frequency * .pi * 2) * 0.7)
                pcm.floatChannelData![0][i] = value; pcm.floatChannelData![1][i] = value
            }
            let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: pcm)
            return url
        }
        let voice = try tone("voice", 4400), background = try tone("nature-fixture", 200)
        let motion = root.appendingPathComponent("motion.m4a")
        let mixed = try await AudioMix.prepare(voice: voice, background: background, volume: 0.22,
            output: root.appendingPathComponent("mix.m4a"), motionOutput: motion, maximumDuration: 1.2)
        let duration = Double(try AVAudioFile(forReading: mixed).length) / 44100
        XCTAssertEqual(duration, 1.2, accuracy: 0.06)
        let samples = try VisualLabPCM(backgroundURL: motion).samples(at: 0.55).left
        func amplitude(_ frequency: Double) -> Double {
            let values = samples.map { (Double($0) - 128) / 127 }
            let a = values.enumerated().reduce(0.0) { $0 + $1.element * sin(Double($1.offset) / 44100 * frequency * .pi * 2) }
            let b = values.enumerated().reduce(0.0) { $0 + $1.element * cos(Double($1.offset) / 44100 * frequency * .pi * 2) }
            return 2 * hypot(a, b) / Double(values.count)
        }
        XCTAssertGreaterThan(amplitude(200), 0.08)
        XCTAssertLessThan(amplitude(4400), 0.015, "Mantra narration must never enter Butterchurn's samples")
    }
}
