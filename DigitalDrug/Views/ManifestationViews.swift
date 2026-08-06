//
//  ManifestationViews.swift
//  DigitalDrug
//

import SwiftUI

enum ManifestationDestination: String, Identifiable {
    case daily
    case builder

    var id: String { rawValue }
}

struct DailyManifestationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("savedManifestationAffirmationIDs") private var savedIDsValue = ""

    let onBeginRitual: (ManifestationAffirmation) -> Void
    let onOpenBuilder: () -> Void
    let onPlayMantra: (ManifestationMantra) -> Void

    @State private var affirmation: ManifestationAffirmation

    init(
        onBeginRitual: @escaping (ManifestationAffirmation) -> Void,
        onOpenBuilder: @escaping () -> Void,
        onPlayMantra: @escaping (ManifestationMantra) -> Void
    ) {
        self.onBeginRitual = onBeginRitual
        self.onOpenBuilder = onOpenBuilder
        self.onPlayMantra = onPlayMantra
        _affirmation = State(initialValue: .daily)
    }

    private var isSaved: Bool {
        savedIDs.contains(affirmation.id)
    }

    private var savedIDs: Set<String> {
        Set(savedIDsValue.split(separator: ",").map(String.init))
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    manifestationHeader
                    celestialHorizon
                    affirmationSection
                    reflectionSection
                    actionSection
                    mantraLibrarySection
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Label("ZenWave", systemImage: "waveform")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.90))

            Spacer()

            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Close")
        }
    }

    private var manifestationHeader: some View {
        VStack(spacing: 12) {
            Text("Daily Manifestation")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, affirmation.theme.accent, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Text("TODAY")
                .font(.caption.weight(.bold))
                .tracking(5)
                .foregroundStyle(.cyan)

            Text(affirmation.theme.title.uppercased())
                .font(.title2.weight(.semibold))
                .tracking(4)
                .foregroundStyle(affirmation.theme.accent)
        }
        .padding(.top, 18)
    }

    private var celestialHorizon: some View {
        ZStack {
            Circle()
                .fill(affirmation.theme.accent.opacity(0.22))
                .frame(width: 176, height: 176)
                .blur(radius: 48)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 210, height: 210)
                .mask(
                    Rectangle()
                        .frame(height: 106)
                        .offset(y: 53)
                )

            Image(systemName: "sparkle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: affirmation.theme.accent, radius: 18)
        }
        .frame(height: 160)
        .accessibilityHidden(true)
    }

    private var affirmationSection: some View {
        Text(affirmation.text)
            .font(.system(size: 32, weight: .medium, design: .serif))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 22)
            .contentTransition(.opacity)
    }

    private var reflectionSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.mind.and.body")
                .font(.title2)
                .foregroundStyle(affirmation.theme.accent)
                .frame(width: 48, height: 48)
                .background(Circle().stroke(affirmation.theme.accent.opacity(0.62)))

            VStack(alignment: .leading, spacing: 5) {
                Text("One aligned action")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(affirmation.reflectionPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 44) {
                actionButton(title: "Listen", icon: "headphones") {
                    onBeginRitual(affirmation)
                }

                actionButton(title: isSaved ? "Saved" : "Save", icon: isSaved ? "bookmark.fill" : "bookmark") {
                    toggleSaved()
                }

                actionButton(title: "Create", icon: "wand.and.stars") {
                    onOpenBuilder()
                }
            }

            Button {
                onBeginRitual(affirmation)
            } label: {
                Label("Begin 3-minute ritual", systemImage: "waveform")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.48, green: 0.17, blue: 0.75), .blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28)))

            Button(action: showAnotherAffirmation) {
                Label("Another affirmation", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.63, green: 0.46, blue: 0.95))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 18)
    }

    private var mantraLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guided Mantras")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Longer spoken practices with a gentle 10 Hz sound bed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ManifestationMantra.library) { mantra in
                        Button {
                            onPlayMantra(mantra)
                        } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                Image(systemName: "waveform.and.mic")
                                    .font(.title2)
                                    .foregroundStyle(mantra.accent)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mantra.title)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                    Text(mantra.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.62))
                                        .lineLimit(2)
                                }

                                Label("Play mantra", systemImage: "play.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(mantra.accent)
                            }
                            .frame(width: 196, height: 194, alignment: .leading)
                            .padding(18)
                            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(mantra.accent.opacity(0.40)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 30)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 46, height: 46)
                    .background(Circle().stroke(affirmation.theme.accent.opacity(0.72)))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func showAnotherAffirmation() {
        guard let currentIndex = ManifestationAffirmation.library.firstIndex(of: affirmation) else {
            affirmation = .daily
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            affirmation = ManifestationAffirmation.library[(currentIndex + 1) % ManifestationAffirmation.library.count]
        }
    }

    private func toggleSaved() {
        var updated = savedIDs
        if updated.contains(affirmation.id) {
            updated.remove(affirmation.id)
        } else {
            updated.insert(affirmation.id)
        }
        savedIDsValue = updated.sorted().joined(separator: ",")
    }
}

