//
//  ManifestationModels.swift
//  DigitalDrug
//

import SwiftUI

enum ManifestationTheme: String, CaseIterable, Identifiable, Codable {
    case abundance
    case love
    case confidence
    case purpose
    case calm

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .abundance: return "diamond.fill"
        case .love: return "heart.fill"
        case .confidence: return "person.crop.circle.fill"
        case .purpose: return "sparkle"
        case .calm: return "water.waves"
        }
    }

    var accent: Color {
        switch self {
        case .abundance: return .cyan
        case .love: return .pink
        case .confidence: return Color(red: 0.48, green: 0.17, blue: 0.75)
        case .purpose: return .purple
        case .calm: return .teal
        }
    }
}

enum ManifestationTone: String, CaseIterable, Identifiable {
    case grounded
    case mystical
    case direct

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct ManifestationAffirmation: Identifiable, Hashable {
    let id: String
    let theme: ManifestationTheme
    let text: String
    let reflectionPrompt: String

    static var daily: ManifestationAffirmation {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return library[day % library.count]
    }

    static let library: [ManifestationAffirmation] = [
        .init(id: "clarity-action", theme: .purpose, text: "I take grounded action toward the life I am creating.", reflectionPrompt: "What is one aligned action you can take today?"),
        .init(id: "abundance-opportunity", theme: .abundance, text: "I notice opportunities that align with my values, and I meet them with clear action.", reflectionPrompt: "Which opportunity deserves your attention today?"),
        .init(id: "love-receive", theme: .love, text: "I make room for honest connection, compassion, and love that feels mutual.", reflectionPrompt: "How can you practice the connection you want to receive?"),
        .init(id: "confidence-trust", theme: .confidence, text: "I trust myself to take the next clear step, even before the whole path is visible.", reflectionPrompt: "What would self-trust look like in one small decision?"),
        .init(id: "calm-space", theme: .calm, text: "I create space between the moment and my response.", reflectionPrompt: "Where can you choose a slower response today?"),
        .init(id: "purpose-direction", theme: .purpose, text: "My direction becomes clearer each time I act in alignment with what matters.", reflectionPrompt: "What matters enough to move toward today?"),
        .init(id: "abundance-capacity", theme: .abundance, text: "I am building the capacity to receive, manage, and grow meaningful abundance.", reflectionPrompt: "What capacity can you strengthen today?"),
        .init(id: "love-boundaries", theme: .love, text: "My boundaries protect the kind of connection I want to cultivate.", reflectionPrompt: "What boundary would make connection feel safer?"),
        .init(id: "confidence-visible", theme: .confidence, text: "I allow my work, voice, and ideas to be seen.", reflectionPrompt: "Where can you show up more fully today?"),
        .init(id: "calm-return", theme: .calm, text: "I can return to steadiness one breath and one choice at a time.", reflectionPrompt: "What helps you return to yourself?"),
        .init(id: "purpose-becoming", theme: .purpose, text: "I practice becoming the person who can hold the life I envision.", reflectionPrompt: "What would that version of you practice today?"),
        .init(id: "abundance-values", theme: .abundance, text: "I welcome resources that support my values, my growth, and the good I can create.", reflectionPrompt: "What would values-aligned abundance support?"),
        .init(id: "love-self", theme: .love, text: "I speak to myself with the care I want to bring into every relationship.", reflectionPrompt: "What do you need to hear from yourself today?"),
        .init(id: "confidence-learning", theme: .confidence, text: "I can be learning and still move with confidence.", reflectionPrompt: "What imperfect action would create useful momentum?"),
        .init(id: "calm-present", theme: .calm, text: "This moment does not require me to solve everything at once.", reflectionPrompt: "What can wait while you attend to this moment?"),
    ]

    static func generated(
        theme: ManifestationTheme,
        tone: ManifestationTone,
        intention: String
    ) -> ManifestationAffirmation {
        let cleanIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = cleanIntention.isEmpty ? defaultSubject(for: theme) : cleanIntention
        let text: String

        switch tone {
        case .grounded:
            text = "I move toward \(subject) through clear choices and grounded action."
        case .mystical:
            text = "I make space for \(subject) to unfold as I align my attention, energy, and action."
        case .direct:
            text = "I choose \(subject), and I take the next real step today."
        }

        return ManifestationAffirmation(
            id: "custom-\(theme.rawValue)-\(tone.rawValue)",
            theme: theme,
            text: text,
            reflectionPrompt: "What is one action that makes this intention more real?"
        )
    }

    private static func defaultSubject(for theme: ManifestationTheme) -> String {
        switch theme {
        case .abundance: return "values-aligned abundance"
        case .love: return "mutual love and connection"
        case .confidence: return "steady self-trust"
        case .purpose: return "a life shaped by purpose"
        case .calm: return "a calmer inner rhythm"
        }
    }
}

struct ManifestationMantra: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let fileName: String
    let accent: Color

