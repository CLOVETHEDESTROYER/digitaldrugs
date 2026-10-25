import Foundation
import CryptoKit
import CSQLite

struct HistoryAsset: Codable, Identifiable {
    let id: String
    let fingerprint: String
    let requestID: String
    let title: String
    let status: String
    let output: String
    let checksum: String
    let error: String
    let created: String
    let recipe: String
}

/// A single local authority. SQLite transactions and a partial unique index protect
/// reservations across windows and processes; completed media stays protected forever.
final class ContentHistory: @unchecked Sendable {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ZenWave Content Studio", isDirectory: true)
    private static let production = Result { try ContentHistory(url: directory.appendingPathComponent("history.sqlite")) }
    static var shared: ContentHistory { get throws { try production.get() } }
    let url: URL
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw StudioError.message("Could not open content history. No video was rendered.")
        }
        sqlite3_busy_timeout(db, 5000)
        do {
            let version = Int(try rows("PRAGMA user_version").first?["user_version"] ?? "0") ?? 0
            guard version <= 1 else { throw StudioError.message("This history database needs a newer studio version. It was not downgraded or reset.") }
            try execute("PRAGMA journal_mode=WAL")
            try execute("CREATE TABLE IF NOT EXISTS assets(id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, request_id TEXT NOT NULL, title TEXT NOT NULL, status TEXT NOT NULL, output TEXT NOT NULL, checksum TEXT NOT NULL DEFAULT '', error TEXT NOT NULL DEFAULT '', created TEXT NOT NULL, recipe TEXT NOT NULL)")
            try execute("CREATE UNIQUE INDEX IF NOT EXISTS unique_content ON assets(fingerprint) WHERE status != 'failed'")
            try execute("CREATE TABLE IF NOT EXISTS requests(id TEXT PRIMARY KEY, payload TEXT NOT NULL, status TEXT NOT NULL, result TEXT NOT NULL DEFAULT '', created TEXT NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY, subject TEXT NOT NULL, event TEXT NOT NULL, created TEXT NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS publications(id TEXT PRIMARY KEY, asset_id TEXT NOT NULL, payload TEXT NOT NULL)")
            // Keep the v1 identity payload intact for older apps and rollback. Full
            // Drive report metadata is an additive extension, enriched once on replay.
            try execute("CREATE TABLE IF NOT EXISTS publication_details(id TEXT PRIMARY KEY, payload TEXT NOT NULL)")
            try execute("PRAGMA user_version=1")
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { sqlite3_close(db) }
    private func withLock<T>(_ body: () throws -> T) rethrows -> T { lock.lock(); defer { lock.unlock() }; return try body() }
    private func rows(_ sql: String, _ arguments: [String] = []) throws -> [[String: String]] {
        try withLock {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
            defer { sqlite3_finalize(statement) }
            for (index, value) in arguments.enumerated() {
                guard sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) == SQLITE_OK else { throw failure() }
            }
            var result: [[String: String]] = []
            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_DONE { return result }
                guard step == SQLITE_ROW else { throw failure() }
                var row: [String: String] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    let key = String(cString: sqlite3_column_name(statement, index))
                    row[key] = sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
                }
                result.append(row)
            }
        }
    }
    private func execute(_ sql: String, _ arguments: [String] = []) throws { _ = try rows(sql, arguments) }
    private func failure() -> StudioError { .message("Content history: \(String(cString: sqlite3_errmsg(db)))") }
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try withLock {
            try execute("BEGIN IMMEDIATE")
            do { let value = try body(); try execute("COMMIT"); return value }
            catch { try? execute("ROLLBACK"); throw error }
        }
    }
    private func event(_ id: String, _ text: String) throws {
        try execute("INSERT INTO events(subject,event,created) VALUES(?,?,?)", [id, text, Self.now])
    }
    private static var now: String { ISO8601DateFormatter().string(from: Date()) }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func fileHash(_ url: URL) throws -> String {
        let stream = try FileHandle(forReadingFrom: url); defer { try? stream.close() }
        var hash = SHA256()
        while let chunk = try stream.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    func assets() throws -> [HistoryAsset] {
        try rows("SELECT * FROM assets ORDER BY created DESC, rowid DESC").map { row in
            HistoryAsset(id: row["id"]!, fingerprint: row["fingerprint"]!, requestID: row["request_id"]!, title: row["title"]!,
                         status: row["status"]!, output: row["output"]!, checksum: row["checksum"]!, error: row["error"]!, created: row["created"]!, recipe: row["recipe"]!)
        }
    }
    func isUsed(_ fingerprint: String) throws -> Bool {
        try !rows("SELECT id FROM assets WHERE fingerprint=? AND status!='failed' LIMIT 1", [fingerprint]).isEmpty
    }
    func isUsed(_ recipe: ContentRecipe) throws -> Bool {
        if try isUsed(recipe.fingerprint) { return true }
        // Legacy receipts omitted imported-audio hashes. Conservatively block any
        // imported background for an otherwise matching legacy core.
        var incoming = try JSONSerialization.jsonObject(with: Data(recipe.canonical.utf8)) as! [String: Any]
        incoming.removeValue(forKey: "importedAudio")
        let normalized = try JSONSerialization.data(withJSONObject: incoming, options: [.sortedKeys])
        return try rows("SELECT recipe FROM assets WHERE status='legacy'").contains { row in
            guard let data = row["recipe"]?.data(using: .utf8) else { return false }
            return data == normalized
        }
    }
    func reserve(recipe: ContentRecipe, output: URL, title: String, requestID: String = "") throws -> String {
        try transaction {
            guard !FileManager.default.fileExists(atPath: output.path) else { throw StudioError.message("An export already exists at this destination.") }
            guard try !isUsed(recipe) else {
                throw StudioError.message("This video/audio combination has already been made or reserved. Choose another visual, color, manifestation or background sound. See History & Agent Jobs.")
            }
            let id = UUID().uuidString
            try execute("INSERT INTO assets(id,fingerprint,request_id,title,status,output,created,recipe) VALUES(?,?,?,?, 'reserved',?,?,?)",
                        [id, recipe.fingerprint, requestID, title, output.path, Self.now, recipe.canonical])
            try event(id, "reserved")
            try event(id, recipe.details)
            return id
        }
    }
    func complete(_ id: String, output: URL) throws {
        let checksum = try Self.fileHash(output)
        try transaction {
            try execute("UPDATE assets SET status='complete', checksum=?, error='' WHERE id=?", [checksum, id])
            try event(id, "complete")
        }
        try backup()
    }
    func fail(_ id: String, output: URL, error: Error) throws {
        // Even if a sidecar failed, a produced MP4 must never be made again.
        let exists = FileManager.default.fileExists(atPath: output.path)
        let checksum = exists ? (try Self.fileHash(output)) : ""
        try transaction {
            try execute("UPDATE assets SET status=?,checksum=?,error=? WHERE id=?", [exists ? "review" : "failed", checksum, error.localizedDescription, id])
            try event(id, exists ? "output retained; review required" : "failed before output")
        }
    }
    /// Explicit recovery only, after the operator has stopped all other studio processes.
    func recoverInterrupted() throws {
        for asset in try assets() where asset.status == "reserved" {
            try fail(asset.id, output: URL(fileURLWithPath: asset.output), error: StudioError.message("Recovered interrupted render; check any retained media."))
        }
        try execute("UPDATE requests SET status='interrupted' WHERE status='rendering'")
        try backup()
    }
    /// Reusing a request ID returns its original result; changed parameters are rejected.
    func acceptRequest(id: String, payload: String) throws -> String {
        try transaction {
            if let existing = try rows("SELECT * FROM requests WHERE id=?", [id]).first {
                guard existing["payload"] == payload else { throw StudioError.message("Request ID already exists with different parameters. Use a new request ID.") }
                return existing["status"]!
            }
            try execute("INSERT INTO requests(id,payload,status,created) VALUES(?,?,'queued',?)", [id, payload, Self.now])
            try event(id, "request accepted")
            return "queued"
        }
    }
    func setRequest(id: String, status: String, result: String) throws {
        try transaction {
            try execute("UPDATE requests SET status=?,result=? WHERE id=?", [status, result, id])
            try event(id, "request \(status)")
        }
    }
    func claimRequest(id: String) throws -> Bool {
        try transaction {
            try execute("UPDATE requests SET status='rendering' WHERE id=? AND status='queued'", [id])
            let claimed = sqlite3_changes(db) == 1
            if claimed { try event(id, "worker claimed request") }
            return claimed
        }
    }
    func requestResult(id: String) throws -> String? { try rows("SELECT result FROM requests WHERE id=?", [id]).first?["result"] }
    func requests() throws -> [[String: String]] { try rows("SELECT * FROM requests ORDER BY created DESC") }
    func publications() throws -> [[String: String]] {
        try rows("SELECT p.id,p.asset_id,COALESCE(d.payload,p.payload) AS payload FROM publications p LEFT JOIN publication_details d ON d.id=p.id ORDER BY p.rowid DESC")
    }
    func events() throws -> [[String: String]] { try rows("SELECT * FROM events ORDER BY id") }
    func recordPublication(id: String, assetID: String, payload: String, details: String? = nil) throws {
        try transaction {
            guard try !rows("SELECT id FROM assets WHERE id=? AND status IN ('complete','review')", [assetID]).isEmpty else {
                throw StudioError.message("Publication must reference a produced asset ID.")
            }
            if let old = try rows("SELECT * FROM publications WHERE id=?", [id]).first {
                guard old["asset_id"] == assetID, old["payload"] == payload else { throw StudioError.message("Publication ID already has different details.") }
                if let details { try enrichPublication(id: id, details: details) }
                return
            }
            try execute("INSERT INTO publications(id,asset_id,payload) VALUES(?,?,?)", [id, assetID, payload])
            try event(assetID, "publication acknowledgement recorded")
            if let details { try enrichPublication(id: id, details: details) }
        }
    }
    private func enrichPublication(id: String, details: String) throws {
        if let existing = try rows("SELECT payload FROM publication_details WHERE id=?", [id]).first {
            guard existing["payload"] == details else { throw StudioError.message("Publication ID already has different metadata. Use a new event ID.") }
        } else {
            try execute("INSERT INTO publication_details(id,payload) VALUES(?,?)", [id, details])
            try event(id, "publication metadata preserved")
        }
    }
    func snapshot(to destination: URL) throws {
        try withLock {
            try backup()
            try FileManager.default.copyItem(at: url.deletingLastPathComponent().appendingPathComponent("history-backup.sqlite"), to: destination)
        }
    }
    func backup() throws {
        try withLock {
            let target = url.deletingLastPathComponent().appendingPathComponent("history-backup.sqlite")
            var destination: OpaquePointer?
            guard sqlite3_open(target.path, &destination) == SQLITE_OK else { sqlite3_close(destination); throw failure() }
            defer { sqlite3_close(destination) }
            guard let backup = sqlite3_backup_init(destination, "main", db, "main") else { throw failure() }
            let result = sqlite3_backup_step(backup, -1)
            let finish = sqlite3_backup_finish(backup)
            guard result == SQLITE_DONE, finish == SQLITE_OK else { throw StudioError.message("History saved, but its backup needs attention.") }
        }
    }
    func importAsset(recipe: ContentRecipe, output: URL, title: String, unresolvedBackground: Bool) throws {
        let checksum = try Self.fileHash(output)
        try transaction {
            if try isUsed(recipe.fingerprint) {
                if unresolvedBackground { try execute("UPDATE assets SET status='legacy',error='Imported legacy background is unresolved; conservative matching applies.' WHERE fingerprint=? AND status!='failed'", [recipe.fingerprint]) }
                return
            }
            let id = UUID().uuidString
            try execute("INSERT INTO assets(id,fingerprint,request_id,title,status,output,checksum,error,created,recipe) VALUES(?,?,'legacy-import',?,?,?,?,?,?,?)",
                [id, recipe.fingerprint, title, unresolvedBackground ? "legacy" : "complete", output.path, checksum,
                 unresolvedBackground ? "Original imported audio was not recorded by hash; conservatively blocks this core with any imported background." : "", Self.now, recipe.canonical])
            try event(id, "imported existing receipt"); try event(id, recipe.details)
        }
    }
}

