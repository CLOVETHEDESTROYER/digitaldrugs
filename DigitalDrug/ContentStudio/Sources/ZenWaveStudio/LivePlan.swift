import Foundation
import AVFoundation
import CoreGraphics

struct LiveChapter: Codable, Identifiable, Equatable {
    var id = UUID()
    var mantraID: String
    var seconds = 240.0
    var style = 10
    var palette = 1
}

struct LivePlan: Codable, Equatable {
    var chapters: [LiveChapter] = []
    var rest = 15.0
    var transition = 8.0
    var evolving = true
    var sceneSeconds = 60.0
    var prompts = true
    var loop = true
    var duration: Double { chapters.reduce(0) { $0 + $1.seconds } }
    func validate() throws {
        guard !chapters.isEmpty, chapters.count <= 30,
              chapters.allSatisfy({ item in item.seconds.isFinite && (30...1200).contains(item.seconds)
                  && VisualStyle.all.contains(where: { $0.id == item.style })
                  && VisualPalette.all.contains(where: { $0.id == item.palette }) }),
              duration <= 3600, rest.isFinite, (0...120).contains(rest),
              transition.isFinite, (0...20).contains(transition),
              sceneSeconds.isFinite, (30...180).contains(sceneSeconds) else {
            throw StudioError.message("Use 1–30 chapters of 30 seconds to 20 minutes, with a total of at most 60 minutes.")
        }
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "livePlan") }
    }
    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: "livePlan"),
              let plan = try? JSONDecoder().decode(Self.self, from: data),
              (try? plan.validate()) != nil else { return Self() }
        return plan
    }
}

struct LiveVoice: Codable {
    let chapter: Int
    let start: Double
    let duration: Double
}

/// A fixed timeline shared by live playback, seeking, captions and exported movies.
struct LiveTimeline: Codable {
    let plan: LivePlan
    let records: [Mantra]
    let voices: [LiveVoice]
    let cues: [Cue]
    var duration: Double { plan.duration }
    var mantra: Mantra {
        Mantra(id: "live-session", title: "Live manifestation journey", subtitle: "",
               fileName: "live-session.m4a", timing: records.contains(where: \.estimated) ? "estimated" : "timed",
               category: "Live", cues: cues)
    }
    func chapterStart(_ index: Int) -> Double { plan.chapters.prefix(index).reduce(0) { $0 + $1.seconds } }
    func chapter(at time: Double) -> Int {
        var end = 0.0
        for (i, item) in plan.chapters.enumerated() {
            end += item.seconds
            if time < end { return i }
        }
        return max(0, plan.chapters.count - 1)
    }
    static func make(plan: LivePlan, library: [Mantra], lengths: [String: Double]) throws -> Self {
        try plan.validate()
        let records = try plan.chapters.map { item -> Mantra in
            guard let record = library.first(where: { $0.id == item.mantraID }),
                  let length = lengths[item.mantraID], length.isFinite, length > 0,
                  length <= item.seconds else {
                throw StudioError.message("Each chapter must fit its complete recording. Increase the chapter length or replace the recording.")
            }
            return record
        }
        var voices: [LiveVoice] = [], cues: [Cue] = [], cursor = 0.0
        for (i, item) in plan.chapters.enumerated() {
            let record = records[i], length = lengths[item.mantraID]!
            let end = cursor + item.seconds
            var start = cursor
            while start + length <= end + 0.00001 {
                voices.append(.init(chapter: i, start: start, duration: length))
                cues += record.cues.map { Cue(start: start + $0.start, end: min(start + $0.end, start + length), text: $0.text) }
                let next = start + length + plan.rest
                let gapEnd = next + length <= end + 0.00001 ? next : end
                if plan.prompts, gapEnd - (start + length) >= 3 {
                    cues.append(Cue(start: start + length + 0.5, end: gapEnd - 0.5,
                                    text: "Breathe slowly.\nLet this intention settle."))
                }
                start = next
            }
            cursor = end
        }
        return Self(plan: plan, records: records, voices: voices, cues: cues)
    }
    func visual(at time: Double, base: ExportSettings) -> ExportSettings {
        let index = chapter(at: time), item = plan.chapters[index]
        var settings = base
        settings.style = item.style; settings.palette = item.palette
        settings.heading = records[index].title
        if plan.evolving {
            let step = Int(max(0, time - chapterStart(index)) / plan.sceneSeconds)
            let styles = [item.style, 14, 10, 20, 9, 22]
            settings.style = styles[step % styles.count]
            settings.palette = (item.palette + step) % VisualPalette.all.count
        }
        return settings
    }
    /// Returns the previous scene and eased blend at chapter and journey boundaries.
    func blend(at time: Double) -> (previousTime: Double, alpha: Double)? {
        guard plan.transition > 0 else { return nil }
        let index = chapter(at: time), start = chapterStart(index)
        let step = plan.evolving ? floor(max(0, time - start) / plan.sceneSeconds) : 0
        let boundary = start + step * plan.sceneSeconds
        let span = min(plan.transition, plan.chapters[index].seconds / 2, plan.sceneSeconds / 2)
        guard boundary > 0, time - boundary < span else { return nil }
        let x = max(0, (time - boundary) / span)
        return (max(0, boundary - 0.001), x * x * (3 - 2 * x))
    }
}

