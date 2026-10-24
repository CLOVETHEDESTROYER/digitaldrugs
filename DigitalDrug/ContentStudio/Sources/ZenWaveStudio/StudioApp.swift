import SwiftUI
import AVFoundation

struct StudioApp: App {
    @State private var studio = StudioState()
    @State private var live = LiveSessionState()
    @State private var breath = BreathPracticeState()
    @State private var batch = RandomBatchState()
    @State private var content = ContentLibraryState()
    var body: some Scene {
        WindowGroup("ZenWave Content Studio") {
            StudioView(studio: studio).onChange(of: studio.playing) { _, playing in if playing { live.pause(); breath.pause() } }
                .task { content.resumeIfEnabled() }
        }
            .defaultSize(width: 1200, height: 840)
        Window("History & Agent Jobs", id: "content-history") {
            ContentLibraryView(state: content)
        }.defaultSize(width: 1100, height: 820)
        Window("Random Batch", id: "random-batch") {
            RandomBatchView(studio: studio, batch: batch, livePlaying: live.playing, onPlay: { live.pause(); breath.pause() })
        }.defaultSize(width: 1100, height: 860)
        Window("Breathing Practice", id: "breathing-practice") {
            BreathPracticeView(breath: breath, studio: studio, onPlay: { studio.pause(); live.pause() })
                .onDisappear { breath.close() }
        }.defaultSize(width: 1100, height: 860)
        Window("ZenWave Breathing Output", id: "breath-output") {
            BreathOutputView(breath: breath).onDisappear { breath.pause() }
        }.defaultSize(width: 540, height: 960).windowStyle(.hiddenTitleBar)
        Window("Live Session", id: "live-session") { LiveSessionView(studio: studio, live: live).onChange(of: live.playing) { _, playing in if playing { breath.pause() } } }
            .defaultSize(width: 1100, height: 860)
        Window("ZenWave Live Output", id: "live-output") {
            LiveOutputView(live: live).onDisappear { live.closeOutput() }
        }
            .defaultSize(width: 540, height: 960)
            .windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(replacing: .newItem) {}
                CommandGroup(after: .saveItem) {
                    Button("Show export folder") { studio.revealExports() }.keyboardShortcut("e", modifiers: [.command, .shift])
                }
            }
    }
}

@main
enum StudioLauncher {
    static func main() {
        if CommandLine.arguments.contains("--agent-poll") || CommandLine.arguments.contains("--breath-review") || CommandLine.arguments.contains("--smoke-export") || CommandLine.arguments.contains("--verify-library") || CommandLine.arguments.contains("--live-review") || CommandLine.arguments.contains("--random-batch-review") {
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    if CommandLine.arguments.contains("--agent-poll") {
                        func argument(_ name: String) -> String? {
                            guard let i = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(i + 1) else { return nil }
                            return CommandLine.arguments[i + 1]
                        }
                        guard let path = argument("--exchange") else { throw StudioError.message("Use --agent-poll --exchange /path/to/ZenWave-Exchange.") }
                        let history = try argument("--history").map { try ContentHistory(url: URL(fileURLWithPath: $0)) } ?? ContentHistory.shared
                        let queue = AgentQueue(root: URL(fileURLWithPath: path), history: history)
                        let library = try StudioResources.library()
                        try queue.setup(library: library); try await queue.poll(library: library)
                        print("Local request poll complete. Read Status/ for results. Nothing was posted or scheduled.")
                    }
                    else if CommandLine.arguments.contains("--breath-review") { try await BreathVerification.run() }
                    else if CommandLine.arguments.contains("--random-batch-review") { try await RandomBatchVerification.run() }
                    else if CommandLine.arguments.contains("--live-review") { try await LiveVerification.run() }
                    else { try await StudioVerification.run() }
                    semaphore.signal()
                } catch {
                    fputs("Studio verification failed: \(error)\n", stderr)
                    exit(1)
                }
            }
            semaphore.wait()
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
            StudioApp.main()
        }
    }
}