struct ContentRecipe {
    let canonical: String
    var details = ""
    var fingerprint: String { ContentHistory.hash(Data(canonical.utf8)) }
    /// Conservative core identity: excerpt length, gain, motion controls, branding,
    /// captions, CTA, file names and aspect ratio cannot bypass duplicate prevention.
    static func make(_ job: ExportJob) throws -> Self {
        var identity: [String: Any] = ["schema": 1, "style": job.settings.style, "palette": job.settings.palette]
        let audio = job.settings.soundscape
        identity["beat"] = audio.beatVolume > 0 ? audio.beat.rawValue : "off"
        if let id = audio.natureID, audio.natureVolume > 0, let nature = StudioNature.all.first(where: { $0.id == id }) {
            identity["nature"] = try ContentHistory.fileHash(nature.url)
        }
        if let chakra = audio.chakra, chakra.active {
            identity["chakraMode"] = chakra.mode.rawValue
            identity["chakraStep"] = chakra.mode == .column ? chakra.step : 0
            identity["chakraSources"] = try chakra.ordered.map { try ContentHistory.fileHash(chakra.mode == .recordings ? $0.recordingURL : $0.loopURL) }
        }
        if let background = job.backgroundURL, job.settings.backgroundVolume > 0 { identity["importedAudio"] = try ContentHistory.fileHash(background) }
        if let breath = job.breathPlan {
            if ![6, 7, 10, 11, 12, 15].contains(job.settings.style) { identity["style"] = 11 }
            identity["kind"] = "breathing"; identity["timings"] = [breath.inhale, breath.hold, breath.exhale, breath.pause]
            identity["voiceMode"] = breath.voice.rawValue
            if breath.voice != .off {
                identity["voicePack"] = try FileManager.default.contentsOfDirectory(at: BreathVoicePack.root, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { try ContentHistory.fileHash($0) }
            }
        } else if let timeline = job.liveTimeline {
            identity.removeValue(forKey: "style"); identity.removeValue(forKey: "palette")
            identity["kind"] = "live"
            identity["chapters"] = try zip(timeline.plan.chapters, timeline.records).map { chapter, record in
                ["voice": try ContentHistory.fileHash(record.audioURL), "style": String(chapter.style), "palette": String(chapter.palette)]
            }
            identity["evolving"] = timeline.plan.evolving
        } else { identity["kind"] = "manifestation"; identity["narration"] = try ContentHistory.fileHash(job.mantra.audioURL) }
        let data = try JSONSerialization.data(withJSONObject: identity, options: [.sortedKeys])
        struct Details: Encodable {
            let settings: ExportSettings; let start: Double; let end: Double?
            let breathPlan: BreathPlan?; let liveTimeline: LiveTimeline?
        }
        return Self(canonical: String(decoding: data, as: UTF8.self), details: try ContentHistory.json(
            Details(settings: job.settings, start: job.start, end: job.end, breathPlan: job.breathPlan, liveTimeline: job.liveTimeline)))
    }
}
