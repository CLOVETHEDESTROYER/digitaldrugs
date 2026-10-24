import SwiftUI
import Observation

@MainActor @Observable
final class ContentLibraryState {
    var assets: [HistoryAsset] = []
    var requests: [[String: String]] = []
    var publications: [[String: String]] = []
    var watching = false
    var error: String?
    var message = "Choose a dedicated exchange folder, then start local processing."
    var search = ""
    var exchange = URL(fileURLWithPath: UserDefaults.standard.string(forKey: "agentExchange") ??
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/ZenWave Exchange").path)
    private var task: Task<Void, Never>?
    var visible: [HistoryAsset] { assets.filter { search.isEmpty || [$0.title, $0.requestID, $0.status, $0.fingerprint].joined(separator: " ").localizedCaseInsensitiveContains(search) } }
    func refresh() {
        do { assets = try ContentHistory.shared.assets(); requests = try ContentHistory.shared.requests(); publications = try ContentHistory.shared.publications() }
        catch { self.error = error.localizedDescription }
    }
    func resumeIfEnabled() { if UserDefaults.standard.bool(forKey: "agentEnabled") { start() } }
    func chooseExchange() {
        guard !watching else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.message = "Choose a dedicated ZenWave exchange folder. A synced folder can be used only after verifying Muse can write and read it."
        if panel.runModal() == .OK, let url = panel.url { exchange = url; UserDefaults.standard.set(url.path, forKey: "agentExchange") }
    }
    func setup() {
        do { try AgentQueue(root: exchange, history: ContentHistory.shared).setup(library: StudioResources.library()); message = "Exchange ready. Instructions, catalog and a test request are inside." }
        catch { self.error = error.localizedDescription }
    }
    func start() {
        guard task == nil else { return }
        do {
            let queue = try AgentQueue(root: exchange, history: ContentHistory.shared)
            let library = try StudioResources.library()
            try queue.setup(library: library)
            watching = true; UserDefaults.standard.set(true, forKey: "agentEnabled")
            message = "Local processing is on. Keep this app open and the Mac awake. Muse account access is configured separately."
            task = Task {
                let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Processing local content jobs")
                defer { ProcessInfo.processInfo.endActivity(activity); watching = false; task = nil; refresh() }
                let worker = Task.detached {
                    while !Task.isCancelled {
                        try await queue.poll(library: library)
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                }
                do { try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() } }
                catch is CancellationError { message = "Local processing stopped. Completed media and history were kept." }
                catch { self.error = error.localizedDescription; UserDefaults.standard.set(false, forKey: "agentEnabled") }
            }
        } catch { self.error = error.localizedDescription }
    }
    func stop() { UserDefaults.standard.set(false, forKey: "agentEnabled"); task?.cancel() }
    func copyMusePrompt() {
        let prompt = """
        Connect to my local ZenWave Content Studio using your authorized Mac file access. The exchange folder is \(exchange.path).
        First read AGENT-INSTRUCTIONS.md and catalog.json. Prove you can write Requests/first-test.json using the provided Examples/first-test.json, wait for Status/first-test.json to say complete, and retrieve the three-second video. Submit the identical request again to verify that it returns the same asset IDs. Do not publish or schedule this test.
        If you cannot access this folder, tell me which local permission or supported read/write storage connection is needed. Do not pretend that your cloud computer is this Mac. Do not host the studio or access its SQLite database directly.
        After the round trip succeeds, use stable request IDs to request the number of unused videos I ask for, normally batches of 10. Keep exact schedules and Facebook Page access separate and wait for my posting instructions. Record actual platform results through the documented Reports folder.
        """
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(prompt, forType: .string)
        message = "Connection test prompt copied. Paste it into Muse after granting access to the exchange folder."
    }
    func recover() {
        guard !watching else { return }
        do { try ContentHistory.shared.recoverInterrupted(); message = "Interrupted reservations checked. Existing media remains protected; requests are marked interrupted. Use a new ID for a reviewed replacement."; refresh() }
        catch { self.error = error.localizedDescription }
    }
    func importHistory() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.message = "Choose your existing ZenWave export folder. MP4s with settings receipts are added to history."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let report = try LegacyHistoryImporter.run(folder: folder, history: ContentHistory.shared, library: StudioResources.library())
            message = report; refresh()
        } catch { self.error = error.localizedDescription }
    }
    func exportHistory() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "ZenWave-History.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            struct Report: Encodable { let assets: [HistoryAsset]; let requests: [[String: String]]; let publications: [[String: String]]; let events: [[String: String]] }
            let history = try ContentHistory.shared
            try Data(ContentHistory.json(Report(assets: history.assets(), requests: history.requests(), publications: history.publications(), events: history.events())).utf8).write(to: url, options: .atomic)
        } catch { self.error = error.localizedDescription }
    }
}

