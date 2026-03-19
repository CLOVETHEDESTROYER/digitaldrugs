//
//  LiquidGlassStyle.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25. 
//

import SwiftUI

/// Shared helpers for Apple's Liquid Glass design language (iOS 18+).
/// References:
/// - https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
/// - https://developer.apple.com/documentation/technologyoverviews/liquid-glass

// MARK: - Aurora Background
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        ZStack {
            auroraGradient
            lightStreaks
            blurLayer
        }
        .clipped()
    }
    
    private var auroraGradient: some View {
        // Deep indigo/purple to lighter blue/teal/pink gradient
        let gradient = Gradient(colors: [
            Color(red: 0.15, green: 0.10, blue: 0.25), // Deep indigo/purple
            Color(red: 0.20, green: 0.15, blue: 0.35), // Medium purple
            Color(red: 0.12, green: 0.25, blue: 0.40), // Deep blue
            Color(red: 0.15, green: 0.35, blue: 0.45), // Teal
            Color(red: 0.25, green: 0.30, blue: 0.50), // Lighter blue
            Color(red: 0.35, green: 0.25, blue: 0.45)  // Pink/teal blend
        ])
        
        return LinearGradient(
            gradient: gradient,
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
    
    private var lightStreaks: some View {
        // Soft light streaks from top-right
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.15),
                    Color.cyan.opacity(0.10),
                    Color.pink.opacity(0.05),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.85, y: 0.15),
                startRadius: 50,
                endRadius: 600
            )
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var blurLayer: some View {
        if !reduceTransparency {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.02))
                )
        }
    }
}

// MARK: - Legacy Background (for compatibility)
struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        AuroraBackground()
    }
}

// MARK: - Particle Texture
struct ParticleTexture: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let tileSize: CGFloat = 500
                let numTilesX = Int(ceil(size.width / tileSize)) + 1
                let numTilesY = Int(ceil(size.height / tileSize)) + 1
                
                // Generate particles for each tile
                for tileY in 0..<numTilesY {
                    for tileX in 0..<numTilesX {
                        let offsetX = CGFloat(tileX) * tileSize
                        let offsetY = CGFloat(tileY) * tileSize
                        
                        // Generate random particles within this tile (using deterministic seed per tile)
                        let seed = UInt64(tileX * 1000 + tileY)
                        var generator = SeededRandomGenerator(seed: seed)
                        
                        for _ in 0..<15 {
                            let x = offsetX + generator.next(in: 0..<tileSize)
                            let y = offsetY + generator.next(in: 0..<tileSize)
                            let radius = generator.next(in: 0.5...2.5)
                            let opacity = generator.next(in: 0.1...0.4)
                            
                            // Mix of white and gold tones
                            let isGold = generator.next(in: 0...1) < 0.3
                            let color = isGold 
                                ? Color(red: 1.0, green: 0.85, blue: 0.5, opacity: opacity)
                                : Color.white.opacity(opacity)
                            
                            var path = Path()
                            path.addEllipse(in: CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: radius * 2,
                                height: radius * 2
                            ))
                            context.fill(path, with: .color(color))
                        }
                    }
                }
            }
        }
    }
}

// Simple seeded random generator for consistent particle patterns
struct SeededRandomGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next<T: BinaryFloatingPoint>(in range: Range<T>) -> T where T.RawSignificand: FixedWidthInteger {
        state = state &* 1103515245 &+ 12345
        let normalized = Double(state & 0x7FFFFFFF) / Double(0x7FFFFFFF)
        return T(normalized) * (range.upperBound - range.lowerBound) + range.lowerBound
    }
    
    mutating func next<T: BinaryFloatingPoint>(in range: ClosedRange<T>) -> T where T.RawSignificand: FixedWidthInteger {
        state = state &* 1103515245 &+ 12345
        let normalized = Double(state & 0x7FFFFFFF) / Double(0x7FFFFFFF)
        return T(normalized) * (range.upperBound - range.lowerBound) + range.lowerBound
    }
}

struct LiquidGlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content
    private let cornerRadius: CGFloat
    private let showParticles: Bool
    
    init(cornerRadius: CGFloat = 34, showParticles: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.showParticles = showParticles
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                // Inner border: 1pt white, 20% opacity, inside alignment
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(reduceTransparency ? 0 : 0.20), lineWidth: 1)
            )
            .overlay(
                // Inner shadow/glow: White, Y: 0, Blur: 20, Spread: 0, Opacity: 15%
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(reduceTransparency ? 0 : 0.15),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: cornerRadius * 2
                        )
                    )
                    .blur(radius: 20)
                    .blendMode(.screen)
            )
            .shadow(
                // Drop shadow: Cyan/Purple tinted, Y: 10, Blur: 30, Opacity: 20%
                color: Color.cyan.opacity(reduceTransparency ? 0.1 : 0.20),
                radius: 30,
                x: 0,
                y: 10
            )
            .overlay(
                // Particle texture overlay
                Group {
                    if showParticles && !reduceTransparency {
                        ParticleTexture()
                            .blendMode(.overlay)
                            .opacity(0.3)
                    }
                }
            )
    }
    
    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
        }
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(Capsule(style: .continuous))
            .foregroundStyle(Color.primary)
            .shadow(color: Color.black.opacity(0.15), radius: configuration.isPressed ? 6 : 14, y: 10)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }
    
    private func background(isPressed: Bool) -> some View {
        let gradient = LinearGradient(
            colors: [
                Color.white.opacity(isPressed ? 0.55 : 0.75),
                Color.white.opacity(isPressed ? 0.25 : 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return gradient
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - Typography System
struct LiquidGlassTypography {
    static let headline: Font = .system(size: 34, weight: .bold, design: .rounded)
    static let cardTitle: Font = .system(size: 17, weight: .semibold, design: .rounded)
    static let cardSubtitle: Font = .system(size: 15, weight: .regular, design: .rounded)
    static let playLabel: Font = .system(size: 17, weight: .medium, design: .rounded)
}

// MARK: - Radial Glow Effect
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

// MARK: - Icon System
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

enum NavigationIcon {
    case waves
    case volume
    case lotus
    case profile
    
    var systemName: String {
        switch self {
        case .waves: return "waveform"
        case .volume: return "speaker.wave.3"
        case .lotus: return "sparkles"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Equalizer Visualizer
struct EqualizerBarsView: View {
    let lowGain: Float
    let midGain: Float
    let highGain: Float
    
    private let minGain: Float = -12.0
    private let maxGain: Float = 12.0
    
    var body: some View {
        HStack(spacing: 24) {
            bar(title: "Low", gain: lowGain, color: .blue)
            bar(title: "Mid", gain: midGain, color: .cyan)
            bar(title: "High", gain: highGain, color: .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private func bar(title: String, gain: Float, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 18, height: 62)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.35), color],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 18, height: normalizedHeight(for: gain))
                    .animation(.easeInOut(duration: 0.15), value: gain)
            }
            
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
    
    private func normalizedHeight(for gain: Float) -> CGFloat {
        let clamped = min(max(gain, minGain), maxGain)
        let normalized = (clamped - minGain) / (maxGain - minGain)
        return CGFloat(14 + normalized * 48)
    }
}

// MARK: - View Extensions
extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 34, showParticles: Bool = false) -> some View {
        LiquidGlassCard(cornerRadius: cornerRadius, showParticles: showParticles) { self }
    }
    
    func liquidGlassButtonStyle() -> some View {
        buttonStyle(LiquidGlassButtonStyle())
    }
}

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


