import Foundation

struct StudioVersion: Comparable, Equatable {
    let parts: [Int]
    init?(_ value: String) {
        let strings = value.split(separator: ".", omittingEmptySubsequences: false)
        guard strings.count == 3, strings.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              strings.allSatisfy({ Int($0) != nil && Int($0)! <= 1_000_000 }) else { return nil }
        parts = strings.map { Int($0)! }
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct StudioReleaseAsset: Decodable {
    let name: String
    let browser_download_url: URL
    let size: Int64
    let digest: String?
    let state: String
}
struct StudioRelease: Decodable {
    let tag_name: String
    let html_url: URL
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [StudioReleaseAsset]
    var version: String { String(tag_name.dropFirst(StudioUpdateClient.tagPrefix.count)) }
}
struct AvailableStudioUpdate {
    let release: StudioRelease
    let asset: StudioReleaseAsset
    var version: String { release.version }
    var checksum: String { String(asset.digest!.dropFirst("sha256:".count)).lowercased() }
}
struct PreparedStudioUpdate {
    let app: URL
    let stage: URL
    let version: String
}

enum StudioUpdateClient {
    static let repository = "CLOVETHEDESTROYER/digitaldrugs"
    static let tagPrefix = "content-studio-v"
    static let assetName = "ZenWave-Content-Studio-Mac.zip"
    static let releasesPage = URL(string: "https://github.com/\(repository)/releases")!
    static let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ZenWaveContentStudio/Updates", isDirectory: true)

    static func select(_ releases: [StudioRelease], newerThan current: String) throws -> AvailableStudioUpdate? {
        guard let installed = StudioVersion(current) else { throw StudioError.message("The installed app has an unrecognized version.") }
        let candidates: [AvailableStudioUpdate] = releases.compactMap { release in
            guard !release.draft, !release.prerelease, release.tag_name.hasPrefix(tagPrefix),
                  let version = StudioVersion(release.version), version > installed,
                  release.html_url.absoluteString == "https://github.com/\(repository)/releases/tag/\(release.tag_name)",
                  let asset = release.assets.first(where: { $0.name == assetName && $0.state == "uploaded" }),
                  asset.size > 0, asset.size <= 512 * 1024 * 1024,
                  asset.browser_download_url.absoluteString == "https://github.com/\(repository)/releases/download/\(release.tag_name)/\(assetName)",
                  let digest = asset.digest, digest.range(of: "^sha256:[A-Fa-f0-9]{64}$", options: .regularExpression) != nil else { return nil }
            return AvailableStudioUpdate(release: release, asset: asset)
        }
        return candidates.max { StudioVersion($0.version)! < StudioVersion($1.version)! }
    }
    static func check(session: URLSession = .shared) async throws -> AvailableStudioUpdate? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=100")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ZenWave-Content-Studio", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw StudioError.message("Could not check GitHub releases. Check your connection or try again later; rendering is unaffected.")
        }
        return try select(JSONDecoder().decode([StudioRelease].self, from: data), newerThan: StudioBuild.version)
    }
    static func prepare(_ update: AvailableStudioUpdate, session: URLSession = .shared) async throws -> PreparedStudioUpdate {
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let available = try cache.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard available > update.asset.size * 5 + 50_000_000 else { throw StudioError.message("Free more disk space before downloading this update. Space is needed for the download, verification and the previous app backup.") }
        let stage = cache.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        do {
            var request = URLRequest(url: update.asset.browser_download_url); request.timeoutInterval = 300
            let (download, response) = try await session.download(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw StudioError.message("The update package could not be downloaded.") }
            let archive = stage.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: download, to: archive)
            let prepared = try await Task.detached {
                let actualSize = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard actualSize == update.asset.size, try ContentHistory.fileHash(archive) == update.checksum else {
                    throw StudioError.message("Update checksum or size did not match GitHub. The installed app was not changed.")
                }
                return try unpack(archive, into: stage, expectedVersion: update.version)
            }.value
            try Task.checkCancellation()
            return prepared
        } catch { try? FileManager.default.removeItem(at: stage); throw error }
    }
    static func unpack(_ archive: URL, into stage: URL, expectedVersion: String) throws -> PreparedStudioUpdate {
        let listing = try run("/usr/bin/zipinfo", ["-1", archive.path])
        try validateEntries(listing.split(separator: "\n").map(String.init))
        let details = try run("/usr/bin/zipinfo", ["-l", archive.path])
        guard !details.split(separator: "\n").contains(where: { $0.hasPrefix("l") }) else { throw StudioError.message("Update archive contains symbolic links.") }
        let totals = try run("/usr/bin/zipinfo", ["-t", archive.path])
        let pattern = try NSRegularExpression(pattern: "([0-9]+) bytes uncompressed")
        let match = pattern.firstMatch(in: totals, range: NSRange(totals.startIndex..., in: totals))
        guard let match, let range = Range(match.range(at: 1), in: totals), let size = Int64(totals[range]), size <= 1_000_000_000 else {
            throw StudioError.message("Update archive expands beyond the supported package size.")
        }
        let space = try stage.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard space > size * 4 + 50_000_000 else { throw StudioError.message("Not enough free space to unpack the update and preserve the previous app.") }
        let extracted = stage.appendingPathComponent("Unpacked", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        _ = try run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path])
        let app = extracted.appendingPathComponent("ZenWave Content Studio.app")
        try validateApp(app, expectedVersion: expectedVersion)
        return PreparedStudioUpdate(app: app, stage: stage, version: expectedVersion)
    }
    static func validateEntries(_ entries: [String]) throws {
        guard !entries.isEmpty, entries.count < 10_000, entries.allSatisfy({ name in
            !name.hasPrefix("/") && !name.contains("\\") && !name.split(separator: "/", omittingEmptySubsequences: false).contains("..") &&
            (name == "ZenWave Content Studio.app/" || name.hasPrefix("ZenWave Content Studio.app/"))
        }) else { throw StudioError.message("The update archive has an unexpected layout.") }
    }
    static func validateApp(_ app: URL, expectedVersion: String) throws {
        guard app.pathExtension == "app", (try app.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              info["CFBundleIdentifier"] as? String == StudioBuild.identifier,
              info["CFBundleShortVersionString"] as? String == expectedVersion,
              info["CFBundleExecutable"] as? String == "ZenWaveStudio" else { throw StudioError.message("The downloaded app identity or version is incorrect.") }
        let resources = app.appendingPathComponent("Contents/Resources/StudioResources")
        let compatibility = try JSONDecoder().decode(StudioCompatibility.self, from: Data(contentsOf: resources.appendingPathComponent("studio-update.json")))
        guard compatibility.schemaVersion == 1, compatibility.exchangeSchemaVersion == 1, compatibility.historySchemaVersion == 1,
              compatibility.bundleIdentifier == StudioBuild.identifier, compatibility.version == expectedVersion,
              info["CFBundleVersion"] as? String == compatibility.build,
              compatibility.minimumMacOS <= ProcessInfo.processInfo.operatingSystemVersion.majorVersion else {
            throw StudioError.message("This update needs a different automation contract, database or macOS version. Keep the current app until a coordinated migration is available.")
        }
        let architectures = try binaryArchitectures(app.appendingPathComponent("Contents/MacOS/ZenWaveStudio"))
        guard Set(["arm64", "x86_64"]).isSubset(of: architectures) else { throw StudioError.message("The update must include both Intel and Apple silicon support.") }
        _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        _ = try JSONDecoder().decode([Mantra].self, from: Data(contentsOf: resources.appendingPathComponent("catalog.json")))
    }
    /// Parse the universal Mach-O header directly: /usr/bin/lipo may require
    /// developer tools, which must not be a runtime dependency on the other Mac.
    static func binaryArchitectures(_ binary: URL) throws -> Set<String> {
        let file = try FileHandle(forReadingFrom: binary); defer { try? file.close() }
        let data = try file.read(upToCount: 4096) ?? Data()
        func big(_ offset: Int) -> UInt32 { data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) } }
        guard data.count >= 8 else { throw StudioError.message("The update executable is truncated.") }
        let magic = big(0), count = Int(big(4)), stride = magic == 0xcafebabf ? 32 : 20
        guard [UInt32(0xcafebabe), UInt32(0xcafebabf)].contains(magic), (1...32).contains(count), data.count >= 8 + count * stride else {
            throw StudioError.message("The update executable is not a supported universal Mac binary.")
        }
        return Set((0..<count).compactMap { index in
            switch big(8 + index * stride) { case 0x01000007: return "x86_64"; case 0x0100000c: return "arm64"; default: return nil }
        })
    }
    @discardableResult static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw StudioError.message("Update verification failed (\(URL(fileURLWithPath: executable).lastPathComponent)): \(String(decoding: data.prefix(2000), as: UTF8.self))") }
        return String(decoding: data, as: UTF8.self)
    }
}
