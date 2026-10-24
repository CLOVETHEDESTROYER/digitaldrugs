import SwiftUI

struct StudioView: View {
    @Bindable var studio: StudioState
    @Environment(\.openWindow) private var openWindow
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
        .onChange(of: studio.settings) { old, new in
            studio.settings.save(); studio.redraw()
            if old.soundscape != new.soundscape || (old.backgroundVolume != new.backgroundVolume && studio.backgroundURL != nil) { studio.refreshAudioMix() }
        }
        .onChange(of: studio.clipIndex) { _, _ in studio.clipChanged() }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label("ZENWAVE", systemImage: "waveform.path").font(.headline).tracking(3).foregroundStyle(.cyan)
                Text("Content Studio").font(.title2.weight(.semibold))
                Text("Your daily content starts here.").font(.subheadline).foregroundStyle(.secondary)
            }.padding(.top, 18)
            Button("Live Session…", systemImage: "play.rectangle.on.rectangle") { studio.pause(); openWindow(id: "live-session") }
                .buttonStyle(.borderedProminent)
            Button("Random Batch…", systemImage: "shuffle") { studio.pause(); openWindow(id: "random-batch") }
                .buttonStyle(.bordered)
            Button("Breathing Practice…", systemImage: "circle.dotted") { studio.pause(); openWindow(id: "breathing-practice") }
                .buttonStyle(.bordered)
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
                    Text(studio.backgroundURL == nil && !studio.settings.soundscape.active ? "Original voice · Ambient motion" : "Voice + background · Background-reactive visuals").font(.caption).foregroundStyle(.secondary)
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
            }.disabled(studio.exporting || !studio.audioReady || studio.duration == 0)
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
                                Section("Flow, blooms & space") {
                                    ForEach(VisualStyle.all.filter { $0.id < 20 }) { Text($0.title).tag($0.id) }
                                }
                                Section("Resonance") {
                                    ForEach(VisualStyle.all.filter { $0.id >= 34 }) { Text($0.title).tag($0.id) }
                                }
                                Section("Chakras") {
                                    ForEach(VisualStyle.all.filter { $0.id >= 26 && $0.id < 34 }) { Text($0.title).tag($0.id) }
                                }
                                Section("Sacred geometry") {
                                    ForEach(VisualStyle.all.filter { $0.id >= 20 && $0.id < 26 }) { Text($0.title).tag($0.id) }
                                }
                            }
                            Picker("Colors", selection: $studio.settings.palette) {
                                ForEach(VisualPalette.all) { Text($0.title).tag($0.id) }
                            }
                            paletteSwatches
                            Picker("Format", selection: $studio.settings.format) {
                                ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) }
                            }
                            Text("\(studio.settings.format.width) × \(studio.settings.format.height) · 30 fps · MP4")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    motionControls
                    SoundscapeControls(soundscape: $studio.settings.soundscape)
                    backgroundControls
                    GroupBox("TEXT & BRANDING") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Show mantra captions", isOn: $studio.settings.captions)
                            Toggle("Show ZenWave branding", isOn: $studio.settings.branding)
                            if studio.settings.branding {
                                Picker("Branding", selection: $studio.settings.brandStyle) {
                                    ForEach(StudioBrandStyle.allCases) { Text($0.rawValue).tag($0) }
                                }
                                if studio.settings.brandStyle.showsLogo {
                                    HStack {
                                        Image(nsImage: StudioBranding.previewImage)
                                            .resizable().scaledToFit().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
                                        Text("Official ZenWave brand mark").font(.caption).foregroundStyle(.secondary)
                                    }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Logo size").font(.caption)
                                        Slider(value: $studio.settings.logoSize, in: 0.08...0.20).accessibilityLabel("Logo size")
                                    }
                                    HStack {
                                        Text("Logo opacity").font(.caption)
                                        Spacer()
                                        Text(studio.settings.logoOpacity, format: .percent.precision(.fractionLength(0))).font(.caption)
                                    }
                                    Slider(value: $studio.settings.logoOpacity, in: 0.25...1).accessibilityLabel("Logo opacity")
                                    Text("Keeps the original logo colors. Size adapts to stay below captions.").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            TextField("Optional heading", text: $studio.settings.heading, axis: .vertical)
                                .lineLimit(2...3).textFieldStyle(.roundedBorder)
                            if !studio.settings.heading.isEmpty {
                                Text("Heading size").font(.caption)
                                Slider(value: $studio.settings.headingEmphasis, in: 0.75...2.4).accessibilityLabel("Heading size")
                            }
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
                    CallToActionControls(cta: $studio.settings.callToAction)
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
                    .disabled(studio.selected == nil || studio.exporting || !studio.audioReady)
                Button("Export queue · \(studio.queued.count) videos") { studio.startExport(batch: true) }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity).disabled(studio.queued.isEmpty || studio.exporting || !studio.audioReady)
                Text("Videos are generated locally on this Mac.").font(.caption2).foregroundStyle(.secondary)
            }.padding(20)
        }
    }
    private var paletteSwatches: some View {
        HStack(spacing: 7) {
            ForEach((VisualPalette.all.first { $0.id == studio.settings.palette } ?? VisualPalette.all[0]).colors, id: \.self) { hex in
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: Double((hex >> 16) & 255) / 255,
                                green: Double((hex >> 8) & 255) / 255,
                                blue: Double(hex & 255) / 255))
                    .frame(height: 12)
            }
        }.accessibilityLabel("Selected color palette")
    }
    private var motionControls: some View {
        GroupBox("MOVEMENT") {
            VStack(alignment: .leading, spacing: 14) {
                motionSlider("Pace", value: $studio.settings.motionSpeed, range: 0.25...2)
                motionSlider("Flow & swell", value: $studio.settings.motionAmount, range: 0...2)
                motionSlider("Sound response", value: $studio.settings.audioResponse, range: 0...2)
                Text("Only background layers drive movement. Background bass opens the field, mids shape the flow, and highs add detail. The mantra never drives the visuals.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reset movement") {
                    studio.settings.motionSpeed = 1
                    studio.settings.motionAmount = 1
                    studio.settings.audioResponse = 1
                }.font(.caption)
            }.padding(8)
        }
    }
    private func motionSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).accessibilityLabel(label)
        }
    }
    private var backgroundControls: some View {
        GroupBox("BACKGROUND AUDIO") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = studio.backgroundURL {
                    Label(url.lastPathComponent, systemImage: "music.note").font(.caption).lineLimit(2)
                    HStack {
                        Button("Replace…", action: studio.chooseBackground)
                        Button("Remove", action: studio.removeBackground)
                    }
                    HStack {
                        Text("Background level").font(.caption)
                        Spacer()
                        Text(studio.settings.backgroundVolume, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Slider(value: $studio.settings.backgroundVolume, in: 0...0.6)
                        .accessibilityLabel("Background audio level")
                    Text("Loops with crossfades to fill the mantra. Voice and background share headroom to avoid clipping.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Add music or ambient audio…", action: studio.chooseBackground)
                    Text("Optional. Visuals react to background layers only. Without a background, gentle ambient motion continues.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if studio.preparingAudio { ProgressView("Preparing mix…").font(.caption) }
            }.padding(8)
        }
    }
    private func clock(_ seconds: Double) -> String {
        let n = max(0, Int(seconds)); return String(format: "%d:%02d", n / 60, n % 60)
    }
}
