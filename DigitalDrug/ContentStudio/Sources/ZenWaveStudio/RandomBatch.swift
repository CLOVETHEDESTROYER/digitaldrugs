import Foundation

struct RandomClip: Codable, Identifiable, Equatable {
    var id: Int
    var mantraID: String
    var style: Int
    var palette: Int
    var locked = false
    var soundscape: StudioSoundscape?
    var audioKey: String { "\(soundscape?.beat.rawValue ?? "off"):\(soundscape?.natureID ?? "none"):\(soundscape?.chakra?.signature ?? "none")" }
    var key: String { "\(mantraID):\(style):\(palette):\(audioKey)" }
    var fileName: String { String(format: "%02d", id + 1) + "-\(mantraID)-v\(style)-c\(palette).mp4" }
    func settings(from base: ExportSettings) -> ExportSettings {
        var settings = base; settings.style = style; settings.palette = palette
        if let soundscape { settings.soundscape = soundscape }
        return settings
    }
}

struct RandomBatchPlan: Codable, Equatable {
    let seed: UInt64
    let settings: ExportSettings
    let mantraPool: [String]
    let stylePool: [Int]
    let palettePool: [Int]
    let backgroundFile: String?
    let postFooter: String
    let beatPool: [StudioBeat]?
    let naturePool: [String]?
    var chakraPool: [String]?
    var clips: [RandomClip]

