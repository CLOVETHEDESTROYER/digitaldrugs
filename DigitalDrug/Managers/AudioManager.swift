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
            print("Error: Binaural file not found!")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Error playing binaural file: \(error.localizedDescription)")
        }
    }

    func playNature(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("Error: Nature sound file not found!")
            return
        }
        do {
            naturePlayer = try AVAudioPlayer(contentsOf: url)
            naturePlayer?.prepareToPlay()
            naturePlayer?.play()
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