    static let library: [ManifestationMantra] = [
        .init(
            id: "abundance",
            title: "Abundance Mantra",
            subtitle: "Receive, steward, and grow with intention",
            fileName: "abundanceMantra.mp3",
            accent: .cyan
        ),
        .init(
            id: "career",
            title: "Career Path Mantra",
            subtitle: "Clarity, confidence, and the next aligned step",
            fileName: "jobManifestaton.mp3",
            accent: .purple
        ),
        .init(
            id: "love",
            title: "Love Mantra",
            subtitle: "Mutual connection, care, and openness",
            fileName: "loveMantra.mp3",
            accent: .pink
        ),
        .init(
            id: "money",
            title: "Money Mantra",
            subtitle: "Prosperity mindset with intentional action",
            fileName: "moneyMantra.mp3",
            accent: .green
        ),
        .init(
            id: "success",
            title: "Success Mantra",
            subtitle: "Confidence, progress, and follow-through",
            fileName: "successMantra.mp3",
            accent: .orange
        ),
        .init(
            id: "wellbeing-happiness",
            title: "Wellbeing + Happiness",
            subtitle: "A bright, grounded daily reset",
            fileName: "healthAndHappinessMantra.mp3",
            accent: .teal
        )
    ]
}

extension GuidedRitual {
    static func manifestationRitual(
        affirmation: ManifestationAffirmation,
        minutes: Int = 3
    ) -> GuidedRitual {
        let duration = max(3, minutes)
        return GuidedRitual(
            id: "manifestation-\(affirmation.id)",
            title: "\(affirmation.theme.title) Manifestation",
            module: .manifestation,
            subtitle: "Affirmation, visualization, and one aligned action",
            intent: .manifestation,
            audioKind: .binaural(left: 400, right: 410),
            duration: TimeInterval(duration * 60),
            accent: affirmation.theme.accent,
            steps: [
                .init(id: "settle", startTime: 0, title: "Arrive", spokenPrompt: "Settle into the sound. Let your breath become easy and unforced.", visualKind: .breathOrb, duration: 45),
                .init(id: "affirm", startTime: 15, title: "Speak the intention", spokenPrompt: affirmation.text, visualKind: .pattern, duration: 60),
                .init(id: "embody", startTime: 75, title: "Rehearse the feeling", spokenPrompt: "Imagine this intention as a normal part of your life. Notice your posture, breath, and choices.", visualKind: .energyField, duration: 55),
                .init(id: "action", startTime: 135, title: "Choose one action", spokenPrompt: affirmation.reflectionPrompt, visualKind: .grounding, duration: 30),
                .init(id: "return", startTime: 165, title: "Return", spokenPrompt: "Bring your attention back to the room. Carry the next clear action with you.", visualKind: .grounding, duration: 15)
            ],
            journalPrompts: [affirmation.reflectionPrompt, "What feeling did you rehearse?"],
            safeDisclaimer: "A reflective visualization ritual. It does not guarantee a particular outcome.",
            summary: affirmation.text,
            codeSequence: []
        )
    }
}