    static func make(count: Int, seed: UInt64, mantras: [String], styles: [Int], palettes: [Int],
                     settings: ExportSettings, backgroundFile: String?, postFooter: String,
                     keeping: [RandomClip] = [], beats: [StudioBeat]? = nil, nature: [String]? = nil, chakras: [String]? = nil) throws -> Self {
        let mantras = Array(Set(mantras)).sorted(), styles = Array(Set(styles)).sorted(), palettes = Array(Set(palettes)).sorted()
        guard (1...50).contains(count), !mantras.isEmpty, !styles.isEmpty, !palettes.isEmpty,
              styles.allSatisfy({ id in VisualStyle.all.contains { $0.id == id } }),
              palettes.allSatisfy({ id in VisualPalette.all.contains { $0.id == id } }) else {
            throw StudioError.message("Choose at least one manifestation, visual and color palette, and 1–50 clips.")
        }
        guard !keeping.contains(where: { $0.locked && $0.id >= count }) else {
            throw StudioError.message("A locked clip is beyond the new batch size. Unlock it or keep a larger batch before generating.")
        }
        try settings.soundscape.validate()
        if let beats, beats.isEmpty || beats.contains(.off) { throw StudioError.message("Select at least one Delta, Theta or Alpha beat for the random pool.") }
        if let nature, nature.isEmpty || !nature.allSatisfy({ id in StudioNature.all.contains { $0.id == id } }) {
            throw StudioError.message("Select at least one bundled nature sound for the random pool.")
        }
        if let chakras, chakras.isEmpty || !Set(chakras).isSubset(of: Set(StudioChakra.randomIDs)) {
            throw StudioError.message("Select at least one bundled chakra or the full column for the random pool.")
        }
        let locked = keeping.filter { $0.locked }
        for clip in locked {
            let audio = clip.soundscape ?? settings.soundscape
            if let chakras, !chakras.contains(audio.chakra?.randomID ?? "") { throw StudioError.message("A locked clip uses chakra audio outside the pool. Include it or unlock the clip.") }
            if let beats, !beats.contains(audio.beat) { throw StudioError.message("A locked clip uses a beat outside the pool. Include it or unlock the clip.") }
            if let nature, !nature.contains(audio.natureID ?? "") { throw StudioError.message("A locked clip uses nature audio outside the pool. Include it or unlock the clip.") }
        }
        guard locked.allSatisfy({ mantras.contains($0.mantraID) && styles.contains($0.style) && palettes.contains($0.palette) }) else {
            throw StudioError.message("A locked clip is outside your selected pools. Include its choices or unlock it before shuffling.")
        }
        let beatChoices = beats.map { Array(Set($0)).sorted { $0.rawValue < $1.rawValue } } ?? [settings.soundscape.beat]
        let natureChoices: [String?] = nature.map { Array(Set($0)).sorted().map { Optional($0) } } ?? [settings.soundscape.natureID]
        let chakraChoices: [StudioChakraLayer?] = chakras.map { ids in
            Array(Set(ids)).sorted().map { (settings.soundscape.chakra ?? StudioChakraLayer()).randomized($0) }
        } ?? [settings.soundscape.chakra]
        let audioChoices = beatChoices.flatMap { beat in natureChoices.flatMap { natureID in chakraChoices.map { chakra -> StudioSoundscape in
            var audio = settings.soundscape; audio.beat = beat; audio.natureID = natureID; audio.chakra = chakra; return audio
        } } }
        let combinations = mantras.count * styles.count * palettes.count * audioChoices.count
        guard count <= combinations else {
            throw StudioError.message("The selected pools offer only \(combinations) unique combinations. Add choices or reduce the batch size.")
        }
        var random = BatchRandom(seed: seed)
        // Keep visual and audio pools separate: a 50-clip request never allocates every
        // combination of 34 visuals × 9 colors × beats × nature × chakras × recordings.
        let visuals = mantras.flatMap { mantra in styles.flatMap { style in palettes.map { palette in
            RandomClip(id: 0, mantraID: mantra, style: style, palette: palette)
        } } }
        func resolved(_ clip: RandomClip) -> RandomClip {
            var next = clip; if next.soundscape == nil { next.soundscape = settings.soundscape }; return next
        }
        let audioKeys = Set(audioChoices.map { RandomClip(id: 0, mantraID: "", style: 0, palette: 0, soundscape: $0).audioKey })
        var used = Set(locked.map { resolved($0).key })
        guard Set(locked.map(\.id)).count == locked.count, used.count == locked.count,
              locked.allSatisfy({ $0.id >= 0 }) else { throw StudioError.message("Locked clips must have unique slots and combinations.") }
        var usedCounts: [String: Int] = [:]
        func visualKey(_ clip: RandomClip) -> String { "\(clip.mantraID):\(clip.style):\(clip.palette)" }
        for clip in locked where audioKeys.contains(resolved(clip).audioKey) { usedCounts[visualKey(clip), default: 0] += 1 }
        var result: [RandomClip] = []
        var usage: [String: Int] = [:], styleUsage: [Int: Int] = [:], paletteUsage: [Int: Int] = [:]
        var beatUsage: [StudioBeat: Int] = [:], natureUsage: [String: Int] = [:], chakraUsage: [String: Int] = [:]
        for clip in locked {
            usage[clip.mantraID, default: 0] += 1
            styleUsage[clip.style, default: 0] += 1; paletteUsage[clip.palette, default: 0] += 1
            beatUsage[clip.soundscape?.beat ?? .off, default: 0] += 1
            natureUsage[clip.soundscape?.natureID ?? "none", default: 0] += 1
            chakraUsage[clip.soundscape?.chakra?.signature ?? "none", default: 0] += 1
        }
        for index in 0..<count {
            if let clip = locked.first(where: { $0.id == index }) { result.append(clip); continue }
            let available = visuals.indices.filter { usedCounts[visualKey(visuals[$0]), default: 0] < audioChoices.count }
            let minimum = available.map { usage[visuals[$0].mantraID, default: 0] }.min()!
            var eligible = available.filter { usage[visuals[$0].mantraID, default: 0] == minimum }
            let styleMinimum = eligible.map { styleUsage[visuals[$0].style, default: 0] }.min()!
            eligible = eligible.filter { styleUsage[visuals[$0].style, default: 0] == styleMinimum }
            let paletteMinimum = eligible.map { paletteUsage[visuals[$0].palette, default: 0] }.min()!
            eligible = eligible.filter { paletteUsage[visuals[$0].palette, default: 0] == paletteMinimum }
            let varied = eligible.filter { visuals[$0].style != result.last?.style && visuals[$0].mantraID != result.last?.mantraID }
            let chosen = (varied.isEmpty ? eligible : varied).randomElement(using: &random)!
            var clip = visuals[chosen]; clip.id = index
            var audioEligible = audioChoices.indices.filter { audioIndex in
                var candidate = clip; candidate.soundscape = audioChoices[audioIndex]; return !used.contains(candidate.key)
            }
            let beatMinimum = audioEligible.map { beatUsage[audioChoices[$0].beat, default: 0] }.min()!
            audioEligible = audioEligible.filter { beatUsage[audioChoices[$0].beat, default: 0] == beatMinimum }
            let natureMinimum = audioEligible.map { natureUsage[audioChoices[$0].natureID ?? "none", default: 0] }.min()!
            audioEligible = audioEligible.filter { natureUsage[audioChoices[$0].natureID ?? "none", default: 0] == natureMinimum }
            let chakraMinimum = audioEligible.map { chakraUsage[audioChoices[$0].chakra?.signature ?? "none", default: 0] }.min()!
            audioEligible = audioEligible.filter { chakraUsage[audioChoices[$0].chakra?.signature ?? "none", default: 0] == chakraMinimum }
            clip.soundscape = audioChoices[audioEligible.randomElement(using: &random)!]
            used.insert(clip.key); usedCounts[visualKey(clip), default: 0] += 1
            usage[clip.mantraID, default: 0] += 1
            styleUsage[clip.style, default: 0] += 1; paletteUsage[clip.palette, default: 0] += 1
            beatUsage[clip.soundscape!.beat, default: 0] += 1
            natureUsage[clip.soundscape!.natureID ?? "none", default: 0] += 1
            chakraUsage[clip.soundscape?.chakra?.signature ?? "none", default: 0] += 1
            result.append(clip)
        }
        return Self(seed: seed, settings: settings, mantraPool: mantras, stylePool: styles, palettePool: palettes, backgroundFile: backgroundFile, postFooter: postFooter, beatPool: beats, naturePool: nature, chakraPool: chakras, clips: result)
    }
}

