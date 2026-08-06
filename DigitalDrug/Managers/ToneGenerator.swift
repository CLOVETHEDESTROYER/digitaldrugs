//
//  ToneGenerator.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import AVFoundation

enum SoundPlaybackKind: String {
    case binaural = "Binaural"
    case pulsed = "Pulsed"
    case chakra = "Chakra"
}

class ToneGenerator: NSObject, ObservableObject {
    struct ChakraBellTimbre: Hashable {
        let ringDuration: TimeInterval
        let loopInterval: TimeInterval
        let brightness: Double
        let decayScale: Double
        let warmth: Double

        static let balanced = ChakraBellTimbre(
            ringDuration: 2.8,
            loopInterval: 4.0,
            brightness: 0.55,
            decayScale: 1.0,
            warmth: 0.45
        )
    }

    private let audioEngine = AVAudioEngine()
    private let binauralPlayerNode = AVAudioPlayerNode()
    private let leftPlayerNode = AVAudioPlayerNode()
    private let rightPlayerNode = AVAudioPlayerNode()
    private let leftMixNode = AVAudioMixerNode()
    private let rightMixNode = AVAudioMixerNode()
    private let sumMixerNode = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private let binauralEQNode = AVAudioUnitEQ(numberOfBands: 3)
    private let reverbNode = AVAudioUnitReverb()
    private var filePlayer: AVAudioPlayer?
    private var manifestationMantraPlayer: AVAudioPlayer?
    private var manifestationMantraRestartTask: DispatchWorkItem?
    private var manifestationMantraGeneration = 0
    private var manifestationMantraLoopGap: TimeInterval = 8

    @Published var isPlaying = false
    @Published var leftFrequency: Double = 440.0
    @Published var rightFrequency: Double = 450.0
    @Published var volume: Float = 0.5
    @Published var currentBinauralBeat: Double = 10.0
    @Published var eqLowGain: Float = 2.0
    @Published var eqMidGain: Float = -3.0
    @Published var eqHighGain: Float = -8.0
    @Published var currentSoundTitle: String?
    @Published var currentSoundSubtitle: String?
    @Published var currentSoundKind: SoundPlaybackKind?
    @Published var isManifestationMantraPlaying = false
    @Published var isManifestationMantraWaitingToRepeat = false

    private var audioFormat: AVAudioFormat!
    private var stereoAudioFormat: AVAudioFormat!
    private let eqGainRange: ClosedRange<Float> = -12.0...12.0
    private var stopGeneration = 0
    private var playbackVolumeScale: Float = 1.0

    private var effectiveOutputVolume: Float {
        volume * playbackVolumeScale
    }

    var hasCurrentSound: Bool {
        currentSoundTitle != nil
    }

    override init() {
        super.init()
        setupAudioEngine()
    }

    deinit {
        stop()
        audioEngine.stop()
    }

