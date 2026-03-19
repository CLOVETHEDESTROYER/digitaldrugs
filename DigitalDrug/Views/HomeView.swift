//
//  HomeView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

// MARK: - Binaural Session Model
struct BinauralSession: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let brainwaveType: BrainwaveType
    let icon: BrainwaveIcon
    let description: String
    let binauralFile: String?
    let natureFile: String?
    let frequencyRange: String
    let benefits: [String]
}

enum BrainwaveType: String {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    case gamma = "Gamma"
}

extension BinauralSession {
    static let allSessions: [BinauralSession] = [
        BinauralSession(
            title: "Deep Sleep",
            subtitle: "(Delta)",
            brainwaveType: .delta,
            icon: .delta,
            description: "Delta brain waves are the gateway into transcendence and deep states of relaxation, where they can help you with increasing deep sleep, healing and pain relief, anti-aging, and access to the unconscious mind.",
            binauralFile: "lucid_dream.mp3",
            natureFile: "Ocean.wav",
            frequencyRange: "0.5 - 4 Hz",
            benefits: [
                "Increasing deep sleep",
                "Healing and pain relief",
                "Anti-aging: cortisol reduction/DHEA increase",
                "Access to the unconscious mind"
            ]
        ),
        BinauralSession(
            title: "Focus & Flow",
            subtitle: "(Gamma)",
            brainwaveType: .gamma,
            icon: .gamma,
            description: "Gamma brain waves can help you achieve the highest concentration levels, spark new insights and improve your creative problem-solving skills.",
            binauralFile: nil,
            natureFile: nil,
            frequencyRange: "30 - 100 Hz",
            benefits: [
                "Peak concentration",
                "Brain synchronization",
                "Better memory",
                "Faster cognition"
            ]
        ),
        BinauralSession(
            title: "Relaxation",
            subtitle: "(Theta)",
            brainwaveType: .theta,
            icon: .theta,
            description: "Theta brain waves are the gateway into deep meditation states, flow states with full transient hypofrontality, and dream journeys.",
            binauralFile: "hangover_cure.mp3",
            natureFile: "Ocean.wav",
            frequencyRange: "4 - 8 Hz",
            benefits: [
                "Meditation and deep relaxation",
                "Reprogramming limiting beliefs",
                "Creativity and insights",
                "Lucid dreaming"
            ]
        ),
        BinauralSession(
            title: "Energy Boost",
            subtitle: "(Beta)",
            brainwaveType: .beta,
            icon: .beta,
            description: "Beta is a higher frequency brainwave associated with our normal waking state when we are actively engaged in thinking or a task.",
            binauralFile: nil,
            natureFile: nil,
            frequencyRange: "12 - 30 Hz",
            benefits: [
                "Keeping your attention focused",
                "Analytical thinking and solving problems",
                "Stimulating energy and action",
                "High-level cognition"
            ]
        )
    ]
}

// MARK: - Chakra Tone Model
struct ChakraTone: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let chakraName: String
    let frequency: Double
    let meaning: String
    let color: Color
    let bellTimbre: ToneGenerator.ChakraBellTimbre
}

extension ChakraTone {
    static let allChakras: [ChakraTone] = [
        ChakraTone(
            name: "Root Chakra",
            chakraName: "Muladhara",
            frequency: 396,
            meaning: "Grounding, safety, and clearing fear.",
            color: .red,
            bellTimbre: .init(
                ringDuration: 3.4,
                loopInterval: 4.8,
                brightness: 0.22,
                decayScale: 1.35,
                warmth: 0.88
            )
        ),
        ChakraTone(
            name: "Sacral Chakra",
            chakraName: "Swadhisthana",
            frequency: 417,
            meaning: "Creativity, emotional balance, and change.",
            color: .orange,
            bellTimbre: .init(
                ringDuration: 3.1,
                loopInterval: 4.4,
                brightness: 0.38,
                decayScale: 1.20,
                warmth: 0.72
            )
        ),
        ChakraTone(
            name: "Solar Plexus Chakra",
            chakraName: "Manipura",
            frequency: 528,
            meaning: "Personal power, confidence, and transformation.",
            color: .yellow,
            bellTimbre: .init(
                ringDuration: 2.8,
                loopInterval: 4.0,
                brightness: 0.62,
                decayScale: 1.05,
                warmth: 0.54
            )
        ),
        ChakraTone(
            name: "Heart Chakra",
            chakraName: "Anahata",
            frequency: 639,
            meaning: "Love, relationships, and compassion.",
            color: .green,
            bellTimbre: .init(
                ringDuration: 3.5,
                loopInterval: 5.0,
                brightness: 0.44,
                decayScale: 1.42,
                warmth: 0.66
            )
        ),
        ChakraTone(
            name: "Throat Chakra",
            chakraName: "Vishuddha",
            frequency: 741,
            meaning: "Communication, expression, and truth.",
            color: .blue,
            bellTimbre: .init(
                ringDuration: 2.6,
                loopInterval: 3.8,
                brightness: 0.72,
                decayScale: 0.95,
                warmth: 0.38
            )
        ),
        ChakraTone(
            name: "Third Eye Chakra",
            chakraName: "Ajna",
            frequency: 852,
            meaning: "Intuition, insight, and spiritual awakening.",
            color: .indigo,
            bellTimbre: .init(
                ringDuration: 3.0,
                loopInterval: 4.2,
                brightness: 0.84,
                decayScale: 1.18,
                warmth: 0.30
            )
        ),
        ChakraTone(
            name: "Crown Chakra",
            chakraName: "Sahasrara",
            frequency: 963,
            meaning: "Higher consciousness, enlightenment, and connection.",
            color: .purple,
            bellTimbre: .init(
                ringDuration: 3.6,
                loopInterval: 5.1,
                brightness: 0.94,
                decayScale: 1.46,
                warmth: 0.26
            )
        )
    ]
}

