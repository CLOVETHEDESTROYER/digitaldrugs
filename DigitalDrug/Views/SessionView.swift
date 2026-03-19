//
//  SessionView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct SessionView: View {
    @EnvironmentObject private var audioManager: AudioManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    let binauralFile: String
    let natureFile: String
    let sessionDescription: String
    
    @State private var isNatureEnabled = false
    @State private var progress: Double = 0.0
    @State private var isPlaying = false
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Now Exploring")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if isPlaying {
                                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.green)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.green.opacity(reduceTransparency ? 0.20 : 0.35))
                                        )
                                }
                            }
                            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: isPlaying)
                            
                            Text(sessionDescription)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    LiquidGlassCard {
                        VStack(spacing: 18) {
                            ProgressView(value: progress, total: 100)
                                .tint(.purple)
                                .scaleEffect(x: 1.0, y: 1.4, anchor: .center)
                            
                            HStack {
                                Text("Progress")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(progress))%")
                                    .font(.headline)
                                    .monospacedDigit()
                            }
                        }
                    }
                    
                    LiquidGlassCard {
                        Toggle(isOn: $isNatureEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nature Layer")
                                    .font(.headline)
                                Text("Blend in ambient textures (Ocean) alongside the binaural carrier tone.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onChange(of: isNatureEnabled) { _, newValue in
                            if newValue {
                                audioManager.playNature(fileName: natureFile)
                            } else {
                                audioManager.stopNature()
                            }
                        }
                    }
                    
                    equalizerCard
                    controlCluster
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private var equalizerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual Equalizer")
                    .font(.title3.weight(.semibold))
                
                Text("Applies to both binaural tracks and nature layers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                EqualizerBarsView(
                    lowGain: audioManager.eqLowGain,
                    midGain: audioManager.eqMidGain,
                    highGain: audioManager.eqHighGain
                )
                
                equalizerSliderRow(
                    title: "Low",
                    color: .blue,
                    value: Binding(
                        get: { Double(audioManager.eqLowGain) },
                        set: { audioManager.setEqualizer(low: Float($0)) }
                    )
                )
                
                equalizerSliderRow(
                    title: "Mid",
                    color: .cyan,
                    value: Binding(
                        get: { Double(audioManager.eqMidGain) },
                        set: { audioManager.setEqualizer(mid: Float($0)) }
                    )
                )
                
                equalizerSliderRow(
                    title: "High",
                    color: .orange,
                    value: Binding(
                        get: { Double(audioManager.eqHighGain) },
                        set: { audioManager.setEqualizer(high: Float($0)) }
                    )
                )
                
                HStack(spacing: 12) {
                    Button("Softer Mix") {
                        audioManager.applySofterEQPreset()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Flat") {
                        audioManager.resetEqualizer()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private func equalizerSliderRow(title: String, color: Color, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(title) Band")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f dB", value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: value, in: -12...12, step: 0.5)
                .tint(color)
        }
    }
    
    private var controlCluster: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    Button {
                        if isPlaying {
                            pauseSession()
                        } else {
                            startSession()
                        }
                    } label: {
                        Label(isPlaying ? "Pause" : "Start", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButtonStyle()
                    
                    Button {
                        stopSession()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .buttonBorderShape(.capsule)
                
                Button(role: .cancel) {
                    resetSession()
                } label: {
                    Text("Reset Progress")
                        .underline()
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Session Controls
    private func startSession() {
        isPlaying = true
        audioManager.playBinaural(fileName: binauralFile)
        if isNatureEnabled {
            audioManager.playNature(fileName: natureFile)
        }
        startProgressTimer()
    }
    
    private func pauseSession() {
        isPlaying = false
        timer?.invalidate()
        audioManager.stopAll()
    }
    
    private func stopSession() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        progress = 0.0
        audioManager.stopAll()
    }
    
    private func resetSession() {
        stopSession()
        isNatureEnabled = false
    }
    
    // MARK: - Progress Timer
    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if progress < 100 {
                progress += 1
            } else {
                timer?.invalidate()
                timer = nil
                isPlaying = false
                audioManager.stopAll()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SessionView(
                binauralFile: "lucid_dream.mp3",
                natureFile: "Ocean.wav",
                sessionDescription: "Experience deep, restorative sleep with our Delta wave sound."
            )
            .environmentObject(AudioManager())
        }
    }
}
