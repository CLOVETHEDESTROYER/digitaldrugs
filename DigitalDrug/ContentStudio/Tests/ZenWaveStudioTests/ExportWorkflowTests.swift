import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class ExportWorkflowTests: XCTestCase {
    @MainActor
    func testBatchExportsTwoFullRecordings() async throws {
        let originalSettings = UserDefaults.standard.data(forKey: "exportSettings")
        defer {
            if let originalSettings { UserDefaults.standard.set(originalSettings, forKey: "exportSettings") }
            else { UserDefaults.standard.removeObject(forKey: "exportSettings") }
        }
        let state = StudioState()
        XCTAssertNil(state.error)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("studio-batch-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        state.outputFolder = root
        state.settings = ExportSettings()
        state.settings.format = .square
        state.queued = ["career-confidence-morning", "career-confidence-evening"]
        state.startExport(batch: true)
        let deadline = Date().addingTimeInterval(120)
        while state.exporting && Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        if state.exporting { state.cancelExport(); XCTFail("Batch export timed out"); return }
        XCTAssertNil(state.error)
        XCTAssertEqual(state.completed, 2)
        XCTAssertEqual(state.progress, 1)
        let folder = try XCTUnwrap(state.lastExportFolder)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let videos = files.filter { $0.pathExtension == "mp4" }
        XCTAssertEqual(videos.count, 2)
        XCTAssertEqual(files.filter { $0.pathExtension == "json" }.count, 2)
        XCTAssertEqual(files.filter { $0.pathExtension == "srt" }.count, 2)
        for url in videos {
            let asset = AVURLAsset(url: url)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            let video = try await asset.loadTracks(withMediaType: .video)
            XCTAssertEqual(audio.count, 1)
            let track = try XCTUnwrap(video.first)
            let size = try await track.load(.naturalSize)
            XCTAssertEqual(size, CGSize(width: 1080, height: 1080))
            let duration = try await asset.load(.duration).seconds
            XCTAssertGreaterThan(duration, 10)
        }
    }

    func testCancellationLeavesNoPartialMovieAndPreservesExistingFiles() async throws {
        let mantra = try XCTUnwrap(StudioResources.library().first)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("studio-cancel-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = root.appendingPathComponent("keep.mp4")
        let original = Data("existing video sentinel".utf8)
        try original.write(to: existing)
        let output = root.appendingPathComponent("cancelled.mp4")
        let job = ExportJob(mantra: mantra, settings: ExportSettings(), start: 0, end: nil)
        let task = Task.detached {
            try await VideoExporter.export(job, to: output, widthOverride: 360, heightOverride: 640) { _ in }
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        do { try await task.value; XCTFail("Cancellation was ignored") }
        catch is CancellationError { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try Data(contentsOf: existing), original)
    }
}
