import AppKit
import AVFoundation
import Observation

@MainActor @Observable
final class StudioState {
    var library: [Mantra] = []
    var selectedID: String?
    var queued: Set<String> = []
    var search = ""
    var settings = ExportSettings.load()
    var outputFolder: URL
    var error: String?
    var status = "Choose a recording to begin."
    var previewImage: CGImage?
    var elapsed = 0.0
    var duration = 0.0
    var playing = false
    var clipIndex = -1
    var exporting = false
    var progress = 0.0
    var completed = 0
    var batchTotal = 0
    var lastExportFolder: URL?
    private var renderer: FrameRenderer?
    private var envelope: AudioEnvelope?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var exportTask: Task<Void, Never>?

    var selected: Mantra? { library.first { $0.id == selectedID } }
    var filtered: [Mantra] {
        library.filter { search.isEmpty || "\($0.title) \($0.subtitle) \($0.category)".localizedCaseInsensitiveContains(search) }
    }
    var clipStart: Double {
        guard let selected, selected.cues.indices.contains(clipIndex) else { return 0 }
        return selected.cues[clipIndex].start
    }
    var clipEnd: Double {
        guard let selected, selected.cues.indices.contains(clipIndex) else { return duration }
        return min(duration, selected.cues[clipIndex].end)
    }
    init() {
        let path = UserDefaults.standard.string(forKey: "outputFolder")
        outputFolder = path.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/ZenWave Content Studio")
        do {
            library = try StudioResources.library()
            renderer = try FrameRenderer()
            selectedID = library.first?.id
            loadSelected()
        } catch { self.error = error.localizedDescription }
    }
    func loadSelected() {
        pause(); clipIndex = -1; elapsed = 0; duration = 0; previewImage = nil
        guard let selected else { return }
        do {
            envelope = try AudioEnvelope(url: selected.audioURL)
            player = try AVAudioPlayer(contentsOf: selected.audioURL)
            player?.prepareToPlay()
            duration = envelope?.duration ?? 0
            status = "Ready · \(library.count) recordings available"
            redraw()
        } catch { self.error = error.localizedDescription }
    }
    func redraw() {
        guard !exporting, let renderer, let selected, let envelope else { return }
        do {
            let w = settings.format == .landscape ? 640 : 360
            let h = settings.format == .portrait ? 640 : 360
            previewImage = try renderer.frame(width: w, height: h, time: elapsed - clipStart, audioTime: elapsed,
                envelope: envelope, mantra: selected, settings: settings)
        } catch { pause(); self.error = error.localizedDescription }
    }
    func togglePlayback() {
        if playing { pause(); return }
        guard let player else { return }
        if elapsed >= clipEnd - 0.04 || elapsed < clipStart { elapsed = clipStart }
        player.currentTime = elapsed
        guard player.play() else { error = "The recording could not start playing."; return }
        playing = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.playing, let player = self.player else { return }
                self.elapsed = min(player.currentTime, self.clipEnd)
                if !player.isPlaying || self.elapsed >= self.clipEnd {
                    self.pause(); self.elapsed = self.clipEnd
                }
                self.redraw()
            }
        }
    }
    func pause() { timer?.invalidate(); timer = nil; player?.pause(); playing = false }
    func seek(_ value: Double) { elapsed = value; player?.currentTime = value; redraw() }
    func clipChanged() { pause(); seek(clipStart) }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.prompt = "Use this folder"
        panel.directoryURL = outputFolder
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
            UserDefaults.standard.set(url.path, forKey: "outputFolder")
        }
    }
    func toggleQueued(_ id: String) {
        if queued.contains(id) { queued.remove(id) } else { queued.insert(id) }
    }
    func startExport(batch: Bool) {
        guard !exporting else { return }
        let records = batch ? library.filter { queued.contains($0.id) } : selected.map { [$0] } ?? []
        guard !records.isEmpty else { return }
        pause(); settings.save()
        let settings = settings
        let jobs = records.map { ExportJob(mantra: $0, settings: settings, start: batch ? 0 : clipStart, end: batch ? nil : clipEnd) }
        let stamp = DateFormatter(); stamp.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let folder = outputFolder.appendingPathComponent("\(stamp.string(from: Date()))-\(UUID().uuidString.prefix(4))", isDirectory: true)
        exporting = true; progress = 0; completed = 0; batchTotal = jobs.count
        status = "Preparing export…"
        exportTask = Task { [weak self] in
            guard let self else { return }
            let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Rendering ZenWave videos")
            defer { ProcessInfo.processInfo.endActivity(activity) }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                self.lastExportFolder = folder
                for (index, job) in jobs.enumerated() {
                    try Task.checkCancellation()
                    self.status = "Exporting \(index + 1) of \(jobs.count) · \(job.mantra.title)"
                    let url = folder.appendingPathComponent("\(String(format: "%02d", index + 1))-\(job.mantra.id).mp4")
                    let progressState = self
                    let worker = Task.detached(priority: .userInitiated) { [progressState] in
                        try await VideoExporter.export(job, to: url) { value in
                            Task { @MainActor in
                                progressState.progress = (Double(index) + value) / Double(jobs.count)
                            }
                        }
                    }
                    try await withTaskCancellationHandler {
                        try await worker.value
                    } onCancel: { worker.cancel() }
                    self.completed += 1
                }
                self.status = "Finished · \(self.completed) video\(self.completed == 1 ? "" : "s") saved"
                self.progress = 1
            } catch is CancellationError {
                self.status = "Stopped · \(self.completed) completed video\(self.completed == 1 ? "" : "s") kept"
            } catch {
                self.error = error.localizedDescription
                self.status = "Export stopped · \(self.completed) completed video\(self.completed == 1 ? "" : "s") kept"
            }
            self.exporting = false; self.exportTask = nil; self.redraw()
        }
    }
    func cancelExport() { exportTask?.cancel(); status = "Stopping export…" }
    func revealExports() { NSWorkspace.shared.open(lastExportFolder ?? outputFolder) }
}
