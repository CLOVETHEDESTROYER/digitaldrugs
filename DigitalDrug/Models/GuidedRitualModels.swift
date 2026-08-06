//
//  GuidedRitualModels.swift
//  DigitalDrug
//

import SwiftUI

enum GuidedRitualModule: String, Codable, Hashable {
    case gateway = "Gateway"
    case quantumCodes = "Quantum Codes"
    case manifestation = "Manifestation"

    var title: String {
        switch self {
        case .gateway: return "Gateway Rituals"
        case .quantumCodes: return "Quantum Code Rituals"
        case .manifestation: return "Manifestation Ritual"
        }
    }

    var badge: String {
        switch self {
        case .gateway: return "Gateway-inspired"
        case .quantumCodes: return "Esoteric code ritual"
        case .manifestation: return "Guided manifestation"
        }
    }
}

enum GuidedRitualVisualKind: String, Codable, Hashable {
    case breathOrb
    case releaseBox
    case bodyMap
    case energyField
    case countdown
    case pattern
    case codePulse
    case grounding
}

struct GuidedRitualStep: Identifiable, Hashable {
    let id: String
    let startTime: TimeInterval
    let title: String
    let spokenPrompt: String
    let visualKind: GuidedRitualVisualKind
    let duration: TimeInterval?

    init(
        id: String,
        startTime: TimeInterval,
        title: String,
        spokenPrompt: String,
        visualKind: GuidedRitualVisualKind,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.title = title
        self.spokenPrompt = spokenPrompt
        self.visualKind = visualKind
        self.duration = duration
    }
}

struct GuidedRitual: Identifiable, Hashable {
    let id: String
    let title: String
    let module: GuidedRitualModule
    let subtitle: String
    let intent: RitualIntent
    let audioKind: RitualAudioKind
    let duration: TimeInterval
    let accent: Color
    let steps: [GuidedRitualStep]
    let journalPrompts: [String]
    let safeDisclaimer: String
    let summary: String
    let codeSequence: [String]

    var durationMinutes: Int {
        Int(ceil(duration / 60))
    }

    var frequencyLabel: String {
        switch audioKind {
        case .binaural(let left, let right):
            return "\(Int(abs(right - left))) Hz beat"
        case .chakra(let frequency, _):
            return "\(Int(frequency)) Hz"
        }
    }

    var codeLine: String {
        codeSequence.joined(separator: "  ")
    }
}