struct ManifestationMantraSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toneGenerator: ToneGenerator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let mantra: ManifestationMantra

    private var isSessionActive: Bool {
        toneGenerator.isPlaying && toneGenerator.currentSoundTitle == mantra.title
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 22)

                mantraStage

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    Text(mantra.title)
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(mantra.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                        .multilineTextAlignment(.center)

                    Text(toneGenerator.isManifestationMantraWaitingToRepeat ? "Quiet integration" : "10 Hz binaural bed · spoken mantra")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(mantra.accent)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 28)

                controls
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Minimize")

            Spacer()

            Label("ZenWave", systemImage: "waveform")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.90))

            Spacer()

            Color.clear.frame(width: 42, height: 42)
        }
    }

    private var mantraStage: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isSessionActive)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let expansion = 0.90 + (sin(phase * 0.55) + 1) * 0.07

            ZStack {
                Circle()
                    .fill(mantra.accent.opacity(0.18))
                    .frame(width: 250, height: 250)
                    .blur(radius: 44)

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.68), mantra.accent.opacity(0.78), .purple.opacity(0.62)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: index == 0 ? 2.2 : 1
                        )
                        .frame(width: CGFloat(128 + index * 42), height: CGFloat(128 + index * 42))
                        .scaleEffect(isSessionActive ? CGFloat(expansion) + CGFloat(index) * 0.015 : 1)
                        .opacity(toneGenerator.isManifestationMantraWaitingToRepeat ? 0.22 : 0.82 - Double(index) * 0.11)
                }

                Image(systemName: isSessionActive ? "waveform.and.mic" : "play.fill")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white)
                    .shadow(color: mantra.accent, radius: 18)
            }
        }
        .frame(height: 340)
        .accessibilityLabel(isSessionActive ? "Mantra session playing" : "Mantra session paused")
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Button(action: togglePlayback) {
                Label(
                    isSessionActive ? "Pause mantra" : "Begin mantra",
                    systemImage: isSessionActive ? "pause.fill" : "play.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [mantra.accent, .blue, .cyan], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.30)))

            Button(action: toneGenerator.stop) {
                Label("End session", systemImage: "stop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .buttonStyle(.plain)
            .disabled(!isSessionActive && !toneGenerator.isManifestationMantraWaitingToRepeat)
        }
        .padding(.bottom, 18)
    }

    private func togglePlayback() {
        if isSessionActive {
            toneGenerator.pause()
        } else if toneGenerator.currentSoundTitle == mantra.title {
            toneGenerator.resume()
        } else {
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: 200,
                rightFreq: 210,
                title: mantra.title,
                subtitle: "10 Hz binaural bed + spoken mantra",
                volumeScale: 0.18
            )
            toneGenerator.playLoopingManifestationMantra(fileName: mantra.fileName, loopGap: 8)
        }
    }
}

