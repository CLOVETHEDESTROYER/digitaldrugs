//
//  ToneSessionView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct ToneSessionView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dismiss) private var dismiss

    let session: BinauralSession
    let leftFrequency: Double
    let rightFrequency: Double

    @State private var isNatureEnabled = false
    @State private var progress: Double = 0.0
    @State private var isPlaying = false
    @State private var timer: Timer?
    @State private var hasPreparedAmbientVolume = false
    @State private var isSoundMixExpanded = false

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

                            Text(session.description)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Frequency")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(leftFrequency)) - \(Int(rightFrequency)) Hz")
                                        .font(.headline)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Beat Frequency")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(String(format: "%.1f", abs(rightFrequency - leftFrequency))) Hz")
                                        .font(.headline)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }

                    controlCluster

                    if isPlaying {
                        progressCard
                    }

                    soundMixDisclosure
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    stopSession()
                    dismiss()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            if isPlaying {
                toneGenerator.stop()
                audioManager.stopAll()
            }
        }
    }

    private var progressCard: some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: false) {
            VStack(spacing: 14) {
                ProgressView(value: progress, total: 100)
                    .tint(session.icon.color)
                    .scaleEffect(x: 1.0, y: 1.3, anchor: .center)

                HStack {
                    Text("Session Progress")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(progress))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var soundMixDisclosure: some View {
        DisclosureGroup(isExpanded: $isSoundMixExpanded) {
            VStack(spacing: 18) {
                if let natureFile = session.natureFile {
                    natureLayerCard(natureFile: natureFile)
                }
                equalizerCard
            }
            .padding(.top, 12)
        } label: {
            Label("Sound mix", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(session.icon.color)
        .padding(.horizontal, 4)
    }

    private func natureLayerCard(natureFile: String) -> some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: false) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $isNatureEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                    Text("Nature Layer")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: isNatureEnabled) { _, newValue in
                    if newValue {
                        prepareAudibleAmbientVolumeIfNeeded()
                        audioManager.playNature(fileName: natureFile)
                    } else {
                        audioManager.stopNature()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Nature Volume", systemImage: "speaker.wave.2.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(audioManager.natureVolume * 100))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(audioManager.natureVolume) },
                            set: { audioManager.setNatureVolume(Float($0)) }
                        ),
                        in: 0...0.6
                    )
                    .tint(.blue)
                }
                .opacity(isNatureEnabled ? 1 : 0.55)
                .disabled(!isNatureEnabled)
            }
        }
    }

    private var equalizerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual Equalizer")
                    .font(.title3.weight(.semibold))

                Text("Tune the tone generator to smooth harsher frequencies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                EqualizerBarsView(
                    lowGain: toneGenerator.eqLowGain,
                    midGain: toneGenerator.eqMidGain,
                    highGain: toneGenerator.eqHighGain
                )

                equalizerSliderRow(
                    title: "Low",
                    color: .blue,
                    value: Binding(
                        get: { Double(toneGenerator.eqLowGain) },
                        set: { toneGenerator.setEqualizer(low: Float($0)) }
                    )
                )

                equalizerSliderRow(
                    title: "Mid",
                    color: .cyan,
                    value: Binding(
                        get: { Double(toneGenerator.eqMidGain) },
                        set: { toneGenerator.setEqualizer(mid: Float($0)) }
                    )
                )

                equalizerSliderRow(
                    title: "High",
                    color: .orange,
                    value: Binding(
                        get: { Double(toneGenerator.eqHighGain) },
                        set: { toneGenerator.setEqualizer(high: Float($0)) }
                    )
                )

                HStack(spacing: 12) {
                    Button("Softer Mix") {
                        toneGenerator.applySofterEQPreset()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Flat") {
                        toneGenerator.resetEqualizer()
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
        toneGenerator.generateContinuousBinauralBeat(
            leftFreq: leftFrequency,
            rightFreq: rightFrequency
        )
        if isNatureEnabled, let natureFile = session.natureFile {
            prepareAudibleAmbientVolumeIfNeeded()
            audioManager.playNature(fileName: natureFile)
        }
        startProgressTimer()
    }

    private func prepareAudibleAmbientVolumeIfNeeded() {
        guard !hasPreparedAmbientVolume else { return }
        hasPreparedAmbientVolume = true

        if audioManager.natureVolume < 0.15 {
            audioManager.setNatureVolume(0.18)
        }
    }

    private func pauseSession() {
        isPlaying = false
        timer?.invalidate()
        toneGenerator.stop()
        audioManager.stopAll()
    }

    private func stopSession() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        progress = 0.0
        toneGenerator.stop()
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
                toneGenerator.stop()
                audioManager.stopAll()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}
