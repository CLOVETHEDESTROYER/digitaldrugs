import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class ContentHistoryTests: XCTestCase {
    private func temporary() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("history-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }
    func testReservationsAreAtomicAcrossConnectionsAndSurviveDeletion() async throws {
        let root = try temporary(), database = root.appendingPathComponent("history.sqlite")
        let stores = try [ContentHistory(url: database), ContentHistory(url: database)]
        let recipe = ContentRecipe(canonical: "{\"test\":1}")
        let results = await withTaskGroup(of: Bool.self) { group in
            for index in 0..<16 { group.addTask {
                do { _ = try stores[index % 2].reserve(recipe: recipe, output: root.appendingPathComponent("\(index).mp4"), title: "test"); return true }
                catch { return false }
            } }
            var values: [Bool] = []; for await value in group { values.append(value) }; return values
        }
        XCTAssertEqual(results.filter { $0 }.count, 1)
        let asset = try XCTUnwrap(stores[0].assets().first)
        let output = URL(fileURLWithPath: asset.output)
        try Data("completed-movie-fixture".utf8).write(to: output)
        try stores[0].complete(asset.id, output: output)
        try FileManager.default.removeItem(at: output)
        XCTAssertThrowsError(try stores[1].reserve(recipe: recipe, output: root.appendingPathComponent("again.mp4"), title: "duplicate"))
        let backup = try ContentHistory(url: root.appendingPathComponent("history-backup.sqlite"))
        XCTAssertEqual(try backup.assets().first?.status, "complete")
        XCTAssertFalse(try XCTUnwrap(backup.assets().first?.checksum).isEmpty)
    }
    func testFailedAndInterruptedRecoveryProtectsProducedFiles() throws {
        let root = try temporary(), store = try ContentHistory(url: root.appendingPathComponent("history.sqlite"))
        let recipe = ContentRecipe(canonical: "{\"case\":1}"), output = root.appendingPathComponent("failed.mp4")
        let id = try store.reserve(recipe: recipe, output: output, title: "cancelled")
        try store.fail(id, output: output, error: CancellationError())
        XCTAssertFalse(try store.isUsed(recipe))
        _ = try store.reserve(recipe: recipe, output: output, title: "retry")
        let produced = root.appendingPathComponent("produced.mp4"), second = ContentRecipe(canonical: "{\"case\":2}")
        _ = try store.reserve(recipe: second, output: produced, title: "sidecar failure")
        try Data("existing media".utf8).write(to: produced)
        try store.recoverInterrupted()
        XCTAssertFalse(try store.isUsed(recipe))
        XCTAssertTrue(try store.isUsed(second))
        XCTAssertEqual(try store.assets().first { $0.output == produced.path }?.status, "review")
        XCTAssertThrowsError(try store.recordPublication(id: "unknown", assetID: "missing", payload: "{}"))
    }
    func testCoreIdentityUsesActualAudioAndIgnoresCosmeticChanges() throws {
        let root = try temporary(), mantra = try XCTUnwrap(StudioResources.library().first)
        var settings = ExportSettings()
        let original = ExportJob(mantra: mantra, settings: settings, start: 0, end: nil)
        let core = try ContentRecipe.make(original)
        settings.branding = false; settings.heading = "Another heading"; settings.format = .square
        settings.callToAction.enabled = true; settings.motionSpeed = 2; settings.backgroundVolume = 0
        settings.soundscape.beat = .theta; settings.soundscape.beatVolume = 0
        settings.soundscape.natureID = "ocean"; settings.soundscape.natureVolume = 0
        let cosmetic = ExportJob(mantra: mantra, settings: settings, start: 10, end: 14)
        XCTAssertEqual(core.fingerprint, try ContentRecipe.make(cosmetic).fingerprint)
        settings.palette = 2
        XCTAssertNotEqual(core.fingerprint, try ContentRecipe.make(ExportJob(mantra: mantra, settings: settings, start: 0, end: nil)).fingerprint)
        let one = root.appendingPathComponent("first.wav"), renamed = root.appendingPathComponent("renamed.wav")
        try Data("audio content A".utf8).write(to: one); try FileManager.default.copyItem(at: one, to: renamed)
        settings = ExportSettings()
        let a = try ContentRecipe.make(ExportJob(mantra: mantra, settings: settings, start: 0, end: nil, backgroundURL: one))
        let b = try ContentRecipe.make(ExportJob(mantra: mantra, settings: settings, start: 0, end: nil, backgroundURL: renamed))
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        try Data("different audio".utf8).write(to: renamed)
        XCTAssertNotEqual(a.fingerprint, try ContentRecipe.make(ExportJob(mantra: mantra, settings: settings, start: 0, end: nil, backgroundURL: renamed)).fingerprint)
    }
    func testBreathingLiveAndSilentLayersHaveStableCoreIdentity() throws {
        let mantra = try XCTUnwrap(StudioResources.library().first)
        var breath = BreathPlan(); breath.apply(.box)
        let first = try ContentRecipe.make(ExportJob(mantra: breath.mantra, settings: ExportSettings(), start: 0, end: nil, breathPlan: breath))
        var fallback = ExportSettings(); fallback.style = 35
        XCTAssertEqual(first.fingerprint, try ContentRecipe.make(ExportJob(mantra: breath.mantra, settings: fallback, start: 0, end: nil, breathPlan: breath)).fingerprint)
        breath.cycles = 50; breath.loop = false
        XCTAssertEqual(first.fingerprint, try ContentRecipe.make(ExportJob(mantra: breath.mantra, settings: ExportSettings(), start: 0, end: nil, breathPlan: breath)).fingerprint)
        breath.apply(.slowBox)
        XCTAssertNotEqual(first.fingerprint, try ContentRecipe.make(ExportJob(mantra: breath.mantra, settings: ExportSettings(), start: 0, end: nil, breathPlan: breath)).fingerprint)
        var live = LivePlan(); live.chapters = [LiveChapter(mantraID: mantra.id, seconds: 60)]
        let timeline = try LiveTimeline.make(plan: live, library: [mantra], lengths: [mantra.id: 20])
        let core = try ContentRecipe.make(ExportJob(mantra: timeline.mantra, settings: ExportSettings(), start: 0, end: nil, liveTimeline: timeline))
        fallback.palette = 5
        XCTAssertEqual(core.fingerprint, try ContentRecipe.make(ExportJob(mantra: timeline.mantra, settings: fallback, start: 0, end: nil, liveTimeline: timeline)).fingerprint)
        live.chapters[0].id = UUID(); live.chapters[0].seconds = 120
        let repeatTimeline = try LiveTimeline.make(plan: live, library: [mantra], lengths: [mantra.id: 20])
        XCTAssertEqual(core.fingerprint, try ContentRecipe.make(ExportJob(mantra: repeatTimeline.mantra, settings: ExportSettings(), start: 0, end: nil, liveTimeline: repeatTimeline)).fingerprint)
    }
    func testRequestIdempotencyAndSingleWorkerClaim() async throws {
        let root = try temporary(), url = root.appendingPathComponent("history.sqlite")
        let a = try ContentHistory(url: url), b = try ContentHistory(url: url)
        XCTAssertEqual(try a.acceptRequest(id: "week-1", payload: "original brief and params"), "queued")
        XCTAssertEqual(try b.acceptRequest(id: "week-1", payload: "original brief and params"), "queued")
        XCTAssertThrowsError(try b.acceptRequest(id: "week-1", payload: "changed params"))
        let claims = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask { try a.claimRequest(id: "week-1") }; group.addTask { try b.claimRequest(id: "week-1") }
            var result: [Bool] = []; for try await claim in group { result.append(claim) }; return result
        }
        XCTAssertEqual(claims.filter { $0 }.count, 1)
        try a.setRequest(id: "week-1", status: "complete", result: "original result")
        XCTAssertEqual(try b.acceptRequest(id: "week-1", payload: "original brief and params"), "complete")
        XCTAssertEqual(try b.requestResult(id: "week-1"), "original result")
    }
    func testLegacyImportBlocksUnresolvedImportedAudioConservatively() throws {
        let root = try temporary(), store = try ContentHistory(url: root.appendingPathComponent("history.sqlite"))
        let mantra = try XCTUnwrap(StudioResources.library().first), settings = ExportSettings()
        let movie = root.appendingPathComponent("legacy.mp4")
        try Data("legacy fixture".utf8).write(to: movie)
        let receipt = ExportReceipt(title: mantra.title, sourceFile: mantra.fileName, captionTiming: mantra.timing,
            start: 0, end: 4, settings: settings, backgroundFile: "missing-original.mp3")
        try Data(ContentHistory.json(receipt).utf8).write(to: root.appendingPathComponent("legacy.json"))
        XCTAssertTrue(try LegacyHistoryImporter.run(folder: root, history: store, library: [mantra]).contains("1 receipts"))
        XCTAssertEqual(try store.assets().first?.status, "legacy")
        let imported = root.appendingPathComponent("any-background.mp3"); try Data("unknown music".utf8).write(to: imported)
        let job = ExportJob(mantra: mantra, settings: settings, start: 0, end: 3, backgroundURL: imported)
        XCTAssertTrue(try store.isUsed(ContentRecipe.make(job)))
        XCTAssertThrowsError(try store.reserve(recipe: ContentRecipe.make(job), output: root.appendingPathComponent("duplicate.mp4"), title: "blocked"))
    }
    func testAgentTenClipRoundTripReplayAndNoDuplicateCore() async throws {
        let root = try temporary(), history = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let queue = AgentQueue(root: root.appendingPathComponent("Exchange"), history: history, widthOverride: 144, heightOverride: 256)
        let library = try StudioResources.library()
        let mantra = try XCTUnwrap(library.first { $0.id == "career-confidence-morning" })
        try queue.setup(library: library)
        XCTAssertTrue(FileManager.default.fileExists(atPath: queue.root.appendingPathComponent("AGENT-INSTRUCTIONS.md").path))
        var request = AgentBatchRequest(requestId: "ten-clips", brief: "Ten calm clips for review", count: 10,
            manifestationIds: [mantra.id], visualStyles: [10, 14, 34, 35], paletteIds: [1, 4, 5], allowedBeats: [.theta], natureIds: ["forest_ambience"], chakraIds: ["root"], clipSeconds: 3)
        let status = try await queue.process(request, library: library)
        XCTAssertEqual(status.status, "complete"); XCTAssertEqual(status.assets.count, 10)
        XCTAssertEqual(Set(status.assets.map(\.fingerprint)).count, 10)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(status.archive)))
        for asset in status.assets {
            XCTAssertEqual(asset.status, "complete")
            XCTAssertEqual(asset.checksum, try ContentHistory.fileHash(URL(fileURLWithPath: asset.output)))
            let movie = AVURLAsset(url: URL(fileURLWithPath: asset.output))
            let duration = try await movie.load(.duration).seconds
            XCTAssertEqual(duration, 3, accuracy: 0.05)
            let tracks = try await movie.loadTracks(withMediaType: .audio); XCTAssertEqual(tracks.count, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: URL(fileURLWithPath: asset.output).deletingPathExtension().appendingPathExtension("jpg").path))
        }
        let again = try await queue.process(request, library: library)
        XCTAssertEqual(again.assets.map(\.id), status.assets.map(\.id)); XCTAssertEqual(try history.assets().count, 10)
        request.brief = "Different brief with reused ID"
        do { _ = try await queue.process(request, library: library); XCTFail("Changed payload was accepted") } catch {}
        let used = status.assets[0]
        let receipt = try JSONDecoder().decode(ExportReceipt.self, from: Data(contentsOf: URL(fileURLWithPath: used.output).deletingPathExtension().appendingPathExtension("json")))
        let duplicate = AgentBatchRequest(requestId: "duplicate-core", brief: "Try the same combination", count: 1,
            manifestationIds: [mantra.id], visualStyles: [receipt.settings.style], paletteIds: [receipt.settings.palette], settings: receipt.settings, clipSeconds: 3)
        do { _ = try await queue.process(duplicate, library: library); XCTFail("Duplicate core was rendered") } catch {}
        XCTAssertEqual(try history.assets().count, 10)
        try history.recordPublication(id: "facebook-1", assetID: used.id, payload: "actual post ack")
        try history.recordPublication(id: "facebook-1", assetID: used.id, payload: "actual post ack")
        XCTAssertThrowsError(try history.recordPublication(id: "facebook-1", assetID: used.id, payload: "changed ack"))
    }
    func testFolderRejectsInvalidRequestsAndManualExporterUsesSameHistory() async throws {
        let root = try temporary(), history = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let queue = AgentQueue(root: root.appendingPathComponent("Exchange"), history: history, widthOverride: 144, heightOverride: 256)
        let library = try StudioResources.library(); try queue.setup(library: library)
        let malformed = queue.root.appendingPathComponent("Requests/bad.json")
        try Data("not json".utf8).write(to: malformed)
        try await queue.poll(library: library)
        XCTAssertTrue(FileManager.default.fileExists(atPath: queue.root.appendingPathComponent("Status/bad.json").path))
        XCTAssertFalse(AgentBatchRequest.validID("../escape"))
        let mantra = try XCTUnwrap(library.first)
        let job = ExportJob(mantra: mantra, settings: ExportSettings(), start: 0, end: 3)
        let output = root.appendingPathComponent("manual.mp4")
        try await VideoExporter.export(job, to: output, widthOverride: 144, heightOverride: 256, historyStore: history) { _ in }
        do {
            try await VideoExporter.export(job, to: root.appendingPathComponent("renamed.mp4"), widthOverride: 144, heightOverride: 256, historyStore: history) { _ in }
            XCTFail("Manual duplicate rendered")
        } catch {}
        XCTAssertEqual(try history.assets().count, 1)
    }
    func testRequestNormalizationAndLimits() throws {
        let library = try StudioResources.library(), mantra = try XCTUnwrap(library.first)
        var settings = ExportSettings(); settings.soundscape.chakra = StudioChakraLayer(selected: ["root", "heart"])
        var a = AgentBatchRequest(requestId: "normalized", brief: "Original request", count: 1,
            manifestationIds: [mantra.id], visualStyles: [35, 34], paletteIds: [4, 1], settings: settings)
        var b = a; b.visualStyles.reverse(); b.paletteIds.reverse()
        XCTAssertEqual(try a.canonicalPayload(), try b.canonicalPayload())
        try a.validate(library: library)
        a.count = 51; XCTAssertThrowsError(try a.validate(library: library))
        a.count = 0; XCTAssertThrowsError(try a.validate(library: library))
        a.count = 1; a.kind = "breathing"; XCTAssertThrowsError(try a.validate(library: library))
        a.kind = "manifestation-batch"; a.manifestationIds = ["missing"]; XCTAssertThrowsError(try a.validate(library: library))
    }
}
