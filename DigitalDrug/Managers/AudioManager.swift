//
//  AudioManager.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import AVFoundation
import SwiftUI

class AudioManager: ObservableObject {
    private var player: AVAudioPlayer?
    private var naturePlayer: AVAudioPlayer?

    func playBinaural(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("Error: Binaural file '\(fileName)' not found in bundle!")
            // List available resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                print("Available audio files in bundle:")
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                    let audioFiles = files.filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") }
                    print(audioFiles)
                }
            }
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            print("Successfully playing binaural file: \(fileName)")
        } catch {
            print("Error playing binaural file: \(error.localizedDescription)")
        }
    }

    func playNature(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("Error: Nature sound file '\(fileName)' not found in bundle!")
            // List available resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                print("Available audio files in bundle:")
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                    let audioFiles = files.filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") }
                    print(audioFiles)
                }
            }
            return
        }
        do {
            naturePlayer = try AVAudioPlayer(contentsOf: url)
            naturePlayer?.prepareToPlay()
            naturePlayer?.play()
            print("Successfully playing nature sound: \(fileName)")
        } catch {
            print("Error playing nature sound: \(error.localizedDescription)")
        }
    }

    func stopNature() {
        naturePlayer?.stop()
    }

    func stopAll() {
        player?.stop()
        naturePlayer?.stop()
    }
    
    func stopBinaural() {
        player?.stop()
    }
}
