//
//  SessionModel.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

/// Binaural session data model
struct BinauralSession: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let brainwaveType: BrainwaveType
    let icon: BrainwaveIcon
    let description: String
    let binauralFile: String?
    let natureFile: String?
    let frequencyRange: String
    let benefits: [String]
}

enum BrainwaveType: String {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    case gamma = "Gamma"
}

enum RitualIntent: String, CaseIterable, Identifiable, Codable {
    case sleep = "sleep"
    case meditate = "meditate"
    case astral = "astral"
    case manifestation = "manifestation"
    case chakra = "chakra"
    case focus = "focus"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .sleep: return "Sleep Deeper"
        case .meditate: return "Meditate"
        case .astral: return "Astral Projection"
        case .manifestation: return "Manifestation Visualization"
        case .chakra: return "Chakra Balance"
        case .focus: return "Focus"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .sleep: return "Sleep"
        case .meditate: return "Meditate"
        case .astral: return "Astral"
        case .manifestation: return "Manifest"
        case .chakra: return "Chakras"
        case .focus: return "Focus"
        }
    }
    
    var iconName: String {
        switch self {
        case .sleep: return "moon.stars.fill"
        case .meditate: return "sparkles"
        case .astral: return "eye.fill"
        case .manifestation: return "target"
        case .chakra: return "circle.hexagongrid.fill"
        case .focus: return "brain.head.profile"
        }
    }
    
    var color: Color {
        switch self {
        case .sleep: return .indigo
        case .meditate: return .cyan
        case .astral: return .purple
        case .manifestation: return .pink
        case .chakra: return .mint
        case .focus: return .orange
        }
    }
}

enum RitualAudioKind: Codable, Hashable {
    case binaural(left: Double, right: Double)
    case chakra(frequency: Double, chakraName: String)
}

struct RitualPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let intent: RitualIntent
    let audioKind: RitualAudioKind
    let durationMinutes: Int
    let instruction: String
    let disclaimer: String
    let accent: Color
    
    var frequencyLabel: String {
        switch audioKind {
        case .binaural(let left, let right):
            return "\(Int(abs(right - left))) Hz beat"
        case .chakra(let frequency, _):
            return "\(Int(frequency)) Hz"
        }
    }
    
    var shareLine: String {
        "I completed \(title) in ZenWave / DigitalDrugz."
    }
}

