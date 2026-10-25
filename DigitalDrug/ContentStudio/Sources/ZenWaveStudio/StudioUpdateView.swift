import SwiftUI
import Observation

@MainActor @Observable
final class StudioUpdateState {
    enum Phase { case idle, checking, available, downloading, prepared, waiting }
    var phase: Phase = .idle
    var available: AvailableStudioUpdate?
    var prepared: PreparedStudioUpdate?
    var receipt: StudioUpdateReceipt?
    var message = "Check for a new studio release. Updates are installed only when you choose."
    var error: String?
    var hasChecked = false
    private var task: Task<Void, Never>?
    private var updateLease: StudioOperationLease?
    var busy: Bool { phase == .checking || phase == .downloading || phase == .waiting }
    func refreshReceipt() {
        if let data = try? Data(contentsOf: StudioUpdateInstaller.lastReceipt) { receipt = try? JSONDecoder().decode(StudioUpdateReceipt.self, from: data) }
    }
    func check() {
        guard !busy else { return }
        phase = .checking; hasChecked = true; error = nil
        available = nil
        task = Task {
            do {
                available = try await StudioUpdateClient.check()
                phase = available == nil ? .idle : .available
                message = available == nil ? "You have the latest compatible studio release." : "Version \(available!.version) is available. Downloading does not interrupt rendering."
            } catch { self.error = error.localizedDescription; phase = .idle }
            task = nil
        }
    }
    func download() {
        guard !busy, let available else { return }
        phase = .downloading; error = nil; message = "Downloading and verifying the update…"
        task = Task {
            do {
                prepared = try await StudioUpdateClient.prepare(available)
                phase = .prepared; message = "Download verified. Install when ready; the studio will wait for current jobs to finish."
            } catch { self.error = error.localizedDescription; phase = .available }
            task = nil
        }
    }
    func install(onQuit: @escaping () -> Void) {
        guard !busy, let prepared else { return }
        do {
            try StudioUpdateInstaller.preflightTarget(Bundle.main.bundleURL)
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: StudioBuild.identifier).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            guard others.isEmpty else { throw StudioError.message("Close other copies of Content Studio before installing. No running copy will be forced to quit.") }
        } catch { self.error = error.localizedDescription; return }
        phase = .waiting; error = nil; message = "Waiting for active jobs to finish. New requests will wait until after the update. You can cancel this wait."
        task = Task {
            var helper: Process?
            do {
                updateLease = try await StudioOperationGate.shared.waitForUpdate()
                try Task.checkCancellation()
                let history = try ContentHistory.shared
                let plan = try StudioUpdateInstaller.makePlan(prepared: prepared, target: Bundle.main.bundleURL, history: history)
                let planURL = prepared.stage.appendingPathComponent("install-plan.json")
                try Data(ContentHistory.json(plan).utf8).write(to: planURL, options: .atomic)
                guard let executable = Bundle.main.executableURL else { throw StudioError.message("The running app executable is unavailable.") }
                let helperURL = prepared.stage.appendingPathComponent("ZenWaveUpdateHelper")
                if FileManager.default.fileExists(atPath: helperURL.path) { try FileManager.default.removeItem(at: helperURL) }
                try FileManager.default.copyItem(at: executable, to: helperURL)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)
                let process = Process(); helper = process; process.executableURL = helperURL
                process.arguments = ["--install-update", planURL.path]
                let logURL = prepared.stage.appendingPathComponent("installer.log")
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
                let log = try FileHandle(forWritingTo: logURL)
                process.standardOutput = log; process.standardError = log
                try process.run(); try? log.close()
                let deadline = Date().addingTimeInterval(15)
                while !FileManager.default.fileExists(atPath: plan.ready.path), process.isRunning, Date() < deadline {
                    try Task.checkCancellation(); try await Task.sleep(nanoseconds: 100_000_000)
                }
                guard process.isRunning, FileManager.default.fileExists(atPath: plan.ready.path) else {
                    throw StudioError.message("The update helper did not become ready. The installed app is unchanged. Details: \(logURL.path)")
                }
                try Task.checkCancellation()
                try Data("install".utf8).write(to: plan.intent, options: .atomic)
                message = "Installing and relaunching…"
                onQuit()
                NSApplication.shared.terminate(nil)
                // Keep the exclusive lease until this process exits. The helper
                // then acquires its own lock before touching either app bundle.
            } catch {
                if let helper, helper.isRunning { helper.terminate() }
                updateLease?.release(); updateLease = nil; StudioOperationGate.shared.cancelUpdate()
                phase = .prepared
                if error is CancellationError { message = "Update postponed. Local processing can continue." }
                else { self.error = error.localizedDescription }
                task = nil
            }
        }
    }
    func cancelWait() { if phase == .waiting { task?.cancel() } }
    func discardDownload() {
        guard !busy, let prepared else { return }
        do {
            if prepared.stage.standardizedFileURL.path.hasPrefix(StudioUpdateClient.cache.standardizedFileURL.path + "/") {
                try FileManager.default.removeItem(at: prepared.stage)
            }
            self.prepared = nil; phase = available == nil ? .idle : .available
            message = "Prepared update discarded. The installed app and recovery backups were not changed."
        } catch { self.error = error.localizedDescription }
    }
    func restorePrevious(onQuit: @escaping () -> Void) {
        guard !busy, let receipt, FileManager.default.fileExists(atPath: receipt.previousApp.path) else { return }
        do {
            let stage = StudioUpdateClient.cache.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
            prepared = PreparedStudioUpdate(app: receipt.previousApp, stage: stage, version: receipt.fromVersion)
            available = nil
            phase = .prepared; install(onQuit: onQuit)
        } catch { self.error = error.localizedDescription }
    }
}

