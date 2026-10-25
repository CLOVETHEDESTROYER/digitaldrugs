import SwiftUI
import WebKit
import AVFoundation
import Observation

/// Fixed-size windows from the separately rendered background mix. This reader
/// never receives the audible voice+background file and does not retain a whole song.
final class VisualLabPCM {
    private let file: AVAudioFile
    private let buffer: AVAudioPCMBuffer
    init(backgroundURL: URL) throws {
        file = try AVAudioFile(forReading: backgroundURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        // Butterchurn's offline input assumes 44.1 kHz. Resample each small window
        // by interpolation rather than changing the audible mix or allocating minutes of PCM.
        let capacity = AVAudioFrameCount(ceil(file.processingFormat.sampleRate / 44100 * 1024) + 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
            throw StudioError.message("Could not prepare background samples for the Visual Lab.")
        }
        self.buffer = buffer
    }
    func samples(at time: Double) throws -> (mono: [UInt8], left: [UInt8], right: [UInt8]) {
        let rate = file.processingFormat.sampleRate
        file.framePosition = min(file.length, max(0, AVAudioFramePosition(time * rate)))
        buffer.frameLength = 0
        if file.framePosition >= file.length {
            let silence = [UInt8](repeating: 128, count: 1024)
            return (silence, silence, silence)
        }
        try file.read(into: buffer, frameCount: buffer.frameCapacity)
        guard let channels = buffer.floatChannelData else { throw StudioError.message("Could not decode the background waveform.") }
        let count = Int(buffer.frameLength), rightChannel = Int(buffer.format.channelCount) > 1 ? 1 : 0
        func value(_ channel: Int, _ index: Int) -> Float {
            let position = Double(index) * rate / 44100
            let a = Int(position), f = Float(position - Double(a))
            guard a < count else { return 0 }
            return channels[channel][a] * (1 - f) + (a + 1 < count ? channels[channel][a + 1] : 0) * f
        }
        func byte(_ sample: Float) -> UInt8 { UInt8(min(255, max(0, Int((sample * 127 + 128).rounded())))) }
        var left = [UInt8](), right = [UInt8]()
        var leftPower: Float = 0, rightPower: Float = 0
        for index in 0..<1024 {
            let l = value(0, index), r = value(rightChannel, index)
            leftPower += l * l; rightPower += r * r
            left.append(byte(l)); right.append(byte(r))
        }
        // Analyse one whole stronger channel for the combined input. Keep both
        // original channels for MilkDrop's stereo waves; avoid phase cancellation.
        let mono = leftPower >= rightPower ? left : right
        return (mono, left, right)
    }
}

@MainActor @Observable
final class VisualLabState {
    var preparing = false
    var playing = false
    var ready = false
    var webReady = false
    var elapsed = 0.0
    var duration = 0.0
    var message = "Use the main studio to choose a recording and background layers, then prepare a comparison."
    var error: String?
    var title = "Visual Lab"
    var metalImage: CGImage?
    var metalStyle = 10
    var compare = true
    var muteVoice = false
    private var webView: WKWebView?
    private var renderer: FrameRenderer?
    private var envelope: AudioEnvelope?
    private var pcm: VisualLabPCM?
    private var player: AVAudioPlayer?
    private var backgroundPlayer: AVAudioPlayer?
    private var folder: URL?
    private var task: Task<Void, Never>?
    private var timer: Timer?
    private var generation = 0
    private var sending = false
    private var lastSentTime = 0.0
    private var mantra: Mantra?
    private var settings = ExportSettings()
    static let page = StudioResources.root.appendingPathComponent("Butterchurn/index.html")

