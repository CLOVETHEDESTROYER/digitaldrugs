import SwiftUI

struct LiveSessionView: View {
    @Bindable var studio: StudioState
    @Bindable var live: LiveSessionState
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Live Session").font(.largeTitle.bold())
                    Text("A manifestation playlist that unfolds over time.").foregroundStyle(.secondary)
                    HStack {
                        Picker("Add manifestation", selection: $studio.selectedID) {
                            ForEach(studio.library) { Text($0.title).tag(Optional($0.id)) }
                        }
                        Button("Add") { if let mantra = studio.selected { live.add(mantra, settings: studio.settings) } }
                            .disabled(live.plan.chapters.count >= 30)
                    }
                    HStack {
                        Text("Fit playlist to")
                        ForEach([10, 15, 20], id: \.self) { minutes in
                            Button("\(minutes) min") { live.preset(minutes: minutes) }
                        }
                    }.disabled(live.plan.chapters.isEmpty)
                    Text("Presets divide the total equally. Or adjust each chapter below; 3–4 minutes is a good starting point.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(live.plan.chapters.enumerated()), id: \.element.id) { index, chapter in
                        chapterRow(index, chapter)
                    }
                    if live.plan.chapters.isEmpty {
                        Button("Use a 10-minute starter journey") {
                            let ids = ["abundance", "love", "wellbeing-happiness"]
                            let styles = [10, 14, 20]
                            for (index, id) in ids.enumerated() {
                                if studio.library.contains(where: { $0.id == id }) {
                                    live.plan.chapters.append(LiveChapter(mantraID: id, seconds: 200, style: styles[index], palette: index + 1))
                                }
                            }
                        }.buttonStyle(.bordered)
                        ContentUnavailableView("Add your first manifestation", systemImage: "list.bullet.rectangle", description: Text("Choose recordings in the order you want to showcase them."))
                    }
                    GroupBox("PACING") {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper("Rest between repetitions: \(Int(live.plan.rest)) sec", value: $live.plan.rest, in: 0...120, step: 5)
                            Stepper("Visual crossfade: \(Int(live.plan.transition)) sec", value: $live.plan.transition, in: 0...20, step: 1)
                            Toggle("Loop session during live playback", isOn: $live.plan.loop)
                            Text("Complete recordings repeat within each chapter. Remaining time is reserved for reflection. Export produces one complete cycle.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    GroupBox("EVOLVING JOURNEY") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Evolve visual scenes and colors", isOn: $live.plan.evolving)
                            Stepper("New scene every \(Int(live.plan.sceneSeconds)) sec", value: $live.plan.sceneSeconds, in: 30...180, step: 15).disabled(!live.plan.evolving)
                            Toggle("Breathing & reflection prompts during rests", isOn: $live.plan.prompts)
                            Text("Cycles through the chapter’s chosen visual, wormholes, prismatic bloom, Merkaba, constellations and Flower of Life. Movement follows background layers only; the mantra stays audible without affecting motion.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    Text("Uses the main studio’s format, motion, caption, branding and optional background audio settings when you prepare. Captions may use estimated timing; review before a live.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Playlist total: \(clock(live.plan.duration))").font(.headline.monospacedDigit())
                    Button("Prepare / update session") {
                        studio.pause()
                        live.prepare(library: studio.library, settings: studio.settings, background: studio.backgroundURL)
                    }.buttonStyle(.borderedProminent).disabled(live.plan.chapters.isEmpty || studio.exporting)
                }.padding(24).disabled(live.busy || live.playing)
            }.frame(minWidth: 440, idealWidth: 540)
            VStack(spacing: 14) {
                Text(live.title).font(.title3.bold())
                LiveOutputView(live: live).clipShape(RoundedRectangle(cornerRadius: 12))
                if live.ready, let timeline = live.timeline {
                    Text("Chapter \(live.activeChapter + 1) of \(timeline.records.count) · \(clock(live.elapsed)) / \(clock(timeline.duration))")
                        .font(.caption.monospacedDigit())
                    Slider(value: Binding(get: { live.elapsed }, set: { live.seek($0) }), in: 0...timeline.duration)
                        .accessibilityLabel("Live session position")
                    HStack {
                        Button(live.playing ? "Pause" : "Play") { studio.pause(); live.toggle() }
                        Button("Restart") { live.seek(0) }
                        Button("Next manifestation", action: live.next)
                    }
                }
                HStack {
                    Button("Open clean output") { openWindow(id: "live-output") }.disabled(!live.ready)
                    Button("Export full MP4…") { live.chooseExport(folder: studio.outputFolder) }.disabled(!live.ready)
                }
                if live.busy {
                    if live.exporting { ProgressView(value: live.progress); Text(live.progress, format: .percent).font(.caption) }
                    else { ProgressView() }
                    Button("Stop", action: live.cancel)
                }
                if live.pendingChanges { Text("Playlist changed. Prepare / update session to apply your edits.").font(.caption).foregroundStyle(.orange) }
                Text(live.status).font(.caption).foregroundStyle(.secondary)
                if let url = live.exportedURL {
                    Button("Show video") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                Text("Capture “ZenWave Live Output” and this app’s audio in your streaming software, or use the exported MP4 as a media source. Opening the output does not start a TikTok broadcast.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(minWidth: 400, idealWidth: 500)
        }
        .frame(minWidth: 960, minHeight: 760)
        .preferredColorScheme(.dark).tint(.cyan)
        .alert("Live session needs attention", isPresented: Binding(get: { live.error != nil }, set: { if !$0 { live.error = nil } })) {
            Button("OK") { live.error = nil }
        } message: { Text(live.error ?? "") }
    }
    private func chapterRow(_ index: Int, _ chapter: LiveChapter) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(index + 1). \(studio.library.first { $0.id == chapter.mantraID }?.title ?? "Missing recording")").font(.headline)
                    Spacer()
                    Button { live.move(index, by: -1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0).accessibilityLabel("Move chapter up")
                    Button { live.move(index, by: 1) } label: { Image(systemName: "arrow.down") }.disabled(index == live.plan.chapters.count - 1).accessibilityLabel("Move chapter down")
                    Button { live.plan.chapters.remove(at: index) } label: { Image(systemName: "trash") }.accessibilityLabel("Remove chapter")
                }
                Stepper("Chapter length: \(clock(chapter.seconds))", value: $live.plan.chapters[index].seconds, in: 30...1200, step: 30)
                Picker("Starting visual", selection: $live.plan.chapters[index].style) {
                    ForEach(VisualStyle.all) { Text($0.title).tag($0.id) }
                }
                Picker("Starting colors", selection: $live.plan.chapters[index].palette) {
                    ForEach(VisualPalette.all) { Text($0.title).tag($0.id) }
                }
            }.padding(8)
        }
    }
    private func clock(_ seconds: Double) -> String {
        let n = max(0, Int(seconds.rounded())); return String(format: "%d:%02d", n / 60, n % 60)
    }
}

struct LiveOutputView: View {
    var live: LiveSessionState
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image = live.image {
                    Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.background(.black)
    }
}
