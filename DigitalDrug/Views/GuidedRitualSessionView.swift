//
//  GuidedRitualSessionView.swift
//  DigitalDrug
//

import SwiftUI

struct GuidedRitualSessionView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var voiceManager: GuidedVoiceManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let ritual: GuidedRitual
    let onSave: (RitualJournalEntry) -> Void

    @State private var isPlaying = false
    @State private var elapsed: TimeInterval = 0
    @State private var playbackAnchorDate: Date?
    @State private var playbackAnchorElapsed: TimeInterval = 0
    @State private var activeStepIndex = 0
    @State private var completedStepIDs = Set<String>()
    @State private var timer: Timer?
    @State private var showCompletion = false
    @State private var isNatureLayerEnabled = false
    @State private var selectedNatureSoundID = GuidedRitualNatureSoundOption.defaultOption.id
    @State private var isSoundOptionsExpanded = false
    @State private var isSessionDetailsExpanded = false

    private let firstVoicePromptDelay: TimeInterval = 15

    private var activeStep: GuidedRitualStep {
        ritual.steps[safe: activeStepIndex] ?? ritual.steps[0]
    }

    private var progress: Double {
        guard ritual.duration > 0 else { return 0 }
        return min(elapsed / ritual.duration, 1)
    }

    private var remaining: TimeInterval {
        max(ritual.duration - elapsed, 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        sessionTopBar
                        immersiveSessionStage
                        activePromptSection
                        sessionControlDeck
                        sessionDetailsDisclosure
                        disclaimerCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 42)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCompletion) {
                GuidedRitualCompletionView(
                    ritual: ritual,
                    voiceEnabled: voiceManager.isVoiceEnabled,
                    onSave: { entry in
                        onSave(entry)
                        stopSession()
                        dismiss()
                    }
                )
            }
        }
        .onAppear {
            loadNatureLayerPreference()
        }
        .onDisappear {
            stopSession()
        }
        .onChange(of: toneGenerator.isPlaying) { _, newValue in
            if !newValue {
                elapsed = currentPlaybackElapsed()
                playbackAnchorDate = nil
                playbackAnchorElapsed = elapsed
                isPlaying = false
                timer?.invalidate()
                timer = nil
                voiceManager.stop()
                audioManager.stopNature()
            }
        }
        .onChange(of: isNatureLayerEnabled) { _, _ in
            saveNatureLayerPreference()
            syncNatureLayerPlayback()
        }
        .onChange(of: selectedNatureSoundID) { _, _ in
            saveNatureLayerPreference()
            syncNatureLayerPlayback()
        }
    }

    private var sessionTopBar: some View {
        ZStack {
            VStack(spacing: 4) {
                Text(ritual.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(ritual.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 48)

            HStack {
                Button {
                    stopSession()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Close")

                Spacer()

                Text("\(ritual.durationMinutes)m")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ritual.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
        }
    }

    private var immersiveSessionStage: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isPlaying)) { context in
            let displayProgress = visualProgress(at: context.date)

            ZStack {
                Circle()
                    .fill(ritual.accent.opacity(0.16))
                    .frame(width: 290, height: 290)
                    .blur(radius: 38)

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.72), ritual.accent.opacity(0.72), ZenWavePalette.electricPurple.opacity(0.66)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: index == 0 ? 2.2 : 1
                        )
                        .frame(width: CGFloat(150 + index * 36), height: CGFloat(150 + index * 36))
                        .opacity(0.90 - Double(index) * 0.12)
                }

                if ritual.module == .manifestation {
                    ManifestationPulseVisual(
                        accent: ritual.accent,
                        isActive: isPlaying,
                        date: context.date
                    )
                    .frame(width: 224, height: 224)
                } else {
                    GuidedRitualVisual(kind: activeStep.visualKind, accent: ritual.accent, isActive: isPlaying)
                        .frame(width: 224, height: 224)
                }

                Circle()
                    .trim(from: 0, to: max(displayProgress, 0.015))
                    .stroke(
                        LinearGradient(colors: [.cyan, ritual.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 322, height: 322)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(height: 340)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(progress * 100)) percent complete")
    }

    private var activePromptSection: some View {
        VStack(spacing: 12) {
            Text("\(timeLabel(remaining)) remaining")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.cyan)

            Text(activeStep.spokenPrompt)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(activeStep.title)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, ritual.accent], startPoint: .leading, endPoint: .trailing)
                )
        }
    }

    private var sessionControlDeck: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 34) {
                sessionToggleButton(
                    title: "Voice",
                    stateLabel: voiceManager.isVoiceEnabled ? "On" : "Off",
                    icon: voiceManager.isVoiceEnabled ? "person.wave.2.fill" : "speaker.slash.fill"
                ) {
                    voiceManager.isVoiceEnabled.toggle()
                    if !voiceManager.isVoiceEnabled {
                        voiceManager.stop()
                    }
                }

                Button {
                    AppLog.info("Guided ritual primary control tapped: \(ritual.title), action=\(isPlaying ? "pause" : "start")")
                    isPlaying ? pauseSession() : startSession()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .bold))
                            .frame(width: 86, height: 86)
                            .background(
                                Circle().fill(
                                    RadialGradient(colors: [ritual.accent.opacity(0.58), Color.black.opacity(0.84)], center: .center, startRadius: 0, endRadius: 54)
                                )
                            )
                            .overlay(Circle().strokeBorder(LinearGradient(colors: [.cyan, ritual.accent], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
                            .shadow(color: ritual.accent.opacity(0.48), radius: 18)
                        Text(isPlaying ? "Pause" : elapsed > 0 ? "Resume" : "Begin")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                sessionToggleButton(
                    title: "Ambient",
                    stateLabel: isNatureLayerEnabled ? "On" : "Off",
                    icon: "water.waves"
                ) {
                    isNatureLayerEnabled.toggle()
                }
            }

            ProgressView(value: progress, total: 1)
                .tint(ritual.accent)

            HStack {
                Button("Stop", role: .destructive) {
                    stopSession()
                }
                .font(.caption.weight(.semibold))

                Spacer()

                Button {
                    showCompletion = true
                } label: {
                    Label("Complete + Journal", systemImage: "checkmark.circle.fill")
                }
                .font(.caption.weight(.semibold))
                .disabled(elapsed < 10)
            }
        }
        .padding(.top, 4)
    }

    private func sessionToggleButton(
        title: String,
        stateLabel: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.black.opacity(0.44)))
                    .overlay(Circle().strokeBorder(ritual.accent.opacity(0.72)))
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(stateLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .frame(width: 74)
    }

    private var sessionDetailsDisclosure: some View {
        DisclosureGroup(isExpanded: $isSessionDetailsExpanded) {
            VStack(spacing: 18) {
                stepTimeline
                natureSoundDisclosure
            }
            .padding(.top, 14)
        } label: {
            Label("Session details", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .tint(ritual.accent)
        .padding(.top, 8)
    }

    private var headerCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(ritual.module.badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ritual.accent)
                    Spacer()
                    Text("\(ritual.durationMinutes)m")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(ritual.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(ritual.subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.78))

                Text(ritual.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(ritual.frequencyLabel, systemImage: "waveform")
                    if !ritual.codeSequence.isEmpty {
                        Label(ritual.codeLine, systemImage: "number")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ritual.accent)
                .lineLimit(2)
            }
        }
    }

    private var visualCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: false) {
            VStack(spacing: 18) {
                GuidedRitualVisual(kind: activeStep.visualKind, accent: ritual.accent, isActive: isPlaying)
                    .frame(height: 220)

                VStack(spacing: 8) {
                    Text(activeStep.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text(activeStep.spokenPrompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ProgressView(value: progress, total: 1)
                    .tint(ritual.accent)

                HStack {
                    Text(timeLabel(elapsed))
                    Spacer()
                    Text(timeLabel(ritual.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private var stepTimeline: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Guided Prompts")
                    .font(.headline)

                ForEach(Array(ritual.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Image(systemName: index <= activeStepIndex ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index <= activeStepIndex ? ritual.accent : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline.weight(.semibold))
                            Text(timeLabel(voiceStartTime(forStepAt: index)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var controlsCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        AppLog.info("Guided ritual control tapped: \(ritual.title), action=\(isPlaying ? "pause" : "start")")
                        isPlaying ? pauseSession() : startSession()
                    } label: {
                        Label(isPlaying ? "Pause" : "Start", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ritual.accent)

                    Button {
                        AppLog.info("Guided ritual stop tapped: \(ritual.title)")
                        stopSession()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    AppLog.info("Guided ritual complete tapped: \(ritual.title), elapsed=\(elapsed)")
                    showCompletion = true
                } label: {
                    Label("Complete + Journal", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(elapsed < 10)

                Toggle(isOn: $voiceManager.isVoiceEnabled) {
                    Label("Guided Voice", systemImage: voiceManager.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .toggleStyle(SwitchToggleStyle(tint: ritual.accent))
            }
        }
    }

    private var natureSoundDisclosure: some View {
        DisclosureGroup(isExpanded: $isSoundOptionsExpanded) {
            natureSoundCard
                .padding(.top, 12)
        } label: {
            Label("Sound mix", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(ritual.accent)
        .padding(.horizontal, 4)
    }

    private var natureSoundCard: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: false) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $isNatureLayerEnabled.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))) {
                    Label(
                        "Nature Sound",
                        systemImage: isNatureLayerEnabled ? "leaf.fill" : "leaf"
                    )
                    .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: ritual.accent))

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedNatureSound.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Blend ambient texture with this ritual.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        ForEach(GuidedRitualNatureSoundOption.available) { sound in
                            Button {
                                selectedNatureSoundID = sound.id
                            } label: {
                                Label(sound.title, systemImage: sound.systemImage)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedNatureSound.systemImage)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 54, height: 40)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isNatureLayerEnabled || GuidedRitualNatureSoundOption.available.count <= 1)
                }
                .opacity(isNatureLayerEnabled ? 1 : 0.58)
            }
        }
    }

    private var disclaimerCard: some View {
        LiquidGlassCard(cornerRadius: 24, showParticles: false) {
            Text(ritual.safeDisclaimer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func startSession() {
        AppLog.info("Guided ritual start requested: \(ritual.module.title) - \(ritual.title), elapsed=\(elapsed)")
        playbackAnchorElapsed = elapsed
        playbackAnchorDate = Date()
        isPlaying = true

        if elapsed == 0 {
            startAudio()
        } else {
            resumeAudio()
        }

        speakCurrentStepIfDue()
        startTimer()
    }

    private func pauseSession() {
        AppLog.info("Guided ritual pause requested: \(ritual.title)")
        elapsed = currentPlaybackElapsed()
        playbackAnchorDate = nil
        playbackAnchorElapsed = elapsed
        isPlaying = false
        timer?.invalidate()
        timer = nil
        voiceManager.stop()
        toneGenerator.pause()
        audioManager.stopAll()
    }

    private func stopSession() {
        AppLog.info("Guided ritual stop requested: \(ritual.title)")
        timer?.invalidate()
        timer = nil
        isPlaying = false
        elapsed = 0
        playbackAnchorDate = nil
        playbackAnchorElapsed = 0
        activeStepIndex = 0
        completedStepIDs.removeAll()
        voiceManager.stop()
        toneGenerator.stop()
        audioManager.stopAll()
    }

    private func startAudio() {
        AppLog.info("Guided ritual start audio requested: \(ritual.title), frequency=\(ritual.frequencyLabel)")
        audioManager.stopAll()
        toneGenerator.stop()
        let guidedToneBedVolumeScale: Float = 0.33

        switch ritual.audioKind {
        case .binaural(let left, let right):
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: left,
                rightFreq: right,
                title: ritual.title,
                subtitle: "\(ritual.module.title) - \(ritual.frequencyLabel)",
                volumeScale: guidedToneBedVolumeScale
            )
        case .chakra(let frequency, let chakraName):
            let chakra = chakraTone(frequency: frequency, chakraName: chakraName)
            toneGenerator.playLoopingAudioFile(
                fileName: chakra.audioFileName,
                title: ritual.title,
                subtitle: "\(ritual.module.title) - \(Int(frequency)) Hz \(chakraName)",
                kind: .chakra,
                volumeScale: guidedToneBedVolumeScale
            )
        }

        syncNatureLayerPlayback()
    }

    private func chakraTone(frequency: Double, chakraName: String) -> ChakraTone {
        ChakraTone.allChakras.first { chakra in
            Int(chakra.frequency) == Int(frequency) || chakra.name.localizedCaseInsensitiveContains(chakraName)
        } ?? ChakraTone.allChakras[0]
    }

    private func resumeAudio() {
        if toneGenerator.isPlaying {
            AppLog.info("Guided ritual resume skipped because tone generator is already playing: \(ritual.title)")
            return
        }
        AppLog.info("Guided ritual resume audio requested: \(ritual.title)")
        startAudio()
    }

    private var selectedNatureSound: GuidedRitualNatureSoundOption {
        GuidedRitualNatureSoundOption.available.first { $0.id == selectedNatureSoundID }
            ?? GuidedRitualNatureSoundOption.defaultOption
    }

    private var natureEnabledDefaultsKey: String {
        "guidedRitualNatureSoundEnabled.\(ritual.id)"
    }

    private var natureSelectionDefaultsKey: String {
        "guidedRitualNatureSoundSelection.\(ritual.id)"
    }

    private func loadNatureLayerPreference() {
        let defaults = UserDefaults.standard
        isNatureLayerEnabled = defaults.bool(forKey: natureEnabledDefaultsKey)
        selectedNatureSoundID = defaults.string(forKey: natureSelectionDefaultsKey)
            ?? GuidedRitualNatureSoundOption.defaultOption.id
    }

    private func saveNatureLayerPreference() {
        let defaults = UserDefaults.standard
        defaults.set(isNatureLayerEnabled, forKey: natureEnabledDefaultsKey)
        defaults.set(selectedNatureSoundID, forKey: natureSelectionDefaultsKey)
    }

    private func syncNatureLayerPlayback() {
        guard isPlaying, isNatureLayerEnabled else {
            audioManager.stopNature()
            return
        }

        audioManager.playNature(fileName: selectedNatureSound.fileName)
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            elapsed = currentPlaybackElapsed()
            updateActiveStep()

            if elapsed >= ritual.duration {
                showCompletion = true
                pauseSession()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func currentPlaybackElapsed(at date: Date = Date()) -> TimeInterval {
        guard isPlaying, let playbackAnchorDate else { return elapsed }
        return min(playbackAnchorElapsed + date.timeIntervalSince(playbackAnchorDate), ritual.duration)
    }

    private func visualProgress(at date: Date) -> Double {
        guard ritual.duration > 0 else { return 0 }
        return min(currentPlaybackElapsed(at: date) / ritual.duration, 1)
    }

    private func updateActiveStep() {
        let nextIndex = ritual.steps.lastIndex(where: { elapsed >= $0.startTime }) ?? 0
        if nextIndex != activeStepIndex {
            activeStepIndex = nextIndex
        }
        speakCurrentStepIfDue()
    }

    private func speakCurrentStepIfDue() {
        guard elapsed >= voiceStartTime(forStepAt: activeStepIndex) else { return }
        guard !completedStepIDs.contains(activeStep.id) else { return }
        completedStepIDs.insert(activeStep.id)
        voiceManager.speak(
            activeStep.spokenPrompt,
            module: ritual.module,
            intent: ritual.intent,
            isCodePrompt: ritual.module == .quantumCodes || activeStep.visualKind == .codePulse,
            bundledAssetBaseName: bundledVoiceAssetBaseName(for: activeStep)
        )
    }

    private func voiceStartTime(forStepAt index: Int) -> TimeInterval {
        guard ritual.steps.indices.contains(index) else { return 0 }
        let stepStartTime = ritual.steps[index].startTime
        return index == 0 ? max(stepStartTime, firstVoicePromptDelay) : stepStartTime
    }

    private func bundledVoiceAssetBaseName(for step: GuidedRitualStep) -> String {
        switch ritual.module {
        case .gateway:
            let ritualSlug = ritual.id.replacingOccurrences(of: "-guided", with: "")
            return "gateway-\(ritualSlug)-\(step.id)"
        case .quantumCodes:
            return "quantum-\(ritual.id)-\(step.id)"
        case .manifestation:
            if step.id == "affirm" || step.id == "action" {
                let affirmationID = ritual.id.replacingOccurrences(of: "manifestation-", with: "")
                return "manifestation-\(affirmationID)-\(step.id)"
            }
            return "manifestation-\(step.id)"
        }
    }

    private func timeLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

private struct GuidedRitualNatureSoundOption: Identifiable, Hashable {
    let id: String
    let title: String
    let fileName: String
    let systemImage: String

    static let all: [GuidedRitualNatureSoundOption] = [
        .init(id: "ocean", title: "Ocean", fileName: "Ocean.wav", systemImage: "water.waves"),
        .init(id: "tropical-rain", title: "Tropical Rain", fileName: "tropical_rain.m4a", systemImage: "cloud.rain.fill"),
        .init(id: "river-valley", title: "River Valley", fileName: "river_valley.m4a", systemImage: "water.waves"),
        .init(id: "thunderstorm", title: "Thunderstorm", fileName: "thunderstorm.m4a", systemImage: "cloud.bolt.rain.fill"),
        .init(id: "forest-ambience", title: "Forest Ambience", fileName: "forest_ambience.m4a", systemImage: "leaf.fill"),
        .init(id: "underwater", title: "Underwater", fileName: "underwater.m4a", systemImage: "drop.fill"),
        .init(id: "continuous-river", title: "Continuous River", fileName: "continuous_river.m4a", systemImage: "water.waves")
    ]

    static var available: [GuidedRitualNatureSoundOption] {
        let bundledSounds = all.filter { sound in
            Bundle.main.url(forResource: sound.fileName, withExtension: nil) != nil
                || Bundle.main.url(forResource: sound.fileName, withExtension: nil, subdirectory: "NatureSounds") != nil
                || Bundle.main.url(forResource: sound.fileName, withExtension: nil, subdirectory: "Audio/NatureSounds") != nil
        }
        return bundledSounds.isEmpty ? all : bundledSounds
    }

    static var defaultOption: GuidedRitualNatureSoundOption {
        available.first ?? all[0]
    }
}

private struct ManifestationPulseVisual: View {
    let accent: Color
    let isActive: Bool
    let date: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let cycleDuration = 5.5
        let time = date.timeIntervalSinceReferenceDate
        let cycle = reduceMotion || !isActive
            ? 0.28
            : time.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        let breath = (sin(cycle * .pi * 2 - .pi / 2) + 1) / 2

        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = (cycle + Double(index) / 3.0)
                    .truncatingRemainder(dividingBy: 1)
                let diameter = 92 + phase * 132
                let fade = sin(phase * .pi)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.72), accent.opacity(0.82), .cyan.opacity(0.52)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
                    .frame(width: diameter, height: diameter)
                    .opacity(fade * 0.72)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.96), accent.opacity(0.72), accent.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 104, height: 104)
                .scaleEffect(0.82 + breath * 0.22)
                .shadow(color: accent.opacity(0.62), radius: 24 + breath * 12)

            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white)
                .scaleEffect(0.94 + breath * 0.10)
                .shadow(color: accent, radius: 12)
        }
    }
}

private struct GuidedRitualVisual: View {
    let kind: GuidedRitualVisualKind
    let accent: Color
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            switch kind {
            case .breathOrb:
                breathOrb
            case .releaseBox:
                releaseBox
            case .bodyMap:
                bodyMap
            case .energyField:
                energyField
            case .countdown:
                countdown
            case .pattern:
                pattern
            case .codePulse:
                codePulse
            case .grounding:
                grounding
            }
        }
        .onAppear { startAnimation() }
        .onChange(of: isActive) { _, _ in startAnimation() }
    }

    private var breathOrb: some View {
        Circle()
            .fill(accent.opacity(0.22))
            .overlay(Circle().stroke(accent.opacity(0.75), lineWidth: 2))
            .frame(width: animate ? 170 : 108, height: animate ? 170 : 108)
            .shadow(color: accent.opacity(0.45), radius: 28)
    }

    private var releaseBox: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(accent.opacity(0.8), lineWidth: 2)
            .background(RoundedRectangle(cornerRadius: 18).fill(accent.opacity(0.12)))
            .frame(width: 150, height: 110)
            .overlay(Image(systemName: "archivebox.fill").font(.system(size: 44)).foregroundStyle(accent))
            .rotation3DEffect(.degrees(animate ? 4 : -4), axis: (x: 0, y: 1, z: 0))
    }

    private var bodyMap: some View {
        VStack(spacing: 10) {
            Circle().fill(accent.opacity(0.3)).frame(width: 42, height: 42)
            RoundedRectangle(cornerRadius: 30).fill(accent.opacity(0.22)).frame(width: 72, height: 120)
        }
        .overlay(
            Circle()
                .stroke(accent.opacity(animate ? 0.2 : 0.75), lineWidth: 2)
                .frame(width: animate ? 210 : 140, height: animate ? 210 : 140)
        )
    }

    private var energyField: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(accent.opacity(0.62 - Double(index) * 0.16), lineWidth: 2)
                    .frame(width: animate ? CGFloat(130 + index * 52) : CGFloat(90 + index * 38))
            }
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(accent)
        }
    }

    private var countdown: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.18), lineWidth: 18).frame(width: 170, height: 170)
            Circle()
                .trim(from: 0, to: animate ? 1 : 0.25)
                .stroke(accent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(-90))
            Text("10")
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var pattern: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 58))
                .foregroundStyle(accent)
            RoundedRectangle(cornerRadius: 16)
                .fill(accent.opacity(0.22))
                .frame(width: animate ? 210 : 150, height: 18)
        }
    }

    private var codePulse: some View {
        VStack(spacing: 16) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 62))
                .foregroundStyle(accent)
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(accent.opacity(animate || index.isMultiple(of: 2) ? 0.9 : 0.35))
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private var grounding: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 58))
                .foregroundStyle(accent)
            Text("Return")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        guard !animate else { return }
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
            animate = true
        }
    }
}

