//
//  HomeView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct HomeView: View {
    // 888 - Mass Scale - $500,000 per month revenue
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var guidedVoiceManager: GuidedVoiceManager
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var gamificationManager: GamificationManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedRitualIntent") private var selectedRitualIntent = RitualIntent.meditate.rawValue
    @AppStorage("ritualChallengeProgress") private var ritualChallengeProgressData = "{}"
    @AppStorage("ritualJournalEntries") private var ritualJournalEntriesData = "[]"
    @AppStorage("homeRecommendationRotationIndex") private var homeRecommendationRotationIndex = -1
    @AppStorage("homeRecommendationLastLaunchID") private var homeRecommendationLastLaunchID = ""
    @State private var selectedRitual: RitualPreset = RitualPreset.recommended(for: .meditate)
    @State private var activeChallenge: RitualChallenge?
    @State private var challengeProgress: [String: Int] = [:]
    @State private var journalEntries: [RitualJournalEntry] = []
    @State private var completedRitual: RitualPreset?
    @State private var selectedAudioSession: BinauralSession?
    @State private var selectedGuidedRitual: GuidedRitual?
    @State private var selectedEducationTopic: EducationTopic?
    @State private var paywallFeature: PaywallFeature?
    @State private var libraryDestination: HomeLibraryDestination?
    @State private var showsConstellation = false
    @State private var selectedGuidedModule: GuidedRitualModule = .gateway
    @State private var isPlaying = false
    @State private var dailySignalTimer: Timer?
    @State private var activeDailySignalID: String?

    private static let launchID = UUID().uuidString
    private static let recommendedRitualScrollID = "recommendedRitualSection"

    private var selectedIntent: RitualIntent {
        RitualIntent(rawValue: selectedRitualIntent) ?? .meditate
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            if isPlaying {
                FullScreenRitualWaveField(accent: selectedRitual.accent)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    homeHeader
                    tonightsPathSection
                        .id(Self.recommendedRitualScrollID)
                    constellationPreviewSection
                    guidedRitualExplorerSection
                    quickAudioRitualsSection
                    practiceSummarySection
                }
                .padding(.horizontal, 24)
                .padding(.top, 76)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            rotateRecommendedRitualIfNeeded()
            loadProgress()
            loadJournal()
            gamificationManager.migrateChallengeProgressIfNeeded(from: challengeProgress)
        }
        .onChange(of: selectedRitualIntent) { _, _ in
            rotateRecommendedRitual(advance: true)
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
                allowsJournal: storeManager.isPremiumUnlocked,
                onSave: saveJournalEntry
            )
        }
        .sheet(item: $selectedAudioSession) { session in
            let frequencies = frequencies(for: session.brainwaveType)
            NavigationStack {
                ToneSessionView(
                    session: session,
                    leftFrequency: frequencies.left,
                    rightFrequency: frequencies.right
                )
                .navigationTitle(session.title)
                .navigationBarTitleDisplayMode(.inline)
            }
            .environmentObject(toneGenerator)
            .environmentObject(audioManager)
        }
        .fullScreenCover(item: $selectedGuidedRitual) { ritual in
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
        .fullScreenCover(item: $libraryDestination) { destination in
            NavigationStack {
                switch destination {
                case .presets:
                    RitualPresetLibraryView(selectedRitualID: selectedRitual.id) { ritual in
                        selectRitual(ritual)
                    }
                case .guided:
                    GuidedRitualLibraryView(initialModule: selectedGuidedModule) { ritual in
                        openGuidedRitual(ritual)
                    } onLearn: { topic in
                        selectedEducationTopic = topic
                    }
                case .practice:
                    PracticeHubView(
                        gamificationManager: gamificationManager,
                        isPremiumUnlocked: storeManager.isPremiumUnlocked,
                        challenges: RitualChallenge.all,
                        challengeProgress: challengeProgress,
                        activeChallengeID: activeChallenge?.id,
                        onPractice: startRecommendedAstralPractice,
                        onChallenge: beginChallenge
                    )
                case .journal:
                    JournalLibraryView(entries: journalEntries, isPremiumUnlocked: storeManager.isPremiumUnlocked) {
                        showPaywall(feature: "journal")
                    }
                }
            }
            .environmentObject(storeManager)
        }
        .fullScreenCover(isPresented: $showsConstellation) {
            GatewayConstellationView(
                gamificationManager: gamificationManager,
                isPremiumUnlocked: storeManager.isPremiumUnlocked
            ) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    startRecommendedAstralPractice()
                }
            }
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 12) {
            Label("ZenWave", systemImage: "waveform")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                libraryDestination = .practice
            } label: {
                Label("\(gamificationManager.currentStreak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(gamificationManager.currentStreak) day streak. Open your practice.")
        }
    }

    private var tonightsPathSection: some View {
        let signal = RitualPreset.dailySignal(for: selectedIntent)

        return VStack(spacing: 18) {
            VStack(spacing: 5) {
                Text("TONIGHT'S PATH")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                    .foregroundStyle(selectedRitual.accent)

                Text(selectedRitual.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(selectedRitual.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
            }

            MeditationPortalView(
                accent: selectedRitual.accent,
                isPlaying: isPlaying
            )
            .frame(height: 270)
            .accessibilityHidden(true)

            HStack(spacing: 16) {
                Label("\(selectedRitual.durationMinutes) min", systemImage: "clock")
                Label(selectedRitual.frequencyLabel, systemImage: "waveform")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.70))

            Button {
                AppLog.info("Tonight's Path tapped: \(selectedRitual.title), currentlyPlaying=\(isPlaying)")
                requirePremium(feature: "ritual preset playback") {
                    toggleRitualPlayback()
                }
            } label: {
                Label(isPlaying ? "Pause Ritual" : "Begin Ritual", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [ZenWavePalette.deepPurple, ZenWavePalette.electricPurple, selectedRitual.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28)))
            .shadow(color: selectedRitual.accent.opacity(0.34), radius: 18, y: 8)

            HStack(spacing: 12) {
                Button {
                    startDailySignal(signal)
                } label: {
                    Label("60s reset", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    libraryDestination = .presets
                } label: {
                    Label("Change path", systemImage: "rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .tint(.white.opacity(0.88))

            intentStrip
        }
        .padding(.vertical, 8)
    }

    private var constellationPreviewSection: some View {
        Button {
            showsConstellation = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image("GatewayConstellation")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 248)
                    .clipped()

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.30), Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("YOUR CONSTELLATION", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(.cyan)

                        Spacer()

                        Text("\(gamificationManager.gatewayFoundationCompletedCount)/\(gamificationManager.gatewayFoundationSteps.count)")
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Text(gamificationManager.currentRank.title)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)

                    if let next = gamificationManager.nextGatewayFoundationStep {
                        Text("Next star: \(next.title)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    } else {
                        Text("All Gateway foundation stars awakened")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }

                    ProgressView(value: gamificationManager.gatewayFoundationProgress, total: 1)
                        .tint(.cyan)

                    Label("Open constellation", systemImage: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.cyan.opacity(0.58), ZenWavePalette.electricPurple.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: ZenWavePalette.electricPurple.opacity(0.32), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Your constellation. \(gamificationManager.gatewayFoundationCompletedCount) of \(gamificationManager.gatewayFoundationSteps.count) stars awakened. Open constellation."
        )
    }

    private var heroCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("ZenWave", systemImage: "waveform.path.ecg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("\(gamificationManager.currentStreak) day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Text("Find your next state.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Choose a focus, begin a ritual, and let the rest wait.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))

                HStack {
                    Image(systemName: selectedIntent.iconName)
                    Text("For \(selectedIntent.title)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedIntent.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(selectedIntent.color.opacity(reduceTransparency ? 0.18 : 0.28)))
            }
        }
    }

    private var todaysSignalSection: some View {
        let signal = RitualPreset.dailySignal(for: selectedIntent)
        let nextStep = gamificationManager.nextGatewayFoundationStep

        return LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("TODAY'S SIGNAL", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(signal.accent)
                        Text(signal.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(signal.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("1 min")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(signal.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(signal.accent.opacity(0.20)))
                }

                Text("A small return counts. Start here, then choose more depth when you want it.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Button {
                    startDailySignal(signal)
                } label: {
                    Label(
                        activeDailySignalID == signal.id && isPlaying ? "Signal Playing" : "Begin 60s Signal",
                        systemImage: activeDailySignalID == signal.id && isPlaying ? "waveform" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(signal.accent)

                if let nextStep {
                    Divider().overlay(Color.white.opacity(0.12))
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(ZenWavePalette.electricPurple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gateway Foundations · Day \(gamificationManager.gatewayFoundationCompletedCount + 1) of \(gamificationManager.gatewayFoundationSteps.count)")
                                .font(.caption.weight(.semibold))
                            Text("Next: \(nextStep.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open") {
                            if storeManager.isPremiumUnlocked {
                                openGatewayFoundationStep(nextStep)
                            } else {
                                showPaywall(feature: "Gateway Foundations")
                            }
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ZenWavePalette.electricPurple)
                    }
                } else {
                    Label("Gateway Foundations complete", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var quickAudioRitualsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Quick Start",
                subtitle: "Simple sound sessions when you want to begin immediately."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(BinauralSession.allSessions) { session in
                        SessionCard(
                            session: session,
                            isSelected: selectedAudioSession?.title == session.title
                        ) {
                            AppLog.info("Quick audio ritual tapped: \(session.title)")
                            requirePremium(feature: "ZenWave audio rituals") {
                                stopRitual()
                                selectedAudioSession = session
                            }
                        }
                        .frame(width: 172)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var recommendedRitualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader(
                    title: "Recommended for you",
                    subtitle: "A focused ritual for the state you chose."
                )
                Button("Browse") {
                    libraryDestination = .presets
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ZenWavePalette.electricPurple)
            }
            intentStrip
            activeRitualCard
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

    private var dashboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Deeper Paths",
                subtitle: "Guided sessions, progression work, and reflection tools."
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                DashboardShortcutCard(
                    title: "Gateway",
                    subtitle: "Guided focus states",
                    iconName: "sparkles",
                    color: .cyan
                ) {
                    openGuidedRitual(GuidedRitual.gatewayRituals.first)
                }

                DashboardShortcutCard(
                    title: "Quantum Codes",
                    subtitle: "Intention rituals",
                    iconName: "number",
                    color: .purple
                ) {
                    openGuidedRitual(GuidedRitual.quantumCodeRituals.first)
                }

                DashboardShortcutCard(
                    title: "Astral Path",
                    subtitle: "Ranks and practice",
                    iconName: "eye.fill",
                    color: .indigo
                ) {
                    if storeManager.isPremiumUnlocked {
                        startRecommendedAstralPractice()
                    } else {
                        showPaywall(feature: "Astral Path")
                    }
                }

                DashboardShortcutCard(
                    title: "Journal",
                    subtitle: "\(journalEntries.count) saved",
                    iconName: "book.closed.fill",
                    color: .teal
                ) {
                    if !storeManager.isPremiumUnlocked {
                        showPaywall(feature: "journal")
                    }
                }
            }
        }
    }

    private var guidedRitualExplorerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader(
                    title: "Guided Rituals",
                    subtitle: "Swipe through a path, then begin when one feels right."
                )
                Button("View all") {
                    libraryDestination = .guided
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ZenWavePalette.electricPurple)
            }

            HStack(spacing: 8) {
                guidedModuleButton(.gateway, icon: "sparkles")
                guidedModuleButton(.quantumCodes, icon: "number.circle.fill")
            }

            TabView {
                ForEach(rituals(for: selectedGuidedModule)) { ritual in
                    GuidedRitualPagerCard(ritual: ritual) {
                        openGuidedRitual(ritual)
                    }
                    .padding(.horizontal, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 236)
        }
    }

    private var practiceSummarySection: some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Your practice", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ZenWavePalette.electricPurple)
                        Text(gamificationManager.currentRank.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(gamificationManager.currentStreak) day streak · \(gamificationManager.totalSessions) sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 10) {
                    Button {
                        libraryDestination = .practice
                    } label: {
                        Label("Practice path", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        libraryDestination = .journal
                    } label: {
                        Label("Journal", systemImage: "book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func guidedModuleButton(_ module: GuidedRitualModule, icon: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                selectedGuidedModule = module
            }
        } label: {
            Label(module == .gateway ? "Gateway" : "Quantum", systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedGuidedModule == module ? .white : .white.opacity(0.70))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(selectedGuidedModule == module ? ZenWavePalette.electricPurple.opacity(0.45) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selectedGuidedModule == module ? ZenWavePalette.electricPurple.opacity(0.78) : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func rituals(for module: GuidedRitualModule) -> [GuidedRitual] {
        switch module {
        case .gateway:
            return GuidedRitual.gatewayRituals
        case .quantumCodes:
            return GuidedRitual.quantumCodeRituals
        case .manifestation:
            return []
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var astralPathSection: some View {
        VStack(spacing: 14) {
            AstralPathSummaryCard(
                gamificationManager: gamificationManager,
                isPremiumUnlocked: storeManager.isPremiumUnlocked
            ) {
                if storeManager.isPremiumUnlocked {
                    startRecommendedAstralPractice()
                } else {
                    showPaywall(feature: "Astral Path")
                }
            }

            AstralBadgeGrid(
                gamificationManager: gamificationManager,
                isPremiumUnlocked: storeManager.isPremiumUnlocked
            )

            AstralRankPathView(
                gamificationManager: gamificationManager,
                isPremiumUnlocked: storeManager.isPremiumUnlocked
            ) { _ in
                if storeManager.isPremiumUnlocked {
                    startRecommendedAstralPractice()
                } else {
                    showPaywall(feature: "Astral Path")
                }
            }
        }
    }

    private var activeRitualCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
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

                Text("A \(selectedRitual.durationMinutes) minute sound ritual for \(selectedIntent.shortTitle.lowercased()).")
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

    private func ritualGrid(scrollProxy: ScrollViewProxy) -> some View {
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
                        selectRitual(ritual, scrollProxy: scrollProxy)
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
                    RainbowInfoButtonLabel()
                }
                .buttonStyle(.plain)
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

    private func selectRitual(_ ritual: RitualPreset, scrollProxy: ScrollViewProxy) {
        selectRitual(ritual)

        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.42)) {
                scrollProxy.scrollTo(Self.recommendedRitualScrollID, anchor: .top)
            }
        }
    }

    private func rotateRecommendedRitualIfNeeded() {
        guard homeRecommendationLastLaunchID != Self.launchID else {
            if selectedRitual.intent != selectedIntent {
                rotateRecommendedRitual(advance: false)
            }
            return
        }

        homeRecommendationLastLaunchID = Self.launchID
        rotateRecommendedRitual(advance: true)
    }

    private func rotateRecommendedRitual(advance: Bool) {
        let intentMatches = RitualPreset.all.filter { $0.intent == selectedIntent }
        let pool = intentMatches.isEmpty ? RitualPreset.all : intentMatches
        guard !pool.isEmpty else { return }

        if advance {
            homeRecommendationRotationIndex += 1
        }

        let index = abs(homeRecommendationRotationIndex) % pool.count
        selectedRitual = pool[index]
    }

    private func openGuidedRitual(_ ritual: GuidedRitual?) {
        guard let ritual else { return }
        requirePremium(feature: ritual.module.title) {
            stopRitual()
            selectedGuidedRitual = ritual
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
            let chakra = chakraTone(frequency: frequency, chakraName: chakraName)
            toneGenerator.playLoopingAudioFile(
                fileName: chakra.audioFileName,
                title: ritual.title,
                subtitle: "\(Int(frequency)) Hz \(chakraName) chakra ritual",
                kind: .chakra
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
        dailySignalTimer?.invalidate()
        dailySignalTimer = nil
        activeDailySignalID = nil
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
        let completedDays = current + 1
        challengeProgress[challenge.id] = completedDays
        saveProgress()
        gamificationManager.recordChallengeProgress(
            challengeID: challenge.id,
            completedDays: completedDays,
            dayCount: challenge.dayCount,
            title: challenge.title
        )
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
        if entry.presetID.hasPrefix("daily-signal-") && !storeManager.isPremiumUnlocked {
            gamificationManager.recordCompletion(
                kind: .generator,
                title: entry.presetTitle,
                ritualID: entry.presetID,
                module: "Daily Signal"
            )
            completedRitual = nil
            return
        }

        guard storeManager.isPremiumUnlocked else {
            showPaywall(feature: "journal")
            return
        }

        let kind: GamificationCompletionKind
        if entry.module == GuidedRitualModule.gateway.rawValue {
            kind = .guidedGateway
        } else if entry.module == GuidedRitualModule.quantumCodes.rawValue {
            kind = .quantumCode
        } else if entry.module == GuidedRitualModule.manifestation.rawValue {
            kind = .manifestation
        } else {
            kind = .ritualPreset
        }

        gamificationManager.recordCompletion(
            kind: kind,
            title: entry.presetTitle,
            ritualID: entry.ritualID ?? entry.presetID,
            module: entry.module
        )
        if entry.module == GuidedRitualModule.gateway.rawValue {
            gamificationManager.recordGatewayFoundationCompletion(ritualID: entry.ritualID ?? entry.presetID)
        }
        gamificationManager.recordCompletion(
            kind: .journal,
            title: "\(entry.presetTitle) Journal",
            ritualID: entry.ritualID ?? entry.presetID,
            module: entry.module
        )

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

    private func frequencies(for type: BrainwaveType) -> (left: Double, right: Double) {
        switch type {
        case .beta:
            return (800.0, 808.0)
        case .gamma:
            return (1600.0, 1630.0)
        case .delta:
            return (100.0, 104.0)
        case .theta:
            return (200.0, 204.0)
        case .alpha:
            return (400.0, 404.0)
        }
    }

    private func chakraTone(frequency: Double, chakraName: String) -> ChakraTone {
        ChakraTone.allChakras.first { chakra in
            Int(chakra.frequency) == Int(frequency) || chakra.name.localizedCaseInsensitiveContains(chakraName)
        } ?? ChakraTone.allChakras[0]
    }

    private func startRecommendedAstralPractice() {
        if let nextStep = gamificationManager.nextGatewayFoundationStep {
            openGatewayFoundationStep(nextStep)
            return
        }
        let targetTitle = gamificationManager.recommendedNextPracticeTitle
        if let ritual = GuidedRitual.gatewayRituals.first(where: { $0.title == targetTitle }) {
            selectedGuidedRitual = ritual
            return
        }

        selectedGuidedRitual = GuidedRitual.gatewayRituals.first { $0.id == "astral-projection-prep-guided" }
    }

    private func startDailySignal(_ signal: RitualPreset) {
        guard !(activeDailySignalID == signal.id && isPlaying) else { return }
        stopRitual()
        activeChallenge = nil
        selectedRitual = signal
        activeDailySignalID = signal.id
        startRitual(signal)

        dailySignalTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in
            guard activeDailySignalID == signal.id else { return }
            stopRitual()
            completedRitual = signal
        }
        dailySignalTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func openGatewayFoundationStep(_ step: PracticeJourneyStep) {
        guard let ritual = GuidedRitual.gatewayRituals.first(where: { $0.id == step.ritualID }) else { return }
        stopRitual()
        selectedGuidedRitual = ritual
    }

}

private struct MeditationPortalView: View {
    let accent: Color
    let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let duration = isPlaying ? 3.8 : 5.6
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: duration) / duration
                let breath = (sin(phase * .pi * 2 - .pi / 2) + 1) / 2

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: size * 0.78, height: size * 0.78)
                        .blur(radius: 34)

                    ForEach(0..<6, id: \.self) { index in
                        let ripplePhase = (phase + Double(index) / 6.0)
                            .truncatingRemainder(dividingBy: 1)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.72), accent.opacity(0.82), ZenWavePalette.electricPurple.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: index == 0 ? 2.4 : 1.2
                            )
                            .frame(
                                width: size * (0.34 + CGFloat(index) * 0.085),
                                height: size * (0.34 + CGFloat(index) * 0.085)
                            )
                            .opacity(0.92 - Double(index) * 0.10)
                            .scaleEffect(isPlaying ? 0.96 + ripplePhase * 0.12 : 0.96 + breath * 0.08)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.95), .cyan.opacity(0.70), accent.opacity(0.20), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.20
                            )
                        )
                        .frame(width: size * 0.34, height: size * 0.34)
                        .scaleEffect(0.88 + breath * 0.24)

                    Image(systemName: isPlaying ? "waveform" : "figure.mind.and.body")
                        .font(.system(size: size * 0.14, weight: .light))
                        .foregroundStyle(.white)
                        .shadow(color: accent, radius: 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct FullScreenRitualWaveField: View {
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            GeometryReader { geometry in
                let diagonal = hypot(geometry.size.width, geometry.size.height)
                let time = context.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(0..<7, id: \.self) { index in
                        let phase = (time / 6.5 + Double(index) / 7.0)
                            .truncatingRemainder(dividingBy: 1)
                        let diameter = 90 + diagonal * 1.28 * phase
                        let fade = sin(phase * .pi)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.52), accent.opacity(0.62), ZenWavePalette.electricPurple.opacity(0.46)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: diameter, height: diameter)
                            .opacity(fade * 0.34)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.38)
            }
        }
    }
}

private enum HomeLibraryDestination: String, Identifiable {
    case presets
    case guided
    case practice
    case journal

    var id: String { rawValue }
}

private struct GuidedRitualPagerCard: View {
    let ritual: GuidedRitual
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 30, showParticles: true) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(
                            ritual.module == .gateway ? "Gateway-inspired" : "Quantum code ritual",
                            systemImage: ritual.module == .gateway ? "sparkles" : "number.circle.fill"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ritual.accent)
                        Spacer()
                        Text("\(ritual.durationMinutes)m")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(ritual.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(ritual.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(ritual.codeSequence.isEmpty ? ritual.frequencyLabel : ritual.codeLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ritual.accent)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Label("Begin ritual", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(ritual.accent.opacity(0.32)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RitualPresetLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedRitualID: String
    let onSelect: (RitualPreset) -> Void

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(RitualPreset.all) { ritual in
                        RitualPresetCard(ritual: ritual, isSelected: ritual.id == selectedRitualID) {
                            dismiss()
                            DispatchQueue.main.async {
                                onSelect(ritual)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Ritual Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct GuidedRitualLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModule: GuidedRitualModule
    let onSelect: (GuidedRitual) -> Void
    let onLearn: (EducationTopic) -> Void

    init(
        initialModule: GuidedRitualModule,
        onSelect: @escaping (GuidedRitual) -> Void,
        onLearn: @escaping (EducationTopic) -> Void
    ) {
        _selectedModule = State(initialValue: initialModule)
        self.onSelect = onSelect
        self.onLearn = onLearn
    }

    private var rituals: [GuidedRitual] {
        selectedModule == .gateway ? GuidedRitual.gatewayRituals : GuidedRitual.quantumCodeRituals
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Picker("Ritual type", selection: $selectedModule) {
                        Text("Gateway").tag(GuidedRitualModule.gateway)
                        Text("Quantum").tag(GuidedRitualModule.quantumCodes)
                    }
                    .pickerStyle(.segmented)

                    ForEach(rituals) { ritual in
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSelect(ritual)
                            }
                        } label: {
                            GuidedRitualLibraryRow(ritual: ritual)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Guided Rituals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    let topic: EducationTopic = selectedModule == .gateway ? .gateway : .quantumCodes
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onLearn(topic)
                    }
                } label: {
                    Image(systemName: "info.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct GuidedRitualLibraryRow: View {
    let ritual: GuidedRitual

    var body: some View {
        LiquidGlassCard(cornerRadius: 24, showParticles: false) {
            HStack(spacing: 14) {
                Image(systemName: ritual.module == .gateway ? "sparkles" : "number.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ritual.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ritual.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(ritual.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(ritual.codeSequence.isEmpty ? ritual.frequencyLabel : ritual.codeLine)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ritual.accent)
                        .lineLimit(1)
                }

                Spacer()
                Text("\(ritual.durationMinutes)m")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }
}

private struct PracticeHubView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gamificationManager: GamificationManager
    let isPremiumUnlocked: Bool
    let challenges: [RitualChallenge]
    let challengeProgress: [String: Int]
    let activeChallengeID: String?
    let onPractice: () -> Void
    let onChallenge: (RitualChallenge) -> Void
    @State private var showsConstellation = false

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    AstralPathSummaryCard(
                        gamificationManager: gamificationManager,
                        isPremiumUnlocked: isPremiumUnlocked,
                        onPrimaryAction: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onPractice()
                            }
                        }
                    )

                    GatewayFoundationsMapView(
                        gamificationManager: gamificationManager,
                        isPremiumUnlocked: isPremiumUnlocked
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPractice()
                        }
                    } onOpenConstellation: {
                        showsConstellation = true
                    }

                    AstralBadgeGrid(
                        gamificationManager: gamificationManager,
                        isPremiumUnlocked: isPremiumUnlocked
                    )

                    AstralRankPathView(
                        gamificationManager: gamificationManager,
                        isPremiumUnlocked: isPremiumUnlocked
                    ) { _ in
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPractice()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenges")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        ForEach(challenges) { challenge in
                            ChallengeCard(
                                challenge: challenge,
                                completedDays: challengeProgress[challenge.id, default: 0],
                                isActive: activeChallengeID == challenge.id
                            ) {
                                dismiss()
                                DispatchQueue.main.async {
                                    onChallenge(challenge)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Your Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .fullScreenCover(isPresented: $showsConstellation) {
            GatewayConstellationView(
                gamificationManager: gamificationManager,
                isPremiumUnlocked: isPremiumUnlocked
            ) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onPractice()
                }
            }
        }
    }
}

private struct JournalLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [RitualJournalEntry]
    let isPremiumUnlocked: Bool
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if !isPremiumUnlocked {
                        LiquidGlassCard(cornerRadius: 28, showParticles: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Premium Journal", systemImage: "lock.fill")
                                    .font(.headline)
                                Text("Keep intentions, moods, dream notes, and ritual reflections together.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("Unlock Journal") {
                                    dismiss()
                                    DispatchQueue.main.async {
                                        onUnlock()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(ZenWavePalette.electricPurple)
                            }
                        }
                    } else if entries.isEmpty {
                        ContentUnavailableView(
                            "No reflections yet",
                            systemImage: "book.closed",
                            description: Text("Complete a ritual to save your intention, mood, and notes.")
                        )
                        .foregroundStyle(.white)
                        .padding(.top, 80)
                    } else {
                        ForEach(entries) { entry in
                            LiquidGlassCard(cornerRadius: 24, showParticles: false) {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(entry.presetTitle)
                                            .font(.headline)
                                        Spacer()
                                        Text(entry.dateLabel)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !entry.intention.isEmpty {
                                        Text(entry.intention)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.82))
                                    }
                                    if !entry.notes.isEmpty {
                                        Text(entry.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
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

struct DashboardShortcutCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            LiquidGlassCard(cornerRadius: 26, showParticles: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: iconName)
                            .font(.title3)
                            .foregroundStyle(color)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 96)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(reduceMotion ? 1.0 : 1.0)
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
    let allowsJournal: Bool
    let onSave: (RitualJournalEntry) -> Void

    @State private var moodBefore = 3.0
    @State private var moodAfter = 4.0
    @State private var intention = ""
    @State private var notes = ""

    private var shareText: String {
        var parts = [
            "Completed \(ritual.title)",
            "\(ritual.frequencyLabel) in ZenWave"
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
                        if allowsJournal {
                            journalCard
                        } else {
                            freeCompletionCard
                        }
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
                    Button(allowsJournal ? "Save" : "Done") {
                        save()
                    }
                }
            }
        }
    }

    private var sharePreviewCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(spacing: 16) {
                Text("ZenWave")
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

    private var freeCompletionCard: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: false) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Signal captured", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(ritual.accent)
                Text("Your session and streak progress will update when you finish. Premium adds reflections, guided paths, and saved ritual notes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .environmentObject(StoreManager())
            .environmentObject(GamificationManager())
    }
}

struct ManifestationHubView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var gamificationManager: GamificationManager
    @AppStorage("ritualJournalEntries") private var ritualJournalEntriesData = "[]"

    @State private var activeChakra: ChakraTone?
    @State private var isAmbientEnabled = true
    @State private var selectedAmbientSoundID = AmbientSoundOption.defaultOption.id
    @State private var progressionStepDuration: Double = 45
    @State private var isProgressionRunning = false
    @State private var progressionIndex = 0
    @State private var progressionSecondsRemaining = 0
    @State private var progressionTask: Task<Void, Never>?
    @State private var showingChakraInfo = false
    @State private var paywallFeature: PaywallFeature?
    @State private var hasPreparedAmbientVolume = false
    @State private var isProgressionExpanded = false
    @State private var isSoundMixExpanded = false
    @State private var manifestationDestination: ManifestationDestination?
    @State private var selectedManifestationMantra: ManifestationMantra?
    @State private var selectedManifestationRitual: GuidedRitual?

    private var selectedAmbientSound: AmbientSoundOption {
        AmbientSoundOption.option(id: selectedAmbientSoundID)
    }

    private var progressionDisclosure: some View {
        DisclosureGroup(isExpanded: $isProgressionExpanded) {
            progressionCard
                .padding(.top, 10)
        } label: {
            Label("Chakra progression", systemImage: "arrow.up.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .tint(.teal)
        .padding(.horizontal, 4)
    }

    private var soundMixDisclosure: some View {
        DisclosureGroup(isExpanded: $isSoundMixExpanded) {
            VStack(spacing: 18) {
                ambientCard
                equalizerCard
            }
            .padding(.top, 10)
        } label: {
            Label("Ambient and sound mix", systemImage: "slider.horizontal.below.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .tint(.teal)
        .padding(.horizontal, 4)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        hubHeader
                        dailyManifestationSection
                        mantraLibrarySection
                        createManifestationButton
                        chakraSectionHeader
                        chakraCards
                        progressionDisclosure
                        soundMixDisclosure
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 42)
                }
            }
            .navigationTitle("Manifest")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingChakraInfo) {
                EducationInfoView(topic: .chakras)
            }
            .sheet(item: $paywallFeature) { feature in
                PaywallView(feature: feature)
                    .environmentObject(storeManager)
            }
            .fullScreenCover(item: $manifestationDestination) { destination in
                switch destination {
                case .daily:
                    DailyManifestationView(
                        onBeginRitual: beginManifestationRitual,
                        onOpenBuilder: openManifestationBuilder,
                        onPlayMantra: beginManifestationMantra
                    )
                case .builder:
                    ManifestationBuilderView(onCreateRitual: beginManifestationRitual)
                }
            }
            .fullScreenCover(item: $selectedManifestationMantra) { mantra in
                ManifestationMantraSessionView(mantra: mantra)
            }
            .fullScreenCover(item: $selectedManifestationRitual) { ritual in
                GuidedRitualSessionView(
                    ritual: ritual,
                    onSave: saveManifestationJournalEntry
                )
            }
            .onDisappear {
                AppLog.info("Chakra view disappeared; active chakra and progression audio remain playing")
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

    private var hubHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MANIFESTATION PRACTICE", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.cyan)

            Text("Shape the signal you return to.")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            Text("Start with today's intention, choose a spoken mantra, or pair reflection with a chakra tone.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dailyManifestationSection: some View {
        let daily = ManifestationAffirmation.daily

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Today's Manifestation",
                subtitle: "A fresh intention and a three-minute guided ritual."
            )

            LiquidGlassCard(cornerRadius: 28, showParticles: true) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label(daily.theme.title.uppercased(), systemImage: daily.theme.systemImage)
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(daily.theme.accent)

                        Spacer()

                        Text("TODAY")
                            .font(.caption2.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Text(daily.text)
                        .font(.system(size: 27, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(daily.reflectionPrompt)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            beginManifestationRitual(daily)
                        } label: {
                            Label("Begin", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(daily.theme.accent)

                        Button {
                            manifestationDestination = .daily
                        } label: {
                            Label("Explore", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
            }
        }
    }

    private var mantraLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Manifestation Library",
                subtitle: "Long-form spoken mantras with a gentle binaural sound bed."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(ManifestationMantra.library) { mantra in
                        Button {
                            beginManifestationMantra(mantra)
                        } label: {
                            mantraCard(mantra)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play \(mantra.title)")
                    }
                }
                .padding(.vertical, 3)
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private func mantraCard(_ mantra: ManifestationMantra) -> some View {
        LiquidGlassCard(cornerRadius: 24, showParticles: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.and.mic")
                        .font(.title2)
                        .foregroundStyle(mantra.accent)

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 0)

                Text(mantra.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(mantra.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: 210, height: 176)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(mantra.accent.opacity(0.42), lineWidth: 1)
        )
    }

    private var createManifestationButton: some View {
        Button {
            openManifestationBuilder()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a Manifestation")
                        .font(.headline)
                    Text("Choose an intention and shape the words around it.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [ZenWavePalette.deepPurple.opacity(0.78), ZenWavePalette.electricPurple.opacity(0.46)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var chakraSectionHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            sectionTitle(
                "Chakra Tones",
                subtitle: "Swipe to choose one of seven reflective sound anchors."
            )

            Spacer(minLength: 8)

            Button {
                AppLog.info("Chakra info button tapped")
                showingChakraInfo = true
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.cyan)
            .accessibilityLabel("Learn About Chakras")
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
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
                        Text("Blend \(selectedAmbientSound.title.lowercased()) ambience underneath chakra bells.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .teal))
                .onChange(of: isAmbientEnabled) { _, _ in
                    AppLog.info("Chakra ambient toggle changed: \(isAmbientEnabled)")
                    updateAmbientPlayback()
                }

                ambientSoundSelector
                    .opacity(isAmbientEnabled ? 1 : 0.56)
                    .disabled(!isAmbientEnabled)

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

    private var ambientSoundSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AmbientSoundOption.available) { sound in
                    let isSelected = selectedAmbientSoundID == sound.id
                    let isLocked = sound.isPremium && !storeManager.isPremiumUnlocked

                    Button {
                        selectAmbientSound(sound)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: isLocked ? "lock.fill" : sound.systemImage)
                            Text(sound.title)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.78))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.teal.opacity(0.34) : Color.white.opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.teal.opacity(0.72) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var chakraCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
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
            .padding(.vertical, 3)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private func chakraCard(_ chakra: ChakraTone) -> some View {
        let isActive = activeChakra == chakra

        return LiquidGlassCard(cornerRadius: 30, showParticles: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(chakra.color.opacity(0.20))
                            .frame(width: 42, height: 42)
                        Circle()
                            .fill(chakra.color)
                            .frame(width: 12, height: 12)
                            .shadow(color: chakra.color, radius: isActive ? 10 : 4)
                    }

                    Spacer()

                    Image(systemName: isActive && !isProgressionRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(chakra.color)
                }

                Text(chakra.commentTag.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(chakra.color)

                Text(chakra.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(chakra.chakraName)
                    Text("·")
                    Text("\(Int(chakra.frequency)) Hz")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

                Spacer(minLength: 0)

                Text(chakra.meaning)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)

                if isProgressionRunning && isActive {
                    Label("LIVE", systemImage: "waveform")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(chakra.color)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: 214, height: 218)
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

    private func openManifestationBuilder() {
        guard storeManager.isPremiumUnlocked else {
            manifestationDestination = nil
            presentManifestationPaywall(after: 0.25)
            return
        }

        manifestationDestination = .builder
    }

    private func beginManifestationRitual(_ affirmation: ManifestationAffirmation) {
        guard storeManager.isPremiumUnlocked else {
            manifestationDestination = nil
            presentManifestationPaywall(after: 0.25)
            return
        }

        let ritual = GuidedRitual.manifestationRitual(affirmation: affirmation)
        manifestationDestination = nil
        toneGenerator.stop()
        audioManager.stopNature()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            selectedManifestationRitual = ritual
        }
    }

    private func beginManifestationMantra(_ mantra: ManifestationMantra) {
        guard storeManager.isPremiumUnlocked else {
            manifestationDestination = nil
            presentManifestationPaywall(after: 0.25)
            return
        }

        manifestationDestination = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            selectedManifestationMantra = mantra
        }
    }

    private func presentManifestationPaywall(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            AppLog.info("Paywall requested from Manifest hub")
            paywallFeature = .premiumRituals
        }
    }

    private func saveManifestationJournalEntry(_ entry: RitualJournalEntry) {
        guard storeManager.isPremiumUnlocked else {
            paywallFeature = .premiumRituals
            return
        }

        gamificationManager.recordCompletion(
            kind: .manifestation,
            title: entry.presetTitle,
            ritualID: entry.ritualID ?? entry.presetID,
            module: entry.module
        )
        gamificationManager.recordCompletion(
            kind: .journal,
            title: "\(entry.presetTitle) Journal",
            ritualID: entry.ritualID ?? entry.presetID,
            module: entry.module
        )

        var entries: [RitualJournalEntry] = []
        if let data = ritualJournalEntriesData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([RitualJournalEntry].self, from: data) {
            entries = decoded
        }

        entries.insert(entry, at: 0)
        let trimmed = Array(entries.prefix(50))
        guard let data = try? JSONEncoder().encode(trimmed),
              let encoded = String(data: data, encoding: .utf8) else { return }
        ritualJournalEntriesData = encoded
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
        toneGenerator.playLoopingAudioFile(
            fileName: chakra.audioFileName,
            title: chakra.name,
            subtitle: "\(Int(chakra.frequency)) Hz - comment: \(chakra.commentTag)",
            kind: .chakra
        )
        activeChakra = chakra
        updateAmbientPlayback()

        if !isProgressionRunning {
            gamificationManager.recordCompletion(
                kind: .chakra,
                title: chakra.name,
                ritualID: "chakra-\(chakra.commentTag.replacingOccurrences(of: " ", with: "-"))",
                module: "Chakra"
            )
        }
    }

    private func updateAmbientPlayback() {
        if isAmbientEnabled && (activeChakra != nil || isProgressionRunning) {
            prepareAudibleAmbientVolumeIfNeeded()
            audioManager.playNature(fileName: selectedAmbientSound.fileName)
        } else {
            audioManager.stopNature()
        }
    }

    private func prepareAudibleAmbientVolumeIfNeeded() {
        guard !hasPreparedAmbientVolume else { return }
        hasPreparedAmbientVolume = true

        if audioManager.natureVolume < 0.15 {
            audioManager.setNatureVolume(0.18)
        }
    }

    private func selectAmbientSound(_ sound: AmbientSoundOption) {
        guard !sound.isPremium || storeManager.isPremiumUnlocked else {
            paywallFeature = .premiumRituals
            return
        }

        selectedAmbientSoundID = sound.id
        updateAmbientPlayback()
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
                gamificationManager.recordCompletion(
                    kind: .chakraProgression,
                    title: "Timed Chakra Progression",
                    ritualID: "chakra-progression",
                    module: "Chakra"
                )
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
    @EnvironmentObject private var gamificationManager: GamificationManager
    @EnvironmentObject private var notificationManager: RitualNotificationManager
    @State private var selectedTab: Tab = .lotus
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
                case .manifest:
                    ManifestationHubView()
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
        .onChange(of: selectedTab) { oldTab, newTab in
            AppLog.info("Tab changed from \(oldTab.rawValue) to \(newTab.rawValue); preserving shared audio")
            toneGenerator.maintainPlayback()
            audioManager.maintainPlayback()
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $gamificationManager.shouldOfferReminderSetup) {
            ReminderSetupView()
                .environmentObject(gamificationManager)
                .environmentObject(notificationManager)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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

                Text(toneGenerator.currentSoundSubtitle ?? "Choose a sound to begin.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if horizontalSizeClass == .regular {
                Slider(
                    value: Binding(
                        get: { Double(toneGenerator.volume) },
                        set: { toneGenerator.setVolume(Float($0)) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .tint(.cyan)
                .frame(width: 110)
                .disabled(!hasSound)
                .opacity(hasSound ? 1.0 : 0.45)
                .accessibilityLabel("Sound volume")
            }

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
                .opacity(0.60)
                .overlay(ZenWavePalette.toolbarGradient.opacity(0.72))
                .overlay(Color.black.opacity(0.06))
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
    case manifest = "Manifest"
    case lotus = "Home"
    case profile = "Settings"

    var icon: NavigationIcon {
        switch self {
        case .waves: return .waves
        case .manifest: return .manifest
        case .lotus: return .lotus
        case .profile: return .profile
        }
    }

    var isFree: Bool {
        switch self {
        case .waves, .lotus, .profile:
            return true
        case .manifest:
            return false
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let requestTab: (Tab) -> Void
    @EnvironmentObject private var storeManager: StoreManager
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
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon.systemName)
                            .navigationIcon(size: 22)
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                            .scaleEffect(selectedTab == tab && !reduceMotion ? 1.06 : 1.0)

                        Text(tab.rawValue)
                            .font(.caption2.weight(selectedTab == tab ? .bold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                    )
                    .overlay(alignment: .topTrailing) {
                        if !tab.isFree && !storeManager.isPremiumUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.cyan)
                                .padding(5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .frame(height: 68)
        .frame(maxWidth: 380)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.60)
                .overlay(ZenWavePalette.toolbarGradient.opacity(0.72))
                .overlay(Color.black.opacity(0.05))
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

private struct RainbowInfoButtonLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    .cyan,
                                    .blue,
                                    .purple,
                                    .pink,
                                    .orange,
                                    .yellow,
                                    .cyan
                                ],
                                center: .center
                            ),
                            lineWidth: 1.4
                        )
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .opacity(0.92)
                )
                .shadow(color: .cyan.opacity(0.28), radius: 10, y: 4)

            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.94))
                .shadow(color: .black.opacity(0.28), radius: 4, y: 2)

            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.08),
                    .cyan.opacity(0.34),
                    .pink.opacity(0.32),
                    .yellow.opacity(0.20),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 72, height: 18)
            .rotationEffect(.degrees(-28))
            .offset(x: isAnimating ? 42 : -42)
            .blendMode(.screen)
            .mask(Circle())
        }
        .frame(width: 38, height: 38)
        .contentShape(Circle())
        .scaleEffect(isAnimating && !reduceMotion ? 1.04 : 1.0)
        .onAppear {
            guard !reduceMotion else {
                isAnimating = true
                return
            }

            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
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
            .navigationTitle("Sound Sessions")
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
    @Environment(\.dismiss) private var dismiss

    let session: BinauralSession
    let leftFrequency: Double
    let rightFrequency: Double

    @State private var isNatureEnabled = false
    @State private var isBinauralOverlayEnabled = false
    @State private var binauralOverlayVolume: Double = 0.10
    @State private var selectedTimerOption: RitualTimerOption = .openEnded
    @State private var elapsedSeconds = 0
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
                                Text(progressStatusText)
                                    .font(.headline)
                                    .monospacedDigit()
                            }
                        }
                    }

                    timerCard

                    if isUsingAudioFile {
                        binauralOverlayCard
                    }

                    if session.natureFile != nil {
                        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                            VStack(alignment: .leading, spacing: 16) {
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
                                .onChange(of: isNatureEnabled) { _, _ in
                                    syncNatureLayerPlayback()
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Label("Nature Volume", systemImage: "speaker.wave.2.fill")
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(Int(audioManager.natureVolume * 100))%")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }

                                    Slider(
                                        value: Binding(
                                            get: { Double(audioManager.natureVolume) },
                                            set: { audioManager.setNatureVolume(Float($0)) }
                                        ),
                                        in: 0...0.6
                                    )
                                    .tint(.blue)
                                }
                                .opacity(isNatureEnabled ? 1 : 0.55)
                                .disabled(!isNatureEnabled)
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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    stopSession()
                    dismiss()
                }
            }
        }
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
                audioManager.stopNature()
            }
        }
        .onChange(of: selectedTimerOption) { _, _ in
            elapsedSeconds = 0
            progress = 0
            if isPlaying {
                startProgressTimer()
            }
        }
        .onChange(of: binauralOverlayVolume) { _, newValue in
            if isBinauralOverlayEnabled {
                toneGenerator.setVolume(Float(newValue))
            }
        }
    }

    private var equalizerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual Equalizer")
                    .font(.title3.weight(.semibold))

                Text("Tune the current ritual mix to smooth harsher frequencies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                EqualizerBarsView(
                    lowGain: activeLowGain,
                    midGain: activeMidGain,
                    highGain: activeHighGain
                )

                equalizerSliderRow(
                    title: "Low",
                    color: .blue,
                    value: Binding(
                        get: { Double(activeLowGain) },
                        set: { setActiveEqualizer(low: Float($0)) }
                    )
                )

                equalizerSliderRow(
                    title: "Mid",
                    color: .cyan,
                    value: Binding(
                        get: { Double(activeMidGain) },
                        set: { setActiveEqualizer(mid: Float($0)) }
                    )
                )

                equalizerSliderRow(
                    title: "High",
                    color: .orange,
                    value: Binding(
                        get: { Double(activeHighGain) },
                        set: { setActiveEqualizer(high: Float($0)) }
                    )
                )

                HStack(spacing: 12) {
                    Button("Softer Mix") {
                        applyActiveSofterEQPreset()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Flat") {
                        resetActiveEqualizer()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var isUsingAudioFile: Bool {
        session.binauralFile != nil
    }

    private var playbackSummary: String {
        if isUsingAudioFile {
            return "\(session.brainwaveType.rawValue) ZenWave audio track"
        }

        return "\(session.brainwaveType.rawValue) binaural beat - \(String(format: "%.1f", abs(rightFrequency - leftFrequency))) Hz"
    }

    private var progressStatusText: String {
        if isPlaying, selectedTimerOption.duration != nil {
            return remainingTimeText
        }

        return "\(Int(progress))%"
    }

    private var remainingTimeText: String {
        guard let duration = selectedTimerOption.duration else {
            return "Open"
        }

        let remaining = max(0, Int(duration) - elapsedSeconds)
        return formattedDuration(TimeInterval(remaining))
    }

    private var timerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Session Timer")
                            .font(.headline)
                        Text(timerDetailText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: selectedTimerOption.duration == nil ? "infinity" : "timer")
                        .font(.title2)
                        .foregroundStyle(session.icon.color)
                }

                Picker("Session Timer", selection: $selectedTimerOption) {
                    ForEach(RitualTimerOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var timerDetailText: String {
        if isPlaying, selectedTimerOption.duration != nil {
            return "Stops automatically in \(remainingTimeText)."
        }

        return selectedTimerOption.subtitle
    }

    private var binauralOverlayCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $isBinauralOverlayEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Binaural Overlay")
                            .font(.headline)
                        Text("Add a true stereo \(session.brainwaveType.rawValue.lowercased()) beat under the ritual track.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: session.icon.color))
                .onChange(of: isBinauralOverlayEnabled) { _, _ in
                    syncBinauralOverlayPlayback()
                }

                if isBinauralOverlayEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Overlay Volume", systemImage: "waveform")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(binauralOverlayVolume * 100))%")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $binauralOverlayVolume, in: 0...0.5)
                            .tint(session.icon.color)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var activeLowGain: Float {
        isUsingAudioFile ? audioManager.eqLowGain : toneGenerator.eqLowGain
    }

    private var activeMidGain: Float {
        isUsingAudioFile ? audioManager.eqMidGain : toneGenerator.eqMidGain
    }

    private var activeHighGain: Float {
        isUsingAudioFile ? audioManager.eqHighGain : toneGenerator.eqHighGain
    }

    private func setActiveEqualizer(low: Float? = nil, mid: Float? = nil, high: Float? = nil) {
        if isUsingAudioFile {
            audioManager.setEqualizer(low: low, mid: mid, high: high)
        } else {
            toneGenerator.setEqualizer(low: low, mid: mid, high: high)
        }
    }

    private func applyActiveSofterEQPreset() {
        if isUsingAudioFile {
            audioManager.applySofterEQPreset()
        } else {
            toneGenerator.applySofterEQPreset()
        }
    }

    private func resetActiveEqualizer() {
        if isUsingAudioFile {
            audioManager.resetEqualizer()
        } else {
            toneGenerator.resetEqualizer()
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
                        Text(isPlaying ? "Sound Is Playing" : "Start Ritual Sound")
                            .font(.headline)
                        Text(playbackSummary)
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
        audioManager.stopAll()
        toneGenerator.stop()
        elapsedSeconds = 0
        progress = 0
        isPlaying = true

        if let binauralFile = session.binauralFile {
            audioManager.playBinaural(fileName: binauralFile)
        } else {
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: leftFrequency,
                rightFreq: rightFrequency,
                title: session.title,
                subtitle: playbackSummary
            )
        }

        syncBinauralOverlayPlayback()
        syncNatureLayerPlayback()
        startProgressTimer()
    }

    private func syncBinauralOverlayPlayback() {
        guard isPlaying, isUsingAudioFile, isBinauralOverlayEnabled else {
            if isUsingAudioFile {
                toneGenerator.stop()
            }
            return
        }

        toneGenerator.setVolume(Float(binauralOverlayVolume))
        toneGenerator.generateContinuousBinauralBeat(
            leftFreq: leftFrequency,
            rightFreq: rightFrequency,
            title: "\(session.title) Overlay",
            subtitle: "\(session.brainwaveType.rawValue) overlay - \(String(format: "%.1f", abs(rightFrequency - leftFrequency))) Hz beat"
        )
    }

    private func syncNatureLayerPlayback() {
        guard isPlaying, isNatureEnabled, let natureFile = session.natureFile else {
            audioManager.stopNature()
            return
        }

        if isNatureEnabled {
            audioManager.playNature(fileName: natureFile)
        }
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
        elapsedSeconds = 0
        toneGenerator.stop()
        audioManager.stopAll()
    }

    private func resetSession() {
        stopSession()
        isNatureEnabled = false
        isBinauralOverlayEnabled = false
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        timer?.invalidate()
        let sessionTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1

            if let duration = selectedTimerOption.duration {
                progress = min(100, (Double(elapsedSeconds) / duration) * 100)
                if Double(elapsedSeconds) >= duration {
                    stopSession()
                }
            } else {
                progress = min(100, progress + 1)
            }
        }
        timer = sessionTimer
        RunLoop.main.add(sessionTimer, forMode: .common)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private enum RitualTimerOption: String, CaseIterable, Identifiable {
    case openEnded
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes
    case sixtyMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openEnded:
            return "Open Ended"
        case .tenMinutes:
            return "10 Minutes"
        case .fifteenMinutes:
            return "15 Minutes"
        case .thirtyMinutes:
            return "30 Minutes"
        case .sixtyMinutes:
            return "60 Minutes"
        }
    }

    var subtitle: String {
        switch self {
        case .openEnded:
            return "Plays until you stop the ritual."
        default:
            return "Stops the ritual automatically after \(title.lowercased())."
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .openEnded:
            return nil
        case .tenMinutes:
            return 10 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .sixtyMinutes:
            return 60 * 60
        }
    }
}
