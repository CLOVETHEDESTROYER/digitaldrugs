import AppKit
import Foundation
import Darwin

struct StudioInstallPlan: Codable {
    let id: String
    let parentPID: Int32
    let sourceApp: URL
    let targetApp: URL
    let stage: URL
    let recovery: URL
    let historyURL: URL
    let fromVersion: String
    let toVersion: String
    // Internal package verification uses only private temporary copies and exits
    // through the existing media-verification CLI, never an installed GUI app.
    var verificationOnly: Bool? = nil
    var previousApp: URL { recovery.appendingPathComponent("Previous Studio.app") }
    var retiredApp: URL { targetApp.deletingLastPathComponent().appendingPathComponent(".ZenWave-previous-\(id).app") }
    var incomingApp: URL { targetApp.deletingLastPathComponent().appendingPathComponent(".ZenWave-incoming-\(id).app") }
    var ready: URL { stage.appendingPathComponent("installer-ready") }
    var intent: URL { stage.appendingPathComponent("install-authorized") }
    var confirmation: URL { stage.appendingPathComponent("launch-confirmation.json") }
    var receiptURL: URL { verificationOnly == true ? stage.appendingPathComponent("update-receipt.json") : StudioUpdateInstaller.lastReceipt }
}
struct StudioUpdateReceipt: Codable {
    var status: String
    let fromVersion: String
    let toVersion: String
    let targetApp: URL
    let previousApp: URL
    let recovery: URL
    var message: String
    let date: Date
}
struct StudioLaunchConfirmation: Codable { let success: Bool; let pid: Int32; let message: String }

