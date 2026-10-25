import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

struct AgentBatchRequest: Codable {
    var schemaVersion = 1
    var kind = "manifestation-batch"
    var requestId: String
    var brief: String
    var count: Int
    var manifestationIds: [String]
    var visualStyles: [Int]
    var paletteIds: [Int]
    var requestedBy: String? = "Muse"
    var campaign: String?
    var format: String? = "portrait"
    var allowedBeats: [StudioBeat]?
    var natureIds: [String]?
    var chakraIds: [String]?
    var settings: ExportSettings?
    var postFooter: String?
    var clipSeconds: Double?

    func canonicalPayload() throws -> String {
        var normalized = self
        normalized.manifestationIds = Array(Set(manifestationIds)).sorted()
        normalized.visualStyles = Array(Set(visualStyles)).sorted(); normalized.paletteIds = Array(Set(paletteIds)).sorted()
        normalized.allowedBeats = allowedBeats.map { Array(Set($0)).sorted { $0.rawValue < $1.rawValue } }
        normalized.natureIds = natureIds.map { Array(Set($0)).sorted() }; normalized.chakraIds = chakraIds.map { Array(Set($0)).sorted() }
        var object = try JSONSerialization.jsonObject(with: Data(ContentHistory.json(normalized).utf8)) as! [String: Any]
        if var settings = object["settings"] as? [String: Any], var soundscape = settings["soundscape"] as? [String: Any],
           var chakra = soundscape["chakra"] as? [String: Any], let selected = chakra["selected"] as? [String] {
            chakra["selected"] = selected.sorted(); soundscape["chakra"] = chakra; settings["soundscape"] = soundscape; object["settings"] = settings
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }

    func validate(library: [Mantra]) throws {
        guard schemaVersion == 1, kind == "manifestation-batch", Self.validID(requestId), !brief.isEmpty, brief.count <= 10_000,
              (1...50).contains(count), !manifestationIds.isEmpty, manifestationIds.count <= library.count,
              Set(manifestationIds).isSubset(of: Set(library.map(\.id))),
              !visualStyles.isEmpty, visualStyles.count <= VisualStyle.all.count,
              Set(visualStyles).isSubset(of: Set(VisualStyle.all.map(\.id))),
              !paletteIds.isEmpty, paletteIds.count <= VisualPalette.all.count,
              Set(paletteIds).isSubset(of: Set(VisualPalette.all.map(\.id))),
              ["portrait", "square", "landscape"].contains(format ?? "portrait"),
              clipSeconds == nil || (clipSeconds!.isFinite && (3...180).contains(clipSeconds!)) else {
            throw StudioError.message("Invalid request. Use schema 1, a safe requestId, 1–50 clips, catalog IDs, portrait/square/landscape and optional 3–180 clipSeconds.")
        }
        let resolved = resolvedSettings
        try resolved.soundscape.validate()
        // Check random audio pools through the same validation as the desktop randomizer.
        _ = try RandomBatchPlan.make(count: 1, seed: 0, mantras: manifestationIds, styles: visualStyles, palettes: paletteIds,
            settings: resolved, backgroundFile: nil, postFooter: "", beats: allowedBeats, nature: natureIds, chakras: chakraIds)
    }
    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 80 && id.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*$", options: .regularExpression) != nil
    }
    var resolvedSettings: ExportSettings {
        var result = settings ?? ExportSettings()
        result.format = format == "square" ? .square : format == "landscape" ? .landscape : .portrait
        return result
    }
}

struct AgentJobStatus: Codable {
    let requestId: String
    var status: String
    var progress: Double = 0
    var assets: [HistoryAsset] = []
    var message = ""
    var archive: String?
}

