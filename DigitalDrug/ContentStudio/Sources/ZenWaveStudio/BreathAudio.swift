import AVFoundation

/// Bundled OpenAI speech. Cue samples are placed on the exact same timeline as the circle.
/// Playback, seeking and exported movies all use this rendered track; no live TTS clock.
enum BreathAudio {
    static func prepare(plan: BreathPlan, settings: ExportSettings, background: URL?, folder: URL, voicePackRoot: URL = BreathVoicePack.root) async throws -> PreparedStudioAudio {
        try plan.validate()
        let rate = 48_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let voiceURL = folder.appendingPathComponent("breath-voice.caf")
        let cues = plan.spokenCues
        let pack = cues.isEmpty ? nil : try BreathVoicePack.load(from: voicePackRoot)
        var samples: [String: [Float]] = [:]
        for text in Set(cues.map(\.text)).sorted() {
            try Task.checkCancellation()
            let url = try pack!.file(for: text, root: voicePackRoot)
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw StudioError.message("Could not read a spoken breathing cue.")
            }
            try file.read(into: buffer)
            guard let channel = buffer.floatChannelData?.pointee, buffer.frameLength > 0 else { throw StudioError.message("The breathing voice produced no audio.") }
            let original = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            // Remove padding; resample sample rate only. Never speed up or pitch-shift the voice to fit a count.
            let first = original.firstIndex { abs($0) > 0.003 } ?? 0
            let last = original.lastIndex { abs($0) > 0.003 } ?? original.count - 1
            let trimmed = Array(original[max(0, first - 120)...min(original.count - 1, last + 240)])
            let slot = cues.first { $0.text == text }!
            let count = max(1, Int(Double(trimmed.count) / file.processingFormat.sampleRate * rate))
            guard count <= Int((slot.end - slot.start + 0.005) * rate) else {
                throw StudioError.message("The OpenAI cue “\(text)” is too long for its breathing slot. Regenerate the voice pack; the studio will not rush the narration or shorten a second.")
            }
            samples[text] = (0..<count).map { i in
                let position = Double(i) * Double(trimmed.count - 1) / Double(max(1, count - 1))
                let lo = Int(position), hi = min(trimmed.count - 1, lo + 1)
                let edge = Float(min(1, min(Double(i), Double(count - 1 - i)) / (rate * 0.004)))
                return (trimmed[lo] + (trimmed[hi] - trimmed[lo]) * Float(position - Double(lo))) * 0.85 * edge
            }
        }
        // Stream one-second buffers, keeping 20-minute live sessions small in memory.
        do {
            let writer = try AVAudioFile(forWriting: voiceURL, settings: format.settings)
            let total = Int((plan.duration * rate).rounded())
            for start in stride(from: 0, to: total, by: Int(rate)) {
                try Task.checkCancellation()
                let count = min(Int(rate), total - start)
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
                buffer.frameLength = AVAudioFrameCount(count)
                let pointer = buffer.floatChannelData!.pointee
                pointer.update(repeating: 0, count: count)
                for cue in cues where cue.start < Double(start + count) / rate && cue.end > Double(start) / rate {
                    guard let sample = samples[cue.text] else { continue }
                    let onset = Int((cue.start * rate).rounded())
                    let lo = max(start, onset), hi = min(start + count, onset + sample.count)
                    if hi > lo { for index in lo..<hi { pointer[index - start] += sample[index - onset] } }
                }
                try writer.write(from: buffer)
            }
        }
        return try await AudioMix.prepareForPlayback(voice: voiceURL, background: background, volume: settings.backgroundVolume,
            output: folder.appendingPathComponent("breath-mix.m4a"), soundscape: settings.soundscape)
    }
}
