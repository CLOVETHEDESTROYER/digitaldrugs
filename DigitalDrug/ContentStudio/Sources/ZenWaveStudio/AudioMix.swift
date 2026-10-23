import AVFoundation

struct PreparedStudioAudio {
    let playbackURL: URL
    let duration: Double
    let motion: AudioEnvelope
}

/// Audible playback includes the mantra. Motion analysis receives background tracks only.
enum AudioMix {
    static func prepareForPlayback(voice: URL, background: URL?, volume: Double, output: URL,
                                   soundscape: StudioSoundscape = StudioSoundscape()) async throws -> PreparedStudioAudio {
        let motionURL = output.deletingLastPathComponent().appendingPathComponent("motion-\(UUID()).m4a")
        defer { try? FileManager.default.removeItem(at: motionURL) }
        let url = try await prepare(voice: voice, background: background, volume: volume, output: output,
                                    soundscape: soundscape, motionOutput: motionURL)
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let motion = FileManager.default.fileExists(atPath: motionURL.path)
            ? try AudioEnvelope(url: motionURL) : AudioEnvelope(silence: duration)
        return PreparedStudioAudio(playbackURL: url, duration: duration, motion: motion)
    }

    static func prepare(voice: URL, background: URL?, volume: Double, output: URL,
                        soundscape: StudioSoundscape = StudioSoundscape(), motionOutput: URL? = nil) async throws -> URL {
        try soundscape.validate()
        guard background != nil || soundscape.active else { return voice }
        try Task.checkCancellation()
        let voiceAsset = AVURLAsset(url: voice)
        let duration = try await voiceAsset.load(.duration)
        guard duration.seconds.isFinite, duration.seconds > 0,
              let voiceSource = try await voiceAsset.loadTracks(withMediaType: .audio).first else {
            throw StudioError.message("Choose a playable voice recording.")
        }
        let composition = AVMutableComposition()
        guard let voiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw StudioError.message("Could not prepare the audio mix.")
        }
        try voiceTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: voiceSource, at: .zero)
        let musicGain = background == nil ? 0 : min(0.6, max(0, volume))
        let natureGain = soundscape.natureID == nil ? 0 : soundscape.natureVolume
        let toneGain = soundscape.beat == .off ? 0 : soundscape.beatVolume
        let chakraGain = soundscape.chakra?.active == true ? soundscape.chakra!.volume : 0
        let requested = musicGain + natureGain + toneGain + chakraGain
        // Reserve at least 40% for the original voice and keep the sum of gains at unity.
        let scale = requested > 0.6 ? 0.6 / requested : 1
        let voiceParameters = AVMutableAudioMixInputParameters(track: voiceTrack)
        voiceParameters.setVolume(Float(1 - requested * scale), at: .zero)
        var parameters: [AVAudioMixInputParameters] = [voiceParameters]
        if let background, musicGain > 0 {
            parameters += try await addLoop(url: background, gain: Float(musicGain * scale), duration: duration, to: composition)
        }
        if let natureID = soundscape.natureID, natureGain > 0,
           let nature = StudioNature.all.first(where: { $0.id == natureID }) {
            parameters += try await addLoop(url: nature.url, gain: Float(natureGain * scale), duration: duration, to: composition)
        }
        if let chakra = soundscape.chakra, chakra.active {
            // Fixed per-layer headroom keeps existing layers steady as the column builds.
            for (index, sound) in chakra.ordered.enumerated() {
                let start = chakra.mode == .column ? Double(index) * chakra.step : 0
                if start < duration.seconds {
                    parameters += try await addLoop(url: chakra.mode == .recordings ? sound.recordingURL : sound.loopURL,
                        gain: Float(chakraGain * scale / Double(chakra.ordered.count)), duration: duration,
                        to: composition, start: start, exactCadence: chakra.mode != .recordings)
                }
            }
        }
        let toneURL = output.deletingLastPathComponent().appendingPathComponent("tone-\(UUID()).m4a")
        defer { try? FileManager.default.removeItem(at: toneURL) }
        if soundscape.beat != .off, toneGain > 0 {
            try StudioToneWriter.write(beat: soundscape.beat, duration: duration.seconds, to: toneURL)
            let toneAsset = AVURLAsset(url: toneURL)
            guard let source = try await toneAsset.loadTracks(withMediaType: .audio).first,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw StudioError.message("Could not prepare the binaural track.")
            }
            let toneDuration = try await toneAsset.load(.duration)
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, toneDuration)), of: source, at: .zero)
            let toneParameters = AVMutableAudioMixInputParameters(track: track)
            toneParameters.setVolume(Float(toneGain * scale), at: .zero)
            parameters.append(toneParameters)
        }
        let mix = AVMutableAudioMix(); mix.inputParameters = parameters
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw StudioError.message("Could not create the audio mix.")
        }
        exporter.audioMix = mix; exporter.timeRange = CMTimeRange(start: .zero, duration: duration)
        exporter.outputFileType = .m4a; exporter.outputURL = output
        await withTaskCancellationHandler { await exporter.export() } onCancel: { exporter.cancelExport() }
        try Task.checkCancellation()
        guard exporter.status == .completed else {
            throw exporter.error ?? StudioError.message("The background layers could not be mixed with this recording.")
        }
        if let motionOutput, requested > 0 {
            try Task.checkCancellation()
            // Physically remove the mantra track: it cannot leak into background analysis,
            // including codec preroll, pauses, caption offsets or a live chapter transition.
            composition.removeTrack(voiceTrack)
            let motionMix = AVMutableAudioMix(); motionMix.inputParameters = Array(parameters.dropFirst())
            guard let motionExporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
                throw StudioError.message("Could not prepare background-only motion analysis.")
            }
            motionExporter.audioMix = motionMix; motionExporter.timeRange = CMTimeRange(start: .zero, duration: duration)
            motionExporter.outputURL = motionOutput; motionExporter.outputFileType = .m4a
            await withTaskCancellationHandler { await motionExporter.export() } onCancel: { motionExporter.cancelExport() }
            try Task.checkCancellation()
            guard motionExporter.status == .completed else {
                throw motionExporter.error ?? StudioError.message("Background-only motion analysis did not finish.")
            }
        }
        return output
    }

    private static func addLoop(url: URL, gain: Float, duration: CMTime, to composition: AVMutableComposition, start: Double = 0, exactCadence: Bool = false) async throws -> [AVAudioMixInputParameters] {
        let asset = AVURLAsset(url: url), bedDuration = try await asset.load(.duration)
        guard bedDuration.seconds.isFinite, bedDuration.seconds >= 0.1,
              let source = try await asset.loadTracks(withMediaType: .audio).first,
              let a = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let b = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw StudioError.message("Choose a playable background file at least 0.1 seconds long. Rebuild the studio if a bundled nature sound is missing.")
        }
        let tracks = [a, b], parameters = tracks.map { AVMutableAudioMixInputParameters(track: $0) }
        // A track whose first segment starts later otherwise defaults to unity before
        // its first ramp; AAC packet preroll can expose that gain at the loop join.
        for parameter in parameters { parameter.setVolume(0, at: .zero) }
        let overlap = exactCadence ? 0 : min(0.35, bedDuration.seconds * 0.1), advance = bedDuration.seconds - overlap
        let total = duration.seconds
        var cursor = start, loop = 0
        func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 60000) }
        while cursor < total - 0.00001 {
            try Task.checkCancellation()
            let slot = loop % 2, length = min(bedDuration.seconds, total - cursor)
            try tracks[slot].insertTimeRange(CMTimeRange(start: .zero, duration: time(length)), of: source, at: time(cursor))
            let fadeIn = min(loop == 0 ? 0.7 : max(0.015, overlap), length / 2)
            let fadeOut = min(cursor + length >= total - 0.00001 ? 0.9 : max(0.015, overlap), length / 2)
            let parameter = parameters[slot]
            parameter.setVolumeRamp(fromStartVolume: 0, toEndVolume: gain, timeRange: CMTimeRange(start: time(cursor), duration: time(fadeIn)))
            parameter.setVolume(gain, at: time(cursor + fadeIn))
            parameter.setVolumeRamp(fromStartVolume: gain, toEndVolume: 0, timeRange: CMTimeRange(start: time(cursor + length - fadeOut), duration: time(fadeOut)))
            cursor += advance; loop += 1
        }
        return parameters
    }
}