extension GuidedRitual {
    static let gatewayRituals: [GuidedRitual] = [
        gateway(
            id: "focus-10",
            title: "Focus 10",
            subtitle: "Mind awake, body relaxed",
            intent: .meditate,
            audioKind: .binaural(left: 200, right: 207),
            minutes: 10,
            accent: .cyan,
            summary: "A Gateway-inspired relaxation ritual for practicing calm awareness while the body softens.",
            steps: [
                .init(id: "container", startTime: 0, title: "Set the container", spokenPrompt: "Settle in. Put your distractions aside for the next few minutes.", visualKind: .releaseBox, duration: 45),
                .init(id: "breath", startTime: 45, title: "Resonant breathing", spokenPrompt: "Inhale slowly. Hold gently. Exhale longer than you inhale.", visualKind: .breathOrb, duration: 120),
                .init(id: "countdown", startTime: 180, title: "Count into Focus 10", spokenPrompt: "Count from one to ten. With each number, let the body become heavier and calmer.", visualKind: .countdown, duration: 180),
                .init(id: "body", startTime: 390, title: "Body map", spokenPrompt: "Notice the body as a quiet outline. Let each area soften without forcing it.", visualKind: .bodyMap, duration: 150),
                .init(id: "return", startTime: 540, title: "Return", spokenPrompt: "Begin returning. Move your fingers and toes. Orient to the room. Open your eyes when ready.", visualKind: .grounding, duration: 60)
            ],
            journalPrompts: ["What felt most relaxed?", "What did you notice as the body settled?"]
        ),
        gateway(
            id: "focus-12",
            title: "Focus 12",
            subtitle: "Expanded awareness",
            intent: .astral,
            audioKind: .binaural(left: 210, right: 217),
            minutes: 12,
            accent: .purple,
            summary: "A spacious awareness ritual inspired by the Focus 10 to Focus 12 progression.",
            steps: [
                .init(id: "settle", startTime: 0, title: "Stabilize", spokenPrompt: "Begin in stillness. Let the sound become the edge of your attention.", visualKind: .breathOrb, duration: 90),
                .init(id: "focus10", startTime: 90, title: "Focus 10 base", spokenPrompt: "Let the body rest while awareness stays clear and awake.", visualKind: .bodyMap, duration: 150),
                .init(id: "expand", startTime: 260, title: "Expand", spokenPrompt: "Imagine awareness extending beyond the body, wider and quieter.", visualKind: .energyField, duration: 250),
                .init(id: "observe", startTime: 530, title: "Observe", spokenPrompt: "Notice images, sensations, or thoughts without chasing them.", visualKind: .energyField, duration: 130),
                .init(id: "return", startTime: 660, title: "Return", spokenPrompt: "Gather awareness back to the body. Move gently and orient to the room.", visualKind: .grounding, duration: 60)
            ],
            journalPrompts: ["What expanded?", "What images, words, or sensations appeared?"]
        ),
        gateway(
            id: "resonant-breath-reset",
            title: "Resonant Breath Reset",
            subtitle: "Breath, pulse, and nervous-system softness",
            intent: .meditate,
            audioKind: .binaural(left: 300, right: 308),
            minutes: 6,
            accent: .teal,
            summary: "A short breath ritual using Gateway-style energy-in and stale-energy-out imagery.",
            steps: [
                .init(id: "inhale", startTime: 0, title: "Energy in", spokenPrompt: "Inhale as if fresh energy rises through the body.", visualKind: .breathOrb, duration: 90),
                .init(id: "circle", startTime: 90, title: "Circle the breath", spokenPrompt: "Let the breath circle gently around the head, then soften down through the body.", visualKind: .energyField, duration: 120),
                .init(id: "exhale", startTime: 220, title: "Release", spokenPrompt: "Exhale slowly. Imagine used-up energy leaving through the feet.", visualKind: .grounding, duration: 100)
            ],
            journalPrompts: ["What changed after breathing?", "Where did the body feel softer?"]
        ),
        gateway(
            id: "release-box",
            title: "Release Box",
            subtitle: "Put distractions down before the ritual",
            intent: .sleep,
            audioKind: .binaural(left: 120, right: 126),
            minutes: 7,
            accent: .indigo,
            summary: "A pre-sleep container ritual for mentally setting aside noise and unfinished loops.",
            steps: [
                .init(id: "name", startTime: 0, title: "Name the noise", spokenPrompt: "Name one thought, worry, or loop you do not need to carry right now.", visualKind: .releaseBox, duration: 90),
                .init(id: "place", startTime: 110, title: "Place it down", spokenPrompt: "Imagine placing that thought inside a secure box. It can wait.", visualKind: .releaseBox, duration: 150),
                .init(id: "seal", startTime: 290, title: "Seal the box", spokenPrompt: "Seal the box and return to breath. There is nothing to solve in this moment.", visualKind: .breathOrb, duration: 100)
            ],
            journalPrompts: ["What did you set down?", "Did the thought feel quieter after the ritual?"]
        ),
        gateway(
            id: "energy-shield",
            title: "Energy Shield",
            subtitle: "A calm boundary around your session",
            intent: .astral,
            audioKind: .binaural(left: 200, right: 207),
            minutes: 9,
            accent: .purple,
            summary: "A REBAL-inspired protective field visualization for entering deeper rituals with a grounded container.",
            steps: [
                .init(id: "breath", startTime: 0, title: "Build the charge", spokenPrompt: "Breathe slowly and imagine a soft light gathering around you.", visualKind: .breathOrb, duration: 120),
                .init(id: "field", startTime: 130, title: "Create the field", spokenPrompt: "Let the light form a calm sphere around the body.", visualKind: .energyField, duration: 180),
                .init(id: "steady", startTime: 330, title: "Steady boundary", spokenPrompt: "This is your container for focus, reflection, and calm visualization.", visualKind: .energyField, duration: 150),
                .init(id: "return", startTime: 480, title: "Return", spokenPrompt: "Let the field soften. Bring attention back to the room.", visualKind: .grounding, duration: 60)
            ],
            journalPrompts: ["How did the boundary feel?", "What color or shape appeared?"]
        ),
        gateway(
            id: "pattern-builder",
            title: "Pattern Builder",
            subtitle: "Manifestation visualization with one real action",
            intent: .manifestation,
            audioKind: .binaural(left: 400, right: 410),
            minutes: 11,
            accent: .pink,
            summary: "A desired-state rehearsal that ends with a grounded next action.",
            steps: [
                .init(id: "choose", startTime: 0, title: "Choose the pattern", spokenPrompt: "Choose one desired state. Keep it simple and specific.", visualKind: .pattern, duration: 90),
                .init(id: "feel", startTime: 120, title: "Feel it as normal", spokenPrompt: "Imagine this state as already normal. Notice posture, breath, and emotion.", visualKind: .pattern, duration: 220),
                .init(id: "release", startTime: 370, title: "Release the image", spokenPrompt: "Let the image move outward without forcing the outcome.", visualKind: .energyField, duration: 160),
                .init(id: "action", startTime: 560, title: "Choose one action", spokenPrompt: "Name one small action you can take after this session.", visualKind: .grounding, duration: 80)
            ],
            journalPrompts: ["What pattern did you rehearse?", "What is one aligned action?"]
        ),
        gateway(
            id: "astral-projection-prep-guided",
            title: "Astral Projection Prep",
            subtitle: "Stillness and float-up visualization",
            intent: .astral,
            audioKind: .binaural(left: 200, right: 207),
            minutes: 12,
            accent: .purple,
            summary: "A safe, guided visualization inspired by out-of-body traditions. It prepares the mind; it does not promise separation.",
            steps: [
                .init(id: "container", startTime: 0, title: "Container", spokenPrompt: "Set your intention for calm exploration. You can stop at any time.", visualKind: .energyField, duration: 90),
                .init(id: "still", startTime: 120, title: "Body still", spokenPrompt: "Let the body become still and heavy while awareness stays awake.", visualKind: .bodyMap, duration: 180),
                .init(id: "float", startTime: 330, title: "Float up", spokenPrompt: "Imagine a lighter version of you floating gently above the body.", visualKind: .energyField, duration: 220),
                .init(id: "observe", startTime: 570, title: "Observe", spokenPrompt: "Notice without chasing. If anything feels too intense, return to breath.", visualKind: .breathOrb, duration: 90),
                .init(id: "return", startTime: 660, title: "Return fully", spokenPrompt: "Return fully to the body. Move fingers and toes. Open your eyes and orient to the room.", visualKind: .grounding, duration: 60)
            ],
            journalPrompts: ["What did the float-up visualization feel like?", "Did any vibration, imagery, or dreamlike state appear?"]
        )
    ]

