import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class LiveSessionTests: XCTestCase {
    @MainActor
    func testPresetsPreparationSeekingAndPendingEdits() async throws {
        let saved = UserDefaults.standard.data(forKey: "livePlan")
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: "livePlan") }
            else { UserDefaults.standard.removeObject(forKey: "livePlan") }
        }
        let library = try StudioResources.library()
        let first = try XCTUnwrap(library.first { $0.id == "career-confidence-morning" })
        let state = LiveSessionState()
        state.plan = LivePlan()
        for _ in 0..<3 { state.add(first, settings: ExportSettings()) }
        for minutes in [10, 15, 20] {
            state.preset(minutes: minutes)
            XCTAssertEqual(state.plan.duration, Double(minutes * 60), accuracy: 0.001)
            XCTAssertEqual(state.plan.chapters[0].seconds, Double(minutes * 20), accuracy: 0.001)
        }
        state.plan.chapters.removeLast()
        for i in state.plan.chapters.indices { state.plan.chapters[i].seconds = 30 }
        state.prepare(library: library, settings: ExportSettings(), background: nil)
        let deadline = Date().addingTimeInterval(15)
        while state.busy && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertFalse(state.busy); XCTAssertNil(state.error); XCTAssertTrue(state.ready)
        XCTAssertNotNil(state.image)
        state.seek(31); XCTAssertEqual(state.activeChapter, 1)
        state.next(); XCTAssertEqual(state.elapsed, 0)
        state.seek(999); XCTAssertEqual(state.elapsed, 60)
        state.plan.chapters[0].seconds = 60
        XCTAssertTrue(state.pendingChanges); XCTAssertFalse(state.ready)
        state.prepare(library: library, settings: ExportSettings(), background: nil)
        state.cancel()
        while state.busy && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertFalse(state.busy); XCTAssertFalse(state.ready); XCTAssertNil(state.error)
    }

    func testTimelineHasCompleteRepetitionsAndDeterministicTransitions() throws {
        let records = try StudioResources.library()
        let selected = Array(records.prefix(3))
        var plan = LivePlan()
        plan.chapters = selected.map { LiveChapter(mantraID: $0.id, seconds: 200, style: 10, palette: 1) }
        plan.rest = 15; plan.sceneSeconds = 60
        let timeline = try LiveTimeline.make(plan: plan, library: records, lengths: Dictionary(uniqueKeysWithValues: selected.map { ($0.id, 25.0) }))
        XCTAssertEqual(timeline.duration, 600)
        XCTAssertEqual(timeline.chapter(at: 199.99), 0)
        XCTAssertEqual(timeline.chapter(at: 200), 1)
        XCTAssertEqual(timeline.chapter(at: 600), 2)
        XCTAssertEqual(timeline.voices.filter { $0.chapter == 0 }.count, 5)
        XCTAssertEqual(timeline.voices.first { $0.chapter == 1 }?.start, 200)
        XCTAssertTrue(timeline.voices.allSatisfy { $0.start + $0.duration <= timeline.chapterStart($0.chapter) + 200 })
        XCTAssertNil(timeline.blend(at: 59))
        XCTAssertEqual(timeline.blend(at: 60)?.alpha, 0)
        XCTAssertEqual(timeline.blend(at: 64)!.alpha, 0.5, accuracy: 0.0001)
        XCTAssertNil(timeline.blend(at: 68))
        XCTAssertEqual(timeline.visual(at: 64, base: ExportSettings()).style, 14)
        XCTAssertEqual(timeline.visual(at: 200, base: ExportSettings()).style, 10)
        XCTAssertTrue(timeline.cues.contains { $0.text.contains("Breathe") })
        let roundTrip = try JSONDecoder().decode(LiveTimeline.self, from: JSONEncoder().encode(timeline))
        XCTAssertEqual(roundTrip.plan, plan)
        plan.chapters[0].seconds = 10
        XCTAssertThrowsError(try plan.validate())
        plan.chapters[0].seconds = 200; plan.rest = .nan
        XCTAssertThrowsError(try plan.validate())
    }

    func testTenMinuteAudioAndMovieHaveExactTimelineAndBothChapters() async throws {
        let library = try StudioResources.library()
        let first = try XCTUnwrap(library.first { $0.id == "career-confidence-morning" })
        let second = try XCTUnwrap(library.first { $0.id == "career-confidence-evening" })
        var plan = LivePlan()
        plan.chapters = [LiveChapter(mantraID: first.id, seconds: 300, style: 10, palette: 1),
                         LiveChapter(mantraID: second.id, seconds: 300, style: 20, palette: 2)]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var settings = ExportSettings(); settings.format = .portrait
        settings.soundscape.beat = .theta; settings.soundscape.natureID = "continuous_river"
        let (timeline, audio, envelope) = try await LiveAudio.prepare(plan: plan, library: library, folder: folder, background: first.audioURL, settings: settings)
        XCTAssertEqual(envelope.duration, 600, accuracy: 0.05)
        let firstVoice = try XCTUnwrap(timeline.voices.first)
        XCTAssertGreaterThan(firstVoice.duration, 10)
        XCTAssertTrue(timeline.voices.contains { $0.chapter == 1 && $0.start == 300 })
        XCTAssertGreaterThan(envelope.signal(at: 299).level, 0.01, "Background continues through chapter rests")
        let renderer = LiveFrameRenderer()
        for time in [0.0, 59.99, 60, 64, 299.99, 300, 304, 599.99] {
            let image = try renderer.frame(width: 168, height: 300, time: time, envelope: envelope, timeline: timeline, settings: settings)
            XCTAssertEqual(image.width, 168)
        }
        let output = folder.appendingPathComponent("ten-minutes.mp4")
        let job = ExportJob(mantra: timeline.mantra, settings: settings, start: 0, end: timeline.duration, liveTimeline: timeline, preparedAudio: audio, preparedMotion: envelope)
        try await VideoExporter.export(job, to: output, widthOverride: 168, heightOverride: 300) { _ in }
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 600, accuracy: 0.05)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audioTracks.count, 1)
        let generator = AVAssetImageGenerator(asset: asset)
        let finalFrame = try await generator.image(at: CMTime(seconds: 599, preferredTimescale: 600))
        XCTAssertEqual(finalFrame.image.width, 168)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.deletingPathExtension().appendingPathExtension("playlist.json").path))
        let subtitles = try String(contentsOf: output.deletingPathExtension().appendingPathExtension("srt"))
        XCTAssertTrue(subtitles.contains("00:05:"))
    }
}
