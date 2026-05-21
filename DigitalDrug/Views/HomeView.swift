//
//  HomeView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var guidedVoiceManager: GuidedVoiceManager
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedRitualIntent") private var selectedRitualIntent = RitualIntent.meditate.rawValue
    @AppStorage("ritualChallengeProgress") private var ritualChallengeProgressData = "{}"
    @AppStorage("ritualJournalEntries") private var ritualJournalEntriesData = "[]"
    @State private var selectedRitual: RitualPreset = RitualPreset.recommended(for: .meditate)
    @State private var activeChallenge: RitualChallenge?
    @State private var challengeProgress: [String: Int] = [:]
    @State private var journalEntries: [RitualJournalEntry] = []
    @State private var completedRitual: RitualPreset?
    @State private var selectedGuidedRitual: GuidedRitual?
    @State private var selectedEducationTopic: EducationTopic?
    @State private var paywallFeature: PaywallFeature?
    @State private var isPlaying = false
    
    private var selectedIntent: RitualIntent {
        RitualIntent(rawValue: selectedRitualIntent) ?? .meditate
    }
    
    private var recommendedRitual: RitualPreset {
        RitualPreset.recommended(for: selectedIntent)
    }
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroCard
                        intentStrip
                        gatewayRitualsSection
                        quantumCodesSection
                        activeRitualCard
                        ritualGrid
                        challengesSection
                        journalSection
                        Spacer().frame(height: 180)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 76)
                    .padding(.bottom, 260)
                }
            }
        }
        .onAppear {
            selectedRitual = recommendedRitual
            loadProgress()
            loadJournal()
        }
        .onChange(of: selectedRitualIntent) { _, _ in
            selectedRitual = recommendedRitual
        }
        .onChange(of: toneGenerator.isPlaying) { _, newValue in
            if !newValue {
                isPlaying = false
            }
        }
        .sheet(item: $completedRitual) { ritual in
            RitualCompletionView(
                ritual: ritual,
                challenge: activeChallenge,
                completedDay: activeChallenge.map { challengeProgress[$0.id, default: 0] },
                onSave: saveJournalEntry
            )
        }
        .sheet(item: $selectedGuidedRitual) { ritual in
            GuidedRitualSessionView(
                ritual: ritual,
                onSave: saveJournalEntry
            )
            .environmentObject(toneGenerator)
            .environmentObject(audioManager)
            .environmentObject(guidedVoiceManager)
        }
        .sheet(item: $selectedEducationTopic) { topic in
            EducationInfoView(topic: topic)
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environmentObject(storeManager)
        }
    }
    
    private var heroCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("ZenWave", systemImage: "waveform.path.ecg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("DigitalDrugz rituals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                
                Text("Choose your state.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Binaural beats, chakra tones, and repeatable rituals built for sleep, focus, meditation, visualization, and altered-state practice.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Image(systemName: selectedIntent.iconName)
                    Text("Recommended for \(selectedIntent.title): \(recommendedRitual.title)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedIntent.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(selectedIntent.color.opacity(reduceTransparency ? 0.18 : 0.28)))
            }
        }
    }
    
    private var intentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RitualIntent.allCases) { intent in
                    Button {
                        AppLog.info("Home intent selected: \(intent.title)")
                        selectedRitualIntent = intent.rawValue
                    } label: {
                        Label(intent.shortTitle, systemImage: intent.iconName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(selectedIntent == intent ? intent.color.opacity(0.35) : Color.white.opacity(0.10))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(selectedIntent == intent ? intent.color.opacity(0.65) : Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    private var activeRitualCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedRitual.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(selectedRitual.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(selectedRitual.frequencyLabel)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selectedRitual.accent.opacity(0.25)))
                }
                
                Text(selectedRitual.instruction)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(selectedRitual.disclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Button {
                        AppLog.info("Home active ritual button tapped: \(selectedRitual.title), currentlyPlaying=\(isPlaying)")
                        requirePremium(feature: "ritual preset playback") {
                            toggleRitualPlayback()
                        }
                    } label: {
                        Label(isPlaying ? "Pause Ritual" : "Start \(selectedRitual.durationMinutes)m Ritual", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selectedRitual.accent)
                    
                    Button {
                        AppLog.info("Home ritual completion tapped: \(selectedRitual.title)")
                        requirePremium(feature: "ritual journal completion") {
                            completedRitual = selectedRitual
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isPlaying)
                }
            }
        }
    }
    
    private var ritualGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ritual Presets")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                ForEach(RitualPreset.all) { ritual in
                    RitualPresetCard(
                        ritual: ritual,
                        isSelected: selectedRitual.id == ritual.id
                    ) {
                        selectRitual(ritual)
                    }
                }
            }
        }
    }
    
    private var gatewayRitualsSection: some View {
        guidedModuleSection(
            title: GuidedRitualModule.gateway.title,
            subtitle: "Gateway-inspired breath, focus, energy field, and pattern rituals.",
            educationTopic: .gateway,
            rituals: GuidedRitual.gatewayRituals
        )
    }
    
    private var quantumCodesSection: some View {
        guidedModuleSection(
            title: GuidedRitualModule.quantumCodes.title,
            subtitle: "Curated code rituals for reflection, intention, and state-shifting.",
            educationTopic: .quantumCodes,
            rituals: GuidedRitual.quantumCodeRituals
        )
    }
    
    private func guidedModuleSection(
        title: String,
        subtitle: String,
        educationTopic: EducationTopic,
        rituals: [GuidedRitual]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    AppLog.info("Education info tapped: \(title)")
                    selectedEducationTopic = educationTopic
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .accessibilityLabel("Learn about \(title)")
            }
            
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 152), spacing: 14, alignment: .top)
                ],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(rituals) { ritual in
                    GuidedRitualCard(ritual: ritual) {
                        AppLog.info("Guided ritual card tapped: \(ritual.module.title) - \(ritual.title)")
                        requirePremium(feature: ritual.module.title) {
                            stopRitual()
                            selectedGuidedRitual = ritual
                        }
                    }
                }
            }
        }
    }
    
    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Repeatable Challenges")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            ForEach(RitualChallenge.all) { challenge in
                ChallengeCard(
                    challenge: challenge,
                    completedDays: challengeProgress[challenge.id, default: 0],
                    isActive: activeChallenge?.id == challenge.id
                ) {
                    beginChallenge(challenge)
                }
            }
        }
    }
    
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Journal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(journalEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !storeManager.isPremiumUnlocked {
                LiquidGlassCard(cornerRadius: 28, showParticles: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Premium Journal", systemImage: "lock.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Save ritual reflections, intentions, moods, and dream notes with ZenWave Premium.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showPaywall(feature: "journal")
                        } label: {
                            Label("Unlock Journal", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ZenWavePalette.electricPurple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if journalEntries.isEmpty {
                LiquidGlassCard(cornerRadius: 28, showParticles: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your ritual notes will appear here.")
                            .font(.headline)
                        Text("Complete a ritual to save intention, mood, and dream notes locally on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(journalEntries.prefix(3)) { entry in
                    LiquidGlassCard(cornerRadius: 24, showParticles: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.presetTitle)
                                    .font(.headline)
                                Spacer()
                                Text(entry.dateLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.notes.isEmpty ? entry.intention : entry.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
    
    private func selectRitual(_ ritual: RitualPreset) {
        AppLog.info("Ritual preset selected: \(ritual.title)")
        guard storeManager.isPremiumUnlocked else {
            showPaywall(feature: "ritual presets")
            return
        }
        
        stopRitual()
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            selectedRitual = ritual
            activeChallenge = nil
        }
    }
    
    private func beginChallenge(_ challenge: RitualChallenge) {
        AppLog.info("Challenge selected: \(challenge.title)")
        guard storeManager.isPremiumUnlocked else {
            showPaywall(feature: "repeatable challenges")
            return
        }
        
        stopRitual()
        if challengeProgress[challenge.id, default: 0] >= challenge.dayCount {
            challengeProgress[challenge.id] = 0
            saveProgress()
        }
        let day = nextDay(for: challenge)
        activeChallenge = challenge
        selectedRitual = challenge.preset(for: day)
    }
    
    private func toggleRitualPlayback() {
        if isPlaying {
            stopRitual()
        } else {
            startRitual(selectedRitual)
        }
    }
    
    private func startRitual(_ ritual: RitualPreset) {
        AppLog.info("Starting active Home ritual: \(ritual.title), audioKind=\(ritual.frequencyLabel)")
        audioManager.stopAll()
        toneGenerator.stop()
        
        switch ritual.audioKind {
        case .binaural(let left, let right):
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: left,
                rightFreq: right,
                title: ritual.title,
                subtitle: "\(ritual.frequencyLabel) - \(ritual.subtitle)"
            )
        case .chakra(let frequency, let chakraName):
            let timbre = ChakraTone.allChakras.first { $0.name.contains(chakraName) }?.bellTimbre ?? .balanced
            toneGenerator.generateChakraBell(
                frequency: frequency,
                timbre: timbre,
                title: ritual.title,
                subtitle: "\(Int(frequency)) Hz \(chakraName) chakra ritual"
            )
            audioManager.playNature(fileName: "Ocean.wav")
        }
        
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            isPlaying = true
        }
        
        if let challenge = activeChallenge {
            markChallengeDayComplete(challenge)
        }
    }
    
    private func stopRitual() {
        AppLog.info("Stopping active Home ritual")
        toneGenerator.stop()
        audioManager.stopAll()
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            isPlaying = false
        }
    }
    
    private func nextDay(for challenge: RitualChallenge) -> Int {
        min(challengeProgress[challenge.id, default: 0] + 1, challenge.dayCount)
    }
    
    private func markChallengeDayComplete(_ challenge: RitualChallenge) {
        let current = challengeProgress[challenge.id, default: 0]
        guard current < challenge.dayCount else { return }
        challengeProgress[challenge.id] = current + 1
        saveProgress()
    }
    
    private func loadProgress() {
        guard let data = ritualChallengeProgressData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            challengeProgress = [:]
            return
        }
        challengeProgress = decoded
    }
    
    private func saveProgress() {
        guard let data = try? JSONEncoder().encode(challengeProgress),
              let encoded = String(data: data, encoding: .utf8) else { return }
        ritualChallengeProgressData = encoded
    }
    
    private func loadJournal() {
        guard let data = ritualJournalEntriesData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RitualJournalEntry].self, from: data) else {
            journalEntries = []
            return
        }
        journalEntries = decoded.sorted { $0.date > $1.date }
    }
    
    private func saveJournalEntry(_ entry: RitualJournalEntry) {
        guard storeManager.isPremiumUnlocked else {
            showPaywall(feature: "journal")
            return
        }
        
        journalEntries.insert(entry, at: 0)
        let trimmed = Array(journalEntries.prefix(50))
        journalEntries = trimmed
        guard let data = try? JSONEncoder().encode(trimmed),
              let encoded = String(data: data, encoding: .utf8) else { return }
        ritualJournalEntriesData = encoded
        completedRitual = nil
        stopRitual()
    }
    
    private func requirePremium(feature: String, perform action: () -> Void) {
        guard storeManager.isPremiumUnlocked else {
            showPaywall(feature: feature)
            return
        }
        
        action()
    }
    
    private func showPaywall(feature: String) {
        AppLog.info("Paywall requested from Home feature: \(feature)")
        paywallFeature = .premiumRituals
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

struct RitualPresetCard: View {
    let ritual: RitualPreset
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 28, showParticles: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: ritual.intent.iconName)
                            .font(.title3)
                            .foregroundStyle(ritual.accent)
                        Spacer()
                        Text("\(ritual.durationMinutes)m")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Text(ritual.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    
                    Text(ritual.frequencyLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ritual.accent)
                }
                .frame(height: 128)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(isSelected ? ritual.accent.opacity(0.70) : Color.clear, lineWidth: 2)
        )
    }
}

