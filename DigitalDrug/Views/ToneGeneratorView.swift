//
//  ToneGeneratorView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct ToneGeneratorView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @State private var generatorMode: GeneratorMode = .binaural
    @State private var leftFrequency: Double = 440.0
    @State private var rightFrequency: Double = 450.0
    @State private var carrierFrequency: Double = 440.0
    @State private var pulseFrequency: Double = 10.0
    @State private var selectedPreset: FrequencyPreset? = nil
    @State private var showingFrequencyInfo = false
    
    var binauralBeatFrequency: Double {
        abs(rightFrequency - leftFrequency)
    }
    
    private var formattedBeat: String {
        String(format: "%.1f", generatorMode == .binaural ? binauralBeatFrequency : pulseFrequency)
    }
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    modePicker
                    frequencySummary
                    presetGrid
                    frequencyControls
                    equalizerControls
                    footer
                    
                    Button("Learn About Brainwave Frequencies") {
                        showingFrequencyInfo = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 12)
                }
                .padding(.top, 76)
                .padding(.bottom, 180)
                .padding(.horizontal, 24)
            }
            .sheet(isPresented: $showingFrequencyInfo) {
                FrequencyInfoView()
            }
        }
    }
    
    private func selectPreset(_ preset: FrequencyPreset, startPlayback: Bool = true) {
        selectedPreset = preset
        leftFrequency = preset.leftFrequency
        rightFrequency = preset.rightFrequency
        carrierFrequency = preset.leftFrequency
        pulseFrequency = preset.beatFrequency
        
        guard startPlayback else { return }
        
        switch generatorMode {
        case .binaural:
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: preset.leftFrequency,
                rightFreq: preset.rightFrequency,
                title: preset.rawValue,
                subtitle: "\(preset.binauralSummary) - \(String(format: "%.1f", preset.beatFrequency)) Hz binaural beat"
            )
        case .pulsed:
            toneGenerator.generatePulsedTone(
                carrierFreq: preset.leftFrequency,
                pulseFreq: preset.beatFrequency,
                title: preset.rawValue,
                subtitle: "\(Int(preset.leftFrequency)) Hz carrier - \(String(format: "%.1f", preset.beatFrequency)) Hz pulsed beat"
            )
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Binaural Beat Generator")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Use headphones for the best experience")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var modePicker: some View {
        Picker("Generator Mode", selection: $generatorMode) {
            ForEach(GeneratorMode.allCases, id: \.self) { mode in
                Label(mode.title, systemImage: mode.iconName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: generatorMode) { _, _ in
            if toneGenerator.isPlaying {
                startSelectedMode()
            }
        }
    }

    private var frequencySummary: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 18) {
                if generatorMode == .binaural {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Left Ear")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text("\(Int(leftFrequency)) Hz")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Right Ear")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("\(Int(rightFrequency)) Hz")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Carrier Tone")
                                .font(.headline)
                                .foregroundColor(.cyan)
                            Text("\(Int(carrierFrequency)) Hz")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Pulse Rate")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("\(formattedBeat) Hz")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                VStack(spacing: 6) {
                    Text(generatorMode == .binaural ? "Binaural Beat" : "Pulsed Beat")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Text("\(formattedBeat) Hz")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.purple.opacity(0.15))
                )
            }
        }
    }

    private var frequencyControls: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 24) {
                Text("Frequency Controls")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if generatorMode == .binaural {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Left Ear Frequency")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(leftFrequency)) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $leftFrequency, in: 20...2000, step: 1)
                            .tint(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Right Ear Frequency")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(rightFrequency)) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $rightFrequency, in: 20...2000, step: 1)
                            .tint(.red)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Carrier Frequency")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(carrierFrequency)) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $carrierFrequency, in: 80...1200, step: 1)
                            .tint(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pulse Rate")
                                .font(.headline)
                            Spacer()
                            Text("\(formattedBeat) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $pulseFrequency, in: 0.5...40, step: 0.5)
                            .tint(.orange)
                    }
                }
            }
        }
    }

    private var equalizerControls: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual Equalizer")
                    .font(.title3.weight(.semibold))
                
                Text("Reduce harshness by lowering Mid and High bands.")
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

    private var presetGrid: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 18) {
                Text("Brainwave Presets")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                    spacing: 14
                ) {
                    ForEach(FrequencyPreset.allCases, id: \.self) { preset in
                        PresetButton(
                            preset: preset,
                            mode: generatorMode,
                            isSelected: selectedPreset == preset,
                            isPlaying: selectedPreset == preset && toneGenerator.isPlaying
                        ) {
                            selectPreset(preset)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedPreset?.rawValue ?? (generatorMode == .binaural ? "Custom Binaural" : "Custom Pulsed"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(footerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(toneGenerator.volume) },
                        set: { toneGenerator.setVolume(Float($0)) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .tint(.green)
                .frame(width: 130)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
            }

            Button {
                if toneGenerator.isPlaying {
                    toneGenerator.stop()
                } else {
                    startSelectedMode()
                }
            } label: {
                Image(systemName: toneGenerator.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.14))
        )
    }
    
    private func startSelectedMode() {
        switch generatorMode {
        case .binaural:
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: leftFrequency,
                rightFreq: rightFrequency,
                title: selectedPreset?.rawValue ?? "Custom Binaural",
                subtitle: "\(Int(leftFrequency)) - \(Int(rightFrequency)) Hz - \(formattedBeat) Hz binaural beat"
            )
        case .pulsed:
            toneGenerator.generatePulsedTone(
                carrierFreq: carrierFrequency,
                pulseFreq: pulseFrequency,
                title: selectedPreset?.rawValue ?? "Custom Pulsed",
                subtitle: "\(Int(carrierFrequency)) Hz carrier - \(formattedBeat) Hz pulsed beat"
            )
        }
    }
    
    private var footerSubtitle: String {
        if let selectedPreset {
            switch generatorMode {
            case .binaural:
                return "\(selectedPreset.binauralSummary) - Beat \(String(format: "%.1f", selectedPreset.beatFrequency)) Hz"
            case .pulsed:
                return "\(Int(selectedPreset.leftFrequency)) Hz carrier - Pulse \(String(format: "%.1f", selectedPreset.beatFrequency)) Hz"
            }
        }
        
        switch generatorMode {
        case .binaural:
            return "\(Int(leftFrequency)) - \(Int(rightFrequency)) Hz - Beat \(formattedBeat) Hz"
        case .pulsed:
            return "\(Int(carrierFrequency)) Hz carrier - Pulse \(formattedBeat) Hz"
        }
    }
}

