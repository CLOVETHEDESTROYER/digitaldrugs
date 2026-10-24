import SwiftUI

struct BreathPracticeView: View {
    @Bindable var breath: BreathPracticeState
    @Bindable var studio: StudioState
    var onPlay: () -> Void
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Breathing Practice").font(.largeTitle.bold())
                    Text("A circle to follow. Space to slow down.").foregroundStyle(.secondary)
                    GroupBox("RHYTHM") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Practice", selection: Binding(get: { breath.plan.preset }, set: { breath.plan.apply($0) })) {
                                ForEach(BreathPreset.allCases) { Text($0.rawValue).tag($0) }
                            }
                            Text(breath.plan.preset.note).font(.caption).foregroundStyle(.secondary)
                            if let url = breath.plan.preset.sourceURL { Link("About this breathing pattern ↗", destination: url).font(.caption) }
                            if breath.plan.preset == .custom {
                                Stepper("Inhale: \(breath.plan.inhale) sec", value: $breath.plan.inhale, in: 2...10)
                                Stepper("Hold after inhale: \(breath.plan.hold) sec", value: $breath.plan.hold, in: 0...8)
                                Stepper("Exhale: \(breath.plan.exhale) sec", value: $breath.plan.exhale, in: 2...10)
                                Stepper("Pause after exhale: \(breath.plan.pause) sec", value: $breath.plan.pause, in: 0...8)
                            }
                            Text("\(breath.plan.inhale)s in → \(breath.plan.hold)s hold → \(breath.plan.exhale)s out → \(breath.plan.pause)s pause").font(.callout.monospacedDigit())
                            Text("Breathe comfortably, without forcing. Skip holds if uncomfortable. Stop and breathe normally if dizzy.").font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    GroupBox("LENGTH & VOICE") {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper("Complete cycles: \(breath.plan.cycles)", value: $breath.plan.cycles, in: 1...breath.plan.maximumCycles)
                            HStack {
                                ForEach([1, 3, 5, 10, 15, 20], id: \.self) { minutes in
                                    Button("\(minutes)m") { breath.plan.fit(minutes: minutes) }
                                }
                            }
                            Text("\(clock(breath.plan.duration)) total · 6s settle-in + complete cycles + 4s finish").font(.caption.monospacedDigit())
                            Picker("Narration", selection: $breath.plan.voice) {
                                ForEach(BreathVoiceMode.allCases) { Text($0.rawValue).tag($0) }
                            }
                            if breath.plan.voice != .off {
                                Text(BreathVoicePack.title).font(.callout.weight(.medium))
                                Text("AI-generated voice. Pre-generated OpenAI narration is bundled with the studio and works offline. Each phase starts with “Inhale”, “Hold”, “Exhale” or “Pause”; remaining seconds count down aloud.").font(.caption).foregroundStyle(.secondary)
                            }
                            Toggle("Repeat during live playback", isOn: $breath.plan.loop)
                            Text("Export saves one full practice. Loop the MP4 in your live software for longer sessions.").font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    GroupBox("LOOK") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Background", selection: $studio.settings.style) {
                                if ![6, 7, 10, 11, 12, 15].contains(studio.settings.style) { Text("Aurora Veil (breathing default)").tag(studio.settings.style) }
                                ForEach(VisualStyle.all.filter { [6, 7, 10, 11, 12, 15].contains($0.id) }) { Text($0.title).tag($0.id) }
                            }
                            Picker("Colors", selection: $studio.settings.palette) { ForEach(VisualPalette.all) { Text($0.title).tag($0.id) } }
                            Picker("Format", selection: $studio.settings.format) { ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) } }
                            Toggle("Show ZenWave branding", isOn: $studio.settings.branding)
                            Text("The circle follows the breathing rhythm. Background movement follows background audio only. Uses your main studio’s logo and call-to-action settings; mantra narration is replaced by breathing cues.").font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    SoundscapeControls(soundscape: $studio.settings.soundscape)
                    Text(studio.backgroundURL.map { "Imported background: \($0.lastPathComponent)" } ?? "Optional imported music can be selected in the main studio.").font(.caption).foregroundStyle(.secondary)
                    Button("Prepare / update practice") { onPlay(); breath.prepare(settings: studio.settings, background: studio.backgroundURL) }
                        .buttonStyle(.borderedProminent).disabled(studio.exporting)
                }.padding(24).disabled(breath.busy || breath.playing)
            }.frame(minWidth: 450, idealWidth: 510)
            VStack(spacing: 14) {
                BreathOutputView(breath: breath).clipShape(RoundedRectangle(cornerRadius: 12))
                if let prepared = breath.preparedPlan {
                    Text("\(clock(breath.elapsed)) / \(clock(prepared.duration))").font(.caption.monospacedDigit())
                    Slider(value: Binding(get: { breath.elapsed }, set: { breath.seek($0) }), in: 0...prepared.duration).disabled(breath.busy)
                        .accessibilityLabel("Breathing practice position")
                }
                HStack {
                    Button(breath.playing ? "Pause" : "Play") { onPlay(); breath.toggle() }.disabled(!breath.ready)
                    Button("Restart") { breath.seek(0) }.disabled(!breath.ready)
                    Button("Clean output") { openWindow(id: "breath-output") }.disabled(!breath.ready)
                }
                Button("Export breathing MP4…") { breath.chooseExport(folder: studio.outputFolder) }.disabled(!breath.ready)
                if breath.busy {
                    if breath.exporting { ProgressView(value: breath.progress) } else { ProgressView() }
                    Button("Stop", action: breath.cancel)
                }
                if breath.pendingChanges || settingsChanged { Text("Settings changed. Prepare / update to apply them.").font(.caption).foregroundStyle(.orange) }
                Text(breath.status).font(.caption).foregroundStyle(.secondary)
                if let url = breath.exportedURL { Button("Show video") { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
                Text("Capture “ZenWave Breathing Output” and this app’s audio for live use, or load the exported MP4 as a media source.").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(minWidth: 400, idealWidth: 490)
        }
        .frame(minWidth: 960, minHeight: 760).preferredColorScheme(.dark).tint(.cyan)
        .onChange(of: breath.plan.cycleDuration) { _, _ in breath.plan.cycles = min(breath.plan.cycles, breath.plan.maximumCycles) }
        .onChange(of: studio.settings) { _, _ in studio.settings.save() }
        .alert("Breathing practice needs attention", isPresented: Binding(get: { breath.error != nil }, set: { if !$0 { breath.error = nil } })) {
            Button("OK") { breath.error = nil }
        } message: { Text(breath.error ?? "") }
    }
    private var settingsChanged: Bool { breath.preparedPlan != nil && (breath.settings != studio.settings || breath.preparedBackground != studio.backgroundURL) }
    private func clock(_ seconds: Double) -> String { let n = max(0, Int(seconds)); return String(format: "%d:%02d", n / 60, n % 60) }
}
struct BreathOutputView: View {
    var breath: BreathPracticeState
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image = breath.image { Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit) }
                else { Text("Prepare a breathing practice").foregroundStyle(.secondary) }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.background(.black)
    }
}