enum LiveAudio {
    static func prepare(plan: LivePlan, library: [Mantra], folder: URL, background: URL?, settings: ExportSettings) async throws -> (LiveTimeline, URL, AudioEnvelope) {
        try plan.validate()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
            throw StudioError.message("Could not configure playlist audio.")
        }
        var recordings: [String: AVAudioPCMBuffer] = [:]
        for item in plan.chapters where recordings[item.mantraID] == nil {
            try Task.checkCancellation()
            guard let record = library.first(where: { $0.id == item.mantraID }) else { throw StudioError.message("A playlist recording is missing.") }
            let file = try AVAudioFile(forReading: record.audioURL)
            guard file.length > 0, file.length < 44100 * 1200,
                  let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  let converter = AVAudioConverter(from: file.processingFormat, to: format),
                  let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(ceil(Double(file.length) * 44100 / file.processingFormat.sampleRate)) + 8192) else {
                throw StudioError.message("Could not decode a playlist recording.")
            }
            try file.read(into: input)
            var sent = false
            var conversionError: NSError?
            let result = converter.convert(to: converted, error: &conversionError) { _, status in
                if sent { status.pointee = .endOfStream; return nil }
                sent = true; status.pointee = .haveData; return input
            }
            guard result != .error, converted.frameLength > 0 else {
                throw conversionError ?? StudioError.message("Could not convert playlist audio.") as NSError
            }
            recordings[item.mantraID] = converted
        }
        let timeline = try LiveTimeline.make(plan: plan, library: library,
            lengths: recordings.mapValues { Double($0.frameLength) / 44100 })
        let voiceURL = folder.appendingPathComponent("voices.m4a")
        // Write actual PCM silence between repetitions, rather than empty compressed-media
        // edits, which Apple's AAC exporter cannot reliably render for repeated MP3 tracks.
        try writeVoices(timeline: timeline, recordings: recordings, format: format, output: voiceURL)
        try Task.checkCancellation()
        let audio = try await AudioMix.prepareForPlayback(voice: voiceURL, background: background, volume: settings.backgroundVolume, output: folder.appendingPathComponent("live-session.m4a"), soundscape: settings.soundscape)
        return (timeline, audio.playbackURL, audio.motion)
    }
    private static func writeVoices(timeline: LiveTimeline, recordings: [String: AVAudioPCMBuffer], format: AVAudioFormat, output: URL) throws {
        let writer = try AVAudioFile(forWriting: output, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192000])
        guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100) else {
            throw StudioError.message("Could not allocate playlist silence.")
        }
        silence.frameLength = 44100
        for channel in 0..<2 { memset(silence.floatChannelData![channel], 0, 44100 * MemoryLayout<Float>.size) }
        var cursor: Int64 = 0
        func pad(to target: Int64) throws {
            while cursor < target {
                try Task.checkCancellation()
                silence.frameLength = AVAudioFrameCount(min(44100, target - cursor))
                try writer.write(from: silence); cursor += Int64(silence.frameLength)
            }
        }
        for voice in timeline.voices {
            try pad(to: Int64((voice.start * 44100).rounded()))
            try Task.checkCancellation()
            let buffer = recordings[timeline.plan.chapters[voice.chapter].mantraID]!
            try writer.write(from: buffer); cursor += Int64(buffer.frameLength)
        }
        try pad(to: Int64((timeline.duration * 44100).rounded()))
    }

}

final class LiveFrameRenderer {
    private let renderer = try? FrameRenderer()
    func frame(width: Int, height: Int, time: Double, envelope: AudioEnvelope, timeline: LiveTimeline, settings: ExportSettings) throws -> CGImage {
        guard let renderer else { throw StudioError.message("The live visualizer could not start Metal on this Mac.") }
        let current = timeline.visual(at: time, base: settings)
        let image = try renderer.frame(width: width, height: height, time: time, audioTime: time, envelope: envelope, mantra: timeline.mantra, settings: current)
        guard let blend = timeline.blend(at: time) else { return image }
        var previous = timeline.visual(at: blend.previousTime, base: settings)
        // Text changes once at the chapter boundary while only the visuals dissolve.
        previous.heading = current.heading
        let old = try renderer.frame(width: width, height: height, time: time, audioTime: time, envelope: envelope, mantra: timeline.mantra, settings: previous)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(old, in: rect); context.setAlpha(blend.alpha); context.draw(image, in: rect)
        return context.makeImage() ?? image
    }
}