extension RitualPreset {
    static let all: [RitualPreset] = [
        RitualPreset(
            id: "astral-projection-prep",
            title: "Astral Projection Prep",
            subtitle: "Body asleep, awareness awake",
            intent: .astral,
            audioKind: .binaural(left: 200, right: 207),
            durationMinutes: 12,
            instruction: "Put headphones on. Keep the body still. When vibration appears, relax into it instead of chasing it.",
            disclaimer: "Designed to support a calm pre-sleep visualization ritual.",
            accent: .purple
        ),
        RitualPreset(
            id: "gateway-theta",
            title: "Gateway Theta",
            subtitle: "A steady 7 Hz theta bridge",
            intent: .astral,
            audioKind: .binaural(left: 210, right: 217),
            durationMinutes: 15,
            instruction: "Breathe slowly and count down from ten. Let each number make the body heavier.",
            disclaimer: "Use as a personal meditation aid; experiences vary.",
            accent: .indigo
        ),
        RitualPreset(
            id: "lucid-dream-prep",
            title: "Lucid Dream Prep",
            subtitle: "Dreamlike awareness before sleep",
            intent: .sleep,
            audioKind: .binaural(left: 120, right: 126),
            durationMinutes: 10,
            instruction: "Set one dream cue, lower the volume, and keep the phrase simple: I notice when I am dreaming.",
            disclaimer: "Designed to support nighttime intention setting.",
            accent: .blue
        ),
        RitualPreset(
            id: "seven-hz-theta",
            title: "7Hz Theta Meditation",
            subtitle: "The TikTok-tested meditation state",
            intent: .meditate,
            audioKind: .binaural(left: 200, right: 207),
            durationMinutes: 7,
            instruction: "Close your eyes. Do not force focus. Return to the pulse each time the mind wanders.",
            disclaimer: "A ritual soundscape for relaxation and inward focus.",
            accent: .cyan
        ),
        RitualPreset(
            id: "deep-sleep-delta",
            title: "Deep Sleep Delta",
            subtitle: "Low and slow wind down",
            intent: .sleep,
            audioKind: .binaural(left: 100, right: 103),
            durationMinutes: 20,
            instruction: "Let your jaw soften. Keep the sound low enough to disappear into the room.",
            disclaimer: "Designed to support a calmer bedtime environment.",
            accent: .indigo
        ),
        RitualPreset(
            id: "manifestation-visualization",
            title: "Manifestation Visualization",
            subtitle: "Future-self rehearsal",
            intent: .manifestation,
            audioKind: .binaural(left: 400, right: 410),
            durationMinutes: 11,
            instruction: "Picture one scene as already normal. Focus on the feeling, not the forcing.",
            disclaimer: "A visualization ritual, not a guarantee of outcomes.",
            accent: .pink
        ),
        RitualPreset(
            id: "root-chakra-grounding",
            title: "Root Chakra Grounding",
            subtitle: "Safety, stability, body",
            intent: .chakra,
            audioKind: .chakra(frequency: 396, chakraName: "Root"),
            durationMinutes: 9,
            instruction: "Place attention on your feet and lower body. Let the sound feel heavy and steady.",
            disclaimer: "Designed to support grounding and body awareness.",
            accent: .red
        ),
        RitualPreset(
            id: "third-eye-clarity",
            title: "Third Eye Clarity",
            subtitle: "Quiet the mental noise",
            intent: .chakra,
            audioKind: .chakra(frequency: 852, chakraName: "Third Eye"),
            durationMinutes: 9,
            instruction: "Soften your forehead. Watch thoughts pass without needing to solve them.",
            disclaimer: "A reflective sound ritual for insight and stillness.",
            accent: .indigo
        ),
        RitualPreset(
            id: "adhd-focus-gamma",
            title: "ADHD Focus Gamma",
            subtitle: "Structured energy for one task",
            intent: .focus,
            audioKind: .binaural(left: 1600, right: 1630),
            durationMinutes: 25,
            instruction: "Pick one task before pressing play. Keep the app open and let the timer hold the container.",
            disclaimer: "Designed as a focus ritual; not medical treatment.",
            accent: .orange
        ),
        RitualPreset(
            id: "calm-wind-down",
            title: "Calm Wind Down",
            subtitle: "Alpha into theta softness",
            intent: .meditate,
            audioKind: .binaural(left: 300, right: 308),
            durationMinutes: 8,
            instruction: "Exhale longer than you inhale. Let the body know there is nothing to solve right now.",
            disclaimer: "Designed to support relaxation and transition time.",
            accent: .teal
        )
    ]
    
    static func recommended(for intent: RitualIntent) -> RitualPreset {
        all.first(where: { $0.intent == intent }) ?? all[3]
    }
    
    static func preset(id: String) -> RitualPreset {
        all.first(where: { $0.id == id }) ?? all[3]
    }
}

struct RitualChallenge: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let dayCount: Int
    let presetIDs: [String]
    let accent: Color
    
    func preset(for day: Int) -> RitualPreset {
        let index = max(0, min(day - 1, presetIDs.count - 1))
        return RitualPreset.preset(id: presetIDs[index])
    }
}

