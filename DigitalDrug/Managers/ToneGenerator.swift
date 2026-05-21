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

class ToneGenerator: ObservableObject {
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
    private let leftPlayerNode = AVAudioPlayerNode()
    private let rightPlayerNode = AVAudioPlayerNode()
    private let leftMixNode = AVAudioMixerNode()
    private let rightMixNode = AVAudioMixerNode()
    private let sumMixerNode = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private let reverbNode = AVAudioUnitReverb()
    
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
    
    private var audioFormat: AVAudioFormat!
    private let eqGainRange: ClosedRange<Float> = -12.0...12.0
    private var stopGeneration = 0
    
    var hasCurrentSound: Bool {
        currentSoundTitle != nil
    }
    
    init() {
        setupAudioEngine()
    }
    
    deinit {
        stop()
        audioEngine.stop()
    }
    
    private func setupAudioEngine() {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            AppLog.info("ToneGenerator audio session configured")
        } catch {
            AppLog.error("ToneGenerator audio session setup failed: \(error.localizedDescription)")
        }
        
        // Create audio format
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)
        
        // Attach nodes
        audioEngine.attach(leftPlayerNode)
        audioEngine.attach(rightPlayerNode)
        audioEngine.attach(leftMixNode)
        audioEngine.attach(rightMixNode)
        audioEngine.attach(sumMixerNode)
        audioEngine.attach(eqNode)
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

        // Connect graph: players -> per-channel mixers -> sum -> EQ -> Reverb -> main
        audioEngine.connect(leftPlayerNode, to: leftMixNode, format: audioFormat)
        audioEngine.connect(rightPlayerNode, to: rightMixNode, format: audioFormat)
        audioEngine.connect(leftMixNode, to: sumMixerNode, format: audioFormat)
        audioEngine.connect(rightMixNode, to: sumMixerNode, format: audioFormat)
        audioEngine.connect(sumMixerNode, to: eqNode, format: audioFormat)
        audioEngine.connect(eqNode, to: reverbNode, format: audioFormat)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        // Set initial volumes
        // Keep mixer at unity and control volume on player nodes for real-time changes
        leftPlayerNode.volume = volume
        rightPlayerNode.volume = volume
        
        startEngine()
    }
    
    private func startEngine() {
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
        guard audioFormat != nil else { return }
        AppLog.info("Generate fixed binaural beat requested: left=\(leftFreq), right=\(rightFreq), duration=\(duration), title=\(title ?? "nil")")
        
        setBinauralPanning()
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
        
        // Generate tones
        let renderDuration = duration > 0 ? duration : 10
        let leftBuffer = generateTone(frequency: leftFreq, duration: renderDuration)
        let rightBuffer = generateTone(frequency: rightFreq, duration: renderDuration)
        
        // Schedule playback
        leftPlayerNode.scheduleBuffer(leftBuffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        })
        
        rightPlayerNode.scheduleBuffer(rightBuffer, at: nil, options: [], completionHandler: nil)
        
        // Start playback
        leftPlayerNode.play()
        rightPlayerNode.play()
        isPlaying = true
    }
    
    func generateContinuousBinauralBeat(
        leftFreq: Double,
        rightFreq: Double,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        guard audioFormat != nil else { return }
        AppLog.info("Generate continuous binaural beat requested: left=\(leftFreq), right=\(rightFreq), title=\(title ?? "nil")")
        
        setBinauralPanning()
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
        
        // Generate continuous tones (10 seconds each, looped)
        let leftBuffer = generateTone(frequency: leftFreq, duration: 10.0)
        let rightBuffer = generateTone(frequency: rightFreq, duration: 10.0)
        
        // Schedule continuous playback
        scheduleContinuousPlayback(leftBuffer: leftBuffer, rightBuffer: rightBuffer)

        // Start silent then fade in for smoothness
        leftPlayerNode.volume = 0
        rightPlayerNode.volume = 0
        isPlaying = true
        fadePlayers(to: volume, duration: 0.6)
    }
    
    func generatePulsedTone(
        carrierFreq: Double,
        pulseFreq: Double,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        guard audioFormat != nil else { return }
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
        
        let pulsedBuffer = generatePulsedToneBuffer(
            carrierFreq: carrierFreq,
            pulseFreq: pulseFreq,
            duration: 10.0
        )
        
        leftPlayerNode.scheduleBuffer(pulsedBuffer, at: nil, options: .loops, completionHandler: nil)
        rightPlayerNode.scheduleBuffer(pulsedBuffer, at: nil, options: .loops, completionHandler: nil)
        
        leftPlayerNode.volume = 0
        rightPlayerNode.volume = 0
        leftPlayerNode.play()
        rightPlayerNode.play()
        isPlaying = true
        fadePlayers(to: volume, duration: 0.35)
    }
    
    func generateChakraBell(
        frequency: Double,
        timbre: ChakraBellTimbre = .balanced,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        guard audioFormat != nil else { return }
        AppLog.info("Generate chakra bell requested: frequency=\(frequency), title=\(title ?? "nil")")
        
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
        let bellLoop = generateChakraToneLoop(
            frequency: frequency,
            ringDuration: safeRingDuration,
            loopInterval: safeLoopInterval,
            timbre: timbre
        )
        
        leftPlayerNode.scheduleBuffer(bellLoop, at: nil, options: .loops, completionHandler: nil)
        rightPlayerNode.scheduleBuffer(bellLoop, at: nil, options: .loops, completionHandler: nil)
        
        leftPlayerNode.volume = 0
        rightPlayerNode.volume = 0
        leftPlayerNode.play()
        rightPlayerNode.play()
        isPlaying = true
        fadePlayers(to: volume, duration: 0.22)
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
        let startL = leftPlayerNode.volume
        let startR = rightPlayerNode.volume
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            let valL = startL + (target - startL) * t
            let valR = startR + (target - startR) * t
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) {
                self.leftPlayerNode.volume = valL
                self.rightPlayerNode.volume = valR
            }
        }
    }
    
    private func generateTone(frequency: Double, duration: TimeInterval) -> AVAudioPCMBuffer {
        let sampleRate = audioFormat.sampleRate
        let frameCount = UInt32(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            fatalError("Could not create buffer")
        }
        
        buffer.frameLength = frameCount
        
        let samples = buffer.floatChannelData![0]
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
    
    private func generatePulsedToneBuffer(
        carrierFreq: Double,
        pulseFreq: Double,
        duration: TimeInterval
    ) -> AVAudioPCMBuffer {
        let sampleRate = audioFormat.sampleRate
        let frameCount = UInt32(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            fatalError("Could not create pulsed tone buffer")
        }
        
        buffer.frameLength = frameCount
        
        let samples = buffer.floatChannelData![0]
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
    ) -> AVAudioPCMBuffer {
        let sampleRate = audioFormat.sampleRate
        let frameCount = UInt32(sampleRate * loopInterval)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            fatalError("Could not create bell loop buffer")
        }
        
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
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
        guard isPlaying || hasCurrentSound else { return }
        AppLog.info("ToneGenerator stop requested. isPlaying=\(isPlaying), current=\(currentSoundTitle ?? "nil")")
        stopGeneration += 1
        let generation = stopGeneration
        
        guard isPlaying else {
            leftPlayerNode.stop()
            rightPlayerNode.stop()
            leftPlayerNode.reset()
            rightPlayerNode.reset()
            clearCurrentSound()
            return
        }
        
        fadePlayers(to: 0, duration: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard generation == self.stopGeneration else { return }
            self.leftPlayerNode.stop()
            self.rightPlayerNode.stop()
            self.leftPlayerNode.reset()
            self.rightPlayerNode.reset()
            self.isPlaying = false
            self.clearCurrentSound()
            self.leftPlayerNode.volume = self.volume
            self.rightPlayerNode.volume = self.volume
        }
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        leftPlayerNode.volume = volume
        rightPlayerNode.volume = volume
        AppLog.info("ToneGenerator volume set: \(volume)")
    }
    
    func pause() {
        guard isPlaying else { return }
        AppLog.info("ToneGenerator pause requested: \(currentSoundTitle ?? "unknown")")
        leftPlayerNode.pause()
        rightPlayerNode.pause()
        isPlaying = false
    }
    
    func resume() {
        guard hasCurrentSound else { return }
        AppLog.info("ToneGenerator resume requested: \(currentSoundTitle ?? "unknown")")
        leftPlayerNode.play()
        rightPlayerNode.play()
        isPlaying = true
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
    
    private func stopImmediately() {
        stopGeneration += 1
        leftPlayerNode.stop()
        rightPlayerNode.stop()
        leftPlayerNode.reset()
        rightPlayerNode.reset()
        isPlaying = false
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
    
    private func setBinauralPanning() {
        leftMixNode.pan = -0.85
        rightMixNode.pan = 0.85
    }
    
    private func setCenteredPanning() {
        leftMixNode.pan = 0.0
        rightMixNode.pan = 0.0
    }
}
