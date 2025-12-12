//
//  RadialGlow.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

/// Programmatic radial glow effect
/// Used behind the central play button to create a strong central light source
struct RadialGlowEffect: View {
    var center: UnitPoint = .center
    var radius: CGFloat = 200
    var opacity: Double = 0.30
    
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(opacity),
                Color.white.opacity(opacity * 0.5),
                Color.clear
            ]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

