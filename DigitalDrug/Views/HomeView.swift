//
//  HomeView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct HomeView: View {
    let sessions = [
        ("Deep Sleep Inducer", "lucid_dream.mp3", "rain.wav", "Experience deep, restorative sleep with our Delta wave sound, designed to promote healing and rejuvenation."),
        ("Meditative Mind", "hangover_cure.mp3", "forest.wav", "Dive into deep relaxation and unlock your creativity with our Theta wave sound, perfect for meditation and stress relief."),
        ("Calm Focus", "alpha_wave.mp3", "stream.wav", "Achieve a state of relaxed alertness with our Alpha wave sound, ideal for enhancing focus and mindfulness."),
        ("Productivity Booster", "beta_wave.mp3", "wind.wav", "Boost your concentration and productivity with our Beta wave sound, designed to keep you alert and focused."),
        ("Cognitive Enhancer", "gamma_wave.mp3", "ocean.wav", "Elevate your cognitive abilities and achieve peak mental performance with our Gamma wave sound.")
    ]

    var body: some View {
        NavigationView {
            List(sessions, id: \.0) { session in
                NavigationLink(destination: SessionView(
                    binauralFile: session.1,
                    natureFile: session.2,
                    sessionDescription: session.3
                ))  {
                    VStack(alignment: .leading) {
                        Text(session.0) // Session name
                            .font(.headline)
                        Text(session.2) // Session description
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("DigitalDrug Sessions")
        }
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
