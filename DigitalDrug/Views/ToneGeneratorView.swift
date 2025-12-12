//
//  ToneGeneratorView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct ToneGeneratorView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @State private var leftFrequency: Double = 440.0
    @State private var rightFrequency: Double = 450.0
    @State private var selectedPreset: FrequencyPreset? = nil
    @State private var showingFrequencyInfo = false
    
    var binauralBeatFrequency: Double {
        abs(rightFrequency - leftFrequency)
    }
    
    private var formattedBeat: String {
        String(format: "%.1f", binauralBeatFrequency)
    }
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    frequencySummary
                    frequencyControls
                    presetGrid
                    
                    Spacer().frame(height: 140)
                    
                    Button("Learn About Brainwave Frequencies") {
                        showingFrequencyInfo = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 12)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
            }
            .sheet(isPresented: $showingFrequencyInfo) {
                FrequencyInfoView()
            }
            .safeAreaInset(edge: .bottom) {
                footer
            }
        }
    }
    
    private func selectPreset(_ preset: FrequencyPreset) {
        selectedPreset = preset
        leftFrequency = preset.leftFrequency
        rightFrequency = preset.rightFrequency
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

    private var frequencySummary: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 18) {
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
                
                VStack(spacing: 6) {
                    Text("Binaural Beat")
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
            }
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
                            isSelected: selectedPreset == preset
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
                Text("Custom Binaural")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(Int(leftFrequency)) • \(Int(rightFrequency)) Hz  •  Beat \(formattedBeat) Hz")
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
                    toneGenerator.generateContinuousBinauralBeat(
                        leftFreq: leftFrequency,
                        rightFreq: rightFrequency
                    )
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
        .background(.ultraThinMaterial)
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
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 24, showParticles: true) {
                VStack(spacing: 8) {
                    Text(preset.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? preset.color : .primary)
                    
                    Text(preset.frequencyRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(preset.leftFrequency)) – \(Int(preset.rightFrequency)) Hz")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
