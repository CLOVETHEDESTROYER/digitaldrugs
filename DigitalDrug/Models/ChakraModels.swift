//
//  ChakraModels.swift
//  DigitalDrug
//

import SwiftUI

struct ChakraTone: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let chakraName: String
    let commentTag: String
    let frequency: Double
    let meaning: String
    let blockedCopy: String
    let recommendedUse: String
    let color: Color
    let bellTimbre: ToneGenerator.ChakraBellTimbre
    let audioFileName: String
}

extension ChakraTone {
    static let allChakras: [ChakraTone] = [
        ChakraTone(
            name: "Root Chakra",
            chakraName: "Muladhara",
            commentTag: "root",
            frequency: 396,
            meaning: "Grounding, safety, and clearing fear.",
            blockedCopy: "When it feels blocked: bracing, survival stress, money fear, or never feeling settled.",
            recommendedUse: "Use 396 Hz when you want a low, steady ritual for grounding.",
            color: .red,
            bellTimbre: .init(ringDuration: 3.4, loopInterval: 4.8, brightness: 0.22, decayScale: 1.35, warmth: 0.88),
            audioFileName: "root_chakra.m4a"
        ),
        ChakraTone(
            name: "Sacral Chakra",
            chakraName: "Swadhisthana",
            commentTag: "sacral",
            frequency: 417,
            meaning: "Creativity, emotional balance, and change.",
            blockedCopy: "When it feels blocked: emotional numbness, guilt around pleasure, or creative stagnation.",
            recommendedUse: "Use 417 Hz before journaling, stretching, or creative work.",
            color: .orange,
            bellTimbre: .init(ringDuration: 3.1, loopInterval: 4.4, brightness: 0.38, decayScale: 1.20, warmth: 0.72),
            audioFileName: "sacral_417.m4a"
        ),
        ChakraTone(
            name: "Solar Plexus Chakra",
            chakraName: "Manipura",
            commentTag: "solar",
            frequency: 528,
            meaning: "Personal power, confidence, and transformation.",
            blockedCopy: "When it feels blocked: procrastination, people-pleasing, self-doubt, or low direction.",
            recommendedUse: "Use 528 Hz before one small action that rebuilds self-trust.",
            color: .yellow,
            bellTimbre: .init(ringDuration: 2.8, loopInterval: 4.0, brightness: 0.62, decayScale: 1.05, warmth: 0.54),
            audioFileName: "solar_plexus_528.m4a"
        ),
        ChakraTone(
            name: "Heart Chakra",
            chakraName: "Anahata",
            commentTag: "heart",
            frequency: 639,
            meaning: "Love, relationships, and compassion.",
            blockedCopy: "When it feels blocked: guardedness, resentment, over-giving, or difficulty receiving.",
            recommendedUse: "Use 639 Hz when practicing boundaries, compassion, or emotional balance.",
            color: .green,
            bellTimbre: .init(ringDuration: 3.5, loopInterval: 5.0, brightness: 0.44, decayScale: 1.42, warmth: 0.66),
            audioFileName: "heart_639.m4a"
        ),
        ChakraTone(
            name: "Throat Chakra",
            chakraName: "Vishuddha",
            commentTag: "throat",
            frequency: 741,
            meaning: "Communication, expression, and truth.",
            blockedCopy: "When it feels blocked: over-explaining, holding back, or saying yes when you mean no.",
            recommendedUse: "Use 741 Hz before a clear conversation or voice-note journal.",
            color: .blue,
            bellTimbre: .init(ringDuration: 2.6, loopInterval: 3.8, brightness: 0.72, decayScale: 0.95, warmth: 0.38),
            audioFileName: "throat_741.m4a"
        ),
        ChakraTone(
            name: "Third Eye Chakra",
            chakraName: "Ajna",
            commentTag: "third eye",
            frequency: 852,
            meaning: "Intuition, insight, and spiritual awakening.",
            blockedCopy: "When it feels blocked: overthinking, mental fog, ignoring signals, or needing reassurance.",
            recommendedUse: "Use 852 Hz when you want stillness before reflection.",
            color: .indigo,
            bellTimbre: .init(ringDuration: 3.0, loopInterval: 4.2, brightness: 0.84, decayScale: 1.18, warmth: 0.30),
            audioFileName: "third_eye_852.m4a"
        ),
        ChakraTone(
            name: "Crown Chakra",
            chakraName: "Sahasrara",
            commentTag: "crown",
            frequency: 963,
            meaning: "Higher consciousness, enlightenment, and connection.",
            blockedCopy: "When it feels blocked: control loops, cynicism, disconnection, or spiritual curiosity without grounding.",
            recommendedUse: "Use 963 Hz as a spacious meditation ritual, not something to force.",
            color: .purple,
            bellTimbre: .init(ringDuration: 3.6, loopInterval: 5.1, brightness: 0.94, decayScale: 1.46, warmth: 0.26),
            audioFileName: "crown_963.m4a"
        )
    ]
}