    func attach(_ webView: WKWebView) { self.webView = webView; sending = false }
    func webMessage(_ event: [String: String]) {
        if event["type"] == "ready" { webReady = true }
        if event["type"] == "error" { pause(); webReady = false; error = event["message"] }
    }
    func detach() { pause(); webView = nil; webReady = false; task?.cancel(); generation += 1; preparing = false; clearAudio() }
    private func clearAudio() {
        player = nil; backgroundPlayer = nil; pcm = nil; envelope = nil; ready = false
        if let folder { try? FileManager.default.removeItem(at: folder) }; folder = nil
    }
    func prepare(studio: StudioState, ambientDemo: Bool = false) {
        guard !preparing, let selected = studio.selected else { return }
        pause(); task?.cancel(); generation += 1; let current = generation
        clearAudio(); elapsed = 0; metalImage = nil; preparing = true; error = nil
        mantra = selected; settings = studio.settings; metalStyle = ambientDemo ? 10 : studio.settings.style; title = selected.title
        if ambientDemo {
            settings.soundscape = StudioSoundscape(); settings.soundscape.beat = .theta
            settings.soundscape.natureID = "forest_ambience"; muteVoice = true
        }
        let capturedSettings = settings, background = ambientDemo ? nil : studio.backgroundURL
        message = "Preparing the same audio for both visual engines…"
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-VisualLab-\(UUID())")
        task = Task {
            defer { if generation == current { preparing = false } }
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let audible = output.appendingPathComponent("audible.m4a"), motion = output.appendingPathComponent("background.m4a")
                let worker = Task.detached(priority: .userInitiated) {
                    let mixed = try await AudioMix.prepare(voice: selected.audioURL, background: background,
                        volume: capturedSettings.backgroundVolume, output: audible,
                        soundscape: capturedSettings.soundscape, motionOutput: motion, maximumDuration: 90)
                    let envelope = FileManager.default.fileExists(atPath: motion.path) ? try AudioEnvelope(url: motion) : nil
                    return (mixed, envelope)
                }
                let (mixed, envelope) = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                guard generation == current else { try? FileManager.default.removeItem(at: output); return }
                let audiblePlayer = try AVAudioPlayer(contentsOf: mixed); audiblePlayer.prepareToPlay()
                player = audiblePlayer; duration = audiblePlayer.duration
                self.envelope = envelope ?? AudioEnvelope(silence: duration)
                if FileManager.default.fileExists(atPath: motion.path) {
                    pcm = try VisualLabPCM(backgroundURL: motion)
                    backgroundPlayer = try AVAudioPlayer(contentsOf: motion); backgroundPlayer?.prepareToPlay()
                }
                folder = output; renderer = try FrameRenderer(); ready = true
                message = pcm == nil ? "No background selected: ambient motion only. Add nature, beats, chakra or music in the main studio, then prepare again." : "Ready · both engines use the same background. Mantra voice never drives movement."
                drawMetal()
            } catch {
                try? FileManager.default.removeItem(at: output)
                if generation == current { clearAudio(); if !(error is CancellationError) { self.error = error.localizedDescription } }
            }
        }
    }
    func toggle(onPlay: () -> Void) {
        if playing { pause(); return }
        guard ready, webReady, let player else { return }
        onPlay()
        if elapsed >= duration - 0.05 { restart() }
        let chosen = muteVoice ? backgroundPlayer : player
        guard let chosen else { message = "There is no background audio to play alone. Turn off Background only or add a sound layer."; return }
        chosen.currentTime = elapsed
        guard chosen.play() else { error = "Comparison audio could not start."; return }
        playing = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }
    func pause() { timer?.invalidate(); timer = nil; player?.pause(); backgroundPlayer?.pause(); playing = false }
    func restart() {
        pause(); elapsed = 0; lastSentTime = 0; generation += 1; drawMetal()
        webView?.evaluateJavaScript("window.ZenWaveLab.reset()", completionHandler: nil)
    }
    func drawMetal() {
        guard compare, let renderer, let mantra, let envelope else { return }
        var styleSettings = settings; styleSettings.style = metalStyle
        // Match the raw Butterchurn comparison: no caption/logo/CTA overlays.
        styleSettings.captions = false; styleSettings.branding = false; styleSettings.heading = ""; styleSettings.callToAction.enabled = false
        do { metalImage = try renderer.frame(width: 360, height: 640, time: elapsed, audioTime: elapsed,
            envelope: envelope, mantra: mantra, settings: styleSettings) }
        catch { pause(); self.error = error.localizedDescription }
    }
    private func tick() {
        guard playing, let chosen = muteVoice ? backgroundPlayer : player else { return }
        elapsed = min(duration, chosen.currentTime)
        if !chosen.isPlaying || elapsed >= duration { pause(); return }
        drawMetal()
        guard !sending, let webView else { return }
        do {
            let silent = [UInt8](repeating: 128, count: 1024)
            let samples = try pcm?.samples(at: elapsed) ?? (mono: silent, left: silent, right: silent)
            let packet: [String: Any] = ["time": elapsed, "delta": max(1.0 / 120, elapsed - lastSentTime), "generation": generation,
                "mono": samples.mono, "left": samples.left, "right": samples.right]
            let json = String(decoding: try JSONSerialization.data(withJSONObject: packet), as: UTF8.self)
            sending = true; lastSentTime = elapsed
            webView.evaluateJavaScript("window.ZenWaveLab.frame(\(json))") { [weak self] _, error in
                guard let self, self.webView === webView else { return }; self.sending = false
                if let error { self.pause(); self.error = error.localizedDescription }
            }
        } catch { pause(); self.error = error.localizedDescription }
    }
}

