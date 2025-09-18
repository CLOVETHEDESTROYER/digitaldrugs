//
//  SessionView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct SessionView: View {
    @EnvironmentObject var audioManager: AudioManager

    let binauralFile: String
    let natureFile: String
    let sessionDescription: String

    @State private var isNatureEnabled = false
    @State private var progress: Double = 0.0
    @State private var isPlaying = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            // Session Title
            Text("Session: \(binauralFile)")
                .font(.title)
                .padding()

            // Session Description
            Text(sessionDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()

            // Progress Bar
            VStack {
                ProgressView(value: progress, total: 100)
                    .padding(.horizontal, 40)
                Text("Progress: \(Int(progress))%")
                    .font(.caption)
            }

            // Toggle for Nature Sounds
            Toggle("Enable Nature Sounds", isOn: $isNatureEnabled)
                .onChange(of: isNatureEnabled) { _, newValue in
                    if newValue {
                        audioManager.playNature(fileName: natureFile)
                    } else {
                        audioManager.stopNature()
                    }
                }
                .padding()

            Spacer()

            // Start and Stop Buttons
            HStack {
                Button(isPlaying ? "Pause Session" : "Start Session") {
                    if isPlaying {
                        pauseSession()
                    } else {
                        startSession()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Stop Session") {
                    stopSession()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    // MARK: - Session Controls
    private func startSession() {
        isPlaying = true
        audioManager.playBinaural(fileName: binauralFile)
        if isNatureEnabled {
            audioManager.playNature(fileName: natureFile)
        }
        startProgressTimer()
    }

    private func pauseSession() {
        isPlaying = false
        timer?.invalidate()
        audioManager.stopAll()
    }

    private func stopSession() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        progress = 0.0
        audioManager.stopAll()
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        timer?.invalidate() // Ensure no duplicate timers
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if progress < 100 {
                progress += 1
            } else {
                timer?.invalidate()
                isPlaying = false
                audioManager.stopAll()
            }
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(
            binauralFile: "delta_wave.mp3",
            natureFile: "rain.wav",
            sessionDescription: "Experience deep, restorative sleep with our Delta wave sound."
        )
        .environmentObject(AudioManager())
    }
}