/// Shared by the randomizer UI and agent jobs. The exporter still atomically
/// reserves each core recipe, so a concurrent render cannot defeat this filter.
enum UnusedBatch {
    static func make(count: Int, seed: UInt64, mantras: [String], styles: [Int], palettes: [Int],
                     settings: ExportSettings, background: URL?, footer: String, library: [Mantra],
                     keeping: [RandomClip] = [], beats: [StudioBeat]? = nil, nature: [String]? = nil,
                     chakras: [String]? = nil, history: ContentHistory) throws -> RandomBatchPlan {
        var accepted = keeping.filter(\.locked)
        var memo: [String: (available: Bool, fingerprint: String)] = [:]
        var cores: Set<String> = []
        func evaluate(_ clip: RandomClip) throws -> (available: Bool, fingerprint: String) {
            if let value = memo[clip.key] { return value }
            guard let record = library.first(where: { $0.id == clip.mantraID }) else { throw StudioError.message("Missing manifestation.") }
            let recipe = try ContentRecipe.make(ExportJob(mantra: record, settings: clip.settings(from: settings), start: 0, end: nil, backgroundURL: background))
            let result = (available: try !history.isUsed(recipe), fingerprint: recipe.fingerprint); memo[clip.key] = result; return result
        }
        for clip in accepted {
            let candidate = try evaluate(clip)
            guard candidate.available, cores.insert(candidate.fingerprint).inserted else { throw StudioError.message("A locked combination is already used. Unlock it before generating.") }
        }
        for attempt in 0..<128 {
            try Task.checkCancellation()
            var plan = try RandomBatchPlan.make(count: count, seed: seed &+ UInt64(attempt), mantras: mantras, styles: styles,
                palettes: palettes, settings: settings, backgroundFile: background?.lastPathComponent, postFooter: footer,
                keeping: accepted, beats: beats, nature: nature, chakras: chakras)
            for var clip in plan.clips where !clip.locked {
                let candidate = try evaluate(clip)
                if candidate.available, cores.insert(candidate.fingerprint).inserted { clip.locked = true; accepted.append(clip) }
            }
            if accepted.count == count {
                let originalLocks = Set(keeping.filter(\.locked).map(\.id))
                plan.clips = accepted.sorted { $0.id < $1.id }.map { item in var clip = item; clip.locked = originalLocks.contains(clip.id); return clip }
                return RandomBatchPlan(seed: seed, settings: plan.settings, mantraPool: plan.mantraPool, stylePool: plan.stylePool,
                    palettePool: plan.palettePool, backgroundFile: plan.backgroundFile, postFooter: plan.postFooter,
                    beatPool: plan.beatPool, naturePool: plan.naturePool, chakraPool: plan.chakraPool, clips: plan.clips)
            }
        }
        throw StudioError.message("Could not fill all \(count) slots with unused combinations. Expand your pools or request fewer clips; nothing has been rendered.")
    }
}

