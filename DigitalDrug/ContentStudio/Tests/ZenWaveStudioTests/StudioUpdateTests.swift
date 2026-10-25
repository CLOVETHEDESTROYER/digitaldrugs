import XCTest
import Foundation
import CSQLite
@testable import ZenWaveStudio

final class StudioUpdateTests: XCTestCase {
    private func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("studio-update-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }; return root
    }
    private func release(_ version: String, prefix: String = StudioUpdateClient.tagPrefix, digest: Bool = true, prerelease: Bool = false) throws -> StudioRelease {
        let tag = prefix + version
        var asset: [String: Any] = ["name": StudioUpdateClient.assetName, "state": "uploaded", "size": 1234,
            "browser_download_url": "https://github.com/\(StudioUpdateClient.repository)/releases/download/\(tag)/\(StudioUpdateClient.assetName)"]
        if digest { asset["digest"] = "sha256:" + String(repeating: "a", count: 64) }
        return try JSONDecoder().decode(StudioRelease.self, from: JSONSerialization.data(withJSONObject: [
            "tag_name": tag, "html_url": "https://github.com/\(StudioUpdateClient.repository)/releases/tag/\(tag)",
            "body": "Release notes", "draft": false, "prerelease": prerelease, "assets": [asset]]))
    }
    func testReleaseSelectionIsNumericScopedAndRequiresVerifiedPackage() throws {
        let releases = try [release("0.14.0"), release("0.14.1"), release("0.15.0"), release("99.0.0", prefix: "ios-v"),
            release("0.20.0", prerelease: true), release("0.19.0", digest: false)]
        XCTAssertEqual(try StudioUpdateClient.select(releases, newerThan: "0.14.0")?.version, "0.15.0")
        XCTAssertNil(try StudioUpdateClient.select(releases, newerThan: "0.15.0"))
        XCTAssertTrue(try XCTUnwrap(StudioVersion("0.10.0")) > XCTUnwrap(StudioVersion("0.9.9")))
        XCTAssertNil(StudioVersion("0.14.0-beta")); XCTAssertNil(StudioVersion("1.2")); XCTAssertNil(StudioVersion("1.2.-1"))
        var object = try JSONSerialization.jsonObject(with: JSONEncoderFixture(releases[2])) as! [String: Any]
        object["html_url"] = "https://example.invalid/release"
        let redirected = try JSONDecoder().decode(StudioRelease.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(try StudioUpdateClient.select([redirected], newerThan: "0.14.0"))
    }
    private func JSONEncoderFixture(_ release: StudioRelease) throws -> Data {
        let asset = release.assets[0]
        return try JSONSerialization.data(withJSONObject: ["tag_name": release.tag_name, "html_url": release.html_url.absoluteString,
            "draft": release.draft, "prerelease": release.prerelease, "assets": [["name": asset.name, "state": asset.state,
                "size": asset.size, "digest": asset.digest!, "browser_download_url": asset.browser_download_url.absoluteString]]])
    }
    func testArchiveTraversalAndInvalidUniversalBinariesAreRejected() throws {
        try StudioUpdateClient.validateEntries(["ZenWave Content Studio.app/", "ZenWave Content Studio.app/Contents/MacOS/ZenWaveStudio"])
        for path in ["/tmp/escape", "ZenWave Content Studio.app/../../escape", "Another.app/Contents/file", "ZenWave Content Studio.app\\escape"] {
            XCTAssertThrowsError(try StudioUpdateClient.validateEntries([path]))
        }
        let root = try temporary(), binary = root.appendingPathComponent("binary")
        var header = Data(repeating: 0, count: 48)
        func put(_ value: UInt32, at offset: Int) { for i in 0..<4 { header[offset + i] = UInt8((value >> (24 - i * 8)) & 255) } }
        put(0xcafebabe, at: 0); put(2, at: 4); put(0x01000007, at: 8); put(0x0100000c, at: 28)
        try header.write(to: binary)
        XCTAssertEqual(try StudioUpdateClient.binaryArchitectures(binary), ["arm64", "x86_64"])
        try Data("not an executable".utf8).write(to: binary)
        XCTAssertThrowsError(try StudioUpdateClient.binaryArchitectures(binary))
    }
    func testUpdateWaitsForActiveWorkAndBlocksOtherProcesses() async throws {
        let root = try temporary(), gate = StudioOperationGate(url: root.appendingPathComponent("operations.lock"))
        let active = try gate.beginWork()
        let waiting = Task { try await gate.waitForUpdate() }
        while !gate.updatePending { await Task.yield() }
        XCTAssertNil(try gate.tryWork())
        let another = StudioOperationGate(url: gate.url)
        XCTAssertNil(try another.tryExclusive())
        active.release()
        let exclusive = try await waiting.value
        XCTAssertNil(try another.tryWork())
        exclusive.release(); gate.cancelUpdate()
        let next = try another.beginWork(); next.release()
    }
    func testCancelledUpdateResumesProcessingWithoutReleasingActiveJob() async throws {
        let root = try temporary(), gate = StudioOperationGate(url: root.appendingPathComponent("operations.lock"))
        let active = try gate.beginWork(); defer { active.release() }
        let waiting = Task { try await gate.waitForUpdate() }
        while !gate.updatePending { await Task.yield() }
        waiting.cancel()
        do { _ = try await waiting.value; XCTFail("Cancellation ignored") } catch is CancellationError {}
        XCTAssertFalse(gate.updatePending)
        let next = try gate.beginWork(); next.release()
        XCTAssertNil(try StudioOperationGate(url: gate.url).tryExclusive())
    }
    func testIncomingDriveRequestWaitsWithoutCreatingErrorOrLosingIdentity() async throws {
        let root = try temporary(), history = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let gate = StudioOperationGate(url: root.appendingPathComponent("operations.lock"))
        let queue = AgentQueue(root: root.appendingPathComponent("Exchange"), history: history, widthOverride: 144, heightOverride: 256, operationGate: gate)
        let library = try StudioResources.library(); try queue.setup(library: library)
        let request = AgentBatchRequest(requestId: "pending-during-update", brief: "Queued by existing automation", count: 1,
            manifestationIds: [library[0].id], visualStyles: [34], paletteIds: [1], allowedBeats: [.theta], clipSeconds: 3)
        let input = queue.root.appendingPathComponent("Requests/\(request.requestId).json")
        let data = try Data(ContentHistory.json(request).utf8); try data.write(to: input)
        let exclusive = try await gate.waitForUpdate()
        try await queue.poll(library: library)
        XCTAssertEqual(try Data(contentsOf: input), data)
        XCTAssertTrue(try history.requests().isEmpty); XCTAssertTrue(try history.assets().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: queue.root.appendingPathComponent("Status/\(request.requestId).json").path))
        exclusive.release(); gate.cancelUpdate()
        try await queue.poll(library: library)
        XCTAssertEqual(try history.assets().count, 1)
        let original = try history.assets()[0].id
        try await queue.poll(library: library)
        XCTAssertEqual(try history.assets()[0].id, original)
    }
    func testActiveNestedExportCanFinishWhileAnUpdateIsWaiting() async throws {
        let root = try temporary(), gate = StudioOperationGate(url: root.appendingPathComponent("operations.lock"))
        let active = try gate.beginWork()
        let waiting = Task { try await gate.waitForUpdate() }
        while !gate.updatePending { await Task.yield() }
        let record = try XCTUnwrap(StudioResources.library().first)
        let output = root.appendingPathComponent("current-job.mp4")
        try await VideoExporter.export(ExportJob(mantra: record, settings: ExportSettings(), start: 0, end: 3), to: output,
            widthOverride: 144, heightOverride: 256, recordHistory: false, operationLease: active) { _ in }
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        active.release()
        let exclusive = try await waiting.value; exclusive.release(); gate.cancelUpdate()
    }
    func testMetadataRefreshPreservesExistingFilesAndCatalogV1() throws {
        let root = try temporary(), store = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let queue = AgentQueue(root: root.appendingPathComponent("Exchange"), history: store)
        let library = try StudioResources.library(); try queue.setup(library: library)
        let catalog = queue.root.appendingPathComponent("catalog.json"), instructions = queue.root.appendingPathComponent("AGENT-INSTRUCTIONS.md")
        let number = try FileManager.default.attributesOfItem(atPath: catalog.path)[.systemFileNumber] as! NSNumber
        let date = try FileManager.default.attributesOfItem(atPath: catalog.path)[.modificationDate] as! Date
        try queue.setup(library: library)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: catalog.path)[.modificationDate] as? Date, date)
        try ExchangeMetadata.write(Data("old metadata".utf8), to: catalog)
        let instructionNumber = try FileManager.default.attributesOfItem(atPath: instructions.path)[.systemFileNumber] as! NSNumber
        try ExchangeMetadata.write(Data("older instructions".utf8), to: instructions)
        try queue.setup(library: library)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: catalog.path)[.systemFileNumber] as? NSNumber, number)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: instructions.path)[.systemFileNumber] as? NSNumber, instructionNumber)
        let published = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as! [String: Any]
        XCTAssertEqual(published["schemaVersion"] as? Int, 1)
        XCTAssertEqual(published["requestKinds"] as? [String], ["manifestation-batch"])
        XCTAssertEqual(Set((published["visuals"] as! [[String: String]]).map { $0["id"]! }), Set((0...35).map(String.init)))
        let baseline = try JSONDecoder().decode([Mantra].self, from: Data(contentsOf: Bundle.module.url(forResource: "exchange-v1-catalog", withExtension: "json", subdirectory: "Fixtures")!))
        for original in baseline { XCTAssertEqual(library.first { $0.id == original.id }?.fileName, original.fileName) }
        let info = try JSONSerialization.jsonObject(with: Data(contentsOf: queue.root.appendingPathComponent("studio-info.json"))) as! [String: Any]
        XCTAssertEqual(info["catalogSHA256"] as? String, try ContentHistory.fileHash(catalog))
        XCTAssertEqual((info["studio"] as? [String: Any])?["exchangeSchemaVersion"] as? Int, 1)
    }
    func testExistingPublicationIDsCanBeEnrichedOnceWithoutChangingV1Identity() async throws {
        let root = try temporary(), store = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let queue = AgentQueue(root: root.appendingPathComponent("Exchange"), history: store)
        let library = try StudioResources.library(); try queue.setup(library: library)
        let output = root.appendingPathComponent("fixture.mp4")
        let asset = try store.reserve(recipe: ContentRecipe(canonical: "{\"fixture\":true}"), output: output, title: "Publication fixture")
        try Data("metadata test fixture, not a real movie".utf8).write(to: output); try store.complete(asset, output: output)
        let report = PublicationReport(id: "publication-existing", assetId: asset, platform: "instagram", accountId: "test-account", postId: "existing-post", status: "published", scheduledAt: nil, url: "https://example.invalid/post")
        let identity = try ContentHistory.json(report)
        try store.recordPublication(id: report.id, assetID: asset, payload: identity)
        var raw = try JSONSerialization.jsonObject(with: Data(identity.utf8)) as! [String: Any]
        raw["postedAt"] = "2026-10-25T13:00:00-06:00"; raw["captionVariant"] = "morning-hook-save"
        raw["futureField"] = ["preserve": true]
        let file = queue.root.appendingPathComponent("Reports/publication-existing.json")
        let data = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]); try data.write(to: file)
        try await queue.poll(library: library)
        let payload = try XCTUnwrap(store.publications().first?["payload"])
        let stored = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as! [String: Any]
        XCTAssertEqual(stored["postedAt"] as? String, raw["postedAt"] as? String)
        XCTAssertEqual(stored["captionVariant"] as? String, "morning-hook-save")
        XCTAssertEqual((stored["futureField"] as? [String: Bool])?["preserve"], true)
        XCTAssertEqual(try Data(contentsOf: file), data)
        let eventCount = try store.events().count
        try await queue.poll(library: library)
        try store.recordPublication(id: report.id, assetID: asset, payload: identity) // older client replay after rollback
        XCTAssertEqual(try store.events().count, eventCount)
        raw["captionVariant"] = "changed"
        try JSONSerialization.data(withJSONObject: raw).write(to: file)
        try await queue.poll(library: library)
        XCTAssertEqual(try store.publications().first?["payload"], payload)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.deletingPathExtension().appendingPathExtension("error.txt").path))
    }
    private func fixturePlan(_ root: URL) throws -> StudioInstallPlan {
        let old = root.appendingPathComponent("Installed.app"), next = root.appendingPathComponent("Downloaded.app")
        for (app, version) in [(old, "old"), (next, "new")] {
            try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
            try Data(version.utf8).write(to: app.appendingPathComponent("version"))
        }
        let recovery = root.appendingPathComponent("Recovery"); try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        return StudioInstallPlan(id: UUID().uuidString, parentPID: 0, sourceApp: next, targetApp: old, stage: root, recovery: recovery,
            historyURL: root.appendingPathComponent("history.sqlite"), fromVersion: "old", toVersion: "new")
    }
    func testInstallationSwapAndRollbackPreserveCurrentHistoryAndPreviousApp() throws {
        let root = try temporary(), plan = try fixturePlan(root)
        let latestHistory = Data("newly generated and published asset history".utf8); try latestHistory.write(to: plan.historyURL)
        try StudioUpdateInstaller.swap(plan, verify: { _, _ in })
        XCTAssertEqual(try String(contentsOf: plan.targetApp.appendingPathComponent("version")), "new")
        XCTAssertEqual(try String(contentsOf: plan.previousApp.appendingPathComponent("version")), "old")
        try StudioUpdateInstaller.restore(plan)
        XCTAssertEqual(try String(contentsOf: plan.targetApp.appendingPathComponent("version")), "old")
        XCTAssertEqual(try Data(contentsOf: plan.historyURL), latestHistory)
    }
    func testVerificationFailureNeverReplacesInstalledApp() throws {
        let root = try temporary(), plan = try fixturePlan(root)
        XCTAssertThrowsError(try StudioUpdateInstaller.swap(plan, verify: { url, _ in
            if url == plan.incomingApp { throw StudioError.message("Simulated signature failure") }
        }))
        XCTAssertEqual(try String(contentsOf: plan.targetApp.appendingPathComponent("version")), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: plan.retiredApp.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: plan.incomingApp.path))
    }
    func testLegacyCompletedRequestReplaysWithoutTouchingReadyFiles() async throws {
        let root = try temporary(), store = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let queue = AgentQueue(root: root.appendingPathComponent("Exchange"), history: store)
        let library = try StudioResources.library(); try queue.setup(library: library)
        let original = Data(#"{"schemaVersion":1,"kind":"manifestation-batch","requestId":"first-test","brief":"One short background-reactive test video","count":1,"manifestationIds":["abundance"],"visualStyles":[34,35],"paletteIds":[1,4],"allowedBeats":["theta"],"format":"portrait","clipSeconds":3,"requestedBy":"Muse"}"#.utf8)
        let request = try JSONDecoder().decode(AgentBatchRequest.self, from: original)
        let legacy = String(decoding: try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: original), options: [.sortedKeys]), as: UTF8.self)
        XCTAssertEqual(try request.canonicalPayload(), legacy)
        _ = try store.acceptRequest(id: "first-test", payload: legacy)
        let previous = AgentJobStatus(requestId: "first-test", status: "complete", progress: 1, message: "Existing result")
        try store.setRequest(id: "first-test", status: "complete", result: ContentHistory.json(previous))
        let ready = queue.root.appendingPathComponent("Ready/first-test"); try FileManager.default.createDirectory(at: ready, withIntermediateDirectories: true)
        let movie = ready.appendingPathComponent("01-abundance-v35-c1.mp4"), bytes = Data("existing media fixture".utf8)
        try bytes.write(to: movie)
        let result = try await queue.process(request, library: library)
        XCTAssertEqual(result.status, "complete"); XCTAssertEqual(try Data(contentsOf: movie), bytes)
        XCTAssertTrue(try store.assets().isEmpty)
    }
    func testNewerHistorySchemaIsNotResetByAnOlderApp() throws {
        let root = try temporary(), database = root.appendingPathComponent("newer.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &handle), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(handle, "PRAGMA user_version=2", nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        XCTAssertThrowsError(try ContentHistory(url: database))
        XCTAssertEqual(sqlite3_open(database.path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 2)
    }
    func testUpdateHistorySnapshotIsIndependentOfLaterJobs() throws {
        let root = try temporary(), store = try ContentHistory(url: root.appendingPathComponent("db/history.sqlite"))
        let output = root.appendingPathComponent("first.mp4")
        let id = try store.reserve(recipe: ContentRecipe(canonical: "{\"snapshot\":1}"), output: output, title: "Snapshot fixture")
        try Data("first fixture".utf8).write(to: output); try store.complete(id, output: output)
        let snapshotURL = root.appendingPathComponent("snapshot.sqlite")
        try store.snapshot(to: snapshotURL)
        _ = try store.reserve(recipe: ContentRecipe(canonical: "{\"snapshot\":2}"), output: root.appendingPathComponent("second.mp4"), title: "Later job")
        let snapshot = try ContentHistory(url: snapshotURL)
        XCTAssertEqual(try snapshot.assets().count, 1)
        XCTAssertEqual(try store.assets().count, 2)
    }
}
