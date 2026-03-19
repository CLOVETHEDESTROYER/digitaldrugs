import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePulse = false
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
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
                            Text("Welcome to DigitalDrug")
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("Craft immersive binaural journeys with Liquid Glass depth, translucency, and calm motion.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 12)
                }
                
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wear headphones")
                                    .font(.headline)
                                Text("Liquid Glass clarity shines when channels are kept distinct.")
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
                                Text("Choose focus, flow, or rest before starting a session.")
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
                                Text("Stay hydrated")
                                    .font(.headline)
                                Text("Pair longer sessions with water for best clarity.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "drop.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                    }
                }
                
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .liquidGlassButtonStyle()
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.vertical, 32)
            .padding(.top, 24)
        }
        .onAppear {
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

