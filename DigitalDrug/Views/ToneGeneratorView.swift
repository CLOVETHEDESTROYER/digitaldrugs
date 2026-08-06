//
//  ToneGeneratorView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct ToneGeneratorView: View {
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var gamificationManager: GamificationManager
    @State private var generatorMode: GeneratorMode = .binaural
    @State private var leftFrequency: Double = 440.0
    @State private var rightFrequency: Double = 450.0
    @State private var carrierFrequency: Double = 440.0
    @State private var pulseFrequency: Double = 10.0
    @State private var selectedPreset: FrequencyPreset? = nil
    @State private var showingFrequencyInfo = false
    @State private var isAmbientEnabled = false
    @State private var selectedAmbientSoundID = AmbientSoundOption.defaultOption.id
    @State private var paywallFeature: PaywallFeature?
    @State private var progressRecordingTask: Task<Void, Never>?
    @State private var hasPreparedAmbientVolume = false
    @State private var isFrequencyControlsExpanded = false
    @State private var isSoundMixExpanded = false

    var binauralBeatFrequency: Double {
        abs(rightFrequency - leftFrequency)
    }

    private var formattedBeat: String {
        String(format: "%.1f", generatorMode == .binaural ? binauralBeatFrequency : pulseFrequency)
    }

    private var selectedAmbientSound: AmbientSoundOption {
        AmbientSoundOption.option(id: selectedAmbientSoundID)
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    modePicker
                    signalStage
                    presetCarousel
                    frequencyControlsDisclosure
                    soundMixDisclosure
                }
                .padding(.top, 76)
                .padding(.bottom, 48)
                .padding(.horizontal, 24)
            }
            .sheet(isPresented: $showingFrequencyInfo) {
                FrequencyInfoView()
            }
            .sheet(item: $paywallFeature) { feature in
                PaywallView(feature: feature)
                    .environmentObject(storeManager)
            }
        }
        .onChange(of: toneGenerator.isPlaying) { _, isPlaying in
            if !isPlaying {
                progressRecordingTask?.cancel()
                progressRecordingTask = nil
                audioManager.stopNature()
            }
        }
        .onDisappear {
            progressRecordingTask?.cancel()
            progressRecordingTask = nil
            AppLog.info("Generator view disappeared; active audio remains under the shared player")
        }
    }

    private func selectPreset(_ preset: FrequencyPreset, startPlayback: Bool = true) {
        selectedPreset = preset
        leftFrequency = preset.leftFrequency
        rightFrequency = preset.rightFrequency
        carrierFrequency = preset.leftFrequency
        pulseFrequency = preset.beatFrequency

        guard startPlayback else { return }

        switch generatorMode {
        case .binaural:
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: preset.leftFrequency,
                rightFreq: preset.rightFrequency,
                title: preset.rawValue,
                subtitle: "\(preset.binauralSummary) - \(String(format: "%.1f", preset.beatFrequency)) Hz binaural beat"
            )
        case .pulsed:
            toneGenerator.generatePulsedTone(
                carrierFreq: preset.leftFrequency,
                pulseFreq: preset.beatFrequency,
                title: preset.rawValue,
                subtitle: "\(Int(preset.leftFrequency)) Hz carrier - \(String(format: "%.1f", preset.beatFrequency)) Hz pulsed beat"
            )
        }

        scheduleGeneratorProgressRecord(
            title: "\(preset.rawValue) \(generatorMode.title)",
            ritualID: "generator-\(generatorMode.rawValue)-\(preset.rawValue.lowercased())",
            expectedSoundTitle: preset.rawValue
        )
        syncAmbientLayerPlayback()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ZENWAVE GENERATOR")
                    .font(.caption.weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(generatorMode.accent)

                Text("Shape your state")
                    .font(.system(size: 35, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Text(generatorMode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: generatorMode.iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(generatorMode.accent)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.black.opacity(0.34)))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.42), generatorMode.accent.opacity(0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(GeneratorMode.allCases, id: \.self) { mode in
                Button {
                    generatorMode = mode
                } label: {
                    Label(mode.title, systemImage: mode.iconName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(generatorMode == mode ? .white : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(generatorMode == mode ? mode.selectedGradient : mode.idleGradient)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(generatorMode == mode ? mode.accent.opacity(0.88) : Color.white.opacity(0.12), lineWidth: 1)
                                .allowsHitTesting(false)
                        )
                        .shadow(color: generatorMode == mode ? mode.accent.opacity(0.42) : .clear, radius: 14, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.05))
                .overlay(ZenWavePalette.deepPurple.opacity(0.18))
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .onChange(of: generatorMode) { _, _ in
            if toneGenerator.isPlaying {
                startSelectedMode(recordProgress: false)
            }
        }
    }

    private var signalStage: some View {
        GeneratorGlassPanel(cornerRadius: 30) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedPreset?.rawValue.uppercased() ?? "CUSTOM SIGNAL")
                            .font(.caption.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(selectedPreset?.color ?? generatorMode.accent)
                        Text(toneGenerator.isPlaying ? "Signal active" : "Ready when you are")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()

                    Label(generatorMode.listeningBadge, systemImage: generatorMode.listeningIcon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
                }

                GeneratorSignalField(
                    frequency: generatorMode == .binaural ? binauralBeatFrequency : pulseFrequency,
                    mode: generatorMode,
                    accent: selectedPreset?.color ?? generatorMode.accent,
                    isPlaying: toneGenerator.isPlaying
                )
                .frame(height: 168)

                HStack(spacing: 12) {
                    signalMetric(
                        title: generatorMode == .binaural ? "LEFT" : "CARRIER",
                        value: "\(Int(generatorMode == .binaural ? leftFrequency : carrierFrequency)) Hz",
                        color: .cyan
                    )

                    signalMetric(
                        title: generatorMode == .binaural ? "RIGHT" : "PULSE",
                        value: generatorMode == .binaural ? "\(Int(rightFrequency)) Hz" : "\(formattedBeat) Hz",
                        color: generatorMode.accent
                    )
                }

                Button(action: toggleGeneratorPlayback) {
                    Label(
                        toneGenerator.isPlaying ? "Pause signal" : "Begin signal",
                        systemImage: toneGenerator.isPlaying ? "pause.fill" : "play.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(generatorMode.selectedGradient, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.28)))
                    .shadow(color: generatorMode.accent.opacity(0.34), radius: 16, y: 7)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func signalMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(0.26))
        )
    }

    private var frequencyControls: some View {
        GeneratorGlassPanel(cornerRadius: 34) {
            VStack(spacing: 24) {
                Text("Frequency Controls")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if generatorMode == .binaural {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Left Ear Frequency")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(leftFrequency)) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $leftFrequency, in: 20...2000, step: 1)
                            .tint(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Right Ear Frequency")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(rightFrequency)) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $rightFrequency, in: 20...2000, step: 1)
                            .tint(ZenWavePalette.electricPurple)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Carrier Frequency")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(carrierFrequency)) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $carrierFrequency, in: 80...1200, step: 1)
                            .tint(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pulse Rate")
                                .font(.headline)
                            Spacer()
                            Text("\(formattedBeat) Hz")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $pulseFrequency, in: 0.5...40, step: 0.5)
                            .tint(generatorMode.accent)
                    }
                }
            }
        }
    }

    private var frequencyControlsDisclosure: some View {
        VStack(spacing: 12) {
            disclosureButton(
                title: "Tune frequencies",
                subtitle: generatorMode == .binaural ? "Adjust the left and right channels" : "Adjust the carrier and pulse",
                icon: "slider.horizontal.3",
                isExpanded: isFrequencyControlsExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isFrequencyControlsExpanded.toggle()
                }
            }

            if isFrequencyControlsExpanded {
                frequencyControls
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var soundMixDisclosure: some View {
        VStack(spacing: 12) {
            disclosureButton(
                title: "Layer your sound",
                subtitle: "Ambient textures and tone shaping",
                icon: "slider.horizontal.below.rectangle",
                isExpanded: isSoundMixExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isSoundMixExpanded.toggle()
                }
            }

            if isSoundMixExpanded {
                VStack(spacing: 18) {
                    ambientLayerControls
                    equalizerControls
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func disclosureButton(
        title: String,
        subtitle: String,
        icon: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(generatorMode.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(generatorMode.accent.opacity(0.13)))
                    .overlay(Circle().strokeBorder(generatorMode.accent.opacity(0.34)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.64))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, 11)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [generatorMode.accent.opacity(0.44), Color.white.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var equalizerControls: some View {
        GeneratorGlassPanel(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual Equalizer")
                    .font(.title3.weight(.semibold))

                Text("Reduce harshness by lowering Mid and High bands.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                EqualizerBarsView(
                    lowGain: toneGenerator.eqLowGain,
                    midGain: toneGenerator.eqMidGain,
                    highGain: toneGenerator.eqHighGain
                )

                equalizerSliderRow(
                    title: "Low",
                    color: .cyan,
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
                    color: ZenWavePalette.electricPurple,
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

    private var ambientLayerControls: some View {
        GeneratorGlassPanel(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $isAmbientEnabled.animation(.easeInOut(duration: 0.2))) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ambient Background Layer")
                            .font(.headline)
                        Text("Ocean is free. Additional bundled nature layers unlock with ZenWave Premium.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: generatorMode.accent))
                .onChange(of: isAmbientEnabled) { _, _ in
                    syncAmbientLayerPlayback()
                }

                ambientSoundSelector
                    .opacity(isAmbientEnabled ? 1 : 0.56)
                    .disabled(!isAmbientEnabled)

                HStack {
                    Text("Ambient Volume")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(audioManager.natureVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(audioManager.natureVolume) },
                        set: { audioManager.setNatureVolume(Float($0)) }
                    ),
                    in: 0...0.6,
                    step: 0.01
                )
                .tint(generatorMode.accent)
                .opacity(isAmbientEnabled ? 1 : 0.55)
                .disabled(!isAmbientEnabled)
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
                                .fill(isSelected ? generatorMode.accent.opacity(0.34) : Color.white.opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? generatorMode.accent.opacity(0.72) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
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

    private var presetCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose a state")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Swipe through brainwave presets")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                Button {
                    showingFrequencyInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Learn about brainwave frequencies")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(FrequencyPreset.allCases, id: \.self) { preset in
                        PresetButton(
                            preset: preset,
                            mode: generatorMode,
                            isSelected: selectedPreset == preset,
                            isPlaying: selectedPreset == preset && toneGenerator.isPlaying
                        ) {
                            selectPreset(preset)
                        }
                        .frame(width: 210)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
    }

    private func toggleGeneratorPlayback() {
        if toneGenerator.isPlaying {
            toneGenerator.pause()
            audioManager.stopNature()
            return
        }

        let expectedTitle = selectedPreset?.rawValue ?? (generatorMode == .binaural ? "Custom Binaural" : "Custom Pulsed")
        let expectedModeText = generatorMode == .binaural ? "binaural beat" : "pulsed beat"
        let canResumeCurrentSignal = toneGenerator.hasCurrentSound
            && toneGenerator.currentSoundTitle == expectedTitle
            && (toneGenerator.currentSoundSubtitle?.lowercased().contains(expectedModeText) ?? false)

        if canResumeCurrentSignal {
            toneGenerator.resume()
            syncAmbientLayerPlayback()
        } else {
            startSelectedMode(recordProgress: true)
        }
    }

    private func startSelectedMode(recordProgress: Bool = true) {
        switch generatorMode {
        case .binaural:
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: leftFrequency,
                rightFreq: rightFrequency,
                title: selectedPreset?.rawValue ?? "Custom Binaural",
                subtitle: "\(Int(leftFrequency)) - \(Int(rightFrequency)) Hz - \(formattedBeat) Hz binaural beat"
            )
        case .pulsed:
            toneGenerator.generatePulsedTone(
                carrierFreq: carrierFrequency,
                pulseFreq: pulseFrequency,
                title: selectedPreset?.rawValue ?? "Custom Pulsed",
                subtitle: "\(Int(carrierFrequency)) Hz carrier - \(formattedBeat) Hz pulsed beat"
            )
        }
        syncAmbientLayerPlayback()

        if recordProgress {
            let title = selectedPreset?.rawValue ?? (generatorMode == .binaural ? "Custom Binaural" : "Custom Pulsed")
            scheduleGeneratorProgressRecord(
                title: title,
                ritualID: selectedPreset.map { "generator-\(generatorMode.rawValue)-\($0.rawValue.lowercased())" } ?? "generator-\(generatorMode.rawValue)-custom",
                expectedSoundTitle: title
            )
        }
    }

    private func selectAmbientSound(_ sound: AmbientSoundOption) {
        guard !sound.isPremium || storeManager.isPremiumUnlocked else {
            paywallFeature = .premiumRituals
            return
        }

        selectedAmbientSoundID = sound.id
        syncAmbientLayerPlayback()
    }

    private func syncAmbientLayerPlayback() {
        guard isAmbientEnabled, toneGenerator.isPlaying else {
            audioManager.stopNature()
            return
        }

        prepareAudibleAmbientVolumeIfNeeded()
        audioManager.playNature(fileName: selectedAmbientSound.fileName)
    }

    private func prepareAudibleAmbientVolumeIfNeeded() {
        guard !hasPreparedAmbientVolume else { return }
        hasPreparedAmbientVolume = true

        if audioManager.natureVolume < 0.15 {
            audioManager.setNatureVolume(0.18)
        }
    }

    private func scheduleGeneratorProgressRecord(title: String, ritualID: String, expectedSoundTitle: String) {
        progressRecordingTask?.cancel()
        progressRecordingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard !Task.isCancelled,
                  toneGenerator.isPlaying,
                  toneGenerator.currentSoundTitle == expectedSoundTitle else {
                return
            }

            gamificationManager.recordCompletion(
                kind: .generator,
                title: title,
                ritualID: ritualID,
                module: "Generator"
            )
        }
    }

}

private struct GeneratorGlassPanel<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let cornerRadius: CGFloat
    private let content: Content
    private let glassOpacity: CGFloat = 0.50

    init(cornerRadius: CGFloat = 34, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(reduceTransparency ? Color(.secondarySystemBackground).opacity(0.92) : Color.white.opacity(0.022))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(reduceTransparency ? 1 : glassOpacity)
                    )
                    .overlay(ZenWavePalette.toolbarGradient.opacity(reduceTransparency ? 0.08 : 0.06))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(reduceTransparency ? 0.20 : 0.40),
                                Color.cyan.opacity(reduceTransparency ? 0.08 : 0.16),
                                ZenWavePalette.electricPurple.opacity(reduceTransparency ? 0.16 : 0.26),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(reduceTransparency ? 0.0 : 0.24),
                        Color.clear,
                        Color.cyan.opacity(reduceTransparency ? 0.0 : 0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            )
            .shadow(color: ZenWavePalette.deepPurple.opacity(0.16), radius: 22, x: 0, y: 10)
    }
}

private struct GeneratorSignalField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let frequency: Double
    let mode: GeneratorMode
    let accent: Color
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isPlaying)) { context in
            let cycleDuration = mode == .binaural ? 4.2 : 3.2
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration

            ZStack {
                Circle()
                    .fill(accent.opacity(isPlaying ? 0.17 : 0.10))
                    .frame(width: 148, height: 148)
                    .blur(radius: 28)

                ForEach(0..<5, id: \.self) { index in
                    let ringPhase = (phase + Double(index) / 5.0)
                        .truncatingRemainder(dividingBy: 1)
                    let animatedScale = 0.62 + ringPhase * 0.54
                    let animatedOpacity = max(0.08, 0.68 * (1 - ringPhase))

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.82), accent.opacity(0.84), ZenWavePalette.electricPurple.opacity(0.70)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: index == 0 ? 2.0 : 1.1
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(isPlaying && !reduceMotion ? animatedScale : 0.72 + Double(index) * 0.10)
                        .opacity(isPlaying && !reduceMotion ? animatedOpacity : 0.58 - Double(index) * 0.08)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.44), ZenWavePalette.deepPurple.opacity(0.54), Color.black.opacity(0.88)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 58
                        )
                    )
                    .frame(width: 104, height: 104)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.82), accent, .white.opacity(0.42)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: accent.opacity(isPlaying ? 0.48 : 0.24), radius: isPlaying ? 22 : 12)

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", frequency))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("HZ \(mode == .binaural ? "BEAT" : "PULSE")")
                        .font(.caption2.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: "%.1f", frequency)) hertz \(mode == .binaural ? "binaural beat" : "pulse")")
    }
}