extension RitualChallenge {
    static let all: [RitualChallenge] = [
        RitualChallenge(
            id: "seven-nights-theta",
            title: "7 Nights of Theta",
            subtitle: "A repeatable sleep-state ritual",
            dayCount: 7,
            presetIDs: Array(repeating: "seven-hz-theta", count: 7),
            accent: .cyan
        ),
        RitualChallenge(
            id: "seven-days-root",
            title: "7 Days Root Grounding",
            subtitle: "Build a steadier signal",
            dayCount: 7,
            presetIDs: Array(repeating: "root-chakra-grounding", count: 7),
            accent: .red
        ),
        RitualChallenge(
            id: "astral-prep-three",
            title: "3-Day Astral Projection Prep",
            subtitle: "Practice stillness before sleep",
            dayCount: 3,
            presetIDs: ["astral-projection-prep", "gateway-theta", "lucid-dream-prep"],
            accent: .purple
        )
    ]
}

struct RitualJournalEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let presetID: String
    let presetTitle: String
    let moodBefore: Int
    let moodAfter: Int
    let intention: String
    let notes: String
    var module: String?
    var ritualID: String?
    var voiceEnabled: Bool?
    var observedSensations: String?
    
    init(
        id: UUID,
        date: Date,
        presetID: String,
        presetTitle: String,
        moodBefore: Int,
        moodAfter: Int,
        intention: String,
        notes: String,
        module: String? = nil,
        ritualID: String? = nil,
        voiceEnabled: Bool? = nil,
        observedSensations: String? = nil
    ) {
        self.id = id
        self.date = date
        self.presetID = presetID
        self.presetTitle = presetTitle
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
        self.intention = intention
        self.notes = notes
        self.module = module
        self.ritualID = ritualID
        self.voiceEnabled = voiceEnabled
        self.observedSensations = observedSensations
    }
    
    var dateLabel: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

extension BinauralSession {
    static let allSessions: [BinauralSession] = [
        BinauralSession(
            title: "Deep Sleep",
            subtitle: "(Delta)",
            brainwaveType: .delta,
            icon: .delta,
            description: "Delta brain waves are the gateway into transcendence and deep states of relaxation, where they can help you with increasing deep sleep, healing and pain relief, anti-aging, and access to the unconscious mind.",
            binauralFile: "lucid_dream.mp3",
            natureFile: "Ocean.wav",
            frequencyRange: "0.5 - 4 Hz",
            benefits: [
                "Increasing deep sleep",
                "Healing and pain relief",
                "Anti-aging: cortisol reduction/DHEA increase",
                "Access to the unconscious mind"
            ]
        ),
        BinauralSession(
            title: "Focus & Flow",
            subtitle: "(Gamma)",
            brainwaveType: .gamma,
            icon: .gamma,
            description: "Gamma brain waves can help you achieve the highest concentration levels, spark new insights and improve your creative problem-solving skills.",
            binauralFile: nil,
            natureFile: nil,
            frequencyRange: "30 - 100 Hz",
            benefits: [
                "Peak concentration",
                "Brain synchronization",
                "Better memory",
                "Faster cognition"
            ]
        ),
        BinauralSession(
            title: "Relaxation",
            subtitle: "(Theta)",
            brainwaveType: .theta,
            icon: .theta,
            description: "Theta brain waves are the gateway into deep meditation states, flow states with full transient hypofrontality, and dream journeys.",
            binauralFile: "hangover_cure.mp3",
            natureFile: "Ocean.wav",
            frequencyRange: "4 - 8 Hz",
            benefits: [
                "Meditation and deep relaxation",
                "Reprogramming limiting beliefs",
                "Creativity and insights",
                "Lucid dreaming"
            ]
        ),
        BinauralSession(
            title: "Energy Boost",
            subtitle: "(Beta)",
            brainwaveType: .beta,
            icon: .beta,
            description: "Beta is a higher frequency brainwave associated with our normal waking state when we are actively engaged in thinking or a task.",
            binauralFile: nil,
            natureFile: nil,
            frequencyRange: "12 - 30 Hz",
            benefits: [
                "Keeping your attention focused",
                "Analytical thinking and solving problems",
                "Stimulating energy and action",
                "High-level cognition"
            ]
        )
    ]
}
