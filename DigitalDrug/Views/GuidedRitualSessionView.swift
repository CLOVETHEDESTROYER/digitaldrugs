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
    @State private var activeStepIndex = 0
    @State private var completedStepIDs = Set<String>()
    @State private var timer: Timer?
    @State private var showCompletion = false
    
    private var activeStep: GuidedRitualStep {
        ritual.steps[safe: activeStepIndex] ?? ritual.steps[0]
    }
    
    private var progress: Double {
        guard ritual.duration > 0 else { return 0 }
        return min(elapsed / ritual.duration, 1)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        headerCard
                        visualCard
                        stepTimeline
                        controlsCard
                        disclaimerCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle(ritual.module.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        stopSession()
                        dismiss()
                    }
                }
            }
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
        .onDisappear {
            stopSession()
        }
        .onChange(of: toneGenerator.isPlaying) { _, newValue in
            if !newValue {
                isPlaying = false
                timer?.invalidate()
                timer = nil
                voiceManager.stop()
            }
        }
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
                            Text(timeLabel(step.startTime))
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
        if elapsed == 0 {
            startAudio()
            speakCurrentStep()
        } else {
            resumeAudio()
        }
        
        isPlaying = true
        startTimer()
    }
    
    private func pauseSession() {
        AppLog.info("Guided ritual pause requested: \(ritual.title)")
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
        
        switch ritual.audioKind {
        case .binaural(let left, let right):
            toneGenerator.generateContinuousBinauralBeat(
                leftFreq: left,
                rightFreq: right,
                title: ritual.title,
                subtitle: "\(ritual.module.title) - \(ritual.frequencyLabel)"
            )
        case .chakra(let frequency, let chakraName):
            let timbre = ChakraTone.allChakras.first { $0.name.contains(chakraName) }?.bellTimbre ?? .balanced
            toneGenerator.generateChakraBell(
                frequency: frequency,
                timbre: timbre,
                title: ritual.title,
                subtitle: "\(ritual.module.title) - \(Int(frequency)) Hz \(chakraName)"
            )
            audioManager.playNature(fileName: "Ocean.wav")
        }
    }
    
    private func resumeAudio() {
        if toneGenerator.isPlaying {
            AppLog.info("Guided ritual resume skipped because tone generator is already playing: \(ritual.title)")
            return
        }
        AppLog.info("Guided ritual resume audio requested: \(ritual.title)")
        startAudio()
    }
    
    private func startTimer() {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
            updateActiveStep()
            
            if elapsed >= ritual.duration {
                showCompletion = true
                pauseSession()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func updateActiveStep() {
        let nextIndex = ritual.steps.lastIndex(where: { elapsed >= $0.startTime }) ?? 0
        guard nextIndex != activeStepIndex else { return }
        activeStepIndex = nextIndex
        speakCurrentStep()
    }
    
    private func speakCurrentStep() {
        guard !completedStepIDs.contains(activeStep.id) else { return }
        completedStepIDs.insert(activeStep.id)
        voiceManager.speak(
            activeStep.spokenPrompt,
            module: ritual.module,
            intent: ritual.intent,
            isCodePrompt: ritual.module == .quantumCodes || activeStep.visualKind == .codePulse
        )
    }
    
    private func timeLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
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
            "ZenWave / DigitalDrugz"
        ].joined(separator: "\n")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        shareCard
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
                Text("ZenWave / DigitalDrugz")
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