/// Stable shuffles allow a saved seed and pool to reproduce a batch.
struct BatchRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

struct RandomBatchReceipt: Codable {
    let plan: RandomBatchPlan
    var completedFiles: [String] = []
    var status = "rendering"
    var motionSource: String? = "background-only"
}

enum RandomBatchExporter {
    /// Sequential rendering keeps memory bounded. Completed movies survive cancellation.
    static func export(plan: RandomBatchPlan, library: [Mantra], background: URL?, folder: URL,
                       widthOverride: Int? = nil, heightOverride: Int? = nil,
                       progress: @escaping @Sendable (Double, Int) -> Void) async throws -> URL {
        guard !plan.clips.isEmpty else { throw StudioError.message("Generate a batch first.") }
        // Validate all recordings before creating any outputs.
        let records = try plan.clips.map { clip -> Mantra in
            guard let mantra = library.first(where: { $0.id == clip.mantraID }) else { throw StudioError.message("A batch recording is missing: \(clip.mantraID)") }
            return mantra
        }
        guard !FileManager.default.fileExists(atPath: folder.path) else { throw StudioError.message("Choose a new batch folder; existing batches are preserved.") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest = folder.appendingPathComponent("batch.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var receipt = RandomBatchReceipt(plan: plan)
        func save() throws { try encoder.encode(receipt).write(to: manifest, options: .atomic) }
        try save()
        do {
            for (index, clip) in plan.clips.enumerated() {
                try Task.checkCancellation()
                let mantra = records[index], output = folder.appendingPathComponent(clip.fileName)
                let job = ExportJob(mantra: mantra, settings: clip.settings(from: plan.settings), start: 0, end: nil, backgroundURL: background)
                try await VideoExporter.export(job, to: output, widthOverride: widthOverride, heightOverride: heightOverride) { value in
                    progress((Double(index) + value) / Double(plan.clips.count) * 0.97, index)
                }
                // Ready-to-copy posting text travels with each finished clip.
                let text = ([mantra.title, mantra.cues.map(\.text).joined(separator: "\n"), plan.postFooter, clip.settings(from: plan.settings).callToAction.enabled ? clip.settings(from: plan.settings).callToAction.postingText : ""]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).joined(separator: "\n\n") + "\n"
                try text.write(to: output.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8)
                receipt.completedFiles.append(clip.fileName); try save()
                progress(Double(index + 1) / Double(plan.clips.count) * 0.97, index + 1)
            }
            try Task.checkCancellation()
            receipt.status = "complete"; try save()
            let archive = folder.appendingPathExtension("zip")
            guard !FileManager.default.fileExists(atPath: archive.path) else { throw StudioError.message("An archive with this name already exists.") }
            let staged = folder.deletingLastPathComponent().appendingPathComponent(".batch-\(UUID()).zip")
            defer { try? FileManager.default.removeItem(at: staged) }
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--norsrc", "--noextattr", "--keepParent", folder.path, staged.path]
            try process.run()
            await withTaskCancellationHandler { process.waitUntilExit() } onCancel: { if process.isRunning { process.terminate() } }
            try Task.checkCancellation()
            guard process.terminationStatus == 0 else { throw StudioError.message("Videos were saved, but the ZIP could not be created. Open the batch folder to use them.") }
            try FileManager.default.moveItem(at: staged, to: archive)
            progress(1, plan.clips.count)
            return archive
        } catch {
            receipt.status = error is CancellationError ? "stopped" : "failed"
            try? save()
            throw error
        }
    }
}
