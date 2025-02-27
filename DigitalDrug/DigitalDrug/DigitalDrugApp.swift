//
//  DigitalDrugApp.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

@main
struct DigitalDrugApp: App {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var colorSchemeManager = ColorSchemeManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                HomeView()
                    .environmentObject(audioManager)
                    .environmentObject(colorSchemeManager)
                    .preferredColorScheme(colorSchemeManager.selectedScheme)
            } else {
                OnboardingView()
            }
        }
    }
}
