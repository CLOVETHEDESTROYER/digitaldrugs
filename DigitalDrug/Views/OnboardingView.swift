import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("selectedRitualIntent") private var selectedRitualIntent = RitualIntent.meditate.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePulse = false
    @State private var selectedIntent: RitualIntent = .meditate
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                Spacer()
                
                LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 160, height: 160)
                                .scaleEffect(animatePulse ? 1.08 : 0.92)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: animatePulse)
                            
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 62, weight: .thin))
                                .foregroundStyle(.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 18, y: 10)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 10) {
                            Text("Welcome to ZenWave")
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("Choose the state you want to practice first. ZenWave will recommend a DigitalDrugz-style ritual to start with.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 12)
                }
                
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What are you here for?")
                            .font(.title3.weight(.semibold))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(RitualIntent.allCases) { intent in
                                Button {
                                    selectedIntent = intent
                                    selectedRitualIntent = intent.rawValue
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: intent.iconName)
                                            .font(.title2)
                                        Text(intent.title)
                                            .font(.caption.weight(.semibold))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 86)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(selectedIntent == intent ? intent.color.opacity(0.36) : Color.white.opacity(0.10))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .strokeBorder(selectedIntent == intent ? intent.color.opacity(0.75) : Color.white.opacity(0.12))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wear headphones")
                                    .font(.headline)
                                Text("Binaural states work best when left and right channels stay distinct.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "headphones")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                        
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Set an intention")
                                    .font(.headline)
                                Text("Pick sleep, focus, meditation, visualization, chakras, or astral prep before starting.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "target")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                        
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keep claims grounded")
                                    .font(.headline)
                                Text("Use ZenWave as a ritual tool for reflection, not a guarantee of outcomes.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                    }
                }
                
                Button {
                    selectedRitualIntent = selectedIntent.rawValue
                    hasSeenOnboarding = true
                } label: {
                    Text("Start With \(selectedIntent.shortTitle)")
                        .frame(maxWidth: .infinity)
                }
                .liquidGlassButtonStyle()
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.vertical, 32)
            .padding(.top, 24)
            }
        }
        .onAppear {
            selectedIntent = RitualIntent(rawValue: selectedRitualIntent) ?? .meditate
            guard !reduceMotion else { return }
            animatePulse = true
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