enum GeneratorMode: String, CaseIterable {
    case binaural
    case pulsed
    
    var title: String {
        switch self {
        case .binaural: return "Binaural"
        case .pulsed: return "Pulsed"
        }
    }
    
    var iconName: String {
        switch self {
        case .binaural: return "headphones"
        case .pulsed: return "waveform.path.ecg"
        }
    }
}

// MARK: - Frequency Presets
enum FrequencyPreset: String, CaseIterable {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    case gamma = "Gamma"
    
    var leftFrequency: Double {
        switch self {
        case .delta: return 100.0
        case .theta: return 200.0
        case .alpha: return 400.0
        case .beta: return 800.0
        case .gamma: return 1600.0
        }
    }
    
    var rightFrequency: Double {
        switch self {
        case .delta: return 104.0  // 4 Hz binaural beat
        case .theta: return 204.0  // 4 Hz binaural beat
        case .alpha: return 404.0  // 4 Hz binaural beat
        case .beta: return 808.0   // 8 Hz binaural beat
        case .gamma: return 1630.0 // 30 Hz binaural beat
        }
    }
    
    var beatFrequency: Double {
        abs(rightFrequency - leftFrequency)
    }
    
    var binauralSummary: String {
        "\(Int(leftFrequency)) - \(Int(rightFrequency)) Hz"
    }
    
    var frequencyRange: String {
        switch self {
        case .delta: return "0.5 - 4 Hz"
        case .theta: return "4 - 8 Hz"
        case .alpha: return "8 - 12 Hz"
        case .beta: return "12 - 30 Hz"
        case .gamma: return "30 - 100 Hz"
        }
    }
    
    var color: Color {
        switch self {
        case .delta: return .purple
        case .theta: return .blue
        case .alpha: return .green
        case .beta: return .orange
        case .gamma: return .red
        }
    }
    
    var benefits: [String] {
        switch self {
        case .delta:
            return [
                "Deep sleep and restoration",
                "Healing and pain relief",
                "Anti-aging benefits",
                "Access to unconscious mind"
            ]
        case .theta:
            return [
                "Deep meditation states",
                "Creativity and insights",
                "Reprogramming beliefs",
                "Lucid dreaming"
            ]
        case .alpha:
            return [
                "Relaxation and focus",
                "Stress reduction",
                "Accelerated learning",
                "Flow state access"
            ]
        case .beta:
            return [
                "Focused attention",
                "Analytical thinking",
                "Energy and action",
                "High-level cognition"
            ]
        case .gamma:
            return [
                "Peak concentration",
                "Brain synchronization",
                "Better memory",
                "Faster cognition"
            ]
        }
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let preset: FrequencyPreset
    let mode: GeneratorMode
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 24, showParticles: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(isSelected ? preset.color : .primary)
                            
                            Text(preset.frequencyRange)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isPlaying ? "waveform.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isSelected ? preset.color : .secondary)
                    }
                    
                    Text(mode == .binaural ? preset.binauralSummary : "\(Int(preset.leftFrequency)) Hz carrier")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(isPlaying ? "Playing \(String(format: "%.1f", preset.beatFrequency)) Hz" : "Tap to start \(String(format: "%.1f", preset.beatFrequency)) Hz")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? preset.color : .white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Frequency Information View
struct FrequencyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(FrequencyPreset.allCases, id: \.self) { preset in
                            FrequencyInfoCard(preset: preset)
                        }
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Brainwave Frequencies")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Frequency Info Card
struct FrequencyInfoCard: View {
    let preset: FrequencyPreset
    
    var body: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(preset.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(preset.color)
                    
                    Spacer()
                    
                    Text(preset.frequencyRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Benefits:")
                    .font(.headline)
                    .padding(.top, 4)
                
                ForEach(preset.benefits, id: \.self) { benefit in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(preset.color)
                            .font(.caption)
                        Text(benefit)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    ToneGeneratorView()
        .environmentObject(ToneGenerator())
}
