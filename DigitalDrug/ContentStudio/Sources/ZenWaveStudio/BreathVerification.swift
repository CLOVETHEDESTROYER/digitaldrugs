import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum BreathVerification {
    static func run() async throws {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--output"), args.indices.contains(index + 1) else { throw StudioError.message("Use --breath-review --output /new/path/practice.mp4") }
        let output = URL(fileURLWithPath: args[index + 1])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-BreathReview-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        var plan = BreathPlan(); plan.apply(args.contains("--slow-box") ? .slowBox : .box); plan.cycles = 2; plan.voiceName = BreathVoicePack.title
        var settings = ExportSettings(); settings.style = 11; settings.palette = 5
        settings.soundscape.beat = .theta
        let audio = try await BreathAudio.prepare(plan: plan, settings: settings, background: nil, folder: folder)
        let renderer = BreathRenderer()
        for format in VideoFormat.allCases {
            for time in [1.0, 6, 8, 10, 12, 14, 16, 18, 22, 38] {
                settings.format = format
                let frame = try renderer.frame(width: format.width, height: format.height, time: time, envelope: audio.motion, plan: plan, settings: settings)
                let name = "breath-\(format.width)x\(format.height)-\(Int(time)).png"
                let url = output.deletingLastPathComponent().appendingPathComponent(name)
                let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, frame, nil)
                guard CGImageDestinationFinalize(destination) else { throw StudioError.message("Could not save breathing review frame.") }
            }
        }
        for format in VideoFormat.allCases {
            settings.format = format; settings.callToAction.enabled = true; settings.callToAction.timing = .always
            for placement in StudioCTAPlacement.allCases {
                settings.callToAction.placement = placement
                let frame = try renderer.frame(width: format.width, height: format.height, time: 10, envelope: audio.motion, plan: plan, settings: settings)
                let url = output.deletingLastPathComponent().appendingPathComponent("breath-cta-\(format.width)x\(format.height)-\(placement.rawValue).png")
                let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, frame, nil)
                guard CGImageDestinationFinalize(destination) else { throw StudioError.message("Could not save breathing CTA frame.") }
            }
        }
        if args.contains("--frames-only") { return }
        settings.callToAction.enabled = false
        settings.format = .portrait
        let job = ExportJob(mantra: plan.mantra, settings: settings, start: 0, end: plan.duration, preparedAudio: audio.playbackURL, preparedMotion: audio.motion, breathPlan: plan)
        try await VideoExporter.export(job, to: output, widthOverride: args.contains("--production") ? nil : 360, heightOverride: args.contains("--production") ? nil : 640, recordHistory: false) { _ in }
        print("Breathing review complete: \(output.path)")
    }
}
