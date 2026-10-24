import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class SoundscapeTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("studio-sound-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func voice(at url: URL, frequency: Double = 1700, amplitude: Double = 0.8) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 4)!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let value = Float(sin(2 * .pi * frequency * Double(i) / 44100) * amplitude)
            buffer.floatChannelData![0][i] = value; buffer.floatChannelData![1][i] = value
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
    private func read(_ url: URL) async throws -> [[Float]] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false])
        reader.add(output); XCTAssertTrue(reader.startReading())
        var channels = [[Float](), [Float]()]
        while let sample = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(sample) {
            let length = CMBlockBufferGetDataLength(block)
            var values = [Float](repeating: 0, count: length / 4)
            _ = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            for i in stride(from: 0, to: values.count - 1, by: 2) { channels[0].append(values[i]); channels[1].append(values[i + 1]) }
        }
        XCTAssertEqual(reader.status, .completed)
        return channels
    }
    private func amplitude(_ samples: [Float], at frequency: Double) -> Double {
        let range = 44100..<min(88200, samples.count)
        var real = 0.0, imaginary = 0.0
        for i in range {
            let phase = 2 * .pi * frequency * Double(i) / 44100
            real += Double(samples[i]) * cos(phase); imaginary += Double(samples[i]) * sin(phase)
        }
        return 2 * hypot(real, imaginary) / Double(range.count)
    }

    func testEveryBeatHasCorrectSeparateStereoFrequenciesAndFades() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        for beat in [StudioBeat.delta, .theta, .alpha] {
            let url = root.appendingPathComponent("\(beat.rawValue).m4a")
            try StudioToneWriter.write(beat: beat, duration: 4, to: url)
            let channels = try await read(url)
            XCTAssertEqual(Double(channels[0].count) / 44100, 4, accuracy: 0.03)
            XCTAssertGreaterThan(amplitude(channels[0], at: beat.left), 0.8)
            XCTAssertGreaterThan(amplitude(channels[1], at: beat.left + beat.difference), 0.8)
            XCTAssertLessThan(amplitude(channels[0], at: beat.left + beat.difference), 0.03)
            XCTAssertLessThan(amplitude(channels[1], at: beat.left), 0.03)
            XCTAssertLessThan(channels[0].prefix(100).map { abs($0) }.max()!, 0.05)
            XCTAssertLessThan(channels[0].suffix(100).map { abs($0) }.max()!, 0.05)
        }
    }

    func testAllNatureAssetsAndLayeredMixPreserveDurationAndVoice() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("voice.caf"), music = root.appendingPathComponent("music.caf")
        try voice(at: original); try voice(at: music, frequency: 900)
        for nature in StudioNature.all {
            let file = try AVAudioFile(forReading: nature.url)
            XCTAssertGreaterThan(file.length, 4410)
            var audio = StudioSoundscape(); audio.beat = .theta; audio.natureID = nature.id
            audio.beatVolume = 0.25; audio.natureVolume = 0.6
            let result = try await AudioMix.prepare(voice: original, background: music, volume: 0.6,
                output: root.appendingPathComponent("\(nature.id).m4a"), soundscape: audio)
            let channels = try await read(result)
            XCTAssertEqual(Double(channels[0].count) / 44100, 4, accuracy: 0.03)
            XCTAssertGreaterThan(amplitude(channels[0], at: 1700), 0.25, "Voice stays present with all layers")
            XCTAssertGreaterThan(amplitude(channels[0], at: 200), 0.05)
            XCTAssertGreaterThan(amplitude(channels[1], at: 207), 0.05)
            XCTAssertLessThan(channels.flatMap { $0 }.map { abs($0) }.max()!, 1.02)
        }
        let passthrough = try await AudioMix.prepare(voice: original, background: nil, volume: 0.22, output: root.appendingPathComponent("unused.m4a"))
        XCTAssertEqual(passthrough, original)
    }

    func testMuxedMovieRetainsBinauralStereo() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("voice.caf"); try voice(at: original, amplitude: 0.1)
        var settings = ExportSettings(); settings.captions = false; settings.soundscape.beat = .delta; settings.soundscape.beatVolume = 0.2
        let audio = try await AudioMix.prepare(voice: original, background: nil, volume: 0,
            output: root.appendingPathComponent("mix.m4a"), soundscape: settings.soundscape)
        let mantra = try XCTUnwrap(StudioResources.library().first)
        let job = ExportJob(mantra: mantra, settings: settings, start: 0, end: 4, preparedAudio: audio)
        let output = root.appendingPathComponent("stereo.mp4")
        try await VideoExporter.export(job, to: output, widthOverride: 168, heightOverride: 300, recordHistory: false) { _ in }
        let channels = try await read(output)
        XCTAssertGreaterThan(amplitude(channels[0], at: 100), 0.15)
        XCTAssertGreaterThan(amplitude(channels[1], at: 103), 0.15)
        XCTAssertLessThan(amplitude(channels[0], at: 103), 0.02)
        XCTAssertLessThan(amplitude(channels[1], at: 100), 0.02)
    }

    func testRandomAudioChoicesAreReproducibleLockedAndBackwardCompatible() throws {
        func plan(_ seed: UInt64, keeping: [RandomClip] = []) throws -> RandomBatchPlan {
            try RandomBatchPlan.make(count: 6, seed: seed, mantras: ["a", "b"], styles: [10, 14, 20], palettes: [1, 2], settings: ExportSettings(), backgroundFile: nil, postFooter: "", keeping: keeping,
                beats: [.delta, .theta, .alpha], nature: ["ocean", "forest_ambience", "tropical_rain"])
        }
        let singleVisual = try RandomBatchPlan.make(count: 6, seed: 9, mantras: ["a"], styles: [10], palettes: [1], settings: ExportSettings(), backgroundFile: nil, postFooter: "", beats: [.delta, .theta, .alpha], nature: ["ocean", "forest_ambience"])
        XCTAssertEqual(Set(singleVisual.clips.map(\.key)).count, 6)
        let first = try plan(42); XCTAssertEqual(first, try plan(42))
        for beat in [StudioBeat.delta, .theta, .alpha] { XCTAssertEqual(first.clips.filter { $0.soundscape?.beat == beat }.count, 2) }
        for nature in ["ocean", "forest_ambience", "tropical_rain"] { XCTAssertEqual(first.clips.filter { $0.soundscape?.natureID == nature }.count, 2) }
        var keeping = first.clips; keeping[0].locked = true
        XCTAssertEqual(try plan(99, keeping: keeping).clips[0], keeping[0])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(first)) as? [String: Any])
        legacy.removeValue(forKey: "beatPool"); legacy.removeValue(forKey: "naturePool")
        var settings = legacy["settings"] as! [String: Any]; settings.removeValue(forKey: "soundscape"); legacy["settings"] = settings
        legacy["clips"] = (legacy["clips"] as! [[String: Any]]).map { clip in var result = clip; result.removeValue(forKey: "soundscape"); return result }
        let decoded = try JSONDecoder().decode(RandomBatchPlan.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(decoded.settings.soundscape.beat, .off); XCTAssertNil(decoded.beatPool); XCTAssertNil(decoded.clips[0].soundscape)
    }
}
