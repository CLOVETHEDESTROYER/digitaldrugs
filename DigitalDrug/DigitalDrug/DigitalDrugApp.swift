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
        print("ZENWAVE_LOG: \(message)")
    }
    
    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        print("ZENWAVE_ERROR: \(message)")
    }
}

@main
struct DigitalDrugApp: App {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var colorSchemeManager = ColorSchemeManager()
    @StateObject private var toneGenerator = ToneGenerator()
    @StateObject private var guidedVoiceManager = GuidedVoiceManager()
    @StateObject private var storeManager = StoreManager()
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
                    .preferredColorScheme(colorSchemeManager.selectedScheme ?? .dark)
                    .onAppear {
                        AppLog.info("App launched into MainTabView")
                    }
            } else {
                OnboardingView()
                    .background(AuroraBackground().ignoresSafeArea())
                    .environmentObject(storeManager)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        AppLog.info("App launched into onboarding")
                    }
            }
        }
    }
}
