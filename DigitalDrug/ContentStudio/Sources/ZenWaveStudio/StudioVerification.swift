import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// An end-to-end check of real bundled assets, shaders, and a decoded exported movie.
enum StudioVerification {
    static func run() async throws {
        let library = try StudioResources.library()
        guard !library.isEmpty, Set(library.map(\.id)).count == library.count else {
            throw StudioError.message("Catalog has missing or duplicate identifiers.")
        }
        var durations: [String: Double] = [:]
        for mantra in library {
            let envelope = try AudioEnvelope(url: mantra.audioURL)
            durations[mantra.id] = envelope.duration
            var previous = -1.0
            for cue in mantra.cues {
                guard cue.start >= previous, cue.end > cue.start, cue.start >= 0,
                      cue.end <= envelope.duration + 0.12, !cue.text.isEmpty else {
                    throw StudioError.message("Invalid caption timing for \(mantra.id): \(cue.start)–\(cue.end), duration \(envelope.duration)")
                }
                previous = cue.end
            }
        }
        print("Verified \(library.count) recordings, unique IDs, decodable audio, caption order, and cue bounds.")
        guard CommandLine.arguments.contains("--smoke-export") else { return }
        func argument(_ name: String) -> String? {
            guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(index + 1) else { return nil }
            return CommandLine.arguments[index + 1]
        }
        let mantra = library.first(where: { $0.id == argument("--mantra") }) ?? library[0]
        let output = URL(fileURLWithPath: argument("--output") ?? "/tmp/ZenWaveStudio-Smoke-\(UUID().uuidString).mp4")
        let renderer = try FrameRenderer()
        let envelope = try AudioEnvelope(url: mantra.audioURL)
        for style in VisualStyle.all {
            var settings = ExportSettings(); settings.style = style.id
            let image = try renderer.frame(width: 360, height: 640, time: 2, audioTime: 2,
                                          envelope: envelope, mantra: mantra, settings: settings)
            let url = output.deletingLastPathComponent().appendingPathComponent("style-\(style.id).png")
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw StudioError.message("Could not write shader verification frame.")
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw StudioError.message("Could not finish shader verification frame.") }
        }
        var settings = ExportSettings()
        settings.heading = "Your daily mantra"
        settings.style = Int(argument("--style") ?? "3") ?? 3
        if argument("--format") == "square" { settings.format = .square }
        if argument("--format") == "landscape" { settings.format = .landscape }
        let production = CommandLine.arguments.contains("--production")
        let end = CommandLine.arguments.contains("--full") ? nil : Optional(3.0)
        let job = ExportJob(mantra: mantra, settings: settings, start: 0, end: end)
        try await VideoExporter.export(job, to: output, widthOverride: production ? nil : 360,
                                       heightOverride: production ? nil : 640) { _ in }
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        guard let video = try await asset.loadTracks(withMediaType: .video).first,
              let audio = try await asset.loadTracks(withMediaType: .audio).first else {
            throw StudioError.message("Export is missing audio or video.")
        }
        let size = try await video.load(.naturalSize)
        let expected = min(envelope.duration, end ?? envelope.duration)
        guard abs(duration - expected) < 0.15,
              size.width == CGFloat(production ? settings.format.width : 360),
              size.height == CGFloat(production ? settings.format.height : 640) else {
            throw StudioError.message("Export size or duration did not match the requested settings.")
        }
        let reader = try AVAssetReader(asset: asset)
        let audioOutput = AVAssetReaderTrackOutput(track: audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32])
        reader.add(audioOutput)
        guard reader.startReading() else { throw StudioError.message("Exported audio did not decode.") }
        var samples = 0
        var audible = false
        while let buffer = audioOutput.copyNextSampleBuffer() {
            samples += CMSampleBufferGetNumSamples(buffer)
            if let block = CMSampleBufferGetDataBuffer(buffer) {
                let length = CMBlockBufferGetDataLength(block)
                var data = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                let status = data.withUnsafeMutableBytes { ptr in
                    CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
                }
                if status == kCMBlockBufferNoErr, data.contains(where: { abs($0) > 0.001 }) { audible = true }
            }
        }
        guard samples > 0, audible, reader.status == .completed else { throw StudioError.message("Exported audio is silent or incomplete.") }
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        let image = try imageGenerator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
        guard image.width == Int(size.width) else { throw StudioError.message("Exported video did not decode.") }
        print("Verified all 12 shaders and MP4: \(Int(size.width))×\(Int(size.height)), \(String(format: "%.3f", duration))s, audible decoded audio (\(samples) samples), decoded video frame.")
        print(output.path)
    }
}
