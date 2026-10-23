import SwiftUI
import AVFoundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class LiveSessionState {
    var plan = LivePlan.load() { didSet { plan.save() } }
    var timeline: LiveTimeline?
    var settings = ExportSettings()
    var image: CGImage?
    var elapsed = 0.0
    var playing = false
    var busy = false
    var exporting = false
    var progress = 0.0
    var status = "Build a playlist, then prepare the session."
    var error: String?
    var exportedURL: URL?
    private var player: AVAudioPlayer?
    private var envelope: AudioEnvelope?
    private var audioURL: URL?
    private var files: LiveSessionFiles?
    private var folder: URL? {
        get { files?.url }
        set { files = newValue.map { LiveSessionFiles(url: $0) } }
    }
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var renderer: LiveFrameRenderer?
    private var activity: NSObjectProtocol?
    var pendingChanges: Bool { timeline.map { $0.plan != plan } ?? false }
    var ready: Bool { timeline != nil && player != nil && !busy && !pendingChanges }
    var activeChapter: Int { timeline?.chapter(at: elapsed) ?? 0 }
    var title: String { timeline?.records[activeChapter].title ?? "Live output" }

    func add(_ mantra: Mantra, settings: ExportSettings) {
        plan.chapters.append(LiveChapter(mantraID: mantra.id, style: settings.style, palette: settings.palette))
    }
    func preset(minutes: Int) {
        guard !plan.chapters.isEmpty else { return }
        let seconds = Double(minutes * 60) / Double(plan.chapters.count)
        for i in plan.chapters.indices { plan.chapters[i].seconds = seconds }
    }
    func move(_ index: Int, by delta: Int) {
        let target = index + delta
        guard plan.chapters.indices.contains(target) else { return }
        plan.chapters.swapAt(index, target)
    }
    func prepare(library: [Mantra], settings: ExportSettings, background: URL?) {
        guard !busy else { return }
        pause(); timeline = nil; player = nil; image = nil; elapsed = 0
        if let folder { try? FileManager.default.removeItem(at: folder) }; folder = nil
        self.settings = settings; exportedURL = nil
        let snapshot = plan
        busy = true; status = "Preparing the complete playlist and audio mix…"
        task = Task {
            let workFolder = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-Live-\(UUID().uuidString)")
            let worker = Task.detached {
                try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
                return try await LiveAudio.prepare(plan: snapshot, library: library, folder: workFolder, background: background, settings: settings)
            }
            do {
                let (timeline, url, envelope) = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                self.timeline = timeline; self.audioURL = url; self.envelope = envelope
                self.player = player; self.folder = workFolder; self.renderer = LiveFrameRenderer()
                self.busy = false; self.draw()
                self.status = "Ready · Open clean output, then press Play. Audio plays through this Mac’s output."
            } catch {
                try? FileManager.default.removeItem(at: workFolder)
                busy = false
                if error is CancellationError { status = "Preparation stopped." }
                else { self.error = error.localizedDescription; status = "Preparation failed." }
            }
        }
    }
    func toggle() {
        guard ready, let player, let timeline else { return }
        if playing { pause(); return }
        if elapsed >= timeline.duration - 0.04 { seek(0) }
        guard player.play() else { error = "Audio playback could not start."; return }
        playing = true
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Playing a live manifestation session")
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func pause() {
        timer?.invalidate(); timer = nil; player?.pause(); playing = false
        if let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
    }
    func seek(_ time: Double) {
        guard let timeline else { return }
        elapsed = min(max(0, time), timeline.duration); player?.currentTime = elapsed; draw()
    }
    func next() {
        guard let timeline else { return }
        let next = activeChapter + 1
        if next < timeline.records.count { seek(timeline.chapterStart(next)) }
        else if timeline.plan.loop { seek(0) }
        else { pause(); seek(timeline.duration) }
    }
    private func tick() {
        guard let player, let timeline else { return }
        if !player.isPlaying || player.currentTime >= timeline.duration - 0.025 {
            if timeline.plan.loop { player.currentTime = 0; player.play(); elapsed = 0 }
            else { pause(); elapsed = timeline.duration; status = "Session complete." }
        } else { elapsed = player.currentTime }
        draw()
    }
    private func draw() {
        guard let timeline, let envelope, let renderer else { return }
        let width = settings.format == .landscape ? 1280 : 720
        let height = settings.format == .portrait ? 1280 : 720
        do { image = try renderer.frame(width: width, height: height, time: min(elapsed, max(0, timeline.duration - 0.001)), envelope: envelope, timeline: timeline, settings: settings) }
        catch { pause(); self.error = error.localizedDescription }
    }
    func cancel() { task?.cancel() }
    func export(to output: URL) {
        guard ready, let timeline, let audioURL else { return }
        pause(); busy = true; exporting = true; progress = 0; status = "Rendering full session…"
        let settings = settings
        let motion = envelope
        task = Task {
            let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Rendering a live session")
            defer { ProcessInfo.processInfo.endActivity(activity); busy = false; exporting = false }
            let worker = Task.detached {
                let job = ExportJob(mantra: timeline.mantra, settings: settings, start: 0, end: timeline.duration,
                                    liveTimeline: timeline, preparedAudio: audioURL, preparedMotion: motion)
                try await VideoExporter.export(job, to: output) { value in
                    Task { @MainActor in self.progress = value }
                }
            }
            do {
                try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                exportedURL = output; status = "Saved full session: \(output.lastPathComponent)"
            } catch {
                if error is CancellationError { status = "Export stopped." }
                else { self.error = error.localizedDescription; status = "Export failed." }
            }
        }
    }
    func chooseExport(folder: URL) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]
        panel.directoryURL = folder; panel.nameFieldStringValue = "ZenWave-Live-\(UUID().uuidString.prefix(8)).mp4"
        if panel.runModal() == .OK, let url = panel.url { export(to: url) }
    }
    func closeOutput() { pause() }
}

/// Owns temporary media independently of the main actor and cleans it up with the session.
private final class LiveSessionFiles {
    let url: URL
    init(url: URL) { self.url = url }
    deinit { try? FileManager.default.removeItem(at: url) }
}
