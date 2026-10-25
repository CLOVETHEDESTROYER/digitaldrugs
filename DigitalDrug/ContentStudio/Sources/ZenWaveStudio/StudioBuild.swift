import Foundation

struct StudioCompatibility: Codable, Equatable {
    let schemaVersion: Int
    let version: String
    let build: String
    let bundleIdentifier: String
    let exchangeSchemaVersion: Int
    let historySchemaVersion: Int
    let minimumMacOS: Int
}

enum StudioBuild {
    static let identifier = "com.zenwave.contentstudio"
    static var compatibility: StudioCompatibility {
        get throws { try JSONDecoder().decode(StudioCompatibility.self, from: Data(contentsOf: StudioResources.root.appendingPathComponent("studio-update.json"))) }
    }
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.15.0" }
}

/// Coordinate with File Provider and update existing catalog/instruction files in
/// place. Do not replace their inode on every launch or churn unchanged Drive files.
/// Request and status atomic-write semantics are deliberately unchanged.
enum ExchangeMetadata {
    static func write(_ data: Data, to url: URL) throws {
        if (try? Data(contentsOf: url)) == data { return }
        var coordinatedError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: [], error: &coordinatedError) { target in
            do {
                let previous = try? Data(contentsOf: target)
                if previous == data { return }
                if previous != nil {
                    let file = try FileHandle(forWritingTo: target)
                    defer { try? file.close() }
                    do {
                        try file.seek(toOffset: 0); try file.write(contentsOf: data)
                        try file.truncate(atOffset: UInt64(data.count)); try file.synchronize()
                    } catch {
                        if let previous {
                            try? file.seek(toOffset: 0); try? file.write(contentsOf: previous)
                            try? file.truncate(atOffset: UInt64(previous.count)); try? file.synchronize()
                        }
                        throw error
                    }
                } else { try data.write(to: target, options: .withoutOverwriting) }
            } catch { writeError = error }
        }
        if let coordinatedError { throw coordinatedError }
        if let writeError { throw writeError }
    }
    static func publishInfo(root: URL, catalog: Data) throws {
        struct Info: Encodable {
            let studio: StudioCompatibility
            let appPath: String
            let catalogSHA256: String
        }
        let info = try Info(studio: StudioBuild.compatibility, appPath: Bundle.main.bundleURL.path, catalogSHA256: ContentHistory.hash(catalog))
        try write(Data(ContentHistory.json(info).utf8), to: root.appendingPathComponent("studio-info.json"))
    }
}
