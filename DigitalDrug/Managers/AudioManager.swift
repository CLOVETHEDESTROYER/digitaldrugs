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
    
    private var cachedBuffers: [String: AVAudioPCMBuffer] = [:]
    private let eqGainRange: ClosedRange<Float> = -12.0...12.0
    
    @Published var eqLowGain: Float = 2.0
    @Published var eqMidGain: Float = -3.0
    @Published var eqHighGain: Float = -8.0
    @Published var binauralVolume: Float = 0.9
    @Published var natureVolume: Float = 0.55
    
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
        
        audioEngine.connect(binauralPlayerNode, to: binauralMixerNode, format: nil)
        audioEngine.connect(naturePlayerNode, to: natureMixerNode, format: nil)
        audioEngine.connect(binauralMixerNode, to: eqNode, format: nil)
        audioEngine.connect(natureMixerNode, to: eqNode, format: nil)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: nil)
        
        startEngine()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth]
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
        playLooping(fileName: fileName, on: binauralPlayerNode)
    }

    func playNature(fileName: String) {
        AppLog.info("AudioManager play nature file requested: \(fileName)")
        playLooping(fileName: fileName, on: naturePlayerNode)
    }

    func stopNature() {
        naturePlayerNode.stop()
        naturePlayerNode.reset()
    }

    func stopAll() {
        AppLog.info("AudioManager stop all requested")
        binauralPlayerNode.stop()
        binauralPlayerNode.reset()
        naturePlayerNode.stop()
        naturePlayerNode.reset()
    }
    
    func stopBinaural() {
        binauralPlayerNode.stop()
        binauralPlayerNode.reset()
    }
    
    func setBinauralVolume(_ newVolume: Float) {
        binauralVolume = min(max(newVolume, 0), 1)
        binauralMixerNode.volume = binauralVolume
    }
    
    func setNatureVolume(_ newVolume: Float) {
        natureVolume = min(max(newVolume, 0), 1)
        natureMixerNode.volume = natureVolume
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
    
    private func playLooping(fileName: String, on node: AVAudioPlayerNode) {
        startEngine()
        
        guard let buffer = loadBuffer(fileName: fileName) else {
            return
        }
        
        node.stop()
        node.reset()
        node.volume = 1.0
        node.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        node.play()
    }
    
    private func loadBuffer(fileName: String) -> AVAudioPCMBuffer? {
        if let buffer = cachedBuffers[fileName] {
            return buffer
        }
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
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
}
