import SwiftUI
import AVFoundation

struct StudioApp: App {
    @State private var studio = StudioState()
    @State private var live = LiveSessionState()
    @State private var batch = RandomBatchState()
    var body: some Scene {
        WindowGroup("ZenWave Content Studio") {
            StudioView(studio: studio).onChange(of: studio.playing) { _, playing in if playing { live.pause() } }
        }
            .defaultSize(width: 1200, height: 840)
        Window("Random Batch", id: "random-batch") {
            RandomBatchView(studio: studio, batch: batch, livePlaying: live.playing, onPlay: { live.pause() })
        }.defaultSize(width: 1100, height: 860)
        Window("Live Session", id: "live-session") { LiveSessionView(studio: studio, live: live) }
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
        if CommandLine.arguments.contains("--smoke-export") || CommandLine.arguments.contains("--verify-library") || CommandLine.arguments.contains("--live-review") || CommandLine.arguments.contains("--random-batch-review") {
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    if CommandLine.arguments.contains("--random-batch-review") { try await RandomBatchVerification.run() }
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
