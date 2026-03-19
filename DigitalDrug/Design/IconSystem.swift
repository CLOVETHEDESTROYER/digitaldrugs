//
//  IconSystem.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

/// Icon system mapping brainwave types to SF Symbols
enum BrainwaveIcon {
    case delta    // Deep Sleep
    case gamma    // Focus & Flow
    case theta    // Relaxation
    case beta     // Energy Boost
    
    var systemName: String {
        switch self {
        case .delta: return "moon.stars.fill"
        case .gamma: return "brain.head.profile"
        case .theta: return "water.waves"
        case .beta: return "sun.max.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .delta: return .purple
        case .gamma: return .cyan
        case .theta: return .blue
        case .beta: return .orange
        }
    }
}

/// Navigation icon system
enum NavigationIcon {
    case waves
    case chakra
    case volume
    case lotus
    case profile
    
    var systemName: String {
        switch self {
        case .waves: return "waveform"
        case .chakra: return "sparkles"
        case .volume: return "speaker.wave.3"
        case .lotus: return "sparkles"
        case .profile: return "person.fill"
        }
    }
}

/// Icon helper functions for consistent sizing and styling
extension Image {
    func brainwaveIcon(size: CGFloat = 32) -> some View {
        self
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
    }
    
    func navigationIcon(size: CGFloat = 24) -> some View {
        self
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
    }
}

