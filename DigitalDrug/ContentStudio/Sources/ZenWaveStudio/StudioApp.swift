import SwiftUI
import AVFoundation

struct StudioApp: App {
    @State private var studio = StudioState()
    var body: some Scene {
        WindowGroup("ZenWave Content Studio") { StudioView(studio: studio) }
            .defaultSize(width: 1200, height: 840)
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
        if CommandLine.arguments.contains("--smoke-export") || CommandLine.arguments.contains("--verify-library") {
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    try await StudioVerification.run()
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
