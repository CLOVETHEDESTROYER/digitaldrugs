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
    case volume = "Volume"
    case lotus = "Home"
    case profile = "Profile"
    
    var icon: NavigationIcon {
        switch self {
        case .waves: return .waves
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
