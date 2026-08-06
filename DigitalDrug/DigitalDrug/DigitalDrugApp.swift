//
//  DigitalDrugApp.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI
import os

enum AppLog {
    private static let logger = Logger(subsystem: "com.hyperlabsAI.DigitalDrug", category: "ZenWave")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

@main
struct DigitalDrugApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audioManager = AudioManager()
    @StateObject private var colorSchemeManager = ColorSchemeManager()
    @StateObject private var toneGenerator = ToneGenerator()
    @StateObject private var guidedVoiceManager = GuidedVoiceManager()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var gamificationManager = GamificationManager()
    @StateObject private var notificationManager = RitualNotificationManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                MainTabView()
                    .environmentObject(audioManager)
                    .environmentObject(colorSchemeManager)
                    .environmentObject(toneGenerator)
                    .environmentObject(guidedVoiceManager)
                    .environmentObject(storeManager)
                    .environmentObject(gamificationManager)
                    .environmentObject(notificationManager)
                    .preferredColorScheme(colorSchemeManager.selectedScheme ?? .dark)
                    .onAppear {
                        AppLog.info("App launched into MainTabView")
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        AppLog.info("App scene changed to \(String(describing: newPhase))")
                        guard newPhase == .active || newPhase == .background else { return }
                        toneGenerator.maintainPlayback()
                        audioManager.maintainPlayback()
                    }
            } else {
                OnboardingView()
                    .background(AuroraBackground().ignoresSafeArea())
                    .environmentObject(storeManager)
                    .environmentObject(gamificationManager)
                    .environmentObject(notificationManager)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        AppLog.info("App launched into onboarding")
                    }
            }
        }
    }
}
