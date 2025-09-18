//
//  ToneGeneratorView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct ToneGeneratorView: View {
    @StateObject private var toneGenerator = ToneGenerator()
    @State private var leftFrequency: Double = 440.0
    @State private var rightFrequency: Double = 450.0
    @State private var selectedPreset: FrequencyPreset? = nil
    @State private var showingFrequencyInfo = false
    @State private var selectedFrequencyInfo: FrequencyPreset? = nil
    
    var binauralBeatFrequency: Double {
        abs(rightFrequency - leftFrequency)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Binaural Beat Generator")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Use headphones for the best experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Current Frequencies Display
                    VStack(spacing: 15) {
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
                        
                        // Binaural Beat Display
                        VStack(spacing: 5) {
                            Text("Binaural Beat")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("\(String(format: "%.1f", binauralBeatFrequency)) Hz")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Frequency Controls
                    VStack(spacing: 20) {
                        Text("Frequency Controls")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        // Left Frequency Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Left Ear Frequency")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(leftFrequency)) Hz")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $leftFrequency, in: 20...2000, step: 1)
                                .accentColor(.blue)
                        }
                        
                        // Right Frequency Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Right Ear Frequency")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(rightFrequency)) Hz")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $rightFrequency, in: 20...2000, step: 1)
                                .accentColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Frequency Presets
                    VStack(spacing: 15) {
                        Text("Brainwave Presets")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Spacer padding so content isn't obscured by sticky footer
                    Color.clear.frame(height: 140)
                    
                    // Frequency Information Button
                    Button("Learn About Brainwave Frequencies") {
                        showingFrequencyInfo = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Tone Generator")
            .sheet(isPresented: $showingFrequencyInfo) {
                FrequencyInfoView()
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    // Left: Session info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Binaural")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(Int(leftFrequency)) • \(Int(rightFrequency)) Hz  •  Beat \(String(format: "%.1f", binauralBeatFrequency)) Hz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Volume (compact)
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.1.fill").foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { Double(toneGenerator.volume) },
                            set: { toneGenerator.setVolume(Float($0)) }
                        ), in: 0...1, step: 0.01)
                        .tint(.green)
                        .frame(width: 130)
                        Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary)
                    }

                    // Play/Pause button
                    Button(action: {
                        if toneGenerator.isPlaying {
                            toneGenerator.stop()
                        } else {
                            toneGenerator.generateContinuousBinauralBeat(
                                leftFreq: leftFrequency,
                                rightFreq: rightFrequency
                            )
                        }
                    }) {
                        Image(systemName: toneGenerator.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private func selectPreset(_ preset: FrequencyPreset) {
        selectedPreset = preset
        leftFrequency = preset.leftFrequency
        rightFrequency = preset.rightFrequency
    }
    
    private func resetFrequencies() {
        leftFrequency = 440.0
        rightFrequency = 450.0
        selectedPreset = nil
        toneGenerator.stop()
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
            VStack(spacing: 8) {
                Text(preset.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(preset.frequencyRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(preset.leftFrequency))-\(Int(preset.rightFrequency)) Hz")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? preset.color.opacity(0.2) : Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? preset.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .foregroundColor(isSelected ? preset.color : .primary)
    }
}

// MARK: - Frequency Information View
struct FrequencyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(FrequencyPreset.allCases, id: \.self) { preset in
                        FrequencyInfoCard(preset: preset)
                    }
                }
                .padding()
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(preset.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(preset.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ToneGeneratorView()
}