/// A local folder bridge, not a network service. A desktop agent or a verified
/// synced-folder connector can exchange JSON and media without hosting the studio.
struct AgentQueue: Sendable {
    let root: URL
    let history: ContentHistory
    var widthOverride: Int? = nil
    var heightOverride: Int? = nil
    var operationGate: StudioOperationGate = .shared
    func setup(library: [Mantra]) throws {
        guard !library.isEmpty else { throw StudioError.message("No studio recordings are available.") }
        if root.path.contains("/Library/CloudStorage/"), !FileManager.default.fileExists(atPath: root.path) {
            throw StudioError.message("The synced exchange folder is unavailable. Open Drive for desktop and restore sync before starting local processing.")
        }
        for name in ["Requests", "Status", "Ready", "Reports", "Examples"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        struct Item: Codable { let id: String; let title: String }
        struct Catalog: Codable {
            let schemaVersion: Int; let manifestations: [Item]; let visuals: [Item]; let palettes: [Item]
            let beats: [String]; let nature: [Item]; let chakras: [Item]
            let requestKinds: [String]; let notes: String
        }
        let catalog = Catalog(schemaVersion: 1, manifestations: library.map { Item(id: $0.id, title: $0.title) },
            visuals: VisualStyle.all.map { Item(id: String($0.id), title: $0.title) }, palettes: VisualPalette.all.map { Item(id: String($0.id), title: $0.title) },
            beats: ["delta", "theta", "alpha"], nature: StudioNature.all.map { Item(id: $0.id, title: $0.title) },
            chakras: StudioChakra.randomIDs.map { Item(id: $0, title: StudioChakra.randomTitle($0)) }, requestKinds: ["manifestation-batch"],
            notes: "Local job processing only. No Facebook posting or scheduling. Breathing and live exports use history but are not agent request types yet. Read AGENT-INSTRUCTIONS.md.")
        let catalogData = try Data(ContentHistory.json(catalog).utf8)
        try ExchangeMetadata.write(catalogData, to: root.appendingPathComponent("catalog.json"))
        let example = AgentBatchRequest(requestId: "first-test", brief: "One short background-reactive test video", count: 1,
            manifestationIds: [library[0].id], visualStyles: [34, 35], paletteIds: [1, 4], allowedBeats: [.theta], clipSeconds: 3)
        let exampleURL = root.appendingPathComponent("Examples/first-test.json")
        if !FileManager.default.fileExists(atPath: exampleURL.path) {
            try Data(ContentHistory.json(example).utf8).write(to: exampleURL, options: .withoutOverwriting)
        }
        if let instructions = Bundle.main.resourceURL?.appendingPathComponent("StudioResources/AgentInstructions.md"), FileManager.default.fileExists(atPath: instructions.path) {
            try ExchangeMetadata.write(Data(contentsOf: instructions), to: root.appendingPathComponent("AGENT-INSTRUCTIONS.md"))
        } else {
            try ExchangeMetadata.write(Data(contentsOf: StudioResources.root.appendingPathComponent("AgentInstructions.md")), to: root.appendingPathComponent("AGENT-INSTRUCTIONS.md"))
        }
        try ExchangeMetadata.publishInfo(root: root, catalog: catalogData)
    }
    func poll(library: [Mantra]) async throws {
        let requests = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Requests"), includingPropertiesForKeys: [.isSymbolicLinkKey])
        for file in requests.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "json" {
            try Task.checkCancellation()
            if operationGate.updatePending { return }
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { continue }
            let id = file.deletingPathExtension().lastPathComponent
            guard AgentBatchRequest.validID(id) else { continue }
            do {
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 262_144 else { throw StudioError.message("Request is larger than 256 KB.") }
                let request = try JSONDecoder().decode(AgentBatchRequest.self, from: Data(contentsOf: file))
                guard request.requestId == id else { throw StudioError.message("Request filename must match requestId.json.") }
                _ = try await process(request, library: library)
            } catch is CancellationError { throw CancellationError() }
            catch { try writeStatus(AgentJobStatus(requestId: id, status: "error", message: error.localizedDescription)) }
        }
        // Reports are explicit external acknowledgements, never proof from a guessed schedule.
        guard let reportLease = try operationGate.tryWork() else { return }
        defer { withExtendedLifetime(reportLease) {} }
        for file in try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Reports"), includingPropertiesForKeys: [.isSymbolicLinkKey]) where file.pathExtension == "json" {
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
                  (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 262_144 else { continue }
            do {
                let report = try JSONDecoder().decode(PublicationReport.self, from: Data(contentsOf: file))
                guard AgentBatchRequest.validID(report.id), !report.assetId.isEmpty, !report.platform.isEmpty,
                      !report.postId.isEmpty, ["scheduled", "published", "failed"].contains(report.status) else {
                    throw StudioError.message("Publication acknowledgement needs stable IDs, platform, postId and scheduled/published/failed status.")
                }
                let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
                let details = String(decoding: try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]), as: UTF8.self)
                try history.recordPublication(id: report.id, assetID: report.assetId, payload: ContentHistory.json(report), details: details)
                try writeUnchanged(Data("Accepted publication acknowledgement. This is an external report, not independent platform verification.\n".utf8), to: file.deletingPathExtension().appendingPathExtension("accepted.txt"))
            } catch { try writeUnchanged(Data(error.localizedDescription.utf8), to: file.deletingPathExtension().appendingPathExtension("error.txt")) }
        }
    }
    func process(_ request: AgentBatchRequest, library: [Mantra]) async throws -> AgentJobStatus {
        guard let lease = try operationGate.tryWork() else {
            return AgentJobStatus(requestId: request.requestId, status: "queued", message: "Waiting for the app update; no render has started.")
        }
        defer { withExtendedLifetime(lease) {} }
        try request.validate(library: library)
        let payload = try request.canonicalPayload()
        let state = try history.acceptRequest(id: request.requestId, payload: payload)
        if state != "queued" {
            if let stored = try history.requestResult(id: request.requestId), !stored.isEmpty,
               let status = try? JSONDecoder().decode(AgentJobStatus.self, from: Data(stored.utf8)) {
                try writeStatus(status); return status
            }
            let status = AgentJobStatus(requestId: request.requestId, status: state, message: "Existing request retained. Check history before retrying an interrupted job.")
            try writeStatus(status); return status
        }
        guard try history.claimRequest(id: request.requestId) else {
            return AgentJobStatus(requestId: request.requestId, status: "rendering", message: "Another worker owns this request.")
        }
        var status = AgentJobStatus(requestId: request.requestId, status: "rendering")
        func save() throws {
            try history.setRequest(id: request.requestId, status: status.status, result: ContentHistory.json(status))
            try writeStatus(status)
        }
        do {
            try save()
            let plan = try UnusedBatch.make(count: request.count, seed: UInt64.random(in: .min ... .max), mantras: request.manifestationIds,
                styles: request.visualStyles, palettes: request.paletteIds, settings: request.resolvedSettings, background: nil,
                footer: request.postFooter ?? "", library: library, beats: request.allowedBeats, nature: request.natureIds, chakras: request.chakraIds, history: history)
            let folder = root.appendingPathComponent("Ready/\(request.requestId)", isDirectory: true)
            guard !FileManager.default.fileExists(atPath: folder.path) else { throw StudioError.message("A result folder already exists. Review it; it will not be overwritten.") }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(ContentHistory.json(request).utf8).write(to: folder.appendingPathComponent("request.json"), options: .atomic)
            try Data(ContentHistory.json(plan).utf8).write(to: folder.appendingPathComponent("plan.json"), options: .atomic)
            for (index, clip) in plan.clips.enumerated() {
                try Task.checkCancellation()
                let mantra = library.first { $0.id == clip.mantraID }!
                let output = folder.appendingPathComponent(clip.fileName)
                let job = ExportJob(mantra: mantra, settings: clip.settings(from: plan.settings), start: 0, end: request.clipSeconds)
                try await VideoExporter.export(job, to: output, widthOverride: widthOverride, heightOverride: heightOverride,
                    historyStore: history, requestID: request.requestId, operationLease: lease) { _ in }
                let postingText = [mantra.title, mantra.cues.map(\.text).joined(separator: "\n"), request.postFooter ?? "",
                    job.settings.callToAction.enabled ? job.settings.callToAction.postingText : ""].filter { !$0.isEmpty }.joined(separator: "\n\n")
                try postingText.write(to: output.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8)
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: output))
                generator.appliesPreferredTrackTransform = true
                let image = try generator.copyCGImage(at: .zero, actualTime: nil)
                if let destination = CGImageDestinationCreateWithURL(output.deletingPathExtension().appendingPathExtension("jpg") as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { throw StudioError.message("Could not save the thumbnail.") }
                } else { throw StudioError.message("Could not prepare the thumbnail.") }
                status.progress = Double(index + 1) / Double(plan.clips.count)
                status.assets = try history.assets().filter { $0.requestID == request.requestId }
                try save()
            }
            status.status = "complete"; status.progress = 1; status.message = "Ready for retrieval. No posts have been scheduled or published."
            // A complete manifest is the commit marker; consumers ignore files until this exists.
            try Data(ContentHistory.json(status).utf8).write(to: folder.appendingPathComponent("ready.json"), options: .atomic)
            let archive = folder.appendingPathExtension("zip")
            guard !FileManager.default.fileExists(atPath: archive.path) else { throw StudioError.message("An archive already exists; it will not be overwritten.") }
            let staged = folder.deletingLastPathComponent().appendingPathComponent(".\(UUID()).zip")
            defer { try? FileManager.default.removeItem(at: staged) }
            let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            zip.arguments = ["-c", "-k", "--keepParent", "--norsrc", "--noextattr", folder.path, staged.path]
            try zip.run()
            await withTaskCancellationHandler { zip.waitUntilExit() } onCancel: { if zip.isRunning { zip.terminate() } }
            try Task.checkCancellation()
            guard zip.terminationStatus == 0 else { throw StudioError.message("Videos were saved, but ZIP packaging failed.") }
            try FileManager.default.moveItem(at: staged, to: archive)
            status.archive = archive.path
            try save(); try history.backup()
            return status
        } catch {
            status.status = error is CancellationError ? "interrupted" : "failed"
            status.message = error.localizedDescription
            status.assets = try history.assets().filter { $0.requestID == request.requestId }
            try save()
            throw error
        }
    }
    private func writeStatus(_ status: AgentJobStatus) throws {
        try writeUnchanged(Data(ContentHistory.json(status).utf8), to: root.appendingPathComponent("Status/\(status.requestId).json"))
    }
    private func writeUnchanged(_ data: Data, to url: URL) throws {
        if (try? Data(contentsOf: url)) != data { try data.write(to: url, options: .atomic) }
    }
}

struct PublicationReport: Codable {
    let id: String
    let assetId: String
    let platform: String
    let accountId: String
    let postId: String
    let status: String
    let scheduledAt: String?
    let url: String?
}
