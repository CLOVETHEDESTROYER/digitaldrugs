import Foundation
import AVFoundation
import CoreGraphics

struct ExportJob: Sendable {
    let mantra: Mantra
    let settings: ExportSettings
    let start: Double
    let end: Double?
    var backgroundURL: URL? = nil
    var liveTimeline: LiveTimeline? = nil
    var preparedAudio: URL? = nil
    var preparedMotion: AudioEnvelope? = nil
}

struct ExportReceipt: Codable {
    let title: String
    let sourceFile: String
    let captionTiming: String
    let start: Double
    let end: Double
    let settings: ExportSettings
    let backgroundFile: String?
    var motionSource: String? = "background-only"
}

enum VideoExporter {
    /// Runs off the main actor. No screen capture, window visibility, or real-time playback is involved.
    static func export(_ job: ExportJob, to output: URL, widthOverride: Int? = nil,
                       heightOverride: Int? = nil, progress: @escaping @Sendable (Double) -> Void) async throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let source: URL
        let envelope: AudioEnvelope
        let audioDuration: Double
        if let prepared = job.preparedAudio {
            source = prepared
            let file = try AVAudioFile(forReading: prepared)
            audioDuration = Double(file.length) / file.processingFormat.sampleRate
            // A prepared playback mix may contain speech. Never use it as a fallback motion source.
            envelope = job.preparedMotion ?? AudioEnvelope(silence: audioDuration)
        } else {
            let audio = try await AudioMix.prepareForPlayback(voice: job.mantra.audioURL, background: job.backgroundURL,
                volume: job.settings.backgroundVolume, output: scratch.appendingPathComponent("mix.m4a"), soundscape: job.settings.soundscape)
            source = audio.playbackURL; envelope = audio.motion; audioDuration = audio.duration
        }
        let start = max(0, job.start)
        let end = min(audioDuration, job.end ?? audioDuration)
        guard end > start else { throw StudioError.message("The clip must end after it starts.") }
        let duration = end - start
        let width = widthOverride ?? job.settings.format.width
        let height = heightOverride ?? job.settings.format.height
        let silent = scratch.appendingPathComponent("visualizer.mov")
        let staged = scratch.appendingPathComponent("finished.mp4")
        let writer = try AVAssetWriter(outputURL: silent, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width * height * 6,
                                             AVVideoExpectedSourceFrameRateKey: 30,
                                             AVVideoMaxKeyFrameIntervalKey: 60],
            AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw StudioError.message("This Mac could not configure H.264 video export.") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? StudioError.message("Could not begin writing video.") }
        writer.startSession(atSourceTime: .zero)
        let renderer = try FrameRenderer()
        let liveRenderer = job.liveTimeline == nil ? nil : LiveFrameRenderer()
        let frameCount = Int(ceil(duration * 30))
        do {
            for i in 0..<frameCount {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    if writer.status == .failed { throw writer.error ?? StudioError.message("The video encoder stopped.") }
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                try autoreleasepool {
                    let time = Double(i) / 30
                    let image: CGImage
                    if let timeline = job.liveTimeline, let liveRenderer {
                        image = try liveRenderer.frame(width: width, height: height, time: time, envelope: envelope, timeline: timeline, settings: job.settings)
                    } else {
                        image = try renderer.frame(width: width, height: height, time: time, audioTime: start + time,
                                                   envelope: envelope, mantra: job.mantra, settings: job.settings)
                    }
                    guard let pool = adaptor.pixelBufferPool else { throw StudioError.message("The encoder has no video buffer pool.") }
                    var optional: CVPixelBuffer?
                    let result = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optional)
                    guard result == kCVReturnSuccess, let buffer = optional else { throw StudioError.message("The encoder ran out of video buffers.") }
                    CVPixelBufferLockBaseAddress(buffer, [])
                    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
                    let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else {
                        throw StudioError.message("Could not prepare an encoded frame.")
                    }
                    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(i), timescale: 30)) else {
                        throw writer.error ?? StudioError.message("Could not encode a video frame.")
                    }
                }
                if i % 6 == 0 { progress(Double(i + 1) / Double(frameCount) * 0.9) }
            }
            writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 60000))
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? StudioError.message("The video did not finish writing.") }
            try Task.checkCancellation()
            progress(0.92)
            let composition = AVMutableComposition()
            let videoAsset = AVURLAsset(url: silent)
            let audioAsset = AVURLAsset(url: source)
            guard let video = try await videoAsset.loadTracks(withMediaType: .video).first,
                  let audio = try await audioAsset.loadTracks(withMediaType: .audio).first,
                  let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw StudioError.message("The recording or rendered video is missing a media track.")
            }
            let length = CMTime(seconds: duration, preferredTimescale: 60000)
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: video, at: .zero)
            try audioTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 60000), duration: length), of: audio, at: .zero)
            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                throw StudioError.message("Could not combine the recording and video.")
            }
            exporter.outputURL = staged; exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = true
            await withTaskCancellationHandler {
                await exporter.export()
            } onCancel: { exporter.cancelExport() }
            try Task.checkCancellation()
            guard exporter.status == .completed else { throw exporter.error ?? StudioError.message("Audio and video export did not complete.") }
            // Create the final file only after the full movie is complete. Never overwrite an existing export.
            try FileManager.default.copyItem(at: staged, to: output)
            let receipt = ExportReceipt(title: job.mantra.title, sourceFile: job.mantra.fileName,
                captionTiming: job.mantra.timing, start: start, end: end, settings: job.settings,
                backgroundFile: job.backgroundURL?.lastPathComponent)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(receipt).write(to: output.deletingPathExtension().appendingPathExtension("json"), options: .atomic)
            if let timeline = job.liveTimeline {
                try encoder.encode(timeline).write(to: output.deletingPathExtension().appendingPathExtension("playlist.json"), options: .atomic)
            }
            let srt = subtitles(job: job, start: start, end: end)
            if job.settings.captions {
                try srt.write(to: output.deletingPathExtension().appendingPathExtension("srt"), atomically: true, encoding: .utf8)
            }
            progress(1)
        } catch {
            if writer.status == .writing || writer.status == .unknown { writer.cancelWriting() }
            throw error
        }
    }

    static func subtitles(job: ExportJob, start: Double, end: Double) -> String {
        var count = 0
        return job.mantra.cues.compactMap { cue -> String? in
            let lo = max(start, cue.start + job.settings.captionOffset)
            let hi = min(end, cue.end + job.settings.captionOffset)
            guard hi > lo else { return nil }
            count += 1
            return "\(count)\n\(timestamp(lo - start)) --> \(timestamp(hi - start))\n\(cue.text)\n"
        }.joined(separator: "\n")
    }
    private static func timestamp(_ time: Double) -> String {
        let ms = Int((max(0, time) * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", ms / 3600000, ms / 60000 % 60, ms / 1000 % 60, ms % 1000)
    }
}