enum StudioUpdateInstaller {
    static let lastReceipt = ContentHistory.directory.appendingPathComponent("last-update.json")
    static func installedInfo(_ app: URL) throws -> (version: String, identifier: String) {
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              let version = info["CFBundleShortVersionString"] as? String,
              let identifier = info["CFBundleIdentifier"] as? String else { throw StudioError.message("Run the installed .app to install updates.") }
        return (version, identifier)
    }
    static func preflightTarget(_ app: URL) throws {
        let info = try installedInfo(app)
        guard app.pathExtension == "app", info.identifier == StudioBuild.identifier,
              (try app.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              FileManager.default.isWritableFile(atPath: app.path), FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path) else {
            throw StudioError.message("The app cannot be replaced at its current location. Move it into your user Applications folder, or install the ZIP manually with the appropriate permissions.")
        }
    }
    static func makePlan(prepared: PreparedStudioUpdate, target: URL, history: ContentHistory) throws -> StudioInstallPlan {
        try preflightTarget(target)
        let oldSize = directorySize(target), newSize = directorySize(prepared.app)
        let historySize = (try? history.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let targetSpace = try target.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        let recoverySpace = try ContentHistory.directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard targetSpace > newSize + 20_000_000, recoverySpace > oldSize + historySize * 2 + 50_000_000 else {
            throw StudioError.message("Free more space before installation so the previous app and current history can both be backed up.")
        }
        let recovery = ContentHistory.directory.appendingPathComponent("Update Recovery/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        try history.snapshot(to: recovery.appendingPathComponent("history.sqlite"))
        if let preferences = UserDefaults.standard.persistentDomain(forName: StudioBuild.identifier) {
            try PropertyListSerialization.data(fromPropertyList: preferences, format: .xml, options: 0)
                .write(to: recovery.appendingPathComponent("Preferences.plist"), options: .atomic)
        }
        return StudioInstallPlan(id: UUID().uuidString, parentPID: getpid(), sourceApp: prepared.app, targetApp: target,
            stage: prepared.stage, recovery: recovery, historyURL: history.url,
            fromVersion: try installedInfo(target).version, toVersion: prepared.version)
    }
    private static func directorySize(_ root: URL) -> Int64 {
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
        var total: Int64 = 0
        while let file = files?.nextObject() as? URL { total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return total
    }
    /// Runs in a detached copy of the existing executable, outside the app being replaced.
    static func run(planURL: URL) async throws {
        let plan = try JSONDecoder().decode(StudioInstallPlan.self, from: Data(contentsOf: planURL))
        if plan.verificationOnly == true {
            let temp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path + "/"
            guard [plan.sourceApp, plan.targetApp, plan.stage, plan.recovery, plan.historyURL].allSatisfy({ $0.resolvingSymlinksInPath().path.hasPrefix(temp) }) else {
                throw StudioError.message("Installer verification is restricted to temporary app copies and history.")
            }
        }
        try preflightTarget(plan.targetApp)
        try StudioUpdateClient.validateApp(plan.sourceApp, expectedVersion: plan.toVersion)
        try Data("ready".utf8).write(to: plan.ready, options: .atomic)
        let deadline = Date().addingTimeInterval(300)
        while kill(plan.parentPID, 0) == 0 || errno == EPERM {
            guard Date() < deadline else { throw StudioError.message("The previous app did not quit. Update cancelled.") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard FileManager.default.fileExists(atPath: plan.intent.path) else { return }
        let gate = StudioOperationGate(url: plan.historyURL.deletingLastPathComponent().appendingPathComponent("studio-operation.lock"))
        var exclusive: StudioOperationLease?
        var probeProcess: Process?
        defer { exclusive?.release() }
        var receipt = StudioUpdateReceipt(status: "installing", fromVersion: plan.fromVersion, toVersion: plan.toVersion,
            targetApp: plan.targetApp, previousApp: plan.previousApp, recovery: plan.recovery, message: "", date: Date())
        do {
            while exclusive == nil {
                guard Date() < deadline else { throw StudioError.message("Another studio process is still busy. Update cancelled.") }
                exclusive = try gate.tryExclusive()
                if exclusive == nil { try await Task.sleep(nanoseconds: 100_000_000) }
            }
            guard plan.verificationOnly == true || NSRunningApplication.runningApplications(withBundleIdentifier: StudioBuild.identifier).isEmpty else {
                throw StudioError.message("Another copy of the studio opened before installation. The app was not replaced.")
            }
            try swap(plan)
            probeProcess = try launch(plan: plan, planURL: planURL, confirm: true)
            let launchDeadline = Date().addingTimeInterval(60)
            var confirmation: StudioLaunchConfirmation?
            while confirmation == nil, Date() < launchDeadline {
                if let data = try? Data(contentsOf: plan.confirmation) { confirmation = try? JSONDecoder().decode(StudioLaunchConfirmation.self, from: data) }
                if confirmation == nil { try await Task.sleep(nanoseconds: 200_000_000) }
            }
            guard confirmation?.success == true else {
                if let pid = confirmation?.pid, kill(pid, 0) == 0 { kill(pid, SIGTERM) }
                throw StudioError.message(confirmation?.message ?? "The updated app did not confirm startup. The previous app will be restored.")
            }
            if let probeProcess { probeProcess.waitUntilExit(); guard probeProcess.terminationStatus == 0 else { throw StudioError.message("The package verification process failed after startup.") } }
            receipt.status = "installed"
            receipt.message = "Update verified. History, preferences and the exchange selection were preserved. The previous app is available for rollback."
            try writeReceipt(receipt, to: plan.receiptURL)
            try? FileManager.default.removeItem(at: plan.retiredApp)
            // Retain recovery app/database, but release the large download/staging files.
            if plan.sourceApp.deletingLastPathComponent() == plan.stage.appendingPathComponent("Unpacked") {
                try? FileManager.default.removeItem(at: plan.sourceApp.deletingLastPathComponent())
            }
            try? FileManager.default.removeItem(at: plan.stage.appendingPathComponent("update.zip"))
        } catch {
            if let probeProcess, probeProcess.isRunning { probeProcess.terminate(); probeProcess.waitUntilExit() }
            if FileManager.default.fileExists(atPath: plan.retiredApp.path) {
                await stopUpdatedApp(plan.targetApp)
                try restore(plan)
                receipt.status = "rolled-back"; receipt.message = error.localizedDescription
                try? writeReceipt(receipt, to: plan.receiptURL)
                let restored = try? launch(plan: plan, planURL: planURL, confirm: false); restored?.waitUntilExit()
            } else {
                receipt.status = "failed"; receipt.message = error.localizedDescription
                try? writeReceipt(receipt, to: plan.receiptURL)
                let restored = try? launch(plan: plan, planURL: planURL, confirm: false); restored?.waitUntilExit()
            }
        }
    }
    private static func launch(plan: StudioInstallPlan, planURL: URL, confirm: Bool) throws -> Process? {
        if plan.verificationOnly == true {
            let process = Process(); process.executableURL = plan.targetApp.appendingPathComponent("Contents/MacOS/ZenWaveStudio")
            process.arguments = (confirm ? ["--confirm-update", planURL.path] : []) + ["--verify-library"]
            let logURL = plan.stage.appendingPathComponent(confirm ? "launch.log" : "restored-launch.log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let log = try FileHandle(forWritingTo: logURL); defer { try? log.close() }
            process.standardOutput = log; process.standardError = log
            try process.run(); return process
        }
        _ = try StudioUpdateClient.run("/usr/bin/open", ["-n", plan.targetApp.path] + (confirm ? ["--args", "--confirm-update", planURL.path] : []))
        return nil
    }
    private static func stopUpdatedApp(_ target: URL) async {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: StudioBuild.identifier).filter {
            $0.bundleURL?.resolvingSymlinksInPath() == target.resolvingSymlinksInPath()
        }
        for app in apps { app.terminate() }
        let deadline = Date().addingTimeInterval(5)
        while apps.contains(where: { !$0.isTerminated }), Date() < deadline { try? await Task.sleep(nanoseconds: 100_000_000) }
        for app in apps where !app.isTerminated { app.forceTerminate() }
    }
    /// The injected verifier is used only by filesystem transaction tests.
    static func swap(_ plan: StudioInstallPlan, verify: (URL, String) throws -> Void = StudioUpdateClient.validateApp) throws {
        let files = FileManager.default
        guard !files.fileExists(atPath: plan.incomingApp.path), !files.fileExists(atPath: plan.retiredApp.path),
              !files.fileExists(atPath: plan.previousApp.path) else { throw StudioError.message("A previous update is awaiting review; nothing was replaced.") }
        try verify(plan.sourceApp, plan.toVersion)
        try files.copyItem(at: plan.targetApp, to: plan.previousApp)
        try files.copyItem(at: plan.sourceApp, to: plan.incomingApp)
        do {
            try verify(plan.incomingApp, plan.toVersion)
            try files.moveItem(at: plan.targetApp, to: plan.retiredApp)
            do { try files.moveItem(at: plan.incomingApp, to: plan.targetApp) }
            catch { try files.moveItem(at: plan.retiredApp, to: plan.targetApp); throw error }
        } catch { try? files.removeItem(at: plan.incomingApp); throw error }
    }
    static func restore(_ plan: StudioInstallPlan) throws {
        guard FileManager.default.fileExists(atPath: plan.retiredApp.path) else { throw StudioError.message("The previous app is unavailable for automatic rollback.") }
        if FileManager.default.fileExists(atPath: plan.targetApp.path) { try FileManager.default.removeItem(at: plan.targetApp) }
        try FileManager.default.moveItem(at: plan.retiredApp, to: plan.targetApp)
        // Never restore an old DB over newly generated content or publication history.
    }
    static func confirmLaunch(planURL: URL) throws {
        let plan = try JSONDecoder().decode(StudioInstallPlan.self, from: Data(contentsOf: planURL))
        do {
            guard Bundle.main.bundleURL.resolvingSymlinksInPath().path == plan.targetApp.resolvingSymlinksInPath().path, StudioBuild.version == plan.toVersion else {
                throw StudioError.message("The updated app launched from an unexpected location or version.")
            }
            guard try !StudioResources.library().isEmpty else { throw StudioError.message("The updated content catalog is empty.") }
            _ = try BreathVoicePack.load(from: BreathVoicePack.root)
            _ = try FrameRenderer()
            _ = try ContentHistory(url: plan.historyURL)
            try Data(ContentHistory.json(StudioLaunchConfirmation(success: true, pid: getpid(), message: "Content, voice, renderer and history opened successfully.")).utf8)
                .write(to: plan.confirmation, options: .atomic)
        } catch {
            try? Data(ContentHistory.json(StudioLaunchConfirmation(success: false, pid: getpid(), message: error.localizedDescription)).utf8)
                .write(to: plan.confirmation, options: .atomic)
            throw error
        }
    }
    static func writeReceipt(_ receipt: StudioUpdateReceipt, to url: URL = lastReceipt) throws {
        try Data(ContentHistory.json(receipt).utf8).write(to: url, options: .atomic)
    }
}
