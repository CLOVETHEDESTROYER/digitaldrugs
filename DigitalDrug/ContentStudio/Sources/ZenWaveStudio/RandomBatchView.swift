import SwiftUI

struct RandomBatchView: View {
    @Bindable var studio: StudioState
    @Bindable var batch: RandomBatchState
    @State private var preview = StudioState()
    @State private var selected: Int?
    var livePlaying: Bool
    var onPlay: () -> Void

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Random Batch").font(.largeTitle.bold())
                    Text("Build a week of unique manifestation videos in one batch.").foregroundStyle(.secondary)
                    HStack {
                        Stepper("\(batch.count) clips", value: $batch.count, in: 1...50)
                        ForEach([7, 14, 30], id: \.self) { count in Button("\(count)") { batch.count = count } }
                    }
                    Picker("Output format", selection: $batch.format) {
                        ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DisclosureGroup("Manifestations · \(batch.mantraPool.count) selected") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("All") { batch.mantraPool = Set(studio.library.map(\.id)) }
                                Button("Use checked queue") { batch.mantraPool = studio.queued }
                                Button("Clear") { batch.mantraPool.removeAll() }
                            }
                            ForEach(studio.library) { mantra in
                                Toggle(mantra.title, isOn: membership(mantra.id, in: $batch.mantraPool))
                            }
                        }.padding(.top, 8)
                    }
                    DisclosureGroup("Visuals · \(batch.stylePool.count) selected") {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button("All") { batch.stylePool = Set(VisualStyle.all.map(\.id)) }
                                    Button("Blooms & wormholes") { batch.stylePool = [10, 14, 15, 16, 17, 18, 19] }
                                    Button("Clear") { batch.stylePool.removeAll() }
                                }
                                HStack {
                                    Button("Sacred") { batch.stylePool = Set(20...25) }
                                    Button("Chakras") { batch.stylePool = Set(26...33) }
                                    Button("Resonance") { batch.stylePool = [34, 35] }
                                }
                            }
                            ForEach(VisualStyle.all) { style in Toggle(style.title, isOn: membership(style.id, in: $batch.stylePool)) }
                        }.padding(.top, 8)
                    }
                    DisclosureGroup("Colors · \(batch.palettePool.count) selected") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("All") { batch.palettePool = Set(VisualPalette.all.map(\.id)) }
                                Button("Clear") { batch.palettePool.removeAll() }
                            }
                            ForEach(VisualPalette.all) { palette in Toggle(palette.title, isOn: membership(palette.id, in: $batch.palettePool)) }
                        }.padding(.top, 8)
                    }
                    SoundscapeControls(soundscape: $batch.soundscape, showBeatLevel: batch.randomizeBeats, showNatureLevel: batch.randomizeNature, showChakraLevel: batch.randomizeChakras)
                    DisclosureGroup("Randomize background layers") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Randomize beat per clip", isOn: $batch.randomizeBeats)
                            if batch.randomizeBeats {
                                ForEach(StudioBeat.allCases.filter { $0 != .off }) { beat in
                                    Toggle(beat.title, isOn: membership(beat, in: $batch.beatPool))
                                }
                            }
                            Toggle("Randomize nature per clip", isOn: $batch.randomizeNature)
                            if batch.randomizeNature {
                                ForEach(StudioNature.all) { sound in
                                    Toggle(sound.title, isOn: membership(sound.id, in: $batch.naturePool))
                                }
                            }
                            Toggle("Randomize chakra per clip", isOn: $batch.randomizeChakras)
                            if batch.randomizeChakras {
                                ForEach(StudioChakra.randomIDs, id: \.self) { id in
                                    Toggle(StudioChakra.randomTitle(id), isOn: membership(id, in: $batch.chakraPool))
                                }
                            }
                            Text("Random pools replace the fixed selections above. Levels stay as chosen. Locked clips keep their audio layers when reshuffling.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 8)
                    }
                    TextField("Optional caption footer / your hashtags", text: $batch.footer, axis: .vertical)
                        .lineLimit(2...4).textFieldStyle(.roundedBorder)
                    Text("The footer is saved in each posting-text file; it is not burned into the video.").font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Reproducible shuffle") {
                        TextField("Seed (optional whole number)", text: $batch.seedText).textFieldStyle(.roundedBorder)
                        Text("Generate uses this seed. Reshuffle chooses a new seed. The batch receipt saves every choice.").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Generate batch") { generate(newSeed: false) }.buttonStyle(.borderedProminent)
                        Button("Reshuffle unlocked") { generate(newSeed: true) }.disabled(batch.plan == nil)
                    }
                    Text("Uses complete recordings and the main studio’s caption, branding, call-to-action, motion and imported background-audio settings at generation time; beat, nature and chakra choices are set here. Export always uses the reviewed batch; generate again to apply settings edits.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let plan = batch.plan {
                        Text("REVIEW · \(plan.clips.count) CLIPS").font(.caption.bold()).foregroundStyle(.cyan)
                        Text("\(plan.settings.format.rawValue) · Captions \(plan.settings.captions ? "on" : "off") · Imported audio: \(plan.backgroundFile ?? "none")")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(plan.clips) { clip in row(clip) }
                    }
                }.padding(24).disabled(batch.exporting)
            }.frame(minWidth: 480, idealWidth: 560)
            VStack(spacing: 16) {
                Text(selected == nil ? "Clip preview" : (preview.selected?.title ?? "Clip preview")).font(.title3.bold())
                GeometryReader { geo in
                    ZStack {
                        Color.black
                        if selected != nil, let image = preview.previewImage {
                            Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                        } else { Text("Generate a batch, then select a clip.").foregroundStyle(.secondary) }
                    }.frame(width: geo.size.width, height: geo.size.height)
                }.clipShape(RoundedRectangle(cornerRadius: 12))
                if selected != nil {
                    HStack {
                        Button(preview.playing ? "Pause" : "Play") {
                            onPlay(); studio.pause(); preview.togglePlayback()
                        }.disabled(!preview.audioReady || batch.exporting)
                        Slider(value: Binding(get: { preview.elapsed }, set: { preview.seek($0) }), in: 0...max(0.01, preview.duration))
                            .accessibilityLabel("Random clip playback position").disabled(!preview.audioReady || batch.exporting)
                    }
                    Text("\(Int(preview.elapsed)) / \(Int(preview.duration)) seconds · Complete recording")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if preview.preparingAudio { ProgressView("Preparing preview mix…") }
                    if preview.selected?.estimated == true {
                        Text("Estimated captions: listen through before posting.").font(.caption).foregroundStyle(.orange)
                    }
                }
                Button("Save batch MP4s + ZIP…") {
                    preview.pause(); studio.pause(); onPlay()
                    chooseDestination()
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(batch.plan == nil || batch.exporting || studio.exporting)
                Text("Each MP4 already includes its audio. Visual movement follows background layers only. Posting text and the batch recipe are saved alongside it; SRT subtitles are included when captions are enabled.")
                    .font(.caption).foregroundStyle(.secondary)
                if batch.exporting { ProgressView(value: batch.progress); Button("Stop batch", action: batch.cancel) }
                Text(batch.status).font(.caption).foregroundStyle(.secondary)
                HStack {
                    if let folder = batch.folder { Button("Show clips") { NSWorkspace.shared.open(folder) } }
                    if let archive = batch.archive { Button("Show ZIP") { NSWorkspace.shared.activateFileViewerSelecting([archive]) } }
                }
            }.padding(24).frame(minWidth: 360, idealWidth: 430)
        }
        .frame(minWidth: 960, minHeight: 760).preferredColorScheme(.dark).tint(.cyan)
        .onAppear {
            if batch.plan == nil {
                if batch.mantraPool.isEmpty { batch.mantraPool = Set(studio.library.map(\.id)) }
                batch.soundscape = studio.settings.soundscape
            }
        }
        .onDisappear { preview.pause() }
        .onChange(of: livePlaying) { _, playing in if playing { preview.pause() } }
        .onChange(of: studio.playing) { _, playing in if playing { preview.pause() } }
        .alert("Batch needs attention", isPresented: Binding(get: { batch.error != nil || preview.error != nil }, set: { if !$0 { batch.error = nil; preview.error = nil } })) {
            Button("OK") { batch.error = nil; preview.error = nil }
        } message: { Text(batch.error ?? preview.error ?? "") }
    }
    private func row(_ clip: RandomClip) -> some View {
        HStack {
            Button { select(clip) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(clip.id + 1). \(studio.library.first { $0.id == clip.mantraID }?.title ?? clip.mantraID)").font(.headline)
                    Text("\(VisualStyle.all.first { $0.id == clip.style }?.title ?? "") · \(VisualPalette.all.first { $0.id == clip.palette }?.title ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                    let audio = clip.settings(from: batch.plan!.settings).soundscape
                    if !audio.summary.isEmpty { Text(audio.summary).font(.caption).foregroundStyle(.cyan) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button { batch.toggleLock(clip.id) } label: { Image(systemName: clip.locked ? "lock.fill" : "lock.open") }
                .accessibilityLabel(clip.locked ? "Unlock clip \(clip.id + 1)" : "Keep clip \(clip.id + 1) when shuffling")
        }.padding(.trailing, 10).background(selected == clip.id ? Color.cyan.opacity(0.15) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
    private func generate(newSeed: Bool) {
        preview.pause(); batch.generate(studio: studio, newSeed: newSeed)
        if let first = batch.plan?.clips.first { select(first) }
    }
    private func select(_ clip: RandomClip) {
        guard let plan = batch.plan else { return }
        preview.pause(); selected = clip.id
        preview.settings = clip.settings(from: plan.settings)
        preview.backgroundURL = batch.background; preview.selectedID = clip.mantraID
        preview.clipIndex = -1; preview.loadSelected()
    }
    private func chooseDestination() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.prompt = "Save batch here"; panel.directoryURL = studio.outputFolder
        if panel.runModal() == .OK, let url = panel.url { batch.export(library: studio.library, destination: url) }
    }
    private func membership<T: Hashable>(_ value: T, in pool: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { pool.wrappedValue.contains(value) }, set: { enabled in
            if enabled { pool.wrappedValue.insert(value) } else { pool.wrappedValue.remove(value) }
        })
    }
}
