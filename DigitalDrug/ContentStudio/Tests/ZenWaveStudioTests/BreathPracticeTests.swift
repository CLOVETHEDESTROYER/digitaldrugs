import XCTest
import AVFoundation
import CryptoKit
@testable import ZenWaveStudio

final class BreathPracticeTests: XCTestCase {
    func testPresetBoundariesAndContinuousCircle() throws {
        for preset in BreathPreset.allCases where preset != .custom {
            var plan = BreathPlan(); plan.apply(preset); plan.cycles = 2
            try plan.validate()
            plan.fit(minutes: 20)
            XCTAssertLessThanOrEqual(plan.duration, 1200)
            XCTAssertLessThan(1200 - plan.duration, plan.cycleDuration)
            plan.cycles = 2
            XCTAssertNotNil(preset.sourceURL)
            XCTAssertEqual(plan.segments.first?.phase, .ready)
            XCTAssertEqual(plan.segments.last?.phase, .finish)
            for segment in plan.segments.dropFirst() {
                let before = plan.moment(at: segment.start - 0.000001)
                let after = plan.moment(at: segment.start)
                XCTAssertEqual(before.fill, after.fill, accuracy: 0.00001, "No jumps at \(segment.phase)")
                XCTAssertEqual(after.countdown, Int(segment.seconds))
                XCTAssertEqual(after.segment.phase, segment.phase)
            }
            XCTAssertEqual(plan.moment(at: plan.duration).segment.phase, .finish)
            XCTAssertEqual(plan.moment(at: .nan).segment.phase, .ready)
        }
    }
    func testEveryCountdownNumberLastsThirtyFramesAtThirtyFPS() throws {
        for preset in [BreathPreset.box, .slowBox] {
            var plan = BreathPlan(); plan.apply(preset); plan.cycles = 2
            for segment in plan.segments where segment.phase != .ready && segment.phase != .finish {
                var frames: [Int: Int] = [:]
                for frame in 0..<Int(segment.seconds * 30) {
                    let time = segment.start + Double(frame) / 30
                    let moment = plan.moment(at: time)
                    XCTAssertEqual(moment.segment.phase, segment.phase)
                    frames[moment.countdown, default: 0] += 1
                }
                XCTAssertEqual(frames.count, Int(segment.seconds))
                for count in 1...Int(segment.seconds) { XCTAssertEqual(frames[count], 30) }
            }
        }
        var slow = BreathPlan(); slow.apply(.slowBox)
        XCTAssertEqual(slow.cycleDuration, 20)
    }
    func testVisibleDigitBoundsAreCenteredOnTheCircle() throws {
        for size in [CGFloat(24), 57, 113] {
            for value in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "∞"] {
                let side = 320, center = CGPoint(x: 160, y: 160)
                var pixels = [UInt8](repeating: 0, count: side * side * 4)
                try pixels.withUnsafeMutableBytes { bytes in
                    let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    BreathRenderer.drawCountdown(value, context: context, center: center, size: size)
                }
                var xs: [Int] = [], ys: [Int] = []
                for y in 0..<side { for x in 0..<side where pixels[(y * side + x) * 4 + 3] > 20 { xs.append(x); ys.append(y) } }
                let minX = try XCTUnwrap(xs.min()), maxX = try XCTUnwrap(xs.max())
                let minY = try XCTUnwrap(ys.min()), maxY = try XCTUnwrap(ys.max())
                XCTAssertEqual(Double(minX + maxX + 1) / 2, 160, accuracy: 1, "Horizontal center of \(value)")
                XCTAssertEqual(Double(minY + maxY + 1) / 2, 160, accuracy: 1, "Vertical center of \(value)")
            }
        }
    }
    func testHoldDoesNotChangeRadiusAndCountdownNeverShowsZero() {
        var plan = BreathPlan(); plan.apply(.box); plan.cycles = 1
        for t in stride(from: 10.0, to: 14, by: 0.1) {
            let moment = plan.moment(at: t)
            XCTAssertEqual(moment.segment.phase, .hold); XCTAssertEqual(moment.fill, 1)
            XCTAssertGreaterThanOrEqual(moment.countdown, 1)
        }
        XCTAssertEqual(plan.moment(at: 11).countdown, 3)
        XCTAssertEqual(plan.moment(at: 14).segment.phase, .exhale)
        XCTAssertGreaterThan(plan.moment(at: 8).fill, plan.moment(at: 7).fill)
        XCTAssertLessThan(plan.moment(at: 17).fill, plan.moment(at: 15).fill)
    }
    func testCustomZeroHoldsCompleteCyclesAndVoiceSchedule() throws {
        var plan = BreathPlan(); plan.apply(.custom); plan.inhale = 3; plan.hold = 5; plan.exhale = 6
        plan.fit(minutes: 20); try plan.validate()
        XCTAssertLessThanOrEqual(plan.duration, 1200)
        XCTAssertLessThan(1200 - plan.duration, plan.cycleDuration)
        let hold = try XCTUnwrap(plan.segments.first { $0.phase == .hold })
        let holdCues = plan.spokenCues.filter { $0.start >= hold.start && $0.start < hold.start + hold.seconds }
        XCTAssertEqual(holdCues.map(\.text), ["Hold", "4", "3", "2", "1"])
        for pair in zip(plan.spokenCues, plan.spokenCues.dropFirst()) { XCTAssertLessThanOrEqual(pair.0.end, pair.1.start) }
        plan.voice = .cues; XCTAssertEqual(plan.spokenCues.count, plan.segments.count)
        plan.voice = .off; XCTAssertTrue(plan.spokenCues.isEmpty)
        plan.hold = 0; XCTAssertFalse(plan.segments.contains { $0.phase == .hold })
        plan.inhale = 0; XCTAssertThrowsError(try plan.validate())
        plan.apply(.box); plan.inhale = 5; XCTAssertThrowsError(try plan.validate())
    }
    func testSpokenAudioExportIsSynchronizedAndVoiceDoesNotDriveMotion() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("breath-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var plan = BreathPlan(); plan.apply(.box); plan.cycles = 1; plan.voiceName = "OpenAI · Marin"
        var settings = ExportSettings(); settings.captionOffset = 12
        let packRoot = try makeVoiceFixture(folder: folder, plan: plan)
        let audio = try await BreathAudio.prepare(plan: plan, settings: settings, background: nil, folder: folder, voicePackRoot: packRoot)
        XCTAssertEqual(audio.duration, 26, accuracy: 0.02)
        for time in [0.5, 6.3, 10.3, 14.3, 18.3] { XCTAssertEqual(audio.motion.signal(at: time).level, 0) }
        let file = try AVAudioFile(forReading: audio.playbackURL)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let data = buffer.floatChannelData!.pointee, rate = file.processingFormat.sampleRate
        func rms(_ start: Double, _ end: Double) -> Double {
            let lo = Int(start * rate), hi = Int(end * rate)
            return sqrt((lo..<hi).reduce(0.0) { $0 + Double(data[$1] * data[$1]) } / Double(hi - lo))
        }
        for cue in plan.spokenCues { XCTAssertGreaterThan(rms(cue.start, min(cue.end, cue.start + 0.85)), 0.002, "Missing audible cue: \(cue.text) at \(cue.start)") }
        XCTAssertLessThan(rms(5.1, 5.8), 0.0001)
        let output = folder.appendingPathComponent("breathing.mp4")
        let job = ExportJob(mantra: plan.mantra, settings: settings, start: 0, end: plan.duration, preparedAudio: audio.playbackURL, preparedMotion: audio.motion, breathPlan: plan)
        try await VideoExporter.export(job, to: output, widthOverride: 180, heightOverride: 320, recordHistory: false) { _ in }
        let movie = AVURLAsset(url: output)
        let duration = try await movie.load(.duration).seconds
        let video = try await movie.loadTracks(withMediaType: .video)
        let voice = try await movie.loadTracks(withMediaType: .audio)
        XCTAssertEqual(duration, 26, accuracy: 0.05); XCTAssertEqual(video.count, 1); XCTAssertEqual(voice.count, 1)
        let reader = try AVAssetReader(asset: movie)
        let track = AVAssetReaderTrackOutput(track: video[0], outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(track); XCTAssertTrue(reader.startReading())
        var countFrames: [String: Int] = [:]
        while let frame = track.copyNextSampleBuffer() {
            let time = CMSampleBufferGetPresentationTimeStamp(frame).seconds
            let moment = plan.moment(at: time)
            if ![BreathPhase.ready, .finish].contains(moment.segment.phase) {
                let key = "\(moment.segment.phase.rawValue)-\(moment.countdown)"
                countFrames[key, default: 0] += 1
            }
        }
        XCTAssertEqual(reader.status, .completed)
        XCTAssertEqual(countFrames.count, 16)
        for count in countFrames.values { XCTAssertEqual(count, 30, "One number must occupy one real second of exported video") }
        let decoded = try JSONDecoder().decode(BreathPlan.self, from: Data(contentsOf: output.deletingPathExtension().appendingPathExtension("breathing.json")))
        XCTAssertEqual(decoded, plan)
        let srt = try String(contentsOf: output.deletingPathExtension().appendingPathExtension("srt"))
        XCTAssertTrue(srt.contains("00:00:10,000 --> 00:00:14,000\nHold gently"))
    }
    /// Deterministic local test tones stand in for audio files; these are not OpenAI-generated speech.
    private func makeVoiceFixture(folder: URL, plan: BreathPlan) throws -> URL {
        let root = folder.appendingPathComponent("fixture-voice")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var clips: [[String: Any]] = []
        for (index, text) in Set(plan.spokenCues.map(\.text)).sorted().enumerated() {
            let url = root.appendingPathComponent("cue-\(index).wav")
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 14400)!
            buffer.frameLength = 14400
            for frame in 0..<14400 { buffer.floatChannelData!.pointee[frame] = Float(sin(Double(frame) * 2 * .pi * 220 / 48000)) * 0.3 }
            do {
                let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
                try file.write(from: buffer)
            }
            let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
            clips.append(["text": text, "file": url.lastPathComponent, "sha256": digest])
        }
        let manifest: [String: Any] = ["schemaVersion": 1, "provider": "OpenAI", "model": "test-fixture",
                                       "voice": "marin", "aiGenerated": true, "clips": clips]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appendingPathComponent("manifest.json"))
        return root
    }
    func testVoicePackRejectsMissingAndDamagedAssetsWithoutAppleFallback() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("voice-pack-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertThrowsError(try BreathVoicePack.load(from: folder))
        let root = try makeVoiceFixture(folder: folder, plan: BreathPlan())
        let pack = try BreathVoicePack.load(from: root)
        XCTAssertEqual(pack.provider, "OpenAI"); XCTAssertEqual(pack.voice, "marin")
        XCTAssertThrowsError(try pack.file(for: "Missing cue", root: root))
        let url = try pack.file(for: "Inhale", root: root)
        try Data("damaged".utf8).write(to: url)
        XCTAssertThrowsError(try BreathVoicePack.load(from: root))
    }
    func testRealBundledOpenAIVoicePackFitsAllBreathingCues() async throws {
        let pack = try BreathVoicePack.load()
        XCTAssertEqual(pack.provider, "OpenAI"); XCTAssertEqual(pack.voice, "marin")
        XCTAssertEqual(pack.model, "gpt-4o-mini-tts-2025-12-15"); XCTAssertEqual(pack.clips.count, 16)
        var plan = BreathPlan(); plan.apply(.custom)
        plan.inhale = 10; plan.exhale = 10; plan.hold = 8; plan.pause = 8; plan.cycles = 1
        for cue in plan.spokenCues {
            let url = try pack.file(for: cue.text)
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            XCTAssertLessThanOrEqual(duration, cue.end - cue.start + 0.02, "Cue must fit without speeding it up: \(cue.text)")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openai-real-voice-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let audio = try await BreathAudio.prepare(plan: plan, settings: ExportSettings(), background: nil, folder: folder)
        XCTAssertEqual(audio.duration, plan.duration, accuracy: 0.001)
        XCTAssertEqual(audio.motion.signal(at: 6.3).level, 0)
    }
    func testSilentPracticeStillHasACompleteAudioClock() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("breath-silent-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var plan = BreathPlan(); plan.cycles = 1; plan.voice = .off
        let audio = try await BreathAudio.prepare(plan: plan, settings: ExportSettings(), background: nil, folder: folder)
        XCTAssertEqual(audio.duration, 20, accuracy: 0.001)
        XCTAssertEqual(audio.motion.signal(at: 6).level, 0)
    }
}