struct HomeView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSession: BinauralSession? = nil
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Binaural Beats")
                        .font(LiquidGlassTypography.headline)
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
                
                // Main Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // 2x2 Grid of Cards
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                            spacing: 16
                        ) {
                            ForEach(BinauralSession.allSessions) { session in
                                SessionCard(
                                    session: session,
                                    isSelected: selectedSession?.id == session.id
                                ) {
                                    selectSession(session)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Central Play Button
                        VStack(spacing: 12) {
                            ZStack {
                                // Radial glow behind play button
                                RadialGlowEffect(
                                    center: .center,
                                    radius: 150,
                                    opacity: 0.30
                                )
                                .frame(width: 240, height: 240)
                                
                                // Play button
                                Button {
                                    playSelectedSession()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                                            )
                                            .shadow(color: Color.cyan.opacity(0.20), radius: 30, y: 10)
                                        
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 40, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .scaleEffect(isPlaying && !reduceMotion ? 1.05 : 1.0)
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                                    value: isPlaying
                                )
                            }
                            
                            Text("Play")
                                .font(LiquidGlassTypography.playLabel)
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 20)
                        
                        Spacer().frame(height: 100) // Space for bottom nav
                    }
                    .padding(.top, 20)
                }
            }
        }
    }
    
    private func selectSession(_ session: BinauralSession) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            selectedSession = session
        }
    }
    
    private func playSelectedSession() {
        guard let session = selectedSession else { return }
        
        if isPlaying {
            // Stop current session
            audioManager.stopAll()
            toneGenerator.stop()
            withAnimation {
                isPlaying = false
            }
        } else {
            // Start session
            if let binauralFile = session.binauralFile {
                // Use audio file if available
                audioManager.playBinaural(fileName: binauralFile)
            } else {
                // Use tone generator for sessions without audio files
                let frequencies = getFrequenciesForBrainwave(session.brainwaveType)
                toneGenerator.generateContinuousBinauralBeat(
                    leftFreq: frequencies.left,
                    rightFreq: frequencies.right
                )
            }
            
            if let natureFile = session.natureFile {
                audioManager.playNature(fileName: natureFile)
            }
            
            withAnimation {
                isPlaying = true
            }
        }
    }
    
    private func getFrequenciesForBrainwave(_ type: BrainwaveType) -> (left: Double, right: Double) {
        switch type {
        case .beta:
            return (800.0, 808.0)  // 8 Hz binaural beat
        case .gamma:
            return (1600.0, 1630.0) // 30 Hz binaural beat
        case .delta:
            return (100.0, 104.0)
        case .theta:
            return (200.0, 204.0)
        case .alpha:
            return (400.0, 404.0)
        }
    }
}

// MARK: - Session Card
struct SessionCard: View {
    let session: BinauralSession
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        Image(systemName: session.icon.systemName)
                            .brainwaveIcon(size: 28)
                            .foregroundStyle(session.icon.color)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(LiquidGlassTypography.cardTitle)
                            .foregroundStyle(.white)
                        
                        Text(session.subtitle)
                            .font(LiquidGlassTypography.cardSubtitle)
                            .foregroundStyle(.white.opacity(0.80))
                    }
                }
                .frame(height: 140)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(
                    isSelected ? session.icon.color.opacity(0.6) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: isSelected
        )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(ToneGenerator())
            .environmentObject(AudioManager())
    }
}