struct ContentLibraryView: View {
    @Bindable var state: ContentLibraryState
    @State private var confirmRecovery = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History & Agent Jobs").font(.largeTitle.bold())
            Text("One local history protects every new export from repeating its core video/audio combination.").foregroundStyle(.secondary)
            GroupBox("Local agent exchange") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.exchange.path).font(.caption).textSelection(.enabled)
                    HStack {
                        Button("Choose folder…", action: state.chooseExchange).disabled(state.watching)
                        Button("Prepare exchange", action: state.setup).disabled(state.watching)
                        Button("Open exchange") { NSWorkspace.shared.open(state.exchange) }
                        Button("Copy Muse connection prompt", action: state.copyMusePrompt)
                        Spacer()
                        if state.watching { Button("Stop processing", action: state.stop) }
                        else { Button("Start local processing", action: state.start).buttonStyle(.borderedProminent) }
                    }
                    Text(state.message).font(.callout).foregroundStyle(.secondary)
                    Text("This processes local JSON requests. It does not sign in to Muse, expose a public server, or publish to Facebook. Share the exchange instructions with Muse after granting its access to this folder.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            HStack {
                TextField("Search history", text: $state.search).textFieldStyle(.roundedBorder)
                Button("Refresh", action: state.refresh)
                Button("Import old exports…", action: state.importHistory).disabled(state.watching)
                Button("Export history…", action: state.exportHistory)
                Button("Open database folder") { NSWorkspace.shared.open(ContentHistory.directory) }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(state.visible) { asset in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asset.title).font(.headline)
                                Text("\(asset.status.uppercased()) · \(asset.created) · \(asset.requestID.isEmpty ? "Manual export" : asset.requestID)").font(.caption).foregroundStyle(.secondary)
                                Text("Asset \(asset.id)").font(.caption2).textSelection(.enabled)
                                DisclosureGroup("Visual/audio identity") { Text(asset.recipe).font(.system(.caption2, design: .monospaced)).textSelection(.enabled) }
                                if !asset.error.isEmpty { Text(asset.error).font(.caption).foregroundStyle(.orange) }
                            }
                            Spacer()
                            if FileManager.default.fileExists(atPath: asset.output) {
                                Button("Open video") { NSWorkspace.shared.open(URL(fileURLWithPath: asset.output)) }
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.output)]) }
                            }
                        }.padding(12).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if state.assets.isEmpty { Text("No history yet. Import existing exports or make your first new video.").foregroundStyle(.secondary).padding() }
                    ForEach(state.requests, id: \.self) { request in
                        DisclosureGroup("Request \(request["id"] ?? "") · \(request["status"] ?? "")") {
                            Text(request["payload"] ?? "").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                    ForEach(state.publications, id: \.self) { publication in
                        DisclosureGroup("Publication acknowledgement \(publication["id"] ?? "")") {
                            Text(publication["payload"] ?? "").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
            }
            HStack {
                Text("Completed videos stay protected even if moved, deleted or rejected. History is stored on this Mac; copy its backup when moving the authoritative renderer.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Recover interrupted renders…") { confirmRecovery = true }.disabled(state.watching)
            }
        }.padding(24).frame(minWidth: 900, minHeight: 680).preferredColorScheme(.dark)
        .task { state.refresh() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in state.refresh() }
        .alert("History needs attention", isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) {
            Button("OK") { state.error = nil }
        } message: { Text(state.error ?? "") }
        .alert("Recover interrupted renders?", isPresented: $confirmRecovery) {
            Button("Cancel", role: .cancel) {}
            Button("Recover", action: state.recover)
        } message: { Text("First close every other ZenWave Studio process on this Mac. Reservations with a saved movie remain blocked; reservations without a movie become retryable. Interrupted requests require review and a new request ID.") }
    }
}

enum LegacyHistoryImporter {
    static func run(folder: URL, history: ContentHistory, library: [Mantra]) throws -> String {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])
        var imported = 0, unresolved = 0, skipped = 0
        while let file = files?.nextObject() as? URL {
            guard file.pathExtension.lowercased() == "mp4", (try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { continue }
            do {
                let base = file.deletingPathExtension()
                let receipt = try JSONDecoder().decode(ExportReceipt.self, from: Data(contentsOf: base.appendingPathExtension("json")))
                let breath = try? JSONDecoder().decode(BreathPlan.self, from: Data(contentsOf: base.appendingPathExtension("breathing.json")))
                let live = try? JSONDecoder().decode(LiveTimeline.self, from: Data(contentsOf: base.appendingPathExtension("playlist.json")))
                guard let mantra = breath?.mantra ?? live?.mantra ?? library.first(where: { $0.fileName == receipt.sourceFile }) else { skipped += 1; continue }
                // Old receipts name imported audio but do not hash it. Never guess its content.
                let missingBackground = receipt.backgroundFile != nil && receipt.settings.backgroundVolume > 0
                let job = ExportJob(mantra: mantra, settings: receipt.settings, start: receipt.start, end: receipt.end, liveTimeline: live, breathPlan: breath)
                try history.importAsset(recipe: ContentRecipe.make(job), output: file, title: receipt.title, unresolvedBackground: missingBackground)
                imported += 1; if missingBackground { unresolved += 1 }
            } catch { skipped += 1 }
        }
        try history.backup()
        return "Processed \(imported) receipts; \(unresolved) use conservative imported-audio blocking; \(skipped) movies could not be reconstructed and need manual review. Deleted media or missing receipts cannot be recovered from chat."
    }
}