struct GuidedRitualCard: View {
    let ritual: GuidedRitual
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 28, showParticles: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: ritual.module == .gateway ? "sparkles" : "number.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ritual.accent)
                        Spacer()
                        Text("\(ritual.durationMinutes)m")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Text(ritual.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    
                    Text(ritual.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    Text(ritual.codeSequence.isEmpty ? ritual.frequencyLabel : ritual.codeLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ritual.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(height: 148)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(!reduceMotion ? 1.0 : 1.0)
    }
}

struct ChallengeCard: View {
    let challenge: RitualChallenge
    let completedDays: Int
    let isActive: Bool
    let action: () -> Void
    
    private var progress: Double {
        guard challenge.dayCount > 0 else { return 0 }
        return Double(completedDays) / Double(challenge.dayCount)
    }
    
    var body: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(challenge.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(min(completedDays, challenge.dayCount))/\(challenge.dayCount)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(challenge.accent.opacity(0.25)))
                }
                
                ProgressView(value: progress, total: 1)
                    .tint(challenge.accent)
                
                Button {
                    action()
                } label: {
                    Label(
                        completedDays >= challenge.dayCount ? "Restart Ritual" : isActive ? "Continue Day \(min(completedDays + 1, challenge.dayCount))" : "Start Day \(min(completedDays + 1, challenge.dayCount))",
                        systemImage: "calendar.badge.clock"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(challenge.accent)
            }
        }
    }
}

