import SwiftUI
import Observation

@MainActor @Observable
final class RandomBatchState {
    var mantraPool: Set<String> = []
    var stylePool: Set<Int> = [9, 10, 14, 15, 17, 18, 20, 21, 22]
    var palettePool = Set(VisualPalette.all.map(\.id))
    var count = 7
    var format: VideoFormat = .portrait
    var footer = ""
    var soundscape = StudioSoundscape()
    var randomizeBeats = false
    var randomizeNature = false
    var randomizeChakras = false
    var chakraPool = Set(StudioChakra.randomIDs)
    var beatPool: Set<StudioBeat> = [.delta, .theta, .alpha]
    var naturePool = Set(StudioNature.all.map(\.id))
    var seedText = ""
    var plan: RandomBatchPlan?
    var background: URL?
    var exporting = false
    var progress = 0.0
    var completed = 0
    var status = "Choose your pools, then generate a batch to review."
    var error: String?
    var folder: URL?
    var archive: URL?
    private var task: Task<Void, Never>?
    private var runID = UUID()

    func generate(studio: StudioState, newSeed: Bool) {
        guard !exporting else { return }
        let seed: UInt64
        if newSeed || seedText.isEmpty { seed = UInt64.random(in: .min ... .max) }
        else if let value = UInt64(seedText) { seed = value }
        else { error = "The seed must be a whole number from 0 to \(UInt64.max)."; return }
        var settings = studio.settings; settings.format = format; settings.soundscape = soundscape
        do {
            let next = try RandomBatchPlan.make(count: count, seed: seed, mantras: Array(mantraPool), styles: Array(stylePool), palettes: Array(palettePool), settings: settings, backgroundFile: studio.backgroundURL?.lastPathComponent, postFooter: footer, keeping: plan?.clips ?? [], beats: randomizeBeats ? Array(beatPool).sorted { $0.rawValue < $1.rawValue } : nil, nature: randomizeNature ? Array(naturePool).sorted() : nil, chakras: randomizeChakras ? Array(chakraPool).sorted() : nil)
            plan = next; background = studio.backgroundURL; seedText = String(seed)
            status = "\(next.clips.count) unique combinations ready to review. Locks survive reshuffling."
        } catch { self.error = error.localizedDescription }
    }
    func toggleLock(_ id: Int) {
        guard !exporting, let index = plan?.clips.firstIndex(where: { $0.id == id }) else { return }
        plan?.clips[index].locked.toggle()
    }
    func export(library: [Mantra], destination: URL, widthOverride: Int? = nil, heightOverride: Int? = nil) {
        guard !exporting, let plan else { return }
        let background = background
        let folder = destination.appendingPathComponent("Random Batch \(UUID().uuidString.prefix(8))", isDirectory: true)
        let runID = UUID(); self.runID = runID
        self.folder = folder; archive = nil; exporting = true; progress = 0; completed = 0
        status = "Rendering \(plan.clips.count) combined audio/video clips…"
        task = Task {
            let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Rendering a randomized content batch")
            defer { ProcessInfo.processInfo.endActivity(activity); exporting = false; task = nil }
            let worker = Task.detached(priority: .userInitiated) {
                try await RandomBatchExporter.export(plan: plan, library: library, background: background, folder: folder,
                    widthOverride: widthOverride, heightOverride: heightOverride) { value, done in
                    Task { @MainActor in
                        guard self.exporting, self.runID == runID else { return }
                        self.progress = value; self.completed = done
                        self.status = done == plan.clips.count ? "Packaging ZIP…" : "Rendering clip \(done + 1) of \(plan.clips.count)…"
                    }
                }
            }
            do {
                archive = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                completed = plan.clips.count; progress = 1
                status = "Saved \(completed) MP4s, posting text, subtitles and a ZIP."
            } catch {
                // Read the receipt as the authoritative count if cancellation raced a UI progress update.
                if let data = try? Data(contentsOf: folder.appendingPathComponent("batch.json")),
                   let receipt = try? JSONDecoder().decode(RandomBatchReceipt.self, from: data) { completed = receipt.completedFiles.count }
                if error is CancellationError { status = "Stopped · \(completed) completed clips kept in the batch folder." }
                else { self.error = error.localizedDescription; status = "Export stopped · \(completed) completed clips kept." }
            }
        }
    }
    func cancel() { task?.cancel() }
}
