import XCTest
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
@testable import ZenWaveStudio

final class ChakraTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("studio-chakras-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func voice(_ url: URL, frequency: Double, duration: Double = 14, amplitude: Float = 0.6) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(duration * 44100))!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let value = amplitude * Float(sin(2 * .pi * frequency * Double(i) / 44100))
            buffer.floatChannelData![0][i] = value; buffer.floatChannelData![1][i] = value
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer)
    }
    private func mono(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
    private func amplitude(_ samples: [Float], _ frequency: Double, at start: Double) -> Double {
        let range = Int(start * 44100)..<min(samples.count, Int((start + 0.5) * 44100))
        var real = 0.0, imaginary = 0.0
        for i in range { let p = 2 * .pi * frequency * Double(i) / 44100; real += Double(samples[i]) * cos(p); imaginary += Double(samples[i]) * sin(p) }
        return 2 * hypot(real, imaginary) / Double(range.count)
    }
    func testBundledOriginalsAndExactTenSecondLoops() throws {
        XCTAssertEqual(StudioChakra.all.count, 7)
        for sound in StudioChakra.all {
            let original = try AVAudioFile(forReading: sound.recordingURL)
            XCTAssertGreaterThan(Double(original.length) / original.processingFormat.sampleRate, 10)
            let loop = try AVAudioFile(forReading: sound.loopURL)
            XCTAssertEqual(Double(loop.length) / loop.processingFormat.sampleRate, 10, accuracy: 1 / 44100)
        }
        let legacy = Data(#"{"beat":"theta","beatVolume":0.1,"natureVolume":0.2}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(StudioSoundscape.self, from: legacy).chakra)
        var layer = StudioChakraLayer(); layer.selected = ["root", "heart", "crown"]; layer.mode = .column; layer.step = 5
        XCTAssertEqual(layer.activeIDs(at: 4.99), ["root"])
        XCTAssertEqual(layer.activeIDs(at: 5), ["root", "heart"])
        XCTAssertEqual(layer.activeIDs(at: 10), layer.selected)
        layer.step = .nan; XCTAssertThrowsError(try layer.validate())
    }
    func testChakraMixBuildsAtSelectedOffsetsAndExcludesVoiceFromMotion() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a.wav"), b = root.appendingPathComponent("b.wav")
        try voice(a, frequency: 2100); try voice(b, frequency: 6500, amplitude: 0.1)
        var audio = StudioSoundscape(); var chakra = StudioChakraLayer()
        chakra.selected = ["root", "heart", "crown"]; chakra.mode = .column; chakra.step = 5; chakra.volume = 0.6; audio.chakra = chakra
        let motionA = root.appendingPathComponent("motion-a.m4a"), motionB = root.appendingPathComponent("motion-b.m4a")
        let mixed = try await AudioMix.prepare(voice: a, background: nil, volume: 0, output: root.appendingPathComponent("mix-a.m4a"), soundscape: audio, motionOutput: motionA)
        _ = try await AudioMix.prepare(voice: b, background: nil, volume: 0, output: root.appendingPathComponent("mix-b.m4a"), soundscape: audio, motionOutput: motionB)
        let x = try mono(motionA), y = try mono(motionB), playback = try mono(mixed)
        XCTAssertEqual(x.count, y.count)
        // AAC decoding can vary below one 16-bit PCM step between identical renders.
        // Keep the comparison below that quantization floor and separately reject voice frequencies.
        let maxDelta = zip(x, y).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThan(maxDelta, 1 / 32768, "Chakra motion must be independent of narration")
        XCTAssertGreaterThan(amplitude(playback, 2100, at: 2), 0.2, "Manifestation remains audible")
        XCTAssertLessThan(amplitude(x, 2100, at: 2), 0.005)
        XCTAssertLessThan(amplitude(y, 6500, at: 2), 0.005)
        // The exact same root loop recurs at 10 sec; later layers add energy without shifting its phase.
        XCTAssertEqual(Double(x.count) / 44100, 14, accuracy: 0.03)
        XCTAssertGreaterThan(x.map { abs($0) }.max()!, 0.01)
        XCTAssertLessThan(playback.map { abs($0) }.max()!, 1.02)
        for time in [2.0, 7.0, 12.0] {
            let envelope = try AudioEnvelope(url: motionA)
            XCTAssertGreaterThan(envelope.signal(at: time).level, 0)
        }
        // Compare a two-layer sequence against root alone: no second-layer leakage before 5 sec.
        audio.chakra?.selected = ["root", "heart"]
        let two = root.appendingPathComponent("two.m4a")
        _ = try await AudioMix.prepare(voice: a, background: nil, volume: 0, output: root.appendingPathComponent("two-voice.m4a"), soundscape: audio, motionOutput: two)
        audio.chakra?.selected = ["root"]; audio.chakra?.volume = 0.3
        let one = root.appendingPathComponent("one.m4a")
        _ = try await AudioMix.prepare(voice: a, background: nil, volume: 0, output: root.appendingPathComponent("one-voice.m4a"), soundscape: audio, motionOutput: one)
        let twoPCM = try mono(two), onePCM = try mono(one)
        let before = (44100..<44100 * 4).reduce(0.0) { $0 + abs(Double(twoPCM[$1] - onePCM[$1])) } / (44100 * 3)
        let after = (44100 * 7..<44100 * 9).reduce(0.0) { $0 + abs(Double(twoPCM[$1] - onePCM[$1])) } / (44100 * 2)
        XCTAssertLessThan(before, 0.001); XCTAssertGreaterThan(after, before + 0.001)
    }
    func testOriginalAndLoopModesMixWithBeatsNatureAndVoice() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("voice.wav"); try voice(source, frequency: 2100, duration: 4)
        for mode in [StudioChakraMode.recordings, .loops] {
            var audio = StudioSoundscape(); audio.beat = .alpha; audio.beatVolume = 0.25
            audio.natureID = "forest_ambience"; audio.natureVolume = 0.6
            var layer = StudioChakraLayer(); layer.mode = mode; layer.selected = Set(StudioChakra.all.map(\.id)); layer.volume = 0.6; audio.chakra = layer
            let prepared = try await AudioMix.prepareForPlayback(voice: source, background: nil, volume: 0,
                output: root.appendingPathComponent("\(mode.rawValue).m4a"), soundscape: audio)
            let pcm = try mono(prepared.playbackURL)
            XCTAssertGreaterThan(amplitude(pcm, 2100, at: 1), 0.20)
            XCTAssertLessThan(pcm.map { abs($0) }.max()!, 1.02)
            XCTAssertGreaterThan(prepared.motion.signal(at: 1).level, 0)
            XCTAssertEqual(prepared.duration, 4, accuracy: 0.03)
        }
    }
    func testBoundedRandomizerUsesChakrasAndPreservesLocksAndLegacyPlans() throws {
        func plan(seed: UInt64 = 42, keeping: [RandomClip] = []) throws -> RandomBatchPlan {
            try RandomBatchPlan.make(count: 8, seed: seed, mantras: ["one"], styles: [33], palettes: [0], settings: ExportSettings(), backgroundFile: nil, postFooter: "", keeping: keeping, chakras: StudioChakra.randomIDs)
        }
        let first = try plan(); XCTAssertEqual(first, try plan())
        XCTAssertEqual(Set(first.clips.map(\.key)).count, 8)
        XCTAssertEqual(Set(first.clips.compactMap { $0.soundscape?.chakra?.randomID }), Set(StudioChakra.randomIDs))
        var locked = first.clips; locked[2].locked = true
        XCTAssertEqual(try plan(seed: 99, keeping: locked).clips[2], locked[2])
        XCTAssertEqual(try JSONDecoder().decode(RandomBatchPlan.self, from: JSONEncoder().encode(first)), first)
        let start = Date()
        let large = try RandomBatchPlan.make(count: 50, seed: 99, mantras: (0..<25).map { "mantra-\($0)" }, styles: VisualStyle.all.map(\.id), palettes: VisualPalette.all.map(\.id), settings: ExportSettings(), backgroundFile: nil, postFooter: "", beats: [.delta, .theta, .alpha], nature: StudioNature.all.map(\.id), chakras: StudioChakra.randomIDs)
        XCTAssertEqual(Set(large.clips.map(\.key)).count, 50)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3, "Generating 50 clips should not enumerate 1.2 million combinations")
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(first)) as? [String: Any]); old.removeValue(forKey: "chakraPool")
        XCTAssertNil(try JSONDecoder().decode(RandomBatchPlan.self, from: JSONSerialization.data(withJSONObject: old)).chakraPool)
    }
    func testChakraVisualsFitAllFormatsAndExportWithLayeredAudio() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let renderer = try FrameRenderer(), mantra = try XCTUnwrap(StudioResources.library().first)
        for style in 26...33 {
            for format in VideoFormat.allCases {
                var settings = ExportSettings(); settings.style = style; settings.format = format
                let image = try renderer.frame(width: format.width / 5, height: format.height / 5, time: 3, audioTime: 3,
                    envelope: AudioEnvelope(silence: 5), mantra: mantra, settings: settings)
                XCTAssertEqual(image.width, format.width / 5); XCTAssertEqual(image.height, format.height / 5)
            }
        }
        var settings = ExportSettings(); settings.style = 33; settings.soundscape.beat = .theta; settings.soundscape.natureID = "forest_ambience"
        settings.soundscape.chakra = StudioChakraLayer().randomized("column")
        let movie = root.appendingPathComponent("chakra.mp4")
        try await VideoExporter.export(ExportJob(mantra: mantra, settings: settings, start: 0, end: 2), to: movie, widthOverride: 168, heightOverride: 300, recordHistory: false) { _ in }
        let asset = AVURLAsset(url: movie)
        let audio = try await asset.loadTracks(withMediaType: .audio), video = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(audio.count, 1); XCTAssertEqual(video.count, 1)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 2, accuracy: 0.1)
    }
}