struct StudioUpdateView: View {
    @Bindable var updates: StudioUpdateState
    let onQuit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("App Updates").font(.largeTitle.bold())
            Text("Installed: \(StudioBuild.version)").font(.headline)
            Text(Bundle.main.bundleURL.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Text("Updates include new visuals, sounds and studio improvements. They preserve your history, saved Drive exchange folder, and version 1 automation interface.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Check for Updates", action: updates.check).disabled(updates.busy || updates.phase == .prepared)
                Button("View releases") { NSWorkspace.shared.open(StudioUpdateClient.releasesPage) }
                if updates.busy { ProgressView().controlSize(.small) }
            }
            if let available = updates.available {
                Text("Available: \(available.version) · \(ByteCountFormatter.string(fromByteCount: available.asset.size, countStyle: .file))").font(.title3)
                ScrollView { Text(available.release.body ?? "Studio improvements.").frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(maxHeight: 180)
            }
            Text(updates.message).fixedSize(horizontal: false, vertical: true)
            if updates.phase == .available { Button("Download Update", action: updates.download).buttonStyle(.borderedProminent) }
            if updates.phase == .prepared {
                Text("Prepared version: \(updates.prepared?.version ?? "")").font(.headline)
                HStack {
                    Button("Install & Relaunch") { updates.install(onQuit: onQuit) }.buttonStyle(.borderedProminent)
                    Button("Discard prepared update", action: updates.discardDownload)
                }
            }
            if updates.phase == .waiting { Button("Cancel waiting", action: updates.cancelWait) }
            Divider()
            Text("Installation waits for existing batches to finish and makes a history snapshot. The previous app is retained for rollback; rolling back never restores an older history database.")
                .font(.callout).foregroundStyle(.secondary)
            if let receipt = updates.receipt {
                Text("Last update: \(receipt.status) · \(receipt.fromVersion) → \(receipt.toVersion)").font(.headline)
                Text(receipt.message).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Open recovery folder") { NSWorkspace.shared.open(receipt.recovery) }
                    if FileManager.default.fileExists(atPath: receipt.previousApp.path) {
                        Button("Restore previous app & relaunch") { updates.restorePrevious(onQuit: onQuit) }.disabled(updates.busy)
                    }
                }
            }
            Text("Only packages from this project's GitHub releases are accepted. Downloads are checked against GitHub's SHA-256 digest, app identity, both CPU architectures and automation compatibility. This remains an ad-hoc-signed personal Mac build.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }.padding(28).frame(minWidth: 620, minHeight: 660).preferredColorScheme(.dark)
        .task { updates.refreshReceipt(); if !updates.hasChecked { updates.check() } }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in updates.refreshReceipt() }
        .alert("Update needs attention", isPresented: Binding(get: { updates.error != nil }, set: { if !$0 { updates.error = nil } })) {
            Button("OK") { updates.error = nil }
        } message: { Text(updates.error ?? "") }
    }
}

struct StudioUpdateCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(after: .appInfo) { Button("Check for Updates…") { openWindow(id: "studio-updates") } }
    }
}
