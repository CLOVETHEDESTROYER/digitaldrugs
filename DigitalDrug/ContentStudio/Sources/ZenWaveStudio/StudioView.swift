import SwiftUI

struct StudioView: View {
    @Bindable var studio: StudioState
    var body: some View {
        HSplitView {
            libraryPanel.frame(minWidth: 260, idealWidth: 290, maxWidth: 340)
            workspace.frame(minWidth: 410, maxWidth: .infinity)
            inspector.frame(minWidth: 285, idealWidth: 310, maxWidth: 360)
        }
        .frame(minWidth: 1040, minHeight: 740)
        .background(Color(red: 0.035, green: 0.045, blue: 0.075))
        .preferredColorScheme(.dark)
        .tint(.cyan)
        .alert("Studio needs attention", isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })) {
            Button("OK") { studio.error = nil }
        } message: { Text(studio.error ?? "") }
        .onChange(of: studio.selectedID) { _, _ in studio.loadSelected() }
        .onChange(of: studio.settings) { _, _ in studio.settings.save(); studio.redraw() }
        .onChange(of: studio.clipIndex) { _, _ in studio.clipChanged() }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label("ZENWAVE", systemImage: "waveform.path").font(.headline).tracking(3).foregroundStyle(.cyan)
                Text("Content Studio").font(.title2.weight(.semibold))
                Text("Your daily content starts here.").font(.subheadline).foregroundStyle(.secondary)
            }.padding(.top, 18)
            TextField("Search recordings", text: $studio.search).textFieldStyle(.roundedBorder)
            HStack {
                Text("\(studio.library.count) RECORDINGS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Menu("Queue") {
                    Button("Add visible recordings") { studio.queued.formUnion(studio.filtered.map(\.id)) }
                    Button("Clear queue") { studio.queued.removeAll() }
                }.menuStyle(.borderlessButton).fixedSize()
            }
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(studio.filtered) { mantra in
                        HStack(spacing: 9) {
                            Toggle("Queue \(mantra.title)", isOn: Binding(get: { studio.queued.contains(mantra.id) }, set: { _ in studio.toggleQueued(mantra.id) }))
                                .toggleStyle(.checkbox).labelsHidden()
                            Button {
                                studio.selectedID = mantra.id
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mantra.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                    Text(mantra.category).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 11).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .background(studio.selectedID == mantra.id ? Color.cyan.opacity(0.12) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(studio.selectedID == mantra.id ? Color.cyan.opacity(0.4) : .clear))
                    }
                }
            }
            Text("Check recordings to build a batch. Click a title to preview it.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 18).padding(.bottom, 18).disabled(studio.exporting)
    }

    private var workspace: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(studio.selected?.title ?? "Preview").font(.title3.weight(.semibold))
                    Text("Original audio · App visualizers").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("PREVIEW").font(.caption2.weight(.medium)).tracking(2).foregroundStyle(.cyan)
            }
            GeometryReader { geo in
                Group {
                    if let image = studio.previewImage {
                        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    } else {
                        ContentUnavailableView("No preview", systemImage: "waveform", description: Text("Choose a recording from the library."))
                    }
                }
                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(12)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22))
            HStack(spacing: 12) {
                Button(action: studio.togglePlayback) {
                    Image(systemName: studio.playing ? "pause.fill" : "play.fill").frame(width: 22, height: 22)
                }.buttonStyle(.borderedProminent).accessibilityLabel(studio.playing ? "Pause preview" : "Play preview")
                Slider(value: Binding(get: { studio.elapsed }, set: { studio.seek($0) }), in: studio.clipStart...max(studio.clipStart + 0.01, studio.clipEnd))
                    .accessibilityLabel("Playback position")
                Text("\(clock(studio.elapsed - studio.clipStart)) / \(clock(studio.clipEnd - studio.clipStart))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 90)
            }.disabled(studio.exporting || studio.duration == 0)
            VStack(alignment: .leading, spacing: 8) {
                if studio.exporting { ProgressView(value: studio.progress) }
                HStack {
                    Text(studio.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    if studio.exporting { Button("Stop", action: studio.cancelExport) }
                    else if studio.lastExportFolder != nil { Button("Show videos", action: studio.revealExports) }
                }
            }.frame(minHeight: 38)
        }.padding(24)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Make it yours").font(.title3.weight(.semibold))
                    GroupBox("VIDEO") {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Visualizer", selection: $studio.settings.style) {
                                ForEach(VisualStyle.all) { Text($0.title).tag($0.id) }
                            }
                            Picker("Format", selection: $studio.settings.format) {
                                ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) }
                            }
                            Text("\(studio.settings.format.width) × \(studio.settings.format.height) · 30 fps · MP4")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    GroupBox("TEXT & BRANDING") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Show mantra captions", isOn: $studio.settings.captions)
                            Toggle("ZenWave wordmark", isOn: $studio.settings.branding)
                            TextField("Optional heading", text: $studio.settings.heading, axis: .vertical)
                                .lineLimit(2...3).textFieldStyle(.roundedBorder)
                            if studio.settings.captions {
                                Text(studio.selected?.estimated == true ? "Estimated caption timing. Listen through before exporting; the offset shifts all captions together." : "Uses the app’s existing line timestamps. Preview before exporting.")
                                    .font(.caption).foregroundStyle(studio.selected?.estimated == true ? .orange : .secondary)
                                HStack {
                                    Text("Caption offset").font(.caption)
                                    Spacer()
                                    TextField("Seconds", value: $studio.settings.captionOffset, format: .number.precision(.fractionLength(1)))
                                        .frame(width: 55).textFieldStyle(.roundedBorder)
                                    Text("sec").font(.caption).foregroundStyle(.secondary)
                                }
                                Text("Positive values show captions later.").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(8)
                    }
                    GroupBox("CLIP") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Export", selection: $studio.clipIndex) {
                                Text("Full recording").tag(-1)
                                if let selected = studio.selected, !selected.estimated {
                                    ForEach(Array(selected.cues.enumerated()), id: \.offset) { i, cue in
                                        Text(cue.text).tag(i)
                                    }
                                }
                            }
                            Text("\(String(format: "%.1f", studio.clipEnd - studio.clipStart)) seconds\(studio.clipIndex >= 0 ? " · Selected line" : " · Original recording")")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Batch exports use full recordings with the settings above.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAVE TO").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text(studio.outputFolder.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Button("Choose folder…", action: studio.chooseFolder)
                    }
                }.padding(20)
            }.disabled(studio.exporting)
            Divider()
            VStack(spacing: 10) {
                Button(action: { studio.startExport(batch: false) }) {
                    Label("Export this video", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(studio.selected == nil || studio.exporting)
                Button("Export queue · \(studio.queued.count) videos") { studio.startExport(batch: true) }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity).disabled(studio.queued.isEmpty || studio.exporting)
                Text("Videos are generated locally on this Mac.").font(.caption2).foregroundStyle(.secondary)
            }.padding(20)
        }
    }
    private func clock(_ seconds: Double) -> String {
        let n = max(0, Int(seconds)); return String(format: "%d:%02d", n / 60, n % 60)
    }
}
