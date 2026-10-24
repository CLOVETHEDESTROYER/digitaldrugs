import Foundation

enum BreathPreset: String, Codable, CaseIterable, Identifiable {
    case gentle = "Gentle · 5 in / 5 out"
    case equal = "Equal breathing · 4 in / 4 out"
    case box = "Box breathing · 4 / 4 / 4 / 4"
    case slowBox = "Slow box breathing · 5 / 5 / 5 / 5"
    case custom = "Custom timing"
    var id: String { rawValue }
    var timings: [Int] {
        switch self {
        case .gentle: [5, 0, 5, 0]
        case .equal: [4, 0, 4, 0]
        case .box: [4, 4, 4, 4]
        case .slowBox: [5, 5, 5, 5]
        case .custom: [5, 0, 5, 0]
        }
    }
    var sourceURL: URL? {
        switch self {
        case .gentle: URL(string: "https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/")
        case .equal: URL(string: "https://yogainternational.com/article/view/why-breath-matters-and-how-to-breathe-well-in-yoga-class/")
        case .box, .slowBox: URL(string: "https://veteranshealthlibrary.va.gov/Encyclopedia/3,84803")
        case .custom: nil
        }
    }
    var note: String {
        switch self {
        case .gentle: "A paced adaptation of the NHS gentle five-count inhale and exhale, without holds."
        case .equal: "Inspired by sama vritti: equal inhale and exhale. Four seconds is this studio’s starting pace; yoga traditions vary."
        case .box: "Four equal phases: inhale, hold, exhale, pause. Choose a no-hold preset if retention is uncomfortable."
        case .slowBox: "The same four equal box-breathing phases, paced at five real seconds each. A complete cycle takes 20 seconds. Choose a no-hold preset if retention is uncomfortable."
        case .custom: "Your own pacing, rather than a named traditional technique."
        }
    }
}

enum BreathVoiceMode: String, Codable, CaseIterable, Identifiable {
    case countdown = "Phase cues + countdown"
    case cues = "Phase cues only"
    case off = "No voice"
    var id: String { rawValue }
}

struct BreathPlan: Codable, Equatable, Sendable {
    var preset: BreathPreset = .gentle
    var inhale = 5
    var hold = 0
    var exhale = 5
    var pause = 0
    var cycles = 6
    var voice: BreathVoiceMode = .countdown
    var voiceName = "OpenAI · Marin"
    var loop = true
    static let intro = 6.0
    static let outro = 4.0
    var maximumCycles: Int { max(1, Int(3600 / cycleDuration)) }
    var cycleDuration: Double { Double(inhale + hold + exhale + pause) }
    var duration: Double { Self.intro + cycleDuration * Double(cycles) + Self.outro }
    var title: String { preset == .custom ? "Breathing Practice" : String(preset.rawValue.split(separator: "·")[0]).trimmingCharacters(in: .whitespaces) }
    mutating func apply(_ preset: BreathPreset) {
        self.preset = preset
        if preset != .custom {
            let t = preset.timings; inhale = t[0]; hold = t[1]; exhale = t[2]; pause = t[3]
            cycles = min(maximumCycles, max(1, cycles))
        }
    }
    mutating func fit(minutes: Int) {
        cycles = min(maximumCycles, max(1, Int((Double(minutes * 60) - Self.intro - Self.outro) / cycleDuration)))
    }
    func validate() throws {
        guard (2...10).contains(inhale), (2...10).contains(exhale), (0...8).contains(hold), (0...8).contains(pause),
              (1...maximumCycles).contains(cycles), duration <= 3610 else {
            throw StudioError.message("Use 2–10 seconds for inhale/exhale, 0–8 for holds, and complete cycles totaling at most one hour.")
        }
        if preset != .custom, [inhale, hold, exhale, pause] != preset.timings {
            throw StudioError.message("Choose Custom timing to change a named preset’s rhythm.")
        }
    }
    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: "breathPlan"),
              var plan = try? JSONDecoder().decode(Self.self, from: data), (try? plan.validate()) != nil else { return Self() }
        plan.voiceName = BreathVoicePack.title
        return plan
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "breathPlan") } }
    var segments: [BreathSegment] {
        var result = [BreathSegment(start: 0, seconds: Self.intro, phase: .ready, cycle: 0)]
        var cursor = Self.intro
        for cycle in 1...max(1, cycles) {
            for (phase, seconds) in [(BreathPhase.inhale, inhale), (.hold, hold), (.exhale, exhale), (.pause, pause)] where seconds > 0 {
                result.append(BreathSegment(start: cursor, seconds: Double(seconds), phase: phase, cycle: cycle))
                cursor += Double(seconds)
            }
        }
        result.append(BreathSegment(start: cursor, seconds: Self.outro, phase: .finish, cycle: cycles))
        return result
    }
    func moment(at time: Double) -> BreathMoment {
        let time = time.isFinite ? min(max(0, time), duration) : 0
        let segment = segments.first { time < $0.start + $0.seconds } ?? segments.last!
        let progress = min(1, max(0, (time - segment.start) / segment.seconds))
        let smooth = progress * progress * (3 - 2 * progress)
        let fill: Double = switch segment.phase {
        case .inhale: smooth
        case .hold: 1
        case .exhale: 1 - smooth
        default: 0
        }
        return BreathMoment(segment: segment, countdown: max(1, Int(ceil(segment.seconds - (time - segment.start)))), progress: progress, fill: fill)
    }
    var spokenCues: [Cue] {
        guard voice != .off else { return [] }
        var result: [Cue] = []
        for segment in segments {
            let phase = segment.phase
            let text = phase == .ready ? "Find a comfortable breath. Follow the circle." : phase == .finish ? "Return to your natural breathing." : phase.spoken
            result.append(Cue(start: segment.start, end: segment.start + (phase == .ready ? 5 : phase == .finish ? 3.5 : 0.9), text: text))
            if voice == .countdown, phase != .ready, phase != .finish {
                for tick in 1..<Int(segment.seconds) {
                    result.append(Cue(start: segment.start + Double(tick), end: segment.start + Double(tick) + 0.9, text: String(Int(segment.seconds) - tick)))
                }
            }
        }
        return result
    }
    var mantra: Mantra {
        Mantra(id: "breathing-practice", title: title, subtitle: "Guided breath pacing", fileName: "generated-breath-cues", timing: "exact phase timeline", category: "Breathing", cues: segments.map { Cue(start: $0.start, end: $0.start + $0.seconds, text: $0.phase.title) })
    }
}

enum BreathPhase: String, Codable, Sendable {
    case ready, inhale, hold, exhale, pause, finish
    var title: String {
        switch self {
        case .ready: "Settle in"
        case .inhale: "Breathe in"
        case .hold: "Hold gently"
        case .exhale: "Breathe out"
        case .pause: "Pause gently"
        case .finish: "Breathe naturally"
        }
    }
    var spoken: String {
        switch self {
        case .inhale: "Inhale"
        case .hold: "Hold"
        case .exhale: "Exhale"
        case .pause: "Pause"
        default: title
        }
    }
}
struct BreathSegment: Codable, Equatable, Sendable {
    let start: Double
    let seconds: Double
    let phase: BreathPhase
    let cycle: Int
}
struct BreathMoment {
    let segment: BreathSegment
    let countdown: Int
    let progress: Double
    let fill: Double
}