struct ManifestationBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    let onCreateRitual: (ManifestationAffirmation) -> Void

    @State private var step = 0
    @State private var selectedTheme: ManifestationTheme = .abundance
    @State private var selectedTone: ManifestationTone = .grounded
    @State private var intention = ""

    private var affirmation: ManifestationAffirmation {
        .generated(theme: selectedTheme, tone: selectedTone, intention: intention)
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressHeader

                ScrollView(showsIndicators: false) {
                    Group {
                        switch step {
                        case 0: intentionStep
                        case 1: toneStep
                        default: previewStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }

                navigationControls
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Close")

            Spacer()

            Label("ZenWave", systemImage: "waveform")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private var progressHeader: some View {
        VStack(spacing: 22) {
            Text("Create a Manifestation")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                builderProgressNode(index: 0, title: "INTENTION")
                progressLine(after: 0)
                builderProgressNode(index: 1, title: "TONE")
                progressLine(after: 1)
                builderProgressNode(index: 2, title: "PREVIEW")
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 24)
    }

    private func builderProgressNode(index: Int, title: String) -> some View {
        VStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(index <= step ? .white : .white.opacity(0.48))
                .frame(width: 42, height: 42)
                .background(Circle().fill(index == step ? Color.cyan.opacity(0.22) : Color.black.opacity(0.42)))
                .overlay(Circle().strokeBorder(index <= step ? Color.cyan : Color.white.opacity(0.24), lineWidth: index == step ? 2 : 1))
                .shadow(color: index == step ? Color.cyan.opacity(0.55) : .clear, radius: 12)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(index == step ? .cyan : .white.opacity(0.48))
        }
    }

    private func progressLine(after index: Int) -> some View {
        Rectangle()
            .fill(index < step ? Color.cyan : Color.white.opacity(0.20))
            .frame(height: 2)
            .offset(y: -12)
    }

    private var intentionStep: some View {
        VStack(spacing: 22) {
            Image(systemName: selectedTheme.systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(selectedTheme.accent)
                .frame(width: 118, height: 118)
                .background(Circle().fill(selectedTheme.accent.opacity(0.12)))
                .overlay(Circle().strokeBorder(selectedTheme.accent.opacity(0.72), lineWidth: 2))
                .shadow(color: selectedTheme.accent.opacity(0.40), radius: 22)

            Text("What are you calling in?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(ManifestationTheme.allCases) { theme in
                    themeButton(theme)
                }
            }

            TextField("Optional: name the intention in your own words", text: $intention, axis: .vertical)
                .lineLimit(2...4)
                .padding(16)
                .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.16)))
        }
    }

    private func themeButton(_ theme: ManifestationTheme) -> some View {
        Button {
            selectedTheme = theme
        } label: {
            HStack(spacing: 16) {
                Image(systemName: theme.systemImage)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 28)
                Text(theme.title)
                    .font(.headline)
                Spacer()
                Image(systemName: selectedTheme == theme ? "circle.inset.filled" : "circle")
                    .foregroundStyle(selectedTheme == theme ? .cyan : .white.opacity(0.38))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: 64)
            .background(Color.black.opacity(selectedTheme == theme ? 0.48 : 0.30), in: Capsule())
            .overlay(Capsule().strokeBorder(selectedTheme == theme ? Color.cyan.opacity(0.85) : Color.white.opacity(0.16), lineWidth: selectedTheme == theme ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var toneStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("How should it feel?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("The tone changes the language, while the intention stays yours.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))

            ForEach(ManifestationTone.allCases) { tone in
                Button {
                    selectedTone = tone
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: toneIcon(tone))
                            .font(.title2)
                            .foregroundStyle(selectedTheme.accent)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tone.title)
                                .font(.headline)
                            Text(toneDescription(tone))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        Spacer()
                        Image(systemName: selectedTone == tone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTone == tone ? .cyan : .white.opacity(0.34))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(selectedTone == tone ? Color.cyan.opacity(0.70) : Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewStep: some View {
        VStack(spacing: 24) {
            Text("Your affirmation")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(.cyan)

            ZStack {
                Circle()
                    .fill(selectedTheme.accent.opacity(0.20))
                    .frame(width: 230, height: 230)
                    .blur(radius: 46)

                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(selectedTheme.accent)
                    .shadow(color: selectedTheme.accent, radius: 20)
            }
            .frame(height: 180)

            Text(affirmation.text)
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Label("10 Hz sound bed · 3 minutes", systemImage: "waveform")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedTheme.accent)

            Text("Your ritual pairs this affirmation with breath, visualization, reflection, and one real action.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 14) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.10), in: Circle())
            }

            Button {
                if step < 2 {
                    withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                } else {
                    onCreateRitual(affirmation)
                }
            } label: {
                Label(step == 2 ? "Create Ritual" : "Continue", systemImage: step == 2 ? "waveform" : "chevron.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color(red: 0.48, green: 0.17, blue: 0.75), .blue, .cyan], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.26)))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func toneIcon(_ tone: ManifestationTone) -> String {
        switch tone {
        case .grounded: return "circle.hexagongrid.fill"
        case .mystical: return "sparkles"
        case .direct: return "arrow.up.right.circle.fill"
        }
    }

    private func toneDescription(_ tone: ManifestationTone) -> String {
        switch tone {
        case .grounded: return "Clear, steady, and action-oriented"
        case .mystical: return "Spacious, symbolic, and reflective"
        case .direct: return "Simple, decisive, and immediate"
        }
    }
}