    static let quantumCodeRituals: [GuidedRitual] = [
        quantum(id: "calm-code", title: "Calm Code", subtitle: "Soothe emotional charge", intent: .meditate, audioKind: .binaural(left: 300, right: 308), minutes: 6, accent: .teal, codes: ["12 57 901"], summary: "A reflective ritual using a code allegedly associated with patience and calm."),
        quantum(id: "sleep-code", title: "Sleep Code", subtitle: "Night signal", intent: .sleep, audioKind: .binaural(left: 100, right: 103), minutes: 8, accent: .indigo, codes: ["11 21 495"], summary: "A bedtime ritual using a code allegedly associated with long-standing insomnia support."),
        quantum(id: "focus-code", title: "Focus Code", subtitle: "One task container", intent: .focus, audioKind: .binaural(left: 1600, right: 1630), minutes: 10, accent: .orange, codes: ["45 88 623"], summary: "A focus ritual using a code allegedly associated with focus."),
        quantum(id: "love-code", title: "Love + Compassion", subtitle: "Heart softening", intent: .meditate, audioKind: .chakra(frequency: 639, chakraName: "Heart"), minutes: 7, accent: .green, codes: ["56 57 893"], summary: "A heart ritual using a code allegedly associated with unconditional love."),
        quantum(id: "abundance-code", title: "Abundance Pattern", subtitle: "Prosperity visualization", intent: .manifestation, audioKind: .binaural(left: 400, right: 410), minutes: 9, accent: .pink, codes: ["80 49 627"], summary: "A manifestation ritual using a code allegedly associated with creating financial abundance."),
        quantum(id: "boundary-code", title: "Protection Boundary", subtitle: "Energetic container", intent: .astral, audioKind: .binaural(left: 200, right: 207), minutes: 8, accent: .purple, codes: ["17 94 625 826 95413"], summary: "A boundary ritual using a code described as a protection attunement."),
        quantum(id: "spiritual-energy-code", title: "Spiritual Energy", subtitle: "Service and light", intent: .chakra, audioKind: .chakra(frequency: 963, chakraName: "Crown"), minutes: 9, accent: .purple, codes: ["51 34 581"], summary: "A reflective ritual using a code allegedly associated with shining your light."),
        quantum(id: "grounding-code", title: "Grounding Code", subtitle: "Return to the body", intent: .chakra, audioKind: .chakra(frequency: 396, chakraName: "Root"), minutes: 7, accent: .red, codes: ["51 86 923"], summary: "A grounding ritual using a code allegedly associated with grounding.")
    ]

