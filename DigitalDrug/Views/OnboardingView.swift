//
//  OnboardingView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to DigitalDrug!")
                .font(.largeTitle)
                .padding()

            Text("""
                DigitalDrug uses binaural beats and nature sounds to enhance your relaxation, focus, and more.
                Use headphones for the best experience.
            """)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Get Started") {
                hasSeenOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
