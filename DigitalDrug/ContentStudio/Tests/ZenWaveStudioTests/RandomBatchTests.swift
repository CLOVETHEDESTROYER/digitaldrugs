import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class RandomBatchTests: XCTestCase {
    func testSeedPoolsBalanceUniquenessAndLocks() throws {
        let records = ["a", "b", "c"]
        func make(_ seed: UInt64, keeping: [RandomClip] = []) throws -> RandomBatchPlan {
            try RandomBatchPlan.make(count: 18, seed: seed, mantras: records, styles: [10, 14, 20], palettes: [1, 2], settings: ExportSettings(), backgroundFile: nil, postFooter: "#mypractice", keeping: keeping)
        }
        let week = try RandomBatchPlan.make(count: 7, seed: 42, mantras: records, styles: Array(14...22), palettes: Array(0...8), settings: ExportSettings(), backgroundFile: nil, postFooter: "")
        XCTAssertEqual(Set(week.clips.map(\.style)).count, 7)
        XCTAssertEqual(Set(week.clips.map(\.palette)).count, 7)
        let first = try make(42)
        XCTAssertEqual(first, try make(42))
        XCTAssertNotEqual(first.clips, try make(43).clips)
        XCTAssertEqual(Set(first.clips.map(\.key)).count, 18)
        for id in records { XCTAssertEqual(first.clips.filter { $0.mantraID == id }.count, 6) }
        XCTAssertTrue(first.clips.allSatisfy { [10, 14, 20].contains($0.style) && [1, 2].contains($0.palette) })
        var keep = first.clips; keep[0].locked = true; keep[9].locked = true
        let shuffled = try make(100, keeping: keep)
        XCTAssertEqual(shuffled.clips[0], keep[0]); XCTAssertEqual(shuffled.clips[9], keep[9])
        XCTAssertEqual(Set(shuffled.clips.map(\.key)).count, 18)
        XCTAssertThrowsError(try RandomBatchPlan.make(count: 5, seed: 1, mantras: records, styles: [10, 14, 20], palettes: [1, 2], settings: ExportSettings(), backgroundFile: nil, postFooter: "", keeping: keep))
        let decoded = try JSONDecoder().decode(RandomBatchPlan.self, from: JSONEncoder().encode(first))
        XCTAssertEqual(decoded, first)
        XCTAssertEqual(decoded.mantraPool, records)
        XCTAssertThrowsError(try RandomBatchPlan.make(count: 2, seed: 1, mantras: ["a"], styles: [10], palettes: [1], settings: ExportSettings(), backgroundFile: nil, postFooter: ""))
        XCTAssertThrowsError(try RandomBatchPlan.make(count: 1, seed: 1, mantras: [], styles: [10], palettes: [1], settings: ExportSettings(), backgroundFile: nil, postFooter: ""))
        XCTAssertThrowsError(try RandomBatchPlan.make(count: 1, seed: 1, mantras: ["outside-pool"], styles: [10], palettes: [1], settings: ExportSettings(), backgroundFile: nil, postFooter: "", keeping: [keep[0]]))
    }

    @MainActor
    func testBatchSavesCombinedMoviesSidecarsAndZip() async throws {
        let library = try StudioResources.library()
        let records = library.filter { ["career-confidence-morning", "career-confidence-evening"].contains($0.id) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("random-batch-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let state = RandomBatchState()
        state.plan = try RandomBatchPlan.make(count: 3, seed: 18, mantras: records.map(\.id), styles: [10, 20], palettes: [1, 2], settings: ExportSettings(), backgroundFile: nil, postFooter: "My weekly practice #ZenWave")
        state.export(library: library, destination: root, widthOverride: 360, heightOverride: 640)
        let deadline = Date().addingTimeInterval(90)
        while state.exporting && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        if state.exporting { state.cancel(); XCTFail("Batch export timed out"); return }
        XCTAssertNil(state.error); XCTAssertEqual(state.completed, 3); XCTAssertEqual(state.progress, 1)
        let folder = try XCTUnwrap(state.folder), archive = try XCTUnwrap(state.archive)
        let receipt = try JSONDecoder().decode(RandomBatchReceipt.self, from: Data(contentsOf: folder.appendingPathComponent("batch.json")))
        XCTAssertEqual(receipt.status, "complete"); XCTAssertEqual(receipt.completedFiles.count, 3)
        for name in receipt.completedFiles {
            let url = folder.appendingPathComponent(name), asset = AVURLAsset(url: folder.appendingPathComponent(name))
            let duration = try await asset.load(.duration).seconds
            XCTAssertGreaterThan(duration, 10)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            let audio = try XCTUnwrap(tracks.first)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32])
            reader.add(output); XCTAssertTrue(reader.startReading())
            var peak: Float = 0
            while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
                let length = CMBlockBufferGetDataLength(block)
                var samples = [Float](repeating: 0, count: length / 4)
                _ = samples.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
                peak = max(peak, samples.map { abs($0) }.max() ?? 0)
            }
            XCTAssertEqual(reader.status, .completed); XCTAssertGreaterThan(peak, 0.01)
            let frame = try await AVAssetImageGenerator(asset: asset).image(at: CMTime(seconds: 2, preferredTimescale: 600)).image
            XCTAssertEqual(frame.width, 360); XCTAssertEqual(frame.height, 640)
            let text = try String(contentsOf: url.deletingPathExtension().appendingPathExtension("txt"))
            XCTAssertTrue(text.contains("My weekly practice #ZenWave"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.deletingPathExtension().appendingPathExtension("srt").path))
        }
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); process.arguments = ["-Z1", archive.path]; process.standardOutput = pipe
        try process.run(); let list = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(list.components(separatedBy: "\n").filter { $0.hasSuffix(".mp4") }.count, 3)
        XCTAssertTrue(list.contains("batch.json"))
    }

    @MainActor
    func testCancellationKeepsCompletedClipsWithoutPublishingPartialZip() async throws {
        let library = try StudioResources.library()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("random-cancel-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let state = RandomBatchState()
        state.plan = try RandomBatchPlan.make(count: 50, seed: 8, mantras: ["career-confidence-morning"], styles: VisualStyle.all.map(\.id), palettes: [1, 2], settings: ExportSettings(), backgroundFile: nil, postFooter: "")
        state.export(library: library, destination: root, widthOverride: 168, heightOverride: 300)
        let deadline = Date().addingTimeInterval(30)
        while state.completed == 0 && state.exporting && Date() < deadline { try await Task.sleep(nanoseconds: 5_000_000) }
        state.cancel()
        while state.exporting && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(state.exporting); XCTAssertNil(state.error); XCTAssertNil(state.archive)
        let folder = try XCTUnwrap(state.folder)
        let receipt = try JSONDecoder().decode(RandomBatchReceipt.self, from: Data(contentsOf: folder.appendingPathComponent("batch.json")))
        XCTAssertEqual(receipt.status, "stopped"); XCTAssertGreaterThan(receipt.completedFiles.count, 0)
        XCTAssertLessThan(receipt.completedFiles.count, 50)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { $0.pathExtension == "mp4" }.count, receipt.completedFiles.count)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathExtension("zip").path))
    }
}