    private static func gateway(
        id: String,
        title: String,
        subtitle: String,
        intent: RitualIntent,
        audioKind: RitualAudioKind,
        minutes: Int,
        accent: Color,
        summary: String,
        steps: [GuidedRitualStep],
        journalPrompts: [String]
    ) -> GuidedRitual {
        GuidedRitual(
            id: id,
            title: title,
            module: .gateway,
            subtitle: subtitle,
            intent: intent,
            audioKind: audioKind,
            duration: TimeInterval(minutes * 60),
            accent: accent,
            steps: steps,
            journalPrompts: journalPrompts,
            safeDisclaimer: "Gateway-inspired visualization for relaxation and inner exploration. Experiences vary.",
            summary: summary,
            codeSequence: []
        )
    }

    private static func quantum(
        id: String,
        title: String,
        subtitle: String,
        intent: RitualIntent,
        audioKind: RitualAudioKind,
        minutes: Int,
        accent: Color,
        codes: [String],
        summary: String
    ) -> GuidedRitual {
        let cadence = quantumSteps(codes: codes, minutes: minutes)
        return GuidedRitual(
            id: id,
            title: title,
            module: .quantumCodes,
            subtitle: subtitle,
            intent: intent,
            audioKind: audioKind,
            duration: TimeInterval(minutes * 60),
            accent: accent,
            steps: cadence,
            journalPrompts: ["What did the code bring up?", "What intention did you pair with it?"],
            safeDisclaimer: "Quantum Codes are offered as esoteric reflection rituals, not medical advice or treatment.",
            summary: summary,
            codeSequence: codes
        )
    }

    private static func quantumSteps(codes: [String], minutes: Int) -> [GuidedRitualStep] {
        let codeLine = codes.joined(separator: ". ")
        let spokenCode = codes.map { code in
            spokenQuantumCode(code)
        }.joined(separator: ". ")
        return [
            .init(id: "intention", startTime: 0, title: "Set intention", spokenPrompt: "Set one clear intention for this code ritual.", visualKind: .releaseBox, duration: 45),
            .init(id: "code-one", startTime: 60, title: codeLine, spokenPrompt: "The code is \(spokenCode). Let each number land slowly.", visualKind: .codePulse, duration: 90),
            .init(id: "code-two", startTime: 180, title: "Repeat the code", spokenPrompt: "Again, \(spokenCode). Pair it with your intention and breath.", visualKind: .codePulse, duration: 120),
            .init(id: "integrate", startTime: max(240, TimeInterval(minutes * 60 - 90)), title: "Integrate", spokenPrompt: "Release the numbers. Notice your breath, body, and state.", visualKind: .grounding, duration: 90)
        ]
    }

    private static func spokenQuantumCode(_ code: String) -> String {
        let numberWords: [Character: String] = [
            "0": "zero",
            "1": "one",
            "2": "two",
            "3": "three",
            "4": "four",
            "5": "five",
            "6": "six",
            "7": "seven",
            "8": "eight",
            "9": "nine"
        ]

        return code
            .split(separator: " ")
            .map { group in
                group.compactMap { numberWords[$0] }.joined(separator: " ")
            }
            .joined(separator: ", ")
    }
}
