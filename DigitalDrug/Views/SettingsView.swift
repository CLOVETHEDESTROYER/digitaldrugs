import SwiftUI

struct SettingsView: View {
    @AppStorage("enableSounds") private var enableSounds = true
    @EnvironmentObject private var colorSchemeManager: ColorSchemeManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedColorScheme = "system"
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    preferencesSection
                    aboutSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .onAppear {
            selectedColorScheme = colorSchemeManager.selectedScheme == .light ? "light" :
                                  colorSchemeManager.selectedScheme == .dark ? "dark" : "system"
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var preferencesSection: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Preferences")
                    .font(.title3.weight(.semibold))
                
                Toggle(isOn: $enableSounds.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Sounds")
                            .font(.headline)
                        Text("Mute ambient layers and UI feedback when disabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Appearance")
                        .font(.headline)
                    Picker("Appearance", selection: $selectedColorScheme) {
                        Text("System Default")
                            .tag("system")
                        Text("Light Mode")
                            .tag("light")
                        Text("Dark Mode")
                            .tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedColorScheme) { _, newValue in
                        colorSchemeManager.setColorScheme(newValue)
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("DigitalDrug")
                    .font(.title3.weight(.semibold))
                Text("Version 1.0")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .opacity(reduceTransparency ? 1 : 0.3)
                
                Text("""
DigitalDrug blends binaural beats with nature textures using Liquid Glass surfaces so your focus stays on the journey. Future updates will add adaptive scenes, wellness insights, and AI-guided sessions.
""")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(ColorSchemeManager())
        }
    }
}
//
//  SettingsView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

