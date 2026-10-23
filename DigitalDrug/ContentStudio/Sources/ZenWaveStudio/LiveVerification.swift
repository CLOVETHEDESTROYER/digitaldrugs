import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum LiveVerification {
    static func run() async throws {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--output"), args.indices.contains(i + 1) else {
            throw StudioError.message("Use --live-review --output /new/path/review.mp4")
        }
        let output = URL(fileURLWithPath: args[i + 1])
        let library = try StudioResources.library()
        let selected = ["career-confidence-morning", "career-confidence-evening"]
        var plan = LivePlan()
        plan.chapters = selected.enumerated().map { LiveChapter(mantraID: $0.element, seconds: 45, style: $0.offset == 0 ? 10 : 20, palette: $0.offset + 1) }
        plan.sceneSeconds = 30; plan.rest = 10
        var settings = ExportSettings(); settings.captionOffset = 0
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-LiveReview-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let (timeline, audio, envelope) = try await LiveAudio.prepare(plan: plan, library: library, folder: folder, background: nil, settings: settings)
        guard abs(envelope.duration - 90) < 0.05 else { throw StudioError.message("Wrong live audio duration: \(envelope.duration)") }
        let renderer = LiveFrameRenderer()
        for time in [5.0, 25, 30, 34, 44, 45, 49, 55, 79, 89] {
            let frame = try renderer.frame(width: 540, height: 960, time: time, envelope: envelope, timeline: timeline, settings: settings)
            let url = output.deletingLastPathComponent().appendingPathComponent("live-\(Int(time)).png")
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw StudioError.message("Could not save review image.") }
            CGImageDestinationAddImage(dest, frame, nil)
            guard CGImageDestinationFinalize(dest) else { throw StudioError.message("Could not finish review image.") }
        }
        let production = args.contains("--production")
        let job = ExportJob(mantra: timeline.mantra, settings: settings, start: 0, end: 90, liveTimeline: timeline, preparedAudio: audio, preparedMotion: envelope)
        try await VideoExporter.export(job, to: output, widthOverride: production ? 1080 : 360, heightOverride: production ? 1920 : 640) { value in
            if Int(value * 100) % 10 == 0 { print("Live review: \(Int(value * 100))%") }
        }
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        guard abs(duration - 90) < 0.05, try await asset.loadTracks(withMediaType: .audio).count == 1 else { throw StudioError.message("The live review movie failed its media check.") }
        print("Verified 90-second live journey: \(output.path)")
    }
}