struct RitualCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    let ritual: RitualPreset
    let challenge: RitualChallenge?
    let completedDay: Int?
    let onSave: (RitualJournalEntry) -> Void
    
    @State private var moodBefore = 3.0
    @State private var moodAfter = 4.0
    @State private var intention = ""
    @State private var notes = ""
    
    private var shareText: String {
        var parts = [
            "Completed \(ritual.title)",
            "\(ritual.frequencyLabel) in ZenWave / DigitalDrugz"
        ]
        if let challenge, let completedDay {
            parts.insert("\(challenge.title) - Day \(min(completedDay, challenge.dayCount))/\(challenge.dayCount)", at: 1)
        }
        return parts.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        sharePreviewCard
                        journalCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("Ritual Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }
    
    private var sharePreviewCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 16) {
                Text("ZenWave / DigitalDrugz")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ritual.accent)
                
                Text(ritual.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                
                if let challenge, let completedDay {
                    Text("\(challenge.title) - Day \(min(completedDay, challenge.dayCount))/\(challenge.dayCount)")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                
                Text(ritual.frequencyLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ritual.accent)
                
                Text("Choose your state. Repeat the ritual.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ShareLink(item: shareText) {
                    Label("Share Text Card", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ritual.accent)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var journalCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Journal")
                    .font(.title3.weight(.semibold))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mood Before: \(Int(moodBefore))/5")
                        .font(.caption.weight(.semibold))
                    Slider(value: $moodBefore, in: 1...5, step: 1)
                        .tint(ritual.accent)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mood After: \(Int(moodAfter))/5")
                        .font(.caption.weight(.semibold))
                    Slider(value: $moodAfter, in: 1...5, step: 1)
                        .tint(ritual.accent)
                }
                
                TextField("Intention or dream cue", text: $intention, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Notes, imagery, vibration stage, or dreams", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private func save() {
        onSave(
            RitualJournalEntry(
                id: UUID(),
                date: Date(),
                presetID: ritual.id,
                presetTitle: ritual.title,
                moodBefore: Int(moodBefore),
                moodAfter: Int(moodAfter),
                intention: intention,
                notes: notes
            )
        )
        dismiss()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(ToneGenerator())
            .environmentObject(AudioManager())
            .environmentObject(GuidedVoiceManager())
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
    @State private var showingChakraInfo = false
    
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
            .sheet(isPresented: $showingChakraInfo) {
                EducationInfoView(topic: .chakras)
            }
            .onDisappear {
                stopProgressionSession(stopAudio: true)
            }
            .onChange(of: toneGenerator.isPlaying) { _, newValue in
                if !newValue {
                    progressionTask?.cancel()
                    progressionTask = nil
                    isProgressionRunning = false
                    progressionIndex = 0
                    progressionSecondsRemaining = 0
                    activeChakra = nil
                    audioManager.stopNature()
                }
            }
        }
    }
    
    private var headerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chakra Frequency Mode")
                    .font(.title3.weight(.semibold))
                Text("Pick the comment-style chakra label you feel today, then use the matching Solfeggio bell as a repeatable ritual.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button {
                    AppLog.info("Chakra info button tapped")
                    showingChakraInfo = true
                } label: {
                    Label("Learn About Chakras", systemImage: "info.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
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
                    AppLog.info("Chakra progression button tapped. currentlyRunning=\(isProgressionRunning)")
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
                    AppLog.info("Chakra ambient toggle changed: \(isAmbientEnabled)")
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
                Button {
                    AppLog.info("Chakra card tapped: \(chakra.name)")
                    toggleChakra(chakra)
                } label: {
                    chakraCard(chakra)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(activeChakra == chakra && !isProgressionRunning ? "Stop" : "Play") \(chakra.name)")
            }
        }
    }
    
    private func chakraCard(_ chakra: ChakraTone) -> some View {
        let isActive = activeChakra == chakra
        
        return LiquidGlassCard(cornerRadius: 30, showParticles: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("comment: \(chakra.commentTag)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(chakra.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(chakra.color.opacity(0.18)))
                        
                        Text(chakra.name)
                            .font(.headline)
                            .foregroundStyle(chakra.color)
                        Text(chakra.chakraName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(Int(chakra.frequency)) Hz")
                            .font(.headline.monospacedDigit())
                        
                        Label(
                            isActive && !isProgressionRunning ? "Playing" : "Tap to play",
                            systemImage: isActive && !isProgressionRunning
                                ? "waveform.circle.fill"
                                : "play.circle.fill"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(chakra.color.opacity(isActive ? 0.85 : 0.45)))
                    }
                }
                
                Text(chakra.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(chakra.blockedCopy)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                
                Text(chakra.recommendedUse)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isProgressionRunning && isActive {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(chakra.color.opacity(0.25)))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(chakra.color.opacity(isActive ? 0.85 : 0), lineWidth: 2)
        )
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
                        AppLog.info("Chakra equalizer softer mix tapped")
                        toneGenerator.applySofterEQPreset()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Flat") {
                        AppLog.info("Chakra equalizer flat tapped")
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
        AppLog.info("Toggle chakra requested: \(chakra.name), active=\(activeChakra?.name ?? "nil"), progressionRunning=\(isProgressionRunning)")
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
        AppLog.info("Play chakra requested: \(chakra.name), frequency=\(chakra.frequency)")
        audioManager.stopBinaural()
        toneGenerator.generateChakraBell(
            frequency: chakra.frequency,
            timbre: chakra.bellTimbre,
            title: chakra.name,
            subtitle: "\(Int(chakra.frequency)) Hz - comment: \(chakra.commentTag)"
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
        AppLog.info("Start chakra progression requested. stepDuration=\(progressionStepDuration)")
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
        AppLog.info("Stop chakra progression requested. stopAudio=\(stopAudio)")
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
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var storeManager: StoreManager
    @State private var selectedTab: Tab = .waves
    @State private var hasAppliedInitialTab = false
    @State private var paywallFeature: PaywallFeature?
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
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
            .clipped()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                UnifiedSoundPlayerBar()
                
                HStack {
                    CustomTabBar(selectedTab: $selectedTab, requestTab: requestTab)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [
                        ZenWavePalette.deepPurple.opacity(0.34),
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .allowsHitTesting(false)
            )
        }
        .onAppear {
            applyInitialTabIfNeeded()
        }
        .onChange(of: storeManager.accessLevel) { _, _ in
            applyInitialTabIfNeeded()
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environmentObject(storeManager)
        }
    }
    
    private func applyInitialTabIfNeeded() {
        guard !hasAppliedInitialTab, storeManager.accessLevel != .loading else { return }
        selectedTab = storeManager.isPremiumUnlocked ? .lotus : .waves
        hasAppliedInitialTab = true
    }
    
    private func requestTab(_ tab: Tab) {
        guard tab.isFree || storeManager.isPremiumUnlocked else {
            AppLog.info("Paywall requested from tab: \(tab.rawValue)")
            paywallFeature = .premiumRituals
            return
        }
        
        selectedTab = tab
    }
}

struct UnifiedSoundPlayerBar: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    private var hasSound: Bool { toneGenerator.hasCurrentSound }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIconName)
                .font(.title2)
                .foregroundStyle(hasSound ? .cyan : .white.opacity(0.48))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(toneGenerator.currentSoundTitle ?? "No Sound Selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(hasSound ? .white : .white.opacity(0.72))
                    .lineLimit(1)
                
                Text(toneGenerator.currentSoundSubtitle ?? "Choose any ritual, chakra, binaural, or pulsed sound.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Slider(
                value: Binding(
                    get: { Double(toneGenerator.volume) },
                    set: { toneGenerator.setVolume(Float($0)) }
                ),
                in: 0...1,
                step: 0.01
            )
            .tint(.cyan)
            .frame(width: 82)
            .disabled(!hasSound)
            .opacity(hasSound ? 1.0 : 0.45)
            
            Button {
                if toneGenerator.isPlaying {
                    toneGenerator.pause()
                } else {
                    toneGenerator.resume()
                }
            } label: {
                Image(systemName: toneGenerator.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(hasSound ? .white : .white.opacity(0.42))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .disabled(!hasSound)
            
            Button {
                toneGenerator.stop()
                audioManager.stopAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .disabled(!hasSound)
            .opacity(hasSound ? 1.0 : 0.42)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(ZenWavePalette.toolbarGradient)
                .overlay(Color.black.opacity(0.10))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(ZenWavePalette.electricPurple.opacity(0.55), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: ZenWavePalette.deepPurple.opacity(0.42), radius: 16, y: 8)
    }
    
    private var statusIconName: String {
        if !hasSound {
            return "waveform"
        }
        return toneGenerator.isPlaying ? "waveform.circle.fill" : "pause.circle.fill"
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
    
    var isFree: Bool {
        switch self {
        case .waves, .lotus, .profile:
            return true
        case .chakra, .volume:
            return false
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let requestTab: (Tab) -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    AppLog.info("Tab tapped: \(tab.rawValue)")
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                        requestTab(tab)
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
        .frame(height: 64)
        .frame(maxWidth: 340)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(ZenWavePalette.toolbarGradient)
                .overlay(Color.black.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(ZenWavePalette.electricPurple.opacity(0.62), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: ZenWavePalette.deepPurple.opacity(0.48), radius: 20, y: 10)
    }
}

// MARK: - Sessions List View (for Volume tab)
struct SessionsListView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(BinauralSession.allSessions) { session in
                            NavigationLink {
                                let frequencies = getFrequenciesForBrainwave(session.brainwaveType)
                                ToneSessionView(
                                    session: session,
                                    leftFrequency: frequencies.left,
                                    rightFrequency: frequencies.right
                                )
                                .navigationTitle(session.title)
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                SessionListCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("DigitalDrug Rituals")
            .navigationBarTitleDisplayMode(.inline)
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

enum EducationTopic: String, Identifiable {
    case quantumCodes
    case chakras
    case gateway
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .quantumCodes: return "Quantum Codes"
        case .chakras: return "Chakras"
        case .gateway: return "Gateway Process"
        }
    }
    
    var subtitle: String {
        switch self {
        case .quantumCodes:
            return "Numbers, intention, repetition, and reflective ritual."
        case .chakras:
            return "Seven energy centers used as a map for sound, body awareness, and intention."
        case .gateway:
            return "Gateway-inspired focus rituals for relaxation, visualization, and inner exploration."
        }
    }
}

struct EducationInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let topic: EducationTopic
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewCard
                        howToUseCard
                        topicReference
                        disclaimerCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var overviewCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text(topic.title)
                    .font(.title2.weight(.bold))
                Text(topic.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(overviewText)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var howToUseCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("How To Use It")
                    .font(.title3.weight(.semibold))
                
                ForEach(howToUseSteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.cyan)
                        Text(step)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private var topicReference: some View {
        switch topic {
        case .quantumCodes:
            VStack(alignment: .leading, spacing: 12) {
                Text("Code Reference")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(GuidedRitual.quantumCodeRituals) { ritual in
                    EducationReferenceCard(
                        title: ritual.title,
                        subtitle: ritual.codeSequence.joined(separator: "  |  "),
                        bodyText: "\(ritual.subtitle). \(ritual.summary)",
                        accent: ritual.accent,
                        footer: "Use by setting one intention, listening to the tone bed, and letting the voice repeat the number sequence slowly."
                    )
                }
            }
        case .chakras:
            VStack(alignment: .leading, spacing: 12) {
                Text("Chakra Reference")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(ChakraTone.allChakras) { chakra in
                    EducationReferenceCard(
                        title: "\(chakra.name) - \(chakra.chakraName)",
                        subtitle: "\(Int(chakra.frequency)) Hz - comment: \(chakra.commentTag)",
                        bodyText: "\(chakra.meaning) \(chakra.blockedCopy)",
                        accent: chakra.color,
                        footer: chakra.recommendedUse
                    )
                }
            }
        case .gateway:
            VStack(alignment: .leading, spacing: 12) {
                Text("Ritual Reference")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(GuidedRitual.gatewayRituals) { ritual in
                    EducationReferenceCard(
                        title: ritual.title,
                        subtitle: "\(Int(ritual.duration / 60)) min - \(ritual.frequencyLabel)",
                        bodyText: ritual.summary,
                        accent: ritual.accent,
                        footer: gatewayUseLine(for: ritual)
                    )
                }
            }
        }
    }
    
    private var disclaimerCard: some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Important")
                    .font(.headline)
                Text(disclaimerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var overviewText: String {
        switch topic {
        case .quantumCodes:
            return "Quantum Codes are presented here as esoteric number-sequence rituals. The theory is that a number pattern can act like a symbolic focus object: you pair the code with an intention, repeat it slowly, and use breath plus sound to create a consistent meditative state."
        case .chakras:
            return "The chakra system is a traditional subtle-body map. In ZenWave, each chakra is treated as a simple reflection category: grounding, creativity, confidence, compassion, expression, intuition, and connection. The frequencies are used as ritual anchors, not as medical treatment."
        case .gateway:
            return "Gateway-inspired practice uses a Monroe-style structure: relax the body, keep awareness alert, use breath and sound as anchors, visualize a specific inner task, then return and ground. ZenWave adapts that structure into short, app-safe guided rituals."
        }
    }
    
    private var howToUseSteps: [String] {
        switch topic {
        case .quantumCodes:
            return [
                "Choose one code that matches the state or intention you want to explore.",
                "Write or mentally hold one simple intention before pressing Start.",
                "Let the voice speak the code slowly; repeat it silently or out loud if that feels natural.",
                "After the session, journal what shifted in mood, body sensation, imagery, or thought."
            ]
        case .chakras:
            return [
                "Choose the chakra label that matches what feels loudest today.",
                "Start the tone and place attention on the matching body area without forcing anything.",
                "Use the blocked-copy prompt as a journaling cue.",
                "Stop if the sound feels uncomfortable; lower volume is usually better for ritual use."
            ]
        case .gateway:
            return [
                "Use headphones, sit or lie down, and choose a short ritual first.",
                "Follow the spoken prompts as a structure, not a test you need to pass.",
                "Let imagery be loose and symbolic; the goal is relaxed awareness.",
                "Always complete the return step: move fingers and toes, orient to the room, then open your eyes."
            ]
        }
    }
    
    private var disclaimerText: String {
        switch topic {
        case .quantumCodes:
            return "Quantum Codes are offered as reflective and esoteric ritual content. They are not medical advice, treatment, diagnosis, or a guaranteed outcome method."
        case .chakras:
            return "Chakra content is used as a wellness and reflection framework. It is not a substitute for medical, mental-health, or professional care."
        case .gateway:
            return "Gateway-inspired rituals are relaxation and visualization practices. ZenWave does not claim that any experience is proven, guaranteed, or required."
        }
    }
    
    private func gatewayUseLine(for ritual: GuidedRitual) -> String {
        if ritual.title.contains("Focus 10") {
            return "Use when you want to practice body relaxation while staying mentally awake."
        }
        if ritual.title.contains("Focus 12") {
            return "Use when you want a spacious awareness meditation after basic relaxation."
        }
        if ritual.title.contains("Breath") {
            return "Use as a quick reset before deeper rituals or sleep."
        }
        if ritual.title.contains("Release") {
            return "Use when thoughts feel sticky and you want to symbolically set them aside."
        }
        if ritual.title.contains("Shield") {
            return "Use as a boundary-setting visualization before meditation or creative work."
        }
        if ritual.title.contains("Pattern") {
            return "Use for future-self rehearsal and one grounded next action."
        }
        return "Use as a pre-sleep stillness and float-up visualization practice, without forcing an outcome."
    }
}

struct EducationReferenceCard: View {
    let title: String
    let subtitle: String
    let bodyText: String
    let accent: Color
    let footer: String
    
    var body: some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(accent)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(bodyText)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    
                    controlCluster
                    
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 140)
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
        .onChange(of: toneGenerator.isPlaying) { _, newValue in
            if !newValue {
                isPlaying = false
                timer?.invalidate()
                timer = nil
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
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isPlaying ? "Sound Is Playing" : "Start Generated Sound")
                            .font(.headline)
                        Text("\(session.brainwaveType.rawValue) binaural beat - \(String(format: "%.1f", abs(rightFrequency - leftFrequency))) Hz")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isPlaying {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                            .foregroundStyle(session.icon.color)
                    }
                }
                
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
        toneGenerator.generateContinuousBinauralBeat(
            leftFreq: leftFrequency,
            rightFreq: rightFrequency,
            title: session.title,
            subtitle: "\(session.brainwaveType.rawValue) binaural beat - \(String(format: "%.1f", abs(rightFrequency - leftFrequency))) Hz"
        )
        isPlaying = true
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
