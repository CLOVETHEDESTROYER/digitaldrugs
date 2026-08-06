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
                    Spacer(minLength: 28)

                    VStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.cyan)
                        Text("Welcome to ZenWave")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Choose a starting focus. You can explore everything else later.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)

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

                Label("Headphones are recommended for binaural sessions.", systemImage: "headphones")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))

                Button {
                    selectedRitualIntent = selectedIntent.rawValue
                    hasSeenOnboarding = true
                } label: {
                    Text("Start With \(selectedIntent.shortTitle)")
                        .frame(maxWidth: .infinity)
                }
                .liquidGlassButtonStyle()
                .padding(.horizontal, 24)

                    Spacer(minLength: 20)
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
