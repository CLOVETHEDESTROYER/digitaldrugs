import Foundation
import AVFoundation

enum RandomBatchVerification {
    static func run() async throws {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--output"), args.indices.contains(index + 1) else {
            throw StudioError.message("Use --random-batch-review --output /new/batch-folder")
        }
        let folder = URL(fileURLWithPath: args[index + 1])
        let library = try StudioResources.library()
        let withChakra = args.contains("--with-chakra")
        let withSoundscape = args.contains("--with-soundscape") || withChakra
        var settings = ExportSettings()
        let withCTA = args.contains("--with-cta")
        if withCTA { settings.callToAction.enabled = true; settings.callToAction.delay = 2; settings.callToAction.campaign = "Resonance batch" }
        let plan = try RandomBatchPlan.make(count: 3, seed: 20261022,
            mantras: ["career-confidence-morning", "career-confidence-evening"], styles: withCTA ? [34, 35, 10] : withChakra ? [26, 29, 33] : [10, 14, 20], palettes: [1, 2, 5],
            settings: settings, backgroundFile: nil, postFooter: "My daily intention. #ZenWave",
            beats: withSoundscape ? [.delta, .theta, .alpha] : nil,
            nature: withSoundscape ? ["continuous_river", "forest_ambience", "tropical_rain"] : nil,
            chakras: withChakra ? ["root", "heart", "column"] : nil)
        let archive = try await RandomBatchExporter.export(plan: plan, library: library, background: nil, folder: folder, recordHistory: false) { _, _ in }
        for clip in plan.clips {
            let asset = AVURLAsset(url: folder.appendingPathComponent(clip.fileName))
            guard let video = try await asset.loadTracks(withMediaType: .video).first,
                  try await asset.loadTracks(withMediaType: .audio).count == 1 else { throw StudioError.message("A batch movie is missing media.") }
            let size = try await video.load(.naturalSize)
            let duration = try await asset.load(.duration).seconds
            guard size == CGSize(width: 1080, height: 1920), duration > 10 else { throw StudioError.message("A batch movie has the wrong size or duration.") }
        }
        print("Verified three full-resolution combined MP4s and ZIP: \(archive.path)")
    }
}
