import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class VisualizerTests: XCTestCase {
    private func tone(in folder: URL, name: String, frequency: Double, duration: Double = 2,
                      amplitude: Float = 0.3, oppositeStereo: Bool = false) throws -> URL {
        let url = folder.appendingPathComponent(name + ".wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(duration * 44100))!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let value = amplitude * Float(sin(2 * Double.pi * frequency * Double(i) / 44100))
            buffer.floatChannelData![0][i] = value
            buffer.floatChannelData![1][i] = oppositeStereo ? -value : value
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("StudioVisualTest-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func bytes(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }
    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).enumerated().filter { $0.offset % 4 != 3 }.reduce(0.0) {
            $0 + Double(abs(Int($1.element.0) - Int($1.element.1)))
        } / Double(a.count / 4 * 3)
    }

    func testIndependentFrequencyBandsAndOppositePhaseStereo() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        for (frequency, index) in [(80.0, 0), (900.0, 1), (6500.0, 2)] {
            let url = try tone(in: root, name: "tone-\(index)", frequency: frequency, oppositeStereo: true)
            let signal = try AudioEnvelope(url: url).signal(at: 1)
            let bands = [signal.bass, signal.mids, signal.treble]
            XCTAssertGreaterThan(signal.level, 0.5, "Opposite-phase stereo must retain its measured energy")
            for other in 0..<3 where other != index {
                XCTAssertGreaterThan(bands[index], bands[other] + 0.25, "Incorrect frequency band for \(frequency) Hz")
            }
        }
    }

    func testEveryStyleMovesRespondsAndRendersStableSnapshots() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let sound = try AudioEnvelope(url: tone(in: root, name: "sound", frequency: 80))
        let silence = try AudioEnvelope(url: tone(in: root, name: "silence", frequency: 80, amplitude: 0))
        let renderer = try FrameRenderer()
        let mantra = try XCTUnwrap(StudioResources.library().first)
        for style in VisualStyle.all {
            var settings = ExportSettings()
            settings.style = style.id; settings.captions = false; settings.branding = false
            func render(_ time: Double, _ envelope: AudioEnvelope) throws -> CGImage {
                try renderer.frame(width: 144, height: 256, time: time, audioTime: time,
                    envelope: envelope, mantra: mantra, settings: settings)
            }
            let first = try render(0.2, silence)
            let originalBytes = bytes(first)
            let moved = bytes(try render(3, silence))
            XCTAssertGreaterThan(difference(originalBytes, moved), 0.1, "\(style.title) appears frozen")
            XCTAssertEqual(bytes(first), originalBytes, "A later frame mutated the earlier snapshot")
            let quiet = bytes(try render(1, silence))
            let loud = bytes(try render(1, sound))
            XCTAssertGreaterThan(difference(quiet, loud), 0.1, "\(style.title) does not respond to sound")
            XCTAssertGreaterThan(loud.enumerated().filter { $0.offset % 4 != 3 }.map { Int($0.element) }.max()!, 25,
                "\(style.title) produced a blank frame")
            settings.audioResponse = 0
            XCTAssertEqual(bytes(try render(1, silence)), bytes(try render(1, sound)),
                "Sound response at zero should remove audio-driven movement")
            let repeatA = bytes(try render(1.3, sound))
            _ = try render(0.1, sound)
            XCTAssertEqual(repeatA, bytes(try render(1.3, sound)), "Seeking must not change the exported scene")
        }
        for size in [(160, 160), (192, 108), (108, 192)] {
            let image = try renderer.frame(width: size.0, height: size.1, time: 1, audioTime: 1,
                envelope: sound, mantra: mantra, settings: ExportSettings())
            XCTAssertEqual(image.width, size.0); XCTAssertEqual(image.height, size.1)
        }
    }

    func testSpaceJourneysAreDistinctAcrossFormatsAndLongTimelines() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let envelope = AudioEnvelope(silence: 1000), renderer = try FrameRenderer()
        let mantra = try XCTUnwrap(StudioResources.library().first)
        for size in [(108, 192), (160, 160), (192, 108)] {
            var snapshots = [[UInt8]]()
            for style in 36...39 {
                var settings = ExportSettings(); settings.style = style
                settings.branding = false; settings.captions = false; settings.palette = 5
                func frame(_ time: Double) throws -> [UInt8] {
                    bytes(try renderer.frame(width: size.0, height: size.1, time: time, audioTime: time,
                        envelope: envelope, mantra: mantra, settings: settings))
                }
                let start = try frame(47)
                for previous in snapshots { XCTAssertGreaterThan(difference(start, previous), 0.8, "Space themes should have distinct structure") }
                snapshots.append(start)
                settings.motionAmount = 0
                XCTAssertGreaterThan(difference(start, try frame(47)), 0.05, "Motion amount should change the camera/flow")
                settings.motionAmount = 1
                XCTAssertGreaterThan(difference(try frame(900), try frame(900.25)), 0.05, "Long live timelines must keep moving")
            }
        }
    }

    func testLiquidConstellationsScrollThroughBothMorphPlateausAndReverse() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let silence = try AudioEnvelope(url: tone(in: root, name: "constellation", frequency: 80, amplitude: 0))
        let renderer = try FrameRenderer()
        let mantra = try XCTUnwrap(StudioResources.library().first)
        var settings = ExportSettings()
        settings.style = 9; settings.captions = false; settings.branding = false
        settings.audioResponse = 0; settings.motionAmount = 0
        settings.motionSpeed = 1 / 1.65 // Observe shader time directly, without sound or global warping.
        let width = 216, height = 384
        func rowProfile(at time: Double) throws -> [Double] {
            let frame = try renderer.frame(width: width, height: height, time: time, audioTime: time,
                envelope: silence, mantra: mantra, settings: settings)
            let data = bytes(frame)
            return (0..<height).map { y in
                (12..<(width - 12)).reduce(0.0) { sum, x in
                    let offset = (y * width + x) * 4
                    return sum + Double(data[offset]) + Double(data[offset + 1]) + Double(data[offset + 2])
                } / Double(width - 24)
            }
        }
        func verticalTravel(from: Double, to: Double) throws -> Int {
            let first = try rowProfile(at: from), last = try rowProfile(at: to)
            // Image-based correlation distinguishes actual scrolling from local node shimmer.
            return (-10...10).min { a, b in
                func error(_ shift: Int) -> Double {
                    (20..<(height - 20)).reduce(0.0) { $0 + abs(first[$1] - last[$1 + shift]) }
                }
                return error(a) < error(b)
            }!
        }
        // Both intervals are inside fully transitioned shapes, away from the turning point.
        let liquidTravel = try verticalTravel(from: 5, to: 6)
        let constellationTravel = try verticalTravel(from: 18, to: 19)
        XCTAssertGreaterThanOrEqual(abs(liquidTravel), 2, "The completed liquid field must keep scrolling")
        XCTAssertGreaterThanOrEqual(abs(constellationTravel), 2, "The completed constellation field must keep scrolling")
        XCTAssertLessThan(liquidTravel * constellationTravel, 0, "The field should return in the opposite direction")
    }

    func testEveryPaletteWorksAcrossEveryStyle() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let sound = try AudioEnvelope(url: tone(in: root, name: "palette", frequency: 900))
        let renderer = try FrameRenderer()
        let mantra = try XCTUnwrap(StudioResources.library().first)
        for style in VisualStyle.all {
            var settings = ExportSettings()
            settings.style = style.id; settings.captions = false; settings.branding = false
            let original = bytes(try renderer.frame(width: 96, height: 170, time: 1.2, audioTime: 1.2,
                envelope: sound, mantra: mantra, settings: settings))
            for palette in VisualPalette.all.dropFirst() {
                settings.palette = palette.id
                let colored = bytes(try renderer.frame(width: 96, height: 170, time: 1.2, audioTime: 1.2,
                    envelope: sound, mantra: mantra, settings: settings))
                XCTAssertGreaterThan(difference(original, colored), 0.2,
                    "\(palette.title) has no visible effect on \(style.title)")
                let roundTrip = try JSONDecoder().decode(ExportSettings.self, from: JSONEncoder().encode(settings))
                XCTAssertEqual(roundTrip.palette, palette.id)
            }
        }
    }

    func testPortalsAreDistinctAndBloomRespondsToFlowControl() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let sound = try AudioEnvelope(url: tone(in: root, name: "portal", frequency: 80))
        let renderer = try FrameRenderer()
        let mantra = try XCTUnwrap(StudioResources.library().first)
        var settings = ExportSettings(); settings.captions = false; settings.branding = false
        var portals: [[UInt8]] = []
        for id in 14...19 {
            settings.style = id
            let pixels = bytes(try renderer.frame(width: 144, height: 256, time: 2, audioTime: 2,
                envelope: sound, mantra: mantra, settings: settings))
            for previous in portals { XCTAssertGreaterThan(difference(previous, pixels), 2, "New fields should look distinct") }
            portals.append(pixels)
        }
        settings.style = 10; settings.motionAmount = 0
        let calm = bytes(try renderer.frame(width: 144, height: 256, time: 2, audioTime: 2,
            envelope: sound, mantra: mantra, settings: settings))
        settings.motionAmount = 2
        let flowing = bytes(try renderer.frame(width: 144, height: 256, time: 2, audioTime: 2,
            envelope: sound, mantra: mantra, settings: settings))
        XCTAssertGreaterThan(difference(calm, flowing), 2, "Prismatic Bloom should open and twist with flow amount")
    }

    func testSacredGeometryIsDistinctAndFitsAllVideoShapes() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let sound = try AudioEnvelope(url: tone(in: root, name: "sacred", frequency: 80))
        let renderer = try FrameRenderer()
        let mantra = try XCTUnwrap(StudioResources.library().first)
        var settings = ExportSettings()
        settings.captions = false; settings.branding = false
        settings.motionAmount = 2; settings.audioResponse = 2
        var collection: [[UInt8]] = []
        for id in 20...25 {
            settings.style = id
            let reference = bytes(try renderer.frame(width: 144, height: 256, time: 2, audioTime: 2,
                envelope: sound, mantra: mantra, settings: settings))
            for previous in collection {
                XCTAssertGreaterThan(difference(reference, previous), 1, "Sacred constructions must remain distinguishable")
            }
            collection.append(reference)
            // A bright boundary check catches clipping at maximal breath in every export aspect.
            for (width, height) in [(160, 160), (192, 108), (108, 192)] {
                let pixels = bytes(try renderer.frame(width: width, height: height, time: 2, audioTime: 2,
                    envelope: sound, mantra: mantra, settings: settings))
                var clipped = 0
                for y in 0..<height {
                    for x in 0..<width where x < 2 || x >= width - 2 || y < 2 || y >= height - 2 {
                        let offset = (y * width + x) * 4
                        if max(pixels[offset], max(pixels[offset + 1], pixels[offset + 2])) > 95 { clipped += 1 }
                    }
                }
                XCTAssertEqual(clipped, 0, "Sacred style \(id) is clipped at \(width)×\(height)")
            }
        }
    }

    func testBackgroundMixLoopsAndKeepsDuration() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let voice = try tone(in: root, name: "voice", frequency: 900, duration: 3)
        let background = try tone(in: root, name: "bed", frequency: 80, duration: 0.6)
        let original = try AudioEnvelope(url: voice)
        let url = try await AudioMix.prepare(voice: voice, background: background, volume: 0.3,
            output: root.appendingPathComponent("mixed.m4a"))
        let mix = try AudioEnvelope(url: url)
        XCTAssertEqual(mix.duration, original.duration, accuracy: 0.08)
        for t in [0.5, 1.0, 1.8, 2.4] {
            let frame = mix.signal(at: t)
            XCTAssertGreaterThan(frame.bass, original.signal(at: t).bass + 0.2, "Background stopped at a loop join")
            XCTAssertGreaterThan(frame.mids, 0.4, "The mantra disappeared from the mix")
        }
    }

    func testOldPresetsKeepNewMotionDefaults() throws {
        let data = Data(#"{"style":3,"format":"Vertical · 9:16","captions":false,"branding":true,"heading":"Daily","captionOffset":0.4}"#.utf8)
        let settings = try JSONDecoder().decode(ExportSettings.self, from: data)
        XCTAssertEqual(settings.palette, 0)
        XCTAssertEqual(settings.motionSpeed, 1)
        XCTAssertEqual(settings.motionAmount, 1)
        XCTAssertEqual(settings.audioResponse, 1)
        XCTAssertEqual(settings.heading, "Daily")
        XCTAssertFalse(settings.captions)
    }
}
