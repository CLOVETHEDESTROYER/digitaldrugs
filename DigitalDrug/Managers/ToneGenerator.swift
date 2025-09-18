//
//  ToneGenerator.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import AVFoundation
import Accelerate

class ToneGenerator: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var leftPlayerNode = AVAudioPlayerNode()
    private var rightPlayerNode = AVAudioPlayerNode()
    private var leftMixNode = AVAudioMixerNode()
    private var rightMixNode = AVAudioMixerNode()
    private var sumMixerNode = AVAudioMixerNode()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 2)
    private var reverbNode = AVAudioUnitReverb()
    
    @Published var isPlaying = false
    @Published var leftFrequency: Double = 440.0
    @Published var rightFrequency: Double = 450.0
    @Published var volume: Float = 0.5
    @Published var currentBinauralBeat: Double = 10.0
    
    private var audioFormat: AVAudioFormat!
    private var isEngineRunning = false
    
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

        // EQ configuration (gentle smoothing)
        if let lp = eqNode.bands.first {
            lp.filterType = .lowPass
            lp.frequency = 8000
            lp.bandwidth = 0.8
            lp.gain = 0
            lp.bypass = false
        }
        if eqNode.bands.count > 1 {
            let lowShelf = eqNode.bands[1]
            lowShelf.filterType = .lowShelf
            lowShelf.frequency = 150
            lowShelf.gain = 2.0
            lowShelf.bypass = false
        }

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
        guard !isEngineRunning else { return }
        
        do {
            try audioEngine.start()
            isEngineRunning = true
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }
    
    func generateBinauralBeat(leftFreq: Double, rightFreq: Double, duration: TimeInterval = 0) {
        guard audioFormat != nil else { return }
        
        leftFrequency = leftFreq
        rightFrequency = rightFreq
        currentBinauralBeat = abs(rightFreq - leftFreq)
        
        // Stop any existing playback
        stop()
        
        // Generate tones
        let leftBuffer = generateTone(frequency: leftFreq, duration: duration)
        let rightBuffer = generateTone(frequency: rightFreq, duration: duration)
        
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
        
        // Stop any existing playback
        stop()
        
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
        
        for i in 0..<Int(frameCount) {
            // Do not bake volume into samples so slider updates apply in real time
            samples[i] = Float(sin(phaseIncrement * Double(i)))
        }
        
        return buffer
    }
    
    func stop() {
        guard isPlaying else { return }
        fadePlayers(to: 0, duration: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.leftPlayerNode.stop()
            self.rightPlayerNode.stop()
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
}
