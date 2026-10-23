import AVFoundation
import Accelerate

struct AudioSignal: Equatable {
    var level: Float = 0
    var peak: Float = 0
    var bass: Float = 0
    var mids: Float = 0
    var treble: Float = 0
    var flow: Double = 0
}

/// Offline analysis makes motion independent of preview frame rate, seeking, or export speed.
/// Each channel contributes power independently, so opposite-phase stereo cannot cancel out.
struct AudioEnvelope {
    let duration: Double
    let frames: [AudioSignal]
    private let frameRate: Double

    /// No background means zero reactive energy, while time-driven ambient animation continues.
    init(silence duration: Double) {
        self.duration = duration; frames = [AudioSignal()]; frameRate = 30
    }

    init(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        duration = Double(file.length) / format.sampleRate
        guard duration.isFinite, duration > 0, format.sampleRate > 0 else {
            throw StudioError.message("This recording is empty.")
        }
        let hop = AVAudioFrameCount(max(1, Int(format.sampleRate / 30)))
        let analysisFrameRate = format.sampleRate / Double(hop)
        frameRate = analysisFrameRate
        let logSize = vDSP_Length(ceil(log2(Double(hop))))
        let size = 1 << Int(logSize)
        guard let setup = vDSP_create_fftsetup(logSize, FFTRadix(kFFTRadix2)),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: hop) else {
            throw StudioError.message("Could not prepare audio analysis.")
        }
        defer { vDSP_destroy_fftsetup(setup) }
        var result: [AudioSignal] = []
        var previous = AudioSignal()
        var real = [Float](repeating: 0, count: size)
        var imaginary = real
        let window = (0..<Int(hop)).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(max(1, hop - 1)))) }
        let windowSum = max(1, window.reduce(0, +))
        let channelCount = Int(format.channelCount)
        func normalized(_ amplitude: Float) -> Float {
            min(1, max(0, (20 * log10(max(amplitude, 0.000001)) + 60) / 52))
        }
        func smooth(_ old: Float, _ value: Float) -> Float {
            let seconds: Float = value > old ? 0.10 : 0.65
            return old + (value - old) * (1 - exp(-1 / Float(analysisFrameRate) / seconds))
        }
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: hop)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw StudioError.message("The recording could not be decoded for visual analysis.")
            }
            var squareSum: Float = 0, peak: Float = 0
            var bands = [Float](repeating: 0, count: 3)
            for channel in 0..<channelCount {
                for i in 0..<size {
                    let sample = i < Int(buffer.frameLength) ? channels[channel][i] : 0
                    real[i] = i < Int(hop) ? sample * window[i] : 0
                    imaginary[i] = 0
                    squareSum += sample * sample
                    peak = max(peak, abs(sample))
                }
                real.withUnsafeMutableBufferPointer { r in
                    imaginary.withUnsafeMutableBufferPointer { im in
                        var split = DSPSplitComplex(realp: r.baseAddress!, imagp: im.baseAddress!)
                        vDSP_fft_zip(setup, &split, 1, logSize, FFTDirection(FFT_FORWARD))
                    }
                }
                for bin in 1..<(size / 2) {
                    let hz = Double(bin) * format.sampleRate / Double(size)
                    let power = real[bin] * real[bin] + imaginary[bin] * imaginary[bin]
                    if hz >= 30 && hz < 250 { bands[0] += power }
                    else if hz < 2000 && hz >= 250 { bands[1] += power }
                    else if hz >= 2000 && hz < 12000 { bands[2] += power }
                }
            }
            let rms = sqrt(squareSum / Float(Int(buffer.frameLength) * channelCount))
            let bandValues = bands.map { normalized(sqrt($0 / Float(channelCount) * 2) / windowSum) }
            var next = AudioSignal(
                level: smooth(previous.level, normalized(rms)),
                peak: smooth(previous.peak, normalized(peak)),
                bass: smooth(previous.bass, bandValues[0]),
                mids: smooth(previous.mids, bandValues[1]),
                treble: smooth(previous.treble, bandValues[2])
            )
            next.flow = previous.flow + Double(next.level * 0.7 + next.bass * 0.3) / analysisFrameRate
            result.append(next)
            previous = next
        }
        frames = result
    }

    func signal(at time: Double) -> AudioSignal {
        guard !frames.isEmpty, time.isFinite else { return AudioSignal() }
        let position = min(Double(frames.count - 1), max(0, time * frameRate))
        let index = Int(position)
        let a = frames[index], b = frames[min(index + 1, frames.count - 1)]
        let t = Float(position - Double(index))
        func lerp(_ x: Float, _ y: Float) -> Float { x + (y - x) * t }
        return AudioSignal(level: lerp(a.level, b.level), peak: lerp(a.peak, b.peak),
            bass: lerp(a.bass, b.bass), mids: lerp(a.mids, b.mids), treble: lerp(a.treble, b.treble),
            flow: a.flow + (b.flow - a.flow) * Double(t))
    }
}
