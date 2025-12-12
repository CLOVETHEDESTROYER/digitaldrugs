//
//  MainTabView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

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

