import SwiftUI
import AVFoundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class BreathPracticeState {
    var plan = BreathPlan.load() { didSet { plan.save() } }
    var settings = ExportSettings()
    var preparedBackground: URL?
    var preparedPlan: BreathPlan?
    var image: CGImage?
    var elapsed = 0.0
    var playing = false
    var busy = false
    var exporting = false
    var progress = 0.0
    var status = "Choose a rhythm, then prepare the practice."
    var error: String?
    var exportedURL: URL?
    private var player: AVAudioPlayer?
    private var audio: PreparedStudioAudio?
    private var files: BreathFiles?
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private let renderer = BreathRenderer()
    private var activity: NSObjectProtocol?
    var pendingChanges: Bool { preparedPlan.map { $0 != plan } ?? false }
    var ready: Bool { preparedPlan != nil && player != nil && !busy && !pendingChanges }
    func prepare(settings: ExportSettings, background: URL?) {
        guard !busy else { return }
        pause(); preparedPlan = nil; player = nil; audio = nil; files = nil; image = nil; elapsed = 0
        exportedURL = nil; self.settings = settings; preparedBackground = background
        plan.voiceName = BreathVoicePack.title
        let snapshot = plan
        busy = true; status = "Rendering local spoken cues and background audio…"
        task = Task {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-Breath-\(UUID())")
            let worker = Task.detached {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                return try await BreathAudio.prepare(plan: snapshot, settings: settings, background: background, folder: folder)
            }
            defer { busy = false }
            do {
                let audio = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                let player = try AVAudioPlayer(contentsOf: audio.playbackURL); player.enableRate = true; player.rate = 1; player.prepareToPlay()
                self.player = player; self.audio = audio; files = BreathFiles(folder)
                preparedPlan = snapshot; draw()
                status = "Ready · Play here, open clean output, or export an MP4."
            } catch {
                try? FileManager.default.removeItem(at: folder)
                if error is CancellationError { status = "Preparation stopped." }
                else { self.error = error.localizedDescription; status = "Preparation failed." }
            }
        }
    }
    func toggle() {
        guard ready, let player, let preparedPlan else { return }
        if playing { pause(); return }
        if elapsed >= preparedPlan.duration - 0.04 { seek(0) }
        guard player.play() else { error = "Could not start the breathing audio."; return }
        playing = true
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Playing a breathing practice")
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func pause() {
        timer?.invalidate(); timer = nil; player?.pause(); playing = false
        if let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
    }
    func seek(_ time: Double) {
        guard let preparedPlan else { return }
        elapsed = min(max(0, time), preparedPlan.duration); player?.currentTime = elapsed; draw()
    }
    private func tick() {
        guard let player, let preparedPlan else { return }
        if !player.isPlaying || player.currentTime >= preparedPlan.duration - 0.025 {
            if preparedPlan.loop { player.currentTime = 0; player.play(); elapsed = 0 }
            else { pause(); elapsed = preparedPlan.duration; status = "Practice complete." }
        } else { elapsed = player.currentTime }
        draw()
    }
    private func draw() {
        guard let preparedPlan, let audio else { return }
        let w = settings.format == .landscape ? 960 : 540
        let h = settings.format == .portrait ? 960 : 540
        do { image = try renderer.frame(width: w, height: h, time: elapsed, envelope: audio.motion, plan: preparedPlan, settings: settings) }
        catch { pause(); self.error = error.localizedDescription }
    }
    func cancel() { task?.cancel() }
    func close() { pause(); if !exporting { task?.cancel() } }
    func chooseExport(folder: URL) {
        guard ready else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]; panel.directoryURL = folder
        panel.nameFieldStringValue = "ZenWave-Breathing-\(UUID().uuidString.prefix(8)).mp4"
        if panel.runModal() == .OK, let url = panel.url { export(to: url) }
    }
    func export(to url: URL) {
        guard ready, let preparedPlan, let audio, let files else { return }
        pause(); busy = true; exporting = true; progress = 0; status = "Rendering breathing practice…"
        let settings = settings
        let background = preparedBackground
        task = Task {
            // Retain the prepared folder until export finishes, even if the window closes.
            let retainedFiles = files
            let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Exporting a breathing practice")
            defer { withExtendedLifetime(retainedFiles) {}; ProcessInfo.processInfo.endActivity(activity); busy = false; exporting = false }
            let worker = Task.detached {
                let job = ExportJob(mantra: preparedPlan.mantra, settings: settings, start: 0, end: preparedPlan.duration, backgroundURL: background,
                    preparedAudio: audio.playbackURL, preparedMotion: audio.motion, breathPlan: preparedPlan)
                try await VideoExporter.export(job, to: url) { value in Task { @MainActor in self.progress = value } }
            }
            do {
                try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                exportedURL = url; status = "Saved \(url.lastPathComponent)"
            } catch {
                if error is CancellationError { status = "Export stopped." }
                else { self.error = error.localizedDescription; status = "Export failed." }
            }
        }
    }
}
private final class BreathFiles {
    let url: URL
    init(_ url: URL) { self.url = url }
    deinit { try? FileManager.default.removeItem(at: url) }
}
