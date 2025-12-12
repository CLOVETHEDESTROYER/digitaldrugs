//
//  ParticleEffect.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

/// Programmatic particle texture generator for glass cards
/// Creates soft white/gold dots with varying opacity in a tiled pattern
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
