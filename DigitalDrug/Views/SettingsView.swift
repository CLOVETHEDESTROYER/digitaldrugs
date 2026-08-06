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
    @EnvironmentObject private var gamificationManager: GamificationManager
    @EnvironmentObject private var notificationManager: RitualNotificationManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedColorScheme = "system"
    @State private var paywallFeature: PaywallFeature?
    @State private var reminderTime = Date()
    @State private var isRequestingNotifications = false
    @State private var showResetProgressConfirmation = false
    @State private var isReminderOptionsExpanded = false
    @State private var isAdvancedOptionsExpanded = false

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
                VStack(spacing: 20) {
                    settingsHeader
                    premiumSection
                    remindersSection
                    preferencesSection
                    aboutSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 76)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            selectedColorScheme = colorSchemeManager.selectedScheme == .light ? "light" :
                                  colorSchemeManager.selectedScheme == .dark ? "dark" : "system"
            reminderTime = notificationManager.selectedReminderDate
            AppLog.info("Settings appeared. enableSounds=\(enableSounds), guidedVoiceEnabled=\(guidedVoiceEnabled), rate=\(guidedVoiceRate), volume=\(guidedVoiceVolume), scheme=\(selectedColorScheme)")
            Task { @MainActor in
                await notificationManager.refreshAuthorizationStatus()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environmentObject(storeManager)
        }
        .alert("Reset Astral Path Progress?", isPresented: $showResetProgressConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                gamificationManager.resetProgress()
            }
        } message: {
            Text("This clears local ranks, badges, streaks, and challenge progress on this device.")
        }
    }

    private var settingsHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ZENWAVE")
                    .font(.caption.weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(ZenWavePalette.electricPurple)

                Text("Settings")
                    .font(.system(size: 35, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Text("Shape your sound, reminders, and access.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ZenWavePalette.electricPurple)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.black.opacity(0.34)))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.42), ZenWavePalette.electricPurple.opacity(0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
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
#if DEBUG
                    Toggle(
                        isOn: Binding(
                            get: { storeManager.isDevelopmentPremiumOverrideEnabled },
                            set: { storeManager.setDevelopmentPremiumOverrideEnabled($0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Development Unlock")
                                .font(.headline)
                            Text("DEBUG-only override for local testing. Hidden from TestFlight and App Store builds.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: ZenWavePalette.electricPurple))
#endif

                    HStack(spacing: 12) {
                        if storeManager.isPremiumUnlocked {
                            Button {
                                storeManager.openManageSubscriptions()
                            } label: {
                                Label("Manage", systemImage: "person.crop.circle.badge.checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white.opacity(0.9))
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
                            Task { @MainActor in
                                await storeManager.restorePurchases()
                            }
                        } label: {
                            Label(storeManager.isRestoring ? "Restoring" : "Restore", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.9))
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

    private var remindersSection: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ritual Reminders")
                            .font(.title3.weight(.semibold))
                        Text("Status: \(notificationManager.statusLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: notificationManager.isDailyReminderEnabled ? "bell.fill" : "bell.slash.fill")
                        .foregroundStyle(ZenWavePalette.electricPurple)
                }

                Toggle(
                    isOn: Binding(
                        get: { notificationManager.isDailyReminderEnabled },
                        set: { newValue in
                            if notificationManager.authorizationStatus == .notDetermined && newValue {
                                requestNotifications()
                            } else {
                                notificationManager.setDailyReminderEnabled(newValue)
                            }
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily ritual reminder")
                            .font(.headline)
                        Text("A gentle local reminder at \(notificationManager.reminderTimeLabel).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: ZenWavePalette.electricPurple))

                DisclosureGroup(isExpanded: $isReminderOptionsExpanded) {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newValue in
                                notificationManager.setReminderTime(newValue)
                            }

                        Toggle(
                            isOn: Binding(
                                get: { notificationManager.isChallengeReminderEnabled },
                                set: { newValue in
                                    if notificationManager.authorizationStatus == .notDetermined && newValue {
                                        requestNotifications(includeChallenge: true)
                                    } else {
                                        notificationManager.setChallengeReminderEnabled(newValue)
                                    }
                                }
                            )
                        ) {
                            Text("Challenge continuation")
                                .font(.headline)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .disabled(!storeManager.isPremiumUnlocked)
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Reminder options", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(ZenWavePalette.electricPurple)

                if notificationManager.authorizationStatus == .denied {
                    Button {
                        notificationManager.openSystemSettings()
                    } label: {
                        Label("Open iOS Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ZenWavePalette.electricPurple)
                } else if notificationManager.authorizationStatus == .notDetermined {
                    Button {
                        requestNotifications()
                    } label: {
                        Label(isRequestingNotifications ? "Requesting" : "Enable Reminders", systemImage: "bell.badge.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ZenWavePalette.electricPurple)
                    .disabled(isRequestingNotifications)
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
                    Text("Enable Sounds")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: enableSounds) { _, newValue in
                    AppLog.info("Settings Enable Sounds changed: \(newValue)")
                }

                Toggle(isOn: $guidedVoiceEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                    Text("Guided Voice")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .onChange(of: guidedVoiceEnabled) { _, newValue in
                    AppLog.info("Settings Guided Voice changed: \(newValue)")
                }

                /*
                 Apple/system voice customization is intentionally hidden from production for now.
                 The app's main guided prompts use bundled voice assets, and the system fallback still
                 sounds too robotic for these controls to provide meaningful user value. Keep this UI
                 available in source so we can revisit when Apple voice options improve.

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
                 */

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
                Text(versionLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()
                    .opacity(reduceTransparency ? 1 : 0.3)

                Text("""
ZenWave blends binaural beats, chakra tones, and nature textures into repeatable rituals for sleep, focus, visualization, meditation, and altered-state practice.
""")
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Link(destination: URL(string: "https://www.hyperlabsai.com/privacypolicy")!) {
                        Label("Privacy", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Label("Terms", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Link(destination: URL(string: "mailto:info@hyperlabsai.com?subject=ZenWave%20Support")!) {
                        Label("Support", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption.weight(.semibold))
                .tint(ZenWavePalette.electricPurple)

                DisclosureGroup(isExpanded: $isAdvancedOptionsExpanded) {
                    Button(role: .destructive) {
                        showResetProgressConfirmation = true
                    } label: {
                        Label("Reset Local Progress", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Local data", systemImage: "internaldrive")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "3.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(version)" : "Version \(version) (\(build))"
    }
}

private extension SettingsView {
    func requestNotifications(includeChallenge: Bool = false) {
        isRequestingNotifications = true
        Task { @MainActor in
            await notificationManager.requestPermissionAndSchedule(
                date: reminderTime,
                includeChallengeReminder: includeChallenge || notificationManager.isChallengeReminderEnabled
            )
            isRequestingNotifications = false
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
                .environmentObject(GamificationManager())
                .environmentObject(RitualNotificationManager())
        }
    }
}
//
//  SettingsView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//
