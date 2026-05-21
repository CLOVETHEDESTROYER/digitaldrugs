import SwiftUI

struct SettingsView: View {
    @AppStorage("enableSounds") private var enableSounds = true
    @AppStorage("guidedVoiceEnabled") private var guidedVoiceEnabled = true
    @AppStorage("guidedVoiceRate") private var guidedVoiceRate = 0.44
    @AppStorage("guidedVoiceVolume") private var guidedVoiceVolume = 0.85
    @AppStorage("guidedVoiceIdentifier") private var guidedVoiceIdentifier = GuidedVoiceManager.systemDefaultVoiceID
    @AppStorage("guidedVoiceProfile") private var guidedVoiceProfile = GuidedVoiceProfile.softGuide.rawValue
    @EnvironmentObject private var colorSchemeManager: ColorSchemeManager
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var voiceManager: GuidedVoiceManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedColorScheme = "system"
    @State private var paywallFeature: PaywallFeature?
    
    private var voiceOptions: [GuidedVoiceOption] {
        GuidedVoiceManager.availableVoiceOptions()
    }
    
    private var selectedVoiceDetail: String {
        voiceOptions.first { $0.id == guidedVoiceIdentifier }?.detail ?? "Falls back to the best English system voice."
    }
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    premiumSection
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
            AppLog.info("Settings appeared. enableSounds=\(enableSounds), guidedVoiceEnabled=\(guidedVoiceEnabled), rate=\(guidedVoiceRate), volume=\(guidedVoiceVolume), scheme=\(selectedColorScheme)")
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environmentObject(storeManager)
        }
    }
    
    private var premiumSection: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: storeManager.isPremiumUnlocked ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundStyle(storeManager.isPremiumUnlocked ? .green : ZenWavePalette.electricPurple)
                        .font(.title3)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(storeManager.accessLevel.title)
                            .font(.title3.weight(.semibold))
                        Text(storeManager.accessLevel.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if storeManager.accessLevel == .loading {
                    ProgressView("Checking App Store access...")
                        .tint(ZenWavePalette.electricPurple)
                } else {
                    HStack(spacing: 12) {
                        if storeManager.isPremiumUnlocked {
                            Button {
                                storeManager.openManageSubscriptions()
                            } label: {
                                Label("Manage", systemImage: "person.crop.circle.badge.checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                paywallFeature = .premiumRituals
                            } label: {
                                Label("Upgrade", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ZenWavePalette.electricPurple)
                        }
                        
                        Button {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        } label: {
                            Label(storeManager.isRestoring ? "Restoring" : "Restore", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(storeManager.isRestoring)
                    }
                }
                
                if let errorMessage = storeManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
                .onChange(of: enableSounds) { _, newValue in
                    AppLog.info("Settings Enable Sounds changed: \(newValue)")
                }
                
                Toggle(isOn: $guidedVoiceEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guided Voice")
                            .font(.headline)
                        Text("Speak timed prompts during Gateway and Quantum Code rituals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .onChange(of: guidedVoiceEnabled) { _, newValue in
                    AppLog.info("Settings Guided Voice changed: \(newValue)")
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice Style")
                        .font(.headline)
                    
                    ForEach(GuidedVoiceProfile.allCases) { profile in
                        Button {
                            guidedVoiceProfile = profile.rawValue
                            AppLog.info("Settings Guided Voice style changed: \(profile.title)")
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: profile.iconName)
                                    .frame(width: 24)
                                    .foregroundStyle(guidedVoiceProfile == profile.rawValue ? .white : ZenWavePalette.electricPurple)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(profile.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if guidedVoiceProfile == profile.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ZenWavePalette.electricPurple)
                                }
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(profile.rawValue == guidedVoiceProfile ? ZenWavePalette.electricPurple.opacity(0.22) : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(profile.rawValue == guidedVoiceProfile ? ZenWavePalette.electricPurple.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!guidedVoiceEnabled)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("System Voice")
                            .font(.headline)
                        Spacer()
                        Button {
                            AppLog.info("Settings Guided Voice preview tapped: voice=\(guidedVoiceIdentifier), profile=\(guidedVoiceProfile)")
                            voiceManager.previewSelectedVoice()
                        } label: {
                            Label(voiceManager.isSpeaking ? "Playing" : "Preview", systemImage: voiceManager.isSpeaking ? "speaker.wave.2.fill" : "play.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .disabled(!guidedVoiceEnabled)
                    }
                    
                    Picker("System Voice", selection: $guidedVoiceIdentifier) {
                        ForEach(voiceOptions) { option in
                            Text(option.name)
                                .tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!guidedVoiceEnabled)
                    .onChange(of: guidedVoiceIdentifier) { _, newValue in
                        AppLog.info("Settings Guided Voice system voice changed: \(newValue)")
                    }
                    
                    Text(selectedVoiceDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Voice Rate")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f", guidedVoiceRate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $guidedVoiceRate, in: 0.30...0.58, step: 0.01)
                        .tint(.purple)
                        .disabled(!guidedVoiceEnabled)
                        .onChange(of: guidedVoiceRate) { _, newValue in
                            AppLog.info("Settings Guided Voice rate changed: \(newValue)")
                        }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Voice Volume")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(guidedVoiceVolume * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $guidedVoiceVolume, in: 0...1, step: 0.01)
                        .tint(.purple)
                        .disabled(!guidedVoiceEnabled)
                        .onChange(of: guidedVoiceVolume) { _, newValue in
                            AppLog.info("Settings Guided Voice volume changed: \(newValue)")
                        }
                }
                
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
                        AppLog.info("Settings appearance changed: \(newValue)")
                        colorSchemeManager.setColorScheme(newValue)
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("ZenWave")
                    .font(.title3.weight(.semibold))
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .opacity(reduceTransparency ? 1 : 0.3)
                
                Text("""
ZenWave blends binaural beats, chakra tones, and nature textures into repeatable DigitalDrugz-style rituals for sleep, focus, visualization, meditation, and altered-state practice.
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
                .environmentObject(StoreManager())
                .environmentObject(GuidedVoiceManager())
        }
    }
}
//
//  SettingsView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//