private struct GuidedRitualCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gamificationManager: GamificationManager
    let ritual: GuidedRitual
    let voiceEnabled: Bool
    let onSave: (RitualJournalEntry) -> Void

    @State private var moodBefore = 3.0
    @State private var moodAfter = 4.0
    @State private var intention = ""
    @State private var notes = ""
    @State private var sensations = ""

    private var shareText: String {
        [
            "Completed \(ritual.title)",
            ritual.module.title,
            ritual.codeSequence.isEmpty ? ritual.frequencyLabel : "\(ritual.codeLine) - \(ritual.frequencyLabel)",
            "ZenWave"
        ].joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        shareCard
                        journeyRewardCard
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
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private var shareCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: false) {
            VStack(spacing: 14) {
                Text("ZenWave")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ritual.accent)
                Text(ritual.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(ritual.module.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(ritual.codeSequence.isEmpty ? ritual.frequencyLabel : ritual.codeLine)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ritual.accent)
                    .multilineTextAlignment(.center)
                ShareLink(item: shareText) {
                    Label("Share Text Card", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ritual.accent)
            }
        }
    }

    private var journalCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Journal")
                    .font(.title3.weight(.semibold))
                slider(title: "Mood Before", value: $moodBefore)
                slider(title: "Mood After", value: $moodAfter)
                TextField("Intention", text: $intention, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                TextField("Sensations, visuals, or body state", text: $sensations, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    @ViewBuilder
    private var journeyRewardCard: some View {
        if let reward = gamificationManager.gatewayFoundationReward(for: ritual.id) {
            LiquidGlassCard(cornerRadius: 30, showParticles: true) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(ritual.accent)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(ritual.accent.opacity(0.18)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gateway Foundations · Day \(reward.completedDay)")
                            .font(.headline)
                        if let nextStep = reward.nextStep {
                            Text("Next node unlocked: \(nextStep.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("You completed the full foundation path.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func slider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): \(Int(value.wrappedValue))/5")
                .font(.caption.weight(.semibold))
            Slider(value: value, in: 1...5, step: 1)
                .tint(ritual.accent)
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
                notes: notes,
                module: ritual.module.rawValue,
                ritualID: ritual.id,
                voiceEnabled: voiceEnabled,
                observedSensations: sensations
            )
        )
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
