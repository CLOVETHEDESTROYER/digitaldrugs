//
//  ToneGenerator.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import AVFoundation

class ToneGenerator: ObservableObject {
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
    
    private var audioFormat: AVAudioFormat!
    private let eqGainRange: ClosedRange<Float> = -12.0...12.0
    
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
        } catch {
            print("Audio session setup failed: \(error)")
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
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }
    
    func generateBinauralBeat(leftFreq: Double, rightFreq: Double, duration: TimeInterval = 10) {
        guard audioFormat != nil else { return }
        
        leftFrequency = leftFreq
        rightFrequency = rightFreq
        currentBinauralBeat = abs(rightFreq - leftFreq)
        
        // Stop any existing playback immediately before scheduling.
        stopImmediately()
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
    
    func generateContinuousBinauralBeat(leftFreq: Double, rightFreq: Double) {
        guard audioFormat != nil else { return }
        
        leftFrequency = leftFreq
        rightFrequency = rightFreq
        currentBinauralBeat = abs(rightFreq - leftFreq)
        
        // Stop any existing playback immediately before scheduling loops.
        stopImmediately()
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
        guard steps > 0 else { return }
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
    
    func stop() {
        guard isPlaying else { return }
        fadePlayers(to: 0, duration: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.leftPlayerNode.stop()
            self.rightPlayerNode.stop()
            self.leftPlayerNode.reset()
            self.rightPlayerNode.reset()
            self.isPlaying = false
            self.leftPlayerNode.volume = self.volume
            self.rightPlayerNode.volume = self.volume
        }
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        leftPlayerNode.volume = volume
        rightPlayerNode.volume = volume
    }
    
    func pause() {
        leftPlayerNode.pause()
        rightPlayerNode.pause()
        isPlaying = false
    }
    
    func resume() {
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
        leftPlayerNode.stop()
        rightPlayerNode.stop()
        leftPlayerNode.reset()
        rightPlayerNode.reset()
        isPlaying = false
    }
}