struct ChakraView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    
    @State private var activeChakra: ChakraTone?
    @State private var isAmbientEnabled = true
    @State private var progressionStepDuration: Double = 45
    @State private var isProgressionRunning = false
    @State private var progressionIndex = 0
    @State private var progressionSecondsRemaining = 0
    @State private var progressionTask: Task<Void, Never>?
    
    private let ambientLayerFile = "Ocean.wav"
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerCard
                        progressionCard
                        ambientCard
                        chakraCards
                        equalizerCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Chakra Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                stopProgressionSession(stopAudio: true)
            }
        }
    }
    
    private var headerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Solfeggio Bell Frequencies")
                    .font(.title3.weight(.semibold))
                Text("Each chakra uses a unique bell timbre profile for a different emotional texture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var progressionCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Timed Progression Session")
                    .font(.title3.weight(.semibold))
                
                Text("Auto-advance through all 7 chakras.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("Per-Chakra Duration")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(progressionStepDuration)) sec")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $progressionStepDuration, in: 10...180, step: 5)
                    .tint(.mint)
                    .disabled(isProgressionRunning)
                
                if isProgressionRunning, let chakra = activeChakra {
                    Text(
                        "Step \(progressionIndex + 1)/7 - \(chakra.name) - \(progressionSecondsRemaining)s left"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Button {
                    if isProgressionRunning {
                        stopProgressionSession(stopAudio: true)
                    } else {
                        startProgressionSession()
                    }
                } label: {
                    Label(
                        isProgressionRunning ? "Stop Progression" : "Start Progression",
                        systemImage: isProgressionRunning ? "stop.fill" : "forward.end.alt.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isProgressionRunning ? .red : .mint)
            }
        }
    }
    
    private var ambientCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $isAmbientEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Background Ambient Layer")
                            .font(.headline)
                        Text("Blend ocean ambience underneath chakra bells.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .teal))
                .onChange(of: isAmbientEnabled) { _, _ in
                    updateAmbientPlayback()
                }
                
                HStack {
                    Text("Ambient Volume")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(audioManager.natureVolume * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(audioManager.natureVolume) },
                        set: { audioManager.setNatureVolume(Float($0)) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .tint(.teal)
            }
        }
    }
    
    private var chakraCards: some View {
        VStack(spacing: 14) {
            ForEach(ChakraTone.allChakras) { chakra in
                LiquidGlassCard(cornerRadius: 30, showParticles: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(chakra.name)
                                    .font(.headline)
                                    .foregroundStyle(chakra.color)
                                Text(chakra.chakraName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(chakra.frequency)) Hz")
                                .font(.headline.monospacedDigit())
                        }
                        
                        Text(chakra.meaning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Button {
                                toggleChakra(chakra)
                            } label: {
                                Label(
                                    activeChakra == chakra && !isProgressionRunning ? "Stop Bell" : "Play Bell",
                                    systemImage: activeChakra == chakra && !isProgressionRunning
                                        ? "stop.circle.fill"
                                        : "play.circle.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(chakra.color.opacity(0.9))
                            
                            if isProgressionRunning && activeChakra == chakra {
                                Text("LIVE")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(chakra.color.opacity(0.25)))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var equalizerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bell Equalizer")
                    .font(.title3.weight(.semibold))
                
                Text("Soften harsh overtones by reducing Mid and High.")
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
    
    private func toggleChakra(_ chakra: ChakraTone) {
        if isProgressionRunning {
            stopProgressionSession(stopAudio: false)
        }
        
        if activeChakra == chakra {
            stopPlayback()
            return
        }
        
        playChakra(chakra)
    }
    
    private func playChakra(_ chakra: ChakraTone) {
        audioManager.stopBinaural()
        toneGenerator.generateChakraBell(
            frequency: chakra.frequency,
            timbre: chakra.bellTimbre
        )
        activeChakra = chakra
        updateAmbientPlayback()
    }
    
    private func updateAmbientPlayback() {
        if isAmbientEnabled && (activeChakra != nil || isProgressionRunning) {
            audioManager.playNature(fileName: ambientLayerFile)
        } else {
            audioManager.stopNature()
        }
    }
    
    private func stopPlayback() {
        toneGenerator.stop()
        audioManager.stopNature()
        activeChakra = nil
    }
    
    private func startProgressionSession() {
        stopProgressionSession(stopAudio: false)
        
        isProgressionRunning = true
        progressionIndex = 0
        progressionSecondsRemaining = max(1, Int(progressionStepDuration))
        
        progressionTask = Task {
            let chakras = ChakraTone.allChakras
            
            for (index, chakra) in chakras.enumerated() {
                if Task.isCancelled { return }
                
                await MainActor.run {
                    progressionIndex = index
                    playChakra(chakra)
                }
                
                let totalSeconds = await MainActor.run { max(1, Int(progressionStepDuration)) }
                
                for remaining in stride(from: totalSeconds, through: 1, by: -1) {
                    if Task.isCancelled { return }
                    
                    await MainActor.run {
                        progressionSecondsRemaining = remaining
                    }
                    
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                stopProgressionSession(stopAudio: true)
            }
        }
    }
    
    private func stopProgressionSession(stopAudio: Bool) {
        progressionTask?.cancel()
        progressionTask = nil
        isProgressionRunning = false
        progressionIndex = 0
        progressionSecondsRemaining = 0
        
        if stopAudio {
            stopPlayback()
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab: Tab = .lotus
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .waves:
                        ToneGeneratorView()
                    case .chakra:
                        ChakraView()
                    case .volume:
                        SessionsListView()
                    case .lotus:
                        HomeView()
                    case .profile:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom navigation bar
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

// MARK: - Tab Navigation
enum Tab: String, CaseIterable {
    case waves = "Waves"
    case chakra = "Chakra"
    case volume = "Volume"
    case lotus = "Home"
    case profile = "Profile"
    
    var icon: NavigationIcon {
        switch self {
        case .waves: return .waves
        case .chakra: return .chakra
        case .volume: return .volume
        case .lotus: return .lotus
        case .profile: return .profile
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon.systemName)
                            .navigationIcon(size: 24)
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                            .scaleEffect(selectedTab == tab && !reduceMotion ? 1.1 : 1.0)
                        
                        if selectedTab == tab {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.20))
                .frame(height: 1)
                .offset(y: -0.5)
        )
    }
}

// MARK: - Sessions List View (for Volume tab)
struct SessionsListView: View {
    @EnvironmentObject private var audioManager: AudioManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(BinauralSession.allSessions) { session in
                            NavigationLink {
                                // Check if session has audio files
                                if let binauralFile = session.binauralFile,
                                   let natureFile = session.natureFile {
                                    // Use regular SessionView for sessions with audio files
                                    SessionView(
                                        binauralFile: binauralFile,
                                        natureFile: natureFile,
                                        sessionDescription: session.description
                                    )
                                    .navigationTitle(session.title)
                                    .navigationBarTitleDisplayMode(.inline)
                                } else {
                                    // Use ToneSessionView for sessions without audio files
                                    // Get frequencies based on brainwave type
                                    let frequencies = getFrequenciesForBrainwave(session.brainwaveType)
                                    ToneSessionView(
                                        session: session,
                                        leftFrequency: frequencies.left,
                                        rightFrequency: frequencies.right
                                    )
                                    .navigationTitle(session.title)
                                    .navigationBarTitleDisplayMode(.inline)
                                }
                            } label: {
                                SessionListCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Sessions")
        }
    }
    
    private func getFrequenciesForBrainwave(_ type: BrainwaveType) -> (left: Double, right: Double) {
        switch type {
        case .beta:
            return (800.0, 808.0)  // 8 Hz binaural beat
        case .gamma:
            return (1600.0, 1630.0) // 30 Hz binaural beat
        case .delta:
            return (100.0, 104.0)
        case .theta:
            return (200.0, 204.0)
        case .alpha:
            return (400.0, 404.0)
        }
    }
}

struct SessionListCard: View {
    let session: BinauralSession
    
    var body: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            HStack(spacing: 16) {
                Image(systemName: session.icon.systemName)
                    .brainwaveIcon(size: 32)
                    .foregroundStyle(session.icon.color)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title)
                        .font(LiquidGlassTypography.cardTitle)
                        .foregroundStyle(.white)
                    
                    Text(session.subtitle)
                        .font(LiquidGlassTypography.cardSubtitle)
                        .foregroundStyle(.white.opacity(0.80))
                    
                    Text(session.frequencyRange)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.60))
            }
        }
    }
}

// MARK: - Tone Session View (for sessions without audio files)
struct ToneSessionView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    let session: BinauralSession
    let leftFrequency: Double
    let rightFrequency: Double
    
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
                    
                    LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                        VStack(spacing: 18) {
                            ProgressView(value: progress, total: 100)
                                .tint(session.icon.color)
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
                    
                    if let natureFile = session.natureFile {
                        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                            Toggle(isOn: $isNatureEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Nature Layer")
                                        .font(.headline)
                                    Text("Blend in ambient textures alongside the binaural tone.")
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
            if isPlaying {
                toneGenerator.stop()
                audioManager.stopAll()
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
            audioManager.playNature(fileName: natureFile)
        }
        startProgressTimer()
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