struct VisualLabWebView: NSViewRepresentable {
    let state: VisualLabState
    func makeCoordinator() -> Coordinator { Coordinator(state) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "visualLab")
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        state.attach(view)
        view.loadFileURL(VisualLabState.page, allowingReadAccessTo: VisualLabState.page.deletingLastPathComponent())
        return view
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.stopLoading(); nsView.configuration.userContentController.removeScriptMessageHandler(forName: "visualLab")
        coordinator.state.detach()
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let state: VisualLabState
        init(_ state: VisualLabState) { self.state = state }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let event = message.body as? [String: String] { state.webMessage(event) }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Keep the preview fully local. External navigation never leaves this lab.
            let root = VisualLabState.page.deletingLastPathComponent().resolvingSymlinksInPath().path + "/"
            let url = navigationAction.request.url
            decisionHandler(url?.isFileURL == true && url!.resolvingSymlinksInPath().path.hasPrefix(root) ? .allow : .cancel)
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            state.webMessage(["type": "error", "message": "The visual preview stopped. Close and reopen Visual Lab, or try Light quality."])
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { state.webMessage(["type": "error", "message": error.localizedDescription]) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { state.webMessage(["type": "error", "message": error.localizedDescription]) }
    }
}

struct VisualLabView: View {
    @Bindable var lab: VisualLabState
    let studio: StudioState
    let onPlay: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Visual Lab").font(.title.bold())
                    Text("Butterchurn / MilkDrop + ZenWave Metal · portrait preview · up to 90 seconds").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Try ambient demo") { lab.prepare(studio: studio, ambientDemo: true) }.disabled(lab.preparing || studio.exporting)
                Button(lab.preparing ? "Preparing…" : "Prepare from main studio") { lab.prepare(studio: studio) }.disabled(lab.preparing || studio.exporting)
            }
            HStack {
                Button(lab.playing ? "Pause" : "Play comparison") { lab.toggle(onPlay: onPlay) }.disabled(!lab.ready || !lab.webReady).buttonStyle(.borderedProminent)
                Button("Restart") { lab.restart() }.disabled(!lab.ready)
                Toggle("Compare with Metal", isOn: $lab.compare).toggleStyle(.checkbox)
                Toggle("Background only", isOn: $lab.muteVoice).toggleStyle(.checkbox).onChange(of: lab.muteVoice) { _, _ in lab.pause() }
                Spacer()
                Text("\(Int(lab.elapsed)) / \(Int(lab.duration)) sec").monospacedDigit().foregroundStyle(.secondary)
            }
            HSplitView {
                if lab.compare {
                    VStack {
                        Picker("Metal visual", selection: $lab.metalStyle) { ForEach(VisualStyle.all) { Text($0.title).tag($0.id) } }
                        GeometryReader { geo in
                            if let image = lab.metalImage { Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit).frame(width: geo.size.width, height: geo.size.height) }
                        }.background(.black).clipShape(RoundedRectangle(cornerRadius: 14))
                        Text("ZenWave original · current palette / motion settings").font(.caption).foregroundStyle(.secondary)
                    }.padding(.trailing, 12).frame(minWidth: 240, idealWidth: 340)
                }
                VisualLabWebView(state: lab).frame(minWidth: 480)
            }
            HStack {
                if lab.preparing { ProgressView().controlSize(.small) }
                Text(lab.message).font(.callout).foregroundStyle(.secondary)
            }
            Text("Preview only: Butterchurn is not yet part of MP4 exports, random batches or Muse requests. Existing production visuals and automation stay on Metal.").font(.caption).foregroundStyle(.secondary)
        }.padding(22).frame(minWidth: 900, minHeight: 700).preferredColorScheme(.dark)
            .onChange(of: lab.metalStyle) { _, _ in lab.drawMetal() }
            .onChange(of: lab.compare) { _, _ in lab.drawMetal() }
            .onDisappear { lab.pause() }
            .alert("Visual Lab needs attention", isPresented: Binding(get: { lab.error != nil }, set: { if !$0 { lab.error = nil } })) { Button("OK") { lab.error = nil } } message: { Text(lab.error ?? "") }
    }
}
