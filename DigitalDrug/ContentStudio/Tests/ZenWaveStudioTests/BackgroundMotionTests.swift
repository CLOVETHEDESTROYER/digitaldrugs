import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class BackgroundMotionTests: XCTestCase {
    private func directory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("background-motion-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private func tone(_ folder: URL, name: String, frequency: Double, amplitude: Float, pulsed: Bool = false) throws -> URL {
        let url = folder.appendingPathComponent(name + ".caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 4)!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let gain: Float = pulsed && (i / 9000) % 2 == 0 ? 0 : amplitude
            let value = gain * Float(sin(2 * .pi * frequency * Double(i) / 44100))
            buffer.floatChannelData![0][i] = value; buffer.floatChannelData![1][i] = value
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
    private func pixels(_ image: CGImage) -> Data {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Data(bytes: context.data!, count: image.width * image.height * 4)
    }

    func testChangingVoiceCannotChangeAnyBackgroundDrivenVisual() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let loud = try tone(root, name: "voice-loud", frequency: 6500, amplitude: 0.9, pulsed: true)
        let quiet = try tone(root, name: "voice-quiet", frequency: 85, amplitude: 0.08)
        let music = try tone(root, name: "music", frequency: 900, amplitude: 0.3, pulsed: true)
        let mantra = try XCTUnwrap(StudioResources.library().first), renderer = try FrameRenderer()
        for mode in 0..<4 {
            var settings = ExportSettings(); settings.captions = false; settings.branding = false
            if mode == 0 || mode == 3 { settings.soundscape.beat = .theta }
            if mode == 1 || mode == 3 { settings.soundscape.natureID = "tropical_rain" }
            let background = mode >= 2 ? music : nil
            let a = try await AudioMix.prepareForPlayback(voice: loud, background: background, volume: 0.25,
                output: root.appendingPathComponent("a-\(mode).m4a"), soundscape: settings.soundscape)
            let b = try await AudioMix.prepareForPlayback(voice: quiet, background: background, volume: 0.25,
                output: root.appendingPathComponent("b-\(mode).m4a"), soundscape: settings.soundscape)
            XCTAssertEqual(a.motion.frames, b.motion.frames, "Voice cannot enter the motion envelope")
            XCTAssertGreaterThan(a.motion.signal(at: 2).level, 0.05, "Background still drives motion")
            let heard = try AudioEnvelope(url: a.playbackURL)
            XCTAssertGreaterThan(heard.signal(at: 1).treble, a.motion.signal(at: 1).treble + 0.1, "The voice remains audible in playback")
            for style in VisualStyle.all {
                settings.style = style.id
                let first = try renderer.frame(width: 96, height: 170, time: 1.5, audioTime: 1.5, envelope: a.motion, mantra: mantra, settings: settings)
                let second = try renderer.frame(width: 96, height: 170, time: 1.5, audioTime: 1.5, envelope: b.motion, mantra: mantra, settings: settings)
                XCTAssertEqual(pixels(first), pixels(second), "Mode \(mode), style \(style.id): voice-independent geometry")
            }
        }
    }

    @MainActor
    func testVoiceOnlyPreviewHasAmbientMotionAndNoReactiveEnergy() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let voice = try tone(root, name: "voice", frequency: 100, amplitude: 0.9, pulsed: true)
        let prepared = try await AudioMix.prepareForPlayback(voice: voice, background: nil, volume: 0.3, output: root.appendingPathComponent("voice-only.m4a"))
        XCTAssertEqual(prepared.playbackURL, voice)
        XCTAssertEqual(prepared.duration, 4, accuracy: 0.001)
        for time in [0.0, 0.3, 1, 2.8, 4] { XCTAssertEqual(prepared.motion.signal(at: time), AudioSignal()) }
        var muted = StudioSoundscape(); muted.beat = .alpha; muted.beatVolume = 0; muted.natureID = "ocean"; muted.natureVolume = 0
        let silent = try await AudioMix.prepareForPlayback(voice: voice, background: voice, volume: 0, output: root.appendingPathComponent("muted.m4a"), soundscape: muted)
        XCTAssertEqual(silent.motion.signal(at: 2), AudioSignal())
        let studio = StudioState()
        studio.backgroundURL = nil; studio.settings = ExportSettings(); studio.settings.captions = false; studio.settings.branding = false; studio.settings.style = 10
        studio.selectedID = "career-confidence-morning"; studio.loadSelected(); studio.seek(2)
        let first = pixels(try XCTUnwrap(studio.previewImage))
        studio.selectedID = "career-confidence-evening"; studio.loadSelected(); studio.seek(2)
        XCTAssertTrue(studio.audioReady)
        XCTAssertEqual(first, pixels(try XCTUnwrap(studio.previewImage)), "Mantra selection does not alter ambient visuals")
        studio.seek(3)
        XCTAssertNotEqual(first, pixels(try XCTUnwrap(studio.previewImage)), "Ambient motion continues without a background")
    }

    func testExportedPicturesIgnoreMantraWhileExportedAudioKeepsIt() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = try StudioResources.library()
        var settings = ExportSettings(); settings.captions = false; settings.branding = false; settings.style = 14
        var pictures: [Data] = []
        for id in ["career-confidence-morning", "career-confidence-evening"] {
            let mantra = try XCTUnwrap(library.first { $0.id == id }), output = root.appendingPathComponent(id + ".mp4")
            try await VideoExporter.export(ExportJob(mantra: mantra, settings: settings, start: 0, end: 3), to: output, widthOverride: 144, heightOverride: 256, recordHistory: false) { _ in }
            let asset = AVURLAsset(url: output), generator = AVAssetImageGenerator(asset: AVURLAsset(url: output))
            generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
            let image = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
            pictures.append(pixels(image))
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            let track = try XCTUnwrap(tracks.first), reader = try AVAssetReader(asset: asset)
            let audio = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32])
            reader.add(audio); XCTAssertTrue(reader.startReading())
            var peak: Float = 0
            while let sample = audio.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(sample) {
                let length = CMBlockBufferGetDataLength(block)
                var values = [Float](repeating: 0, count: length / 4)
                _ = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
                peak = max(peak, values.map { abs($0) }.max() ?? 0)
            }
            XCTAssertEqual(reader.status, .completed); XCTAssertGreaterThan(peak, 0.01)
        }
        XCTAssertEqual(pictures[0], pictures[1], "Encoded video stays identical when only narration changes")
    }
}
