//
//  VideoBackground.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI
import AVFoundation
import AVKit

/// Video background component that plays a looping video file
struct VideoBackgroundView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        
        // Find video file in bundle
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            print("VideoBackground: Could not find \(videoName).\(videoExtension) in bundle")
            print("VideoBackground: Available bundle resources: \(Bundle.main.paths(forResourcesOfType: videoExtension, inDirectory: nil))")
            return view
        }
        
        print("VideoBackground: Found video at \(url.path)")
        
        // Create player
        let player = AVPlayer(url: url)
        player.isMuted = true // Background video should be silent
        player.actionAtItemEnd = .none // Prevent pause at end
        
        // Create player layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        // Store player in context
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        
        // Set up looping
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        // Start playing
        player.play()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update layer frame if view size changes
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        
        @objc func playerItemDidReachEnd(notification: Notification) {
            // Loop video by seeking to beginning
            if let player = player {
                player.seek(to: .zero)
                player.play()
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