    private func setupAudioEngine() {
        configureAudioSession()

        // Create audio format
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)
        stereoAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)

        // Attach nodes
        audioEngine.attach(binauralPlayerNode)
        audioEngine.attach(leftPlayerNode)
        audioEngine.attach(rightPlayerNode)
        audioEngine.attach(leftMixNode)
        audioEngine.attach(rightMixNode)
        audioEngine.attach(sumMixerNode)
        audioEngine.attach(eqNode)
        audioEngine.attach(binauralEQNode)
        audioEngine.attach(reverbNode)

        // Panning
        leftMixNode.pan = -0.85
        rightMixNode.pan = 0.85

        // EQ configuration for a visual 3-band equalizer.
        configureEqualizerBands()
        applyEqualizer()

        // Reverb (very light)
        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = 8

        // Connect graph:
        // - true binaural path: stereo player -> stereo EQ -> main mixer
        // - pulsed/chakra path: mono players -> per-channel mixers -> sum -> EQ -> Reverb -> main
        audioEngine.connect(binauralPlayerNode, to: binauralEQNode, format: stereoAudioFormat)
        audioEngine.connect(binauralEQNode, to: audioEngine.mainMixerNode, format: stereoAudioFormat)
        audioEngine.connect(leftPlayerNode, to: leftMixNode, format: audioFormat)
        audioEngine.connect(rightPlayerNode, to: rightMixNode, format: audioFormat)
        audioEngine.connect(leftMixNode, to: sumMixerNode, format: audioFormat)
        audioEngine.connect(rightMixNode, to: sumMixerNode, format: audioFormat)
        audioEngine.connect(sumMixerNode, to: eqNode, format: audioFormat)
        audioEngine.connect(eqNode, to: reverbNode, format: audioFormat)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: audioFormat)

        // Set initial volumes
        // Keep mixer at unity and control volume on player nodes for real-time changes
        binauralPlayerNode.volume = effectiveOutputVolume
        leftPlayerNode.volume = effectiveOutputVolume
        rightPlayerNode.volume = effectiveOutputVolume

        // Start lazily when a tone is requested to avoid idle audio-engine churn at launch.
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            AppLog.info("ToneGenerator audio session configured")
        } catch {
            AppLog.error("ToneGenerator audio session setup failed: \(error.localizedDescription)")
        }
    }

    private func startEngine() {
        configureAudioSession()
        guard !audioEngine.isRunning else { return }

        do {
            try audioEngine.start()
            AppLog.info("ToneGenerator engine started")
        } catch {
            AppLog.error("ToneGenerator engine start failed: \(error.localizedDescription)")
        }
    }

    func generateBinauralBeat(
        leftFreq: Double,
        rightFreq: Double,
        duration: TimeInterval = 10,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        guard stereoAudioFormat != nil else { return }
        setPlaybackVolumeScale(1.0)
        AppLog.info("Generate fixed binaural beat requested: left=\(leftFreq), right=\(rightFreq), duration=\(duration), title=\(title ?? "nil")")

        leftFrequency = leftFreq
        rightFrequency = rightFreq
        currentBinauralBeat = abs(rightFreq - leftFreq)

        // Stop any existing playback immediately before scheduling.
        stopImmediately()
        setCurrentSound(
            title: title ?? "Binaural Beat",
            subtitle: subtitle ?? "\(Int(leftFreq)) - \(Int(rightFreq)) Hz - \(String(format: "%.1f", abs(rightFreq - leftFreq))) Hz beat",
            kind: .binaural
        )
        startEngine()

        // Generate one true stereo buffer: left tone in channel 0, right tone in channel 1.
        let renderDuration = duration > 0 ? duration : 10
        guard let binauralBuffer = generateBinauralStereoBuffer(
            leftFrequency: leftFreq,
            rightFrequency: rightFreq,
            duration: renderDuration
        ) else {
            failPlaybackPreparation("fixed stereo binaural buffer")
            return
        }

        binauralPlayerNode.scheduleBuffer(binauralBuffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        })

        binauralPlayerNode.volume = effectiveOutputVolume
        binauralPlayerNode.play()
        isPlaying = true
    }

    func generateContinuousBinauralBeat(
        leftFreq: Double,
        rightFreq: Double,
        title: String? = nil,
        subtitle: String? = nil,
        volumeScale: Float = 1.0
    ) {
        guard stereoAudioFormat != nil else { return }
        setPlaybackVolumeScale(volumeScale)
        AppLog.info("Generate continuous binaural beat requested: left=\(leftFreq), right=\(rightFreq), title=\(title ?? "nil"), volumeScale=\(playbackVolumeScale)")

        leftFrequency = leftFreq
        rightFrequency = rightFreq
        currentBinauralBeat = abs(rightFreq - leftFreq)

        // Stop any existing playback immediately before scheduling loops.
        stopImmediately()
        setCurrentSound(
            title: title ?? "Binaural Beat",
            subtitle: subtitle ?? "\(Int(leftFreq)) - \(Int(rightFreq)) Hz - \(String(format: "%.1f", abs(rightFreq - leftFreq))) Hz beat",
            kind: .binaural
        )
        startEngine()

        // Generate continuous true stereo tones (10 seconds, looped).
        guard let binauralBuffer = generateBinauralStereoBuffer(
            leftFrequency: leftFreq,
            rightFrequency: rightFreq,
            duration: 10.0
        ) else {
            failPlaybackPreparation("continuous stereo binaural buffer")
            return
        }

        // Start silent then fade in for smoothness
        binauralPlayerNode.volume = 0
        leftPlayerNode.volume = 0
        rightPlayerNode.volume = 0
        binauralPlayerNode.scheduleBuffer(binauralBuffer, at: nil, options: .loops, completionHandler: nil)
        binauralPlayerNode.play()
        isPlaying = true
        fadePlayers(to: effectiveOutputVolume, duration: 0.6)
    }

    func generatePulsedTone(
        carrierFreq: Double,
        pulseFreq: Double,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        guard audioFormat != nil else { return }
        setPlaybackVolumeScale(1.0)
        AppLog.info("Generate pulsed tone requested: carrier=\(carrierFreq), pulse=\(pulseFreq), title=\(title ?? "nil")")

        setCenteredPanning()
        leftFrequency = carrierFreq
        rightFrequency = carrierFreq
        currentBinauralBeat = pulseFreq

        stopImmediately()
        setCurrentSound(
            title: title ?? "Pulsed Beat",
            subtitle: subtitle ?? "\(Int(carrierFreq)) Hz carrier - \(String(format: "%.1f", pulseFreq)) Hz pulse",
            kind: .pulsed
        )
        startEngine()

        guard let pulsedBuffer = generatePulsedToneBuffer(
            carrierFreq: carrierFreq,
            pulseFreq: pulseFreq,
            duration: 10.0
        ) else {
            failPlaybackPreparation("pulsed tone buffer")
            return
        }

        leftPlayerNode.scheduleBuffer(pulsedBuffer, at: nil, options: .loops, completionHandler: nil)
        rightPlayerNode.scheduleBuffer(pulsedBuffer, at: nil, options: .loops, completionHandler: nil)

        leftPlayerNode.volume = 0
        rightPlayerNode.volume = 0
        leftPlayerNode.play()
        rightPlayerNode.play()
        isPlaying = true
        fadePlayers(to: effectiveOutputVolume, duration: 0.35)
    }

    func generateChakraBell(
        frequency: Double,
        timbre: ChakraBellTimbre = .balanced,
        title: String? = nil,
        subtitle: String? = nil,
        volumeScale: Float = 1.0
    ) {
        guard audioFormat != nil else { return }
        setPlaybackVolumeScale(volumeScale)
        AppLog.info("Generate chakra bell requested: frequency=\(frequency), title=\(title ?? "nil"), volumeScale=\(playbackVolumeScale)")

        setCenteredPanning()
        leftFrequency = frequency
        rightFrequency = frequency
        currentBinauralBeat = 0.0

        stopImmediately()
        setCurrentSound(
            title: title ?? "Chakra Tone",
            subtitle: subtitle ?? "\(Int(frequency)) Hz chakra tone",
            kind: .chakra
        )
        startEngine()

        let safeRingDuration = max(0.3, min(timbre.ringDuration, timbre.loopInterval))
        let safeLoopInterval = max(safeRingDuration + 0.2, timbre.loopInterval)
        guard let bellLoop = generateChakraToneLoop(
            frequency: frequency,
            ringDuration: safeRingDuration,
            loopInterval: safeLoopInterval,
            timbre: timbre
        ) else {
            failPlaybackPreparation("chakra bell buffer")
            return
        }

        leftPlayerNode.scheduleBuffer(bellLoop, at: nil, options: .loops, completionHandler: nil)
        rightPlayerNode.scheduleBuffer(bellLoop, at: nil, options: .loops, completionHandler: nil)

        leftPlayerNode.volume = 0
        rightPlayerNode.volume = 0
        leftPlayerNode.play()
        rightPlayerNode.play()
        isPlaying = true
        fadePlayers(to: effectiveOutputVolume, duration: 0.22)
    }

    func playLoopingAudioFile(
        fileName: String,
        title: String,
        subtitle: String,
        kind: SoundPlaybackKind,
        volumeScale: Float = 1.0
    ) {
        AppLog.info("ToneGenerator file playback requested: file=\(fileName), title=\(title), volumeScale=\(volumeScale)")
        configureAudioSession()
        setPlaybackVolumeScale(volumeScale)
        stopImmediately()
        setCurrentSound(title: title, subtitle: subtitle, kind: kind)

        guard let url = bundledAudioFileURL(fileName: fileName) else {
            AppLog.error("ToneGenerator file playback missing bundle file: \(fileName)")
            failPlaybackPreparation("audio file \(fileName)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = effectiveOutputVolume
            player.prepareToPlay()
            filePlayer = player
            player.play()
            isPlaying = true
            AppLog.info("ToneGenerator file playback started: \(url.lastPathComponent)")
        } catch {
            AppLog.error("ToneGenerator file playback failed: \(fileName), error=\(error.localizedDescription)")
            failPlaybackPreparation("audio file \(fileName)")
        }
    }

    func playLoopingManifestationMantra(
        fileName: String,
        loopGap: TimeInterval = 8
    ) {
        configureAudioSession()
        stopManifestationMantra()

        guard let url = bundledAudioFileURL(fileName: fileName) else {
            AppLog.error("ToneGenerator manifestation mantra missing bundle file: \(fileName)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.numberOfLoops = 0
            player.volume = manifestationMantraVolume
            player.prepareToPlay()

            manifestationMantraLoopGap = max(2, loopGap)
            manifestationMantraPlayer = player
            manifestationMantraGeneration += 1
            isManifestationMantraWaitingToRepeat = false
            isManifestationMantraPlaying = player.play()
            AppLog.info("ToneGenerator manifestation mantra started: \(url.lastPathComponent), gap=\(String(format: "%.1f", manifestationMantraLoopGap))")
        } catch {
            AppLog.error("ToneGenerator manifestation mantra playback failed: \(fileName), error=\(error.localizedDescription)")
            stopManifestationMantra()
        }
    }

    private func scheduleContinuousPlayback(leftBuffer: AVAudioPCMBuffer, rightBuffer: AVAudioPCMBuffer) {
        leftPlayerNode.scheduleBuffer(leftBuffer, at: nil, options: .loops, completionHandler: nil)
        rightPlayerNode.scheduleBuffer(rightBuffer, at: nil, options: .loops, completionHandler: nil)

        leftPlayerNode.play()
        rightPlayerNode.play()
    }

    // Smooth fade utility
    private func fadePlayers(to target: Float, duration: TimeInterval) {
        let steps = 30
        let stepTime = duration / Double(steps)
        let startBinaural = binauralPlayerNode.volume
        let startL = leftPlayerNode.volume
        let startR = rightPlayerNode.volume
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            let valBinaural = startBinaural + (target - startBinaural) * t
            let valL = startL + (target - startL) * t
            let valR = startR + (target - startR) * t
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) {
                self.binauralPlayerNode.volume = valBinaural
                self.leftPlayerNode.volume = valL
                self.rightPlayerNode.volume = valR
            }
        }
    }

    private func generateTone(frequency: Double, duration: TimeInterval) -> AVAudioPCMBuffer? {
        let sampleRate = audioFormat.sampleRate
        let frameCount = UInt32(sampleRate * duration)
        guard frameCount > 0 else {
            AppLog.error("ToneGenerator buffer request had zero frames: frequency=\(frequency), duration=\(duration)")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            AppLog.error("ToneGenerator could not create tone buffer: frequency=\(frequency), duration=\(duration)")
            return nil
        }

        buffer.frameLength = frameCount

        guard let samples = buffer.floatChannelData?[0] else {
            AppLog.error("ToneGenerator tone buffer missing channel data")
            return nil
        }
        let phaseIncrement = 2.0 * Double.pi * frequency / sampleRate
        let total = Int(frameCount)
        let fadeSamples = min(1024, max(32, total / 24))

        for i in 0..<total {
            let rawSample = sin(phaseIncrement * Double(i))
            var window: Double = 1.0
            if i < fadeSamples {
                window = Double(i) / Double(fadeSamples)
            } else if i > total - fadeSamples {
                window = Double(total - i) / Double(fadeSamples)
            }
            samples[i] = Float(rawSample * window)
        }

        return buffer
    }

    private func generateBinauralStereoBuffer(
        leftFrequency: Double,
        rightFrequency: Double,
        duration: TimeInterval
    ) -> AVAudioPCMBuffer? {
        let sampleRate = stereoAudioFormat.sampleRate
        let frameCount = UInt32(sampleRate * duration)
        guard frameCount > 0 else {
            AppLog.error("ToneGenerator binaural stereo buffer request had zero frames: left=\(leftFrequency), right=\(rightFrequency), duration=\(duration)")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: stereoAudioFormat, frameCapacity: frameCount) else {
            AppLog.error("ToneGenerator could not create stereo binaural buffer: left=\(leftFrequency), right=\(rightFrequency), duration=\(duration)")
            return nil
        }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData,
              stereoAudioFormat.channelCount >= 2 else {
            AppLog.error("ToneGenerator stereo binaural buffer missing channel data")
            return nil
        }

        let leftSamples = channelData[0]
        let rightSamples = channelData[1]
        let total = Int(frameCount)
        let leftIncrement = 2.0 * Double.pi * leftFrequency / sampleRate
        let rightIncrement = 2.0 * Double.pi * rightFrequency / sampleRate
        let fadeSamples = min(1024, max(32, total / 24))

        for i in 0..<total {
            var window: Double = 1.0
            if i < fadeSamples {
                window = Double(i) / Double(fadeSamples)
            } else if i > total - fadeSamples {
                window = Double(total - i) / Double(fadeSamples)
            }

            leftSamples[i] = Float(sin(leftIncrement * Double(i)) * window)
            rightSamples[i] = Float(sin(rightIncrement * Double(i)) * window)
        }

        return buffer
    }

    private func generatePulsedToneBuffer(
        carrierFreq: Double,
        pulseFreq: Double,
        duration: TimeInterval
    ) -> AVAudioPCMBuffer? {
        let sampleRate = audioFormat.sampleRate
        let frameCount = UInt32(sampleRate * duration)
        guard frameCount > 0 else {
            AppLog.error("ToneGenerator pulsed buffer request had zero frames: carrier=\(carrierFreq), pulse=\(pulseFreq), duration=\(duration)")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            AppLog.error("ToneGenerator could not create pulsed tone buffer: carrier=\(carrierFreq), pulse=\(pulseFreq), duration=\(duration)")
            return nil
        }

        buffer.frameLength = frameCount

        guard let samples = buffer.floatChannelData?[0] else {
            AppLog.error("ToneGenerator pulsed buffer missing channel data")
            return nil
        }
        let total = Int(frameCount)
        let carrierIncrement = 2.0 * Double.pi * carrierFreq / sampleRate
        let pulseIncrement = 2.0 * Double.pi * max(0.1, pulseFreq) / sampleRate
        let fadeSamples = min(2048, max(64, total / 18))

        for i in 0..<total {
            let carrier = sin(carrierIncrement * Double(i))
            let pulse = 0.18 + 0.82 * pow((sin(pulseIncrement * Double(i)) + 1.0) * 0.5, 1.8)
            var window = 1.0
            if i < fadeSamples {
                window = Double(i) / Double(fadeSamples)
            } else if i > total - fadeSamples {
                window = Double(total - i) / Double(fadeSamples)
            }
            samples[i] = Float(carrier * pulse * window)
        }

        return buffer
    }

    private func generateChakraToneLoop(
        frequency: Double,
        ringDuration: TimeInterval,
        loopInterval: TimeInterval,
        timbre: ChakraBellTimbre
    ) -> AVAudioPCMBuffer? {
        let sampleRate = audioFormat.sampleRate
        let frameCount = UInt32(sampleRate * loopInterval)
        guard frameCount > 0 else {
            AppLog.error("ToneGenerator chakra buffer request had zero frames: frequency=\(frequency), interval=\(loopInterval)")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            AppLog.error("ToneGenerator could not create bell loop buffer: frequency=\(frequency), interval=\(loopInterval)")
            return nil
        }

        buffer.frameLength = frameCount
        guard let samples = buffer.floatChannelData?[0] else {
            AppLog.error("ToneGenerator bell loop buffer missing channel data")
            return nil
        }
        let total = Int(frameCount)
        let brightness = min(max(timbre.brightness, 0.0), 1.0)
        let warmth = min(max(timbre.warmth, 0.0), 1.0)
        let decayScale = max(0.55, min(timbre.decayScale, 1.8))

        // A soft sustained bed gives immediate feedback, while inharmonic partials
        // add a repeating bell shimmer on top.
        let partials: [(ratio: Double, amplitude: Double, decay: Double)] = [
            (1.00, 1.00, 3.2),
            (2.01, 0.58, 4.8),
            (2.98, 0.34, 6.0),
            (4.20, 0.22, 7.6),
            (5.43, 0.13, 9.2)
        ]
        let attack = min(0.03, ringDuration * 0.2)

        for i in 0..<total {
            let t = Double(i) / sampleRate
            let sustainedEnvelope = min(1.0, t / 0.18)
            let slowPulse = 0.88 + 0.12 * sin(2.0 * Double.pi * 0.08 * t)
            let sustainedTone = sin(2.0 * Double.pi * frequency * t) * 0.28 * sustainedEnvelope * slowPulse

            let attackEnvelope = t < attack ? (t / attack) : 1.0
            var bellValue = 0.0
            if t <= ringDuration {
                for (index, partial) in partials.enumerated() {
                    let partialFreq = frequency * partial.ratio
                    var amplitude = partial.amplitude
                    if index <= 1 {
                        amplitude *= (0.72 + warmth * 0.55)
                    } else if index >= 3 {
                        amplitude *= (0.40 + brightness * 1.05)
                    } else {
                        amplitude *= (0.80 + brightness * 0.25 + warmth * 0.20)
                    }

                    let decay = partial.decay / decayScale
                    let ampEnvelope = exp(-decay * t)
                    bellValue += amplitude * ampEnvelope * sin(2.0 * Double.pi * partialFreq * t)
                }
            }

            let shimmer = sin(2.0 * Double.pi * frequency * 0.13 * t) * 0.035
            let softLimiter = tanh(sustainedTone + bellValue * 0.52 + shimmer) * 0.7 * attackEnvelope
            samples[i] = Float(softLimiter)
        }

        return buffer
    }

    func stop() {
        guard isPlaying || hasCurrentSound || manifestationMantraPlayer != nil else { return }
        AppLog.info("ToneGenerator stop requested. isPlaying=\(isPlaying), current=\(currentSoundTitle ?? "nil")")
        stopGeneration += 1
        let generation = stopGeneration
        stopManifestationMantra()

        if filePlayer != nil {
            stopFilePlayback()
            isPlaying = false
            clearCurrentSound()
            setPlaybackVolumeScale(1.0)
            return
        }

        guard isPlaying else {
            binauralPlayerNode.stop()
            binauralPlayerNode.reset()
            leftPlayerNode.stop()
            rightPlayerNode.stop()
            leftPlayerNode.reset()
            rightPlayerNode.reset()
            clearCurrentSound()
            setPlaybackVolumeScale(1.0)
            binauralPlayerNode.volume = effectiveOutputVolume
            leftPlayerNode.volume = effectiveOutputVolume
            rightPlayerNode.volume = effectiveOutputVolume
            return
        }

        fadePlayers(to: 0, duration: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard generation == self.stopGeneration else { return }
            self.binauralPlayerNode.stop()
            self.leftPlayerNode.stop()
            self.rightPlayerNode.stop()
            self.binauralPlayerNode.reset()
            self.leftPlayerNode.reset()
            self.rightPlayerNode.reset()
            self.isPlaying = false
            self.clearCurrentSound()
            self.setPlaybackVolumeScale(1.0)
            self.binauralPlayerNode.volume = self.effectiveOutputVolume
            self.leftPlayerNode.volume = self.effectiveOutputVolume
            self.rightPlayerNode.volume = self.effectiveOutputVolume
        }
    }

    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        binauralPlayerNode.volume = effectiveOutputVolume
        leftPlayerNode.volume = effectiveOutputVolume
        rightPlayerNode.volume = effectiveOutputVolume
        filePlayer?.volume = effectiveOutputVolume
        manifestationMantraPlayer?.volume = manifestationMantraVolume
    }

    func pause() {
        guard isPlaying || manifestationMantraPlayer?.isPlaying == true else { return }
        AppLog.info("ToneGenerator pause requested: \(currentSoundTitle ?? "unknown")")
        if let filePlayer {
            filePlayer.pause()
        } else {
            binauralPlayerNode.pause()
            leftPlayerNode.pause()
            rightPlayerNode.pause()
        }
        let wasWaitingToRepeat = isManifestationMantraWaitingToRepeat
        manifestationMantraRestartTask?.cancel()
        manifestationMantraRestartTask = nil
        if wasWaitingToRepeat {
            manifestationMantraPlayer?.currentTime = 0
        }
        manifestationMantraPlayer?.pause()
        isManifestationMantraPlaying = false
        isManifestationMantraWaitingToRepeat = false
        isPlaying = false
    }

    func resume() {
        guard hasCurrentSound || manifestationMantraPlayer != nil else { return }
        AppLog.info("ToneGenerator resume requested: \(currentSoundTitle ?? "unknown")")
        if let filePlayer {
            filePlayer.play()
        } else {
            binauralPlayerNode.play()
            leftPlayerNode.play()
            rightPlayerNode.play()
        }
        if let manifestationMantraPlayer, !manifestationMantraPlayer.isPlaying {
            manifestationMantraPlayer.volume = manifestationMantraVolume
            isManifestationMantraPlaying = manifestationMantraPlayer.play()
        }
        isPlaying = true
    }

    func maintainPlayback() {
        guard isPlaying || manifestationMantraPlayer != nil else { return }
        configureAudioSession()

        if let manifestationMantraPlayer,
           !manifestationMantraPlayer.isPlaying,
           !isManifestationMantraWaitingToRepeat {
            manifestationMantraPlayer.volume = manifestationMantraVolume
            isManifestationMantraPlaying = manifestationMantraPlayer.play()
            AppLog.info("ToneGenerator restored manifestation mantra across an app transition")
        }

        guard isPlaying, hasCurrentSound else { return }

        if let filePlayer {
            if !filePlayer.isPlaying {
                filePlayer.play()
                AppLog.info("ToneGenerator restored file playback across an app transition")
            }
            return
        }

        startEngine()
        switch currentSoundKind {
        case .binaural:
            if !binauralPlayerNode.isPlaying {
                binauralPlayerNode.play()
                AppLog.info("ToneGenerator restored binaural playback across an app transition")
            }
        case .pulsed, .chakra:
            if !leftPlayerNode.isPlaying {
                leftPlayerNode.play()
            }
            if !rightPlayerNode.isPlaying {
                rightPlayerNode.play()
            }
            AppLog.info("ToneGenerator verified generated playback across an app transition")
        case .none:
            break
        }
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
        configureEqualizerBands(on: eqNode)
        configureEqualizerBands(on: binauralEQNode)
    }

    private func configureEqualizerBands(on node: AVAudioUnitEQ) {
        guard node.bands.count >= 3 else { return }

        let lowBand = node.bands[0]
        lowBand.filterType = .lowShelf
        lowBand.frequency = 180
        lowBand.bandwidth = 0.8
        lowBand.bypass = false

        let midBand = node.bands[1]
        midBand.filterType = .parametric
        midBand.frequency = 1600
        midBand.bandwidth = 1.1
        midBand.bypass = false

        let highBand = node.bands[2]
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

        guard binauralEQNode.bands.count >= 3 else { return }
        binauralEQNode.bands[0].gain = eqLowGain
        binauralEQNode.bands[1].gain = eqMidGain
        binauralEQNode.bands[2].gain = eqHighGain
    }

    private func clampedGain(_ gain: Float) -> Float {
        min(max(gain, eqGainRange.lowerBound), eqGainRange.upperBound)
    }

    private func stopImmediately() {
        stopGeneration += 1
        stopFilePlayback()
        stopManifestationMantra()
        binauralPlayerNode.stop()
        leftPlayerNode.stop()
        rightPlayerNode.stop()
        binauralPlayerNode.reset()
        leftPlayerNode.reset()
        rightPlayerNode.reset()
        isPlaying = false
    }

    private var manifestationMantraVolume: Float {
        min(max(volume * 1.6, 0), 0.92)
    }

    private func stopManifestationMantra() {
        manifestationMantraGeneration += 1
        manifestationMantraRestartTask?.cancel()
        manifestationMantraRestartTask = nil
        manifestationMantraPlayer?.stop()
        manifestationMantraPlayer = nil
        isManifestationMantraPlaying = false
        isManifestationMantraWaitingToRepeat = false
    }

    private func setPlaybackVolumeScale(_ scale: Float) {
        playbackVolumeScale = min(max(scale, 0.0), 1.0)
    }

    private func setCurrentSound(title: String, subtitle: String, kind: SoundPlaybackKind) {
        currentSoundTitle = title
        currentSoundSubtitle = subtitle
        currentSoundKind = kind
    }

    private func clearCurrentSound() {
        currentSoundTitle = nil
        currentSoundSubtitle = nil
        currentSoundKind = nil
    }

    private func failPlaybackPreparation(_ context: String) {
        AppLog.error("ToneGenerator failed to prepare playback: \(context)")
        stopImmediately()
        clearCurrentSound()
        setPlaybackVolumeScale(1.0)
    }

    private func stopFilePlayback() {
        filePlayer?.stop()
        filePlayer = nil
    }

    private func bundledAudioFileURL(fileName: String) -> URL? {
        let subdirectories = [
            "ChakraSounds",
            "Audio/ChakraSounds",
            "ManifestationMantras",
            "Audio/ManifestationMantras"
        ]

        for subdirectory in subdirectories {
            if let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: subdirectory) {
                return url
            }
        }

        return Bundle.main.url(forResource: fileName, withExtension: nil)
    }

    private func setBinauralPanning() {
        leftMixNode.pan = -0.85
        rightMixNode.pan = 0.85
    }

    private func setCenteredPanning() {
        leftMixNode.pan = 0.0
        rightMixNode.pan = 0.0
    }
}

extension ToneGenerator: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === manifestationMantraPlayer else { return }

        let generation = manifestationMantraGeneration
        isManifestationMantraPlaying = false
        isManifestationMantraWaitingToRepeat = true

        let restartTask = DispatchWorkItem { [weak self, weak player] in
            guard let self,
                  let player,
                  generation == self.manifestationMantraGeneration,
                  player === self.manifestationMantraPlayer else {
                return
            }

            player.currentTime = 0
            player.volume = self.manifestationMantraVolume
            self.isManifestationMantraWaitingToRepeat = false
            self.isManifestationMantraPlaying = player.play()
            AppLog.info("ToneGenerator manifestation mantra repeated after quiet buffer")
        }

        manifestationMantraRestartTask?.cancel()
        manifestationMantraRestartTask = restartTask
        DispatchQueue.main.asyncAfter(deadline: .now() + manifestationMantraLoopGap, execute: restartTask)
        AppLog.info("ToneGenerator manifestation mantra entered quiet buffer: \(String(format: "%.1f", manifestationMantraLoopGap)) seconds")
    }
}
