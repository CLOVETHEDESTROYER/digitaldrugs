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