enum GeneratorMode: String, CaseIterable {
    case binaural
    case pulsed

    var title: String {
        switch self {
        case .binaural: return "Binaural"
        case .pulsed: return "Pulsed"
        }
    }

    var iconName: String {
        switch self {
        case .binaural: return "headphones"
        case .pulsed: return "waveform.path.ecg"
        }
    }

    var subtitle: String {
        switch self {
        case .binaural:
            return "Stereo frequency rituals for sleep, meditation, and focus"
        case .pulsed:
            return "Rhythmic frequency rituals without headphones"
        }
    }

    var listeningBadge: String {
        switch self {
        case .binaural: return "HEADPHONES"
        case .pulsed: return "SPEAKER READY"
        }
    }

    var listeningIcon: String {
        switch self {
        case .binaural: return "headphones"
        case .pulsed: return "speaker.wave.2.fill"
        }
    }

    var accent: Color {
        switch self {
        case .binaural:
            return .cyan
        case .pulsed:
            return Color(red: 1.0, green: 0.62, blue: 0.18)
        }
    }

    var selectedGradient: LinearGradient {
        switch self {
        case .binaural:
            return LinearGradient(
                colors: [
                    ZenWavePalette.electricPurple.opacity(0.92),
                    Color.cyan.opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pulsed:
            return LinearGradient(
                colors: [
                    ZenWavePalette.deepPurple.opacity(0.92),
                    Color(red: 1.0, green: 0.32, blue: 0.88).opacity(0.72),
                    Color(red: 1.0, green: 0.62, blue: 0.18).opacity(0.70)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var idleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                ZenWavePalette.deepPurple.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Frequency Presets
enum FrequencyPreset: String, CaseIterable {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    case gamma = "Gamma"

    var leftFrequency: Double {
        switch self {
        case .delta: return 100.0
        case .theta: return 200.0
        case .alpha: return 400.0
        case .beta: return 800.0
        case .gamma: return 1600.0
        }
    }

    var rightFrequency: Double {
        switch self {
        case .delta: return 104.0  // 4 Hz binaural beat
        case .theta: return 204.0  // 4 Hz binaural beat
        case .alpha: return 404.0  // 4 Hz binaural beat
        case .beta: return 808.0   // 8 Hz binaural beat
        case .gamma: return 1630.0 // 30 Hz binaural beat
        }
    }

    var beatFrequency: Double {
        abs(rightFrequency - leftFrequency)
    }

    var binauralSummary: String {
        "\(Int(leftFrequency)) - \(Int(rightFrequency)) Hz"
    }

    var frequencyRange: String {
        switch self {
        case .delta: return "0.5 - 4 Hz"
        case .theta: return "4 - 8 Hz"
        case .alpha: return "8 - 12 Hz"
        case .beta: return "12 - 30 Hz"
        case .gamma: return "30 - 100 Hz"
        }
    }

    var color: Color {
        switch self {
        case .delta: return Color(red: 0.58, green: 0.38, blue: 1.0)
        case .theta: return Color(red: 0.10, green: 0.78, blue: 1.0)
        case .alpha: return Color(red: 0.26, green: 0.92, blue: 0.70)
        case .beta: return Color(red: 1.0, green: 0.62, blue: 0.18)
        case .gamma: return Color(red: 1.0, green: 0.32, blue: 0.76)
        }
    }

    var systemImage: String {
        switch self {
        case .delta: return "moon.zzz.fill"
        case .theta: return "sparkles"
        case .alpha: return "leaf.fill"
        case .beta: return "bolt.fill"
        case .gamma: return "brain.head.profile"
        }
    }

    var stateLabel: String {
        switch self {
        case .delta: return "Deep rest"
        case .theta: return "Meditation"
        case .alpha: return "Relaxed focus"
        case .beta: return "Active focus"
        case .gamma: return "Peak focus"
        }
    }

    var benefits: [String] {
        switch self {
        case .delta:
            return [
                "Deep sleep preparation",
                "Physical relaxation",
                "Quieting mental activity",
                "Reflective awareness"
            ]
        case .theta:
            return [
                "Deep meditation states",
                "Creativity and insights",
                "Reprogramming beliefs",
                "Lucid dreaming"
            ]
        case .alpha:
            return [
                "Relaxation and focus",
                "Stress reduction",
                "Accelerated learning",
                "Flow state access"
            ]
        case .beta:
            return [
                "Focused attention",
                "Analytical thinking",
                "Energy and action",
                "High-level cognition"
            ]
        case .gamma:
            return [
                "Peak concentration",
                "Brain synchronization",
                "Better memory",
                "Faster cognition"
            ]
        }
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let preset: FrequencyPreset
    let mode: GeneratorMode
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void
    private let glassOpacity: CGFloat = 0.50

    private var statusText: String {
        let beat = String(format: "%.1f", preset.beatFrequency)
        return isPlaying ? "Playing \(beat) Hz" : "\(beat) Hz \(mode == .binaural ? "beat" : "pulse")"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: preset.systemImage)
                        .font(.headline)
                        .foregroundStyle(preset.color)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(preset.color.opacity(0.14)))
                        .overlay(Circle().strokeBorder(preset.color.opacity(0.40)))
                        .shadow(color: preset.color.opacity(0.22), radius: 10)

                    Spacer()

                    Image(systemName: isPlaying ? "waveform.circle.fill" : isSelected ? "checkmark.circle.fill" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? preset.color : .white.opacity(0.62))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.rawValue)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? preset.color : .white)
                    Text(preset.stateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }

                HStack {
                    Text(preset.frequencyRange)
                    Spacer()
                    Text(statusText)
                }
                    .font(.caption)
                    .foregroundStyle(isSelected ? preset.color : .white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(reduceTransparency ? Color(.secondarySystemBackground).opacity(0.90) : Color.white.opacity(isSelected ? 0.038 : 0.022))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(reduceTransparency ? 1 : glassOpacity)
                    )
                    .overlay(ZenWavePalette.deepPurple.opacity(isSelected ? 0.10 : 0.05))
                    .overlay(preset.color.opacity(isSelected ? 0.14 : 0.05))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isSelected ? 0.42 : 0.24),
                                preset.color.opacity(isSelected ? 0.78 : 0.30),
                                ZenWavePalette.deepPurple.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.3 : 1
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(reduceTransparency ? 0.0 : 0.24),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)
            )
            .shadow(color: preset.color.opacity(isSelected ? 0.28 : 0.10), radius: isSelected ? 18 : 8, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Frequency Information View
struct FrequencyInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(FrequencyPreset.allCases, id: \.self) { preset in
                            FrequencyInfoCard(preset: preset)
                        }
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Brainwave Frequencies")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Frequency Info Card
struct FrequencyInfoCard: View {
    let preset: FrequencyPreset

    var body: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(preset.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(preset.color)

                    Spacer()

                    Text(preset.frequencyRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Benefits:")
                    .font(.headline)
                    .padding(.top, 4)

                ForEach(preset.benefits, id: \.self) { benefit in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(preset.color)
                            .font(.caption)
                        Text(benefit)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    ToneGeneratorView()
        .environmentObject(ToneGenerator())
        .environmentObject(AudioManager())
        .environmentObject(StoreManager())
        .environmentObject(GamificationManager())
}
