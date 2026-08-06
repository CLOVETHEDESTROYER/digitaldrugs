//
//  AudioManager.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import AVFoundation
import SwiftUI

class AudioManager: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let binauralPlayerNode = AVAudioPlayerNode()
    private let naturePlayerNode = AVAudioPlayerNode()
    private let binauralMixerNode = AVAudioMixerNode()
    private let natureMixerNode = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)

    private var binauralFilePlayer: AVAudioPlayer?
    private var natureFilePlayer: AVAudioPlayer?
    private var currentBinauralFileName: String?
    private var currentNatureFileName: String?
    private var binauralLoopTimer: Timer?
    private var natureLoopTimer: Timer?
    private var cachedBuffers: [String: AVAudioPCMBuffer] = [:]
    private var hasConnectedAudioGraph = false
    private let eqGainRange: ClosedRange<Float> = -12.0...12.0
    private let managedLoopFadeDuration: TimeInterval = 1.2

    @Published var eqLowGain: Float = 2.0
    @Published var eqMidGain: Float = -3.0
    @Published var eqHighGain: Float = -8.0
    @Published var binauralVolume: Float = 0.9
    @Published var natureVolume: Float = 0.05

    init() {
        setupAudioEngine()
    }

    deinit {
        stopAll()
        audioEngine.stop()
    }

    private func setupAudioEngine() {
        configureAudioSession()

        audioEngine.attach(binauralPlayerNode)
        audioEngine.attach(naturePlayerNode)
        audioEngine.attach(binauralMixerNode)
        audioEngine.attach(natureMixerNode)
        audioEngine.attach(eqNode)

        // Keep file and nature layers centered with independent volume.
        binauralMixerNode.pan = 0.0
        natureMixerNode.pan = 0.0
        binauralMixerNode.volume = binauralVolume
        natureMixerNode.volume = natureVolume

        configureEqualizerBands()
        applyEqualizer()

        connectAudioGraph()

        // Start lazily on generated-engine playback; AVAudioPlayer file layers do not need it at launch.
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            AppLog.info("AudioManager audio session configured")
        } catch {
            AppLog.error("AudioManager audio session setup failed: \(error.localizedDescription)")
        }
    }

    private func startEngine() {
        guard !audioEngine.isRunning else { return }

        do {
            try audioEngine.start()
            AppLog.info("AudioManager engine started")
        } catch {
            AppLog.error("AudioManager engine start failed: \(error.localizedDescription)")
        }
    }

    func playBinaural(fileName: String) {
        AppLog.info("AudioManager play binaural file requested: \(fileName)")
        playLoopingFile(fileName: fileName, kind: .binaural)
    }

    func playNature(fileName: String) {
        AppLog.info("AudioManager play nature file requested: \(fileName)")
        playLoopingFile(fileName: fileName, kind: .nature)
    }

    func stopNature() {
        naturePlayerNode.stop()
        natureLoopTimer?.invalidate()
        natureLoopTimer = nil
        natureFilePlayer?.stop()
        natureFilePlayer = nil
        currentNatureFileName = nil
    }

    func stopAll() {
        AppLog.info("AudioManager stop all requested")
        binauralPlayerNode.stop()
        naturePlayerNode.stop()
        binauralLoopTimer?.invalidate()
        natureLoopTimer?.invalidate()
        binauralLoopTimer = nil
        natureLoopTimer = nil
        binauralFilePlayer?.stop()
        natureFilePlayer?.stop()
        binauralFilePlayer = nil
        natureFilePlayer = nil
        currentBinauralFileName = nil
        currentNatureFileName = nil
    }

    func maintainPlayback() {
        guard binauralFilePlayer != nil || natureFilePlayer != nil else { return }
        configureAudioSession()

        if let binauralFilePlayer, !binauralFilePlayer.isPlaying {
            binauralFilePlayer.play()
            AppLog.info("AudioManager restored the binaural file layer")
        }

        if let natureFilePlayer, !natureFilePlayer.isPlaying {
            natureFilePlayer.play()
            AppLog.info("AudioManager restored the ambient file layer")
        }
    }

    func stopBinaural() {
        binauralPlayerNode.stop()
        binauralLoopTimer?.invalidate()
        binauralLoopTimer = nil
        binauralFilePlayer?.stop()
        binauralFilePlayer = nil
        currentBinauralFileName = nil
    }

    func setBinauralVolume(_ newVolume: Float) {
        binauralVolume = min(max(newVolume, 0), 1)
        binauralMixerNode.volume = binauralVolume
        binauralFilePlayer?.volume = binauralVolume
    }

    func setNatureVolume(_ newVolume: Float) {
        natureVolume = min(max(newVolume, 0), 1)
        natureMixerNode.volume = natureVolume
        natureFilePlayer?.volume = natureVolume
    }

    func setEqualizer(low: Float? = nil, mid: Float? = nil, high: Float? = nil) {
        if let low {
            eqLowGain = clampedGain(low)
        }
        if let mid {
            eqMidGain = clampedGain(mid)
        }
        if let high {
            eqHighGain = clampedGain(high)
        }
        applyEqualizer()
    }

    func applySofterEQPreset() {
        setEqualizer(low: 3.0, mid: -4.5, high: -9.5)
    }

    func resetEqualizer() {
        setEqualizer(low: 0.0, mid: 0.0, high: 0.0)
    }

    private func configureEqualizerBands() {
        guard eqNode.bands.count >= 3 else { return }

        let lowBand = eqNode.bands[0]
        lowBand.filterType = .lowShelf
        lowBand.frequency = 180
        lowBand.bandwidth = 0.8
        lowBand.bypass = false

        let midBand = eqNode.bands[1]
        midBand.filterType = .parametric
        midBand.frequency = 1600
        midBand.bandwidth = 1.1
        midBand.bypass = false

        let highBand = eqNode.bands[2]
        highBand.filterType = .highShelf
        highBand.frequency = 4200
        highBand.bandwidth = 0.7
        highBand.bypass = false
    }

    private func applyEqualizer() {
        guard eqNode.bands.count >= 3 else { return }
        eqNode.bands[0].gain = eqLowGain
        eqNode.bands[1].gain = eqMidGain
        eqNode.bands[2].gain = eqHighGain
    }

    private func clampedGain(_ gain: Float) -> Float {
        min(max(gain, eqGainRange.lowerBound), eqGainRange.upperBound)
    }

    private enum FilePlaybackKind {
        case binaural
        case nature
    }

    private func playLoopingFile(fileName: String, kind: FilePlaybackKind) {
        configureAudioSession()

        if isAlreadyPlaying(fileName: fileName, kind: kind) {
            let player = kind == .binaural ? binauralFilePlayer : natureFilePlayer
            player?.volume = kind == .binaural ? binauralVolume : natureVolume
            AppLog.info("AudioManager file already playing: \(fileName), volume=\(player?.volume ?? 0)")
            return
        }

        guard let url = bundledAudioFileURL(fileName: fileName) else {
            AppLog.error("Audio file not found in bundle: \(fileName)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = kind == .binaural ? binauralVolume : natureVolume
            player.prepareToPlay()

            switch kind {
            case .binaural:
                binauralLoopTimer?.invalidate()
                binauralFilePlayer?.stop()
                binauralFilePlayer = player
                currentBinauralFileName = fileName
            case .nature:
                natureLoopTimer?.invalidate()
                natureFilePlayer?.stop()
                natureFilePlayer = player
                currentNatureFileName = fileName
            }

            let didStart = player.play()
            AppLog.info("AudioManager file playback \(didStart ? "started" : "did not start"): \(fileName), duration=\(String(format: "%.1f", player.duration)), volume=\(String(format: "%.2f", player.volume))")
        } catch {
            AppLog.error("AudioManager could not play file \(fileName): \(error.localizedDescription)")
        }
    }

    private func isAlreadyPlaying(fileName: String, kind: FilePlaybackKind) -> Bool {
        switch kind {
        case .binaural:
            return currentBinauralFileName == fileName && binauralFilePlayer?.isPlaying == true
        case .nature:
            return currentNatureFileName == fileName && natureFilePlayer?.isPlaying == true
        }
    }

    private func scheduleManagedLoop(for kind: FilePlaybackKind, player: AVAudioPlayer) {
        let targetVolume = kind == .binaural ? binauralVolume : natureVolume
        let fadeDuration = min(managedLoopFadeDuration, max(0.2, player.duration * 0.25))
        let triggerDelay = max(0.1, player.duration - fadeDuration)

        let timer = Timer(timeInterval: triggerDelay, repeats: false) { [weak self, weak player] _ in
            guard let self,
                  let player,
                  self.isCurrentPlayer(player, for: kind) else {
                return
            }

            self.fade(player: player, to: 0, duration: fadeDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak self, weak player] in
                guard let self,
                      let player,
                      self.isCurrentPlayer(player, for: kind) else {
                    return
                }

                player.currentTime = 0
                player.volume = 0
                player.play()
                self.fade(player: player, to: targetVolume, duration: fadeDuration)
                self.scheduleManagedLoop(for: kind, player: player)
            }
        }

        switch kind {
        case .binaural:
            binauralLoopTimer?.invalidate()
            binauralLoopTimer = timer
        case .nature:
            natureLoopTimer?.invalidate()
            natureLoopTimer = timer
        }

        RunLoop.main.add(timer, forMode: .common)
    }

    private func isCurrentPlayer(_ player: AVAudioPlayer, for kind: FilePlaybackKind) -> Bool {
        switch kind {
        case .binaural:
            return binauralFilePlayer === player
        case .nature:
            return natureFilePlayer === player
        }
    }

    private func fade(player: AVAudioPlayer, to targetVolume: Float, duration: TimeInterval) {
        let steps = 24
        let startVolume = player.volume
        let stepTime = duration / Double(steps)

        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(step)) { [weak player] in
                guard let player else { return }
                let progress = Float(step) / Float(steps)
                player.volume = startVolume + (targetVolume - startVolume) * progress
            }
        }
    }

    private func playLooping(fileName: String, on node: AVAudioPlayerNode) {
        reconnectAudioGraphIfNeeded()
        startEngine()

        guard !audioEngine.outputConnectionPoints(for: node, outputBus: 0).isEmpty else {
            AppLog.error("AudioManager playback skipped because player node is disconnected: \(fileName)")
            return
        }

        guard let buffer = loadBuffer(fileName: fileName) else {
            return
        }

        node.stop()
        node.volume = 1.0
        node.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        node.play()
    }

    private func loadBuffer(fileName: String) -> AVAudioPCMBuffer? {
        if let buffer = cachedBuffers[fileName] {
            return buffer
        }

        guard let url = bundledAudioFileURL(fileName: fileName) else {
            AppLog.error("Audio file not found in bundle: \(fileName)")
            return nil
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: frameCount
            ) else {
                return nil
            }

            try file.read(into: buffer)
            cachedBuffers[fileName] = buffer
            return buffer
        } catch {
            AppLog.error("Error reading audio file \(fileName): \(error.localizedDescription)")
            return nil
        }
    }

    private func bundledAudioFileURL(fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil) {
            return url
        }

        let subdirectories = ["DDrituals ", "Audio/DDrituals ", "NatureSounds", "Audio/NatureSounds", "Audio"]
        for subdirectory in subdirectories {
            if let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: subdirectory) {
                return url
            }
        }

        guard fileName.contains("/"),
              let resourceURL = Bundle.main.resourceURL else {
            return nil
        }

        let directURL = resourceURL.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: directURL.path) ? directURL : nil
    }

    private func connectAudioGraph() {
        audioEngine.connect(binauralPlayerNode, to: binauralMixerNode, format: nil)
        audioEngine.connect(naturePlayerNode, to: natureMixerNode, format: nil)
        audioEngine.connect(binauralMixerNode, to: eqNode, format: nil)
        audioEngine.connect(natureMixerNode, to: eqNode, format: nil)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: nil)
        hasConnectedAudioGraph = true
    }

    private func reconnectAudioGraphIfNeeded() {
        let binauralConnections = audioEngine.outputConnectionPoints(for: binauralPlayerNode, outputBus: 0)
        let natureConnections = audioEngine.outputConnectionPoints(for: naturePlayerNode, outputBus: 0)
        let eqConnections = audioEngine.outputConnectionPoints(for: eqNode, outputBus: 0)

        guard !hasConnectedAudioGraph || binauralConnections.isEmpty || natureConnections.isEmpty || eqConnections.isEmpty else {
            return
        }

        AppLog.info("AudioManager reconnecting audio graph before playback")
        let wasRunning = audioEngine.isRunning
        if wasRunning {
            audioEngine.pause()
        }

        audioEngine.disconnectNodeOutput(binauralPlayerNode)
        audioEngine.disconnectNodeOutput(naturePlayerNode)
        audioEngine.disconnectNodeOutput(binauralMixerNode)
        audioEngine.disconnectNodeOutput(natureMixerNode)
        audioEngine.disconnectNodeOutput(eqNode)
        connectAudioGraph()

        if wasRunning {
            startEngine()
        }
    }
}
