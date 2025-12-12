//
//  NatureSoundsManager.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import Foundation
import SwiftUI

class NatureSoundsManager: ObservableObject {
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadedSounds: Set<String> = []
    
    private let documentsDirectory: URL
    private let soundsDirectory: URL
    private let supabaseManager: SupabaseManager
    
    init() {
        // Get Documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        soundsDirectory = documentsDirectory.appendingPathComponent("NatureSounds", isDirectory: true)
        
        // Create sounds directory if it doesn't exist
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        
        // Initialize Supabase manager
        supabaseManager = SupabaseManager()
        
        // Load list of downloaded sounds
        loadDownloadedSounds()
    }
    
    // MARK: - Get Available Sounds
    
    func getAvailableSounds() -> [NatureSound] {
        var sounds: [NatureSound] = []
        
        // Add local sounds from bundle
        sounds.append(contentsOf: NatureSound.localSounds)
        
        // Add downloaded sounds (will be populated from Supabase later)
        // For now, just return local sounds
        
        return sounds
    }
    
    // MARK: - Download Management
    
    func isSoundDownloaded(_ sound: NatureSound) -> Bool {
        if sound.isLocal {
            return true
        }
        return downloadedSounds.contains(sound.id)
    }
    
    func getLocalPath(for sound: NatureSound) -> URL? {
        if sound.isLocal {
            // Try to find in bundle
            return Bundle.main.url(
                forResource: sound.fileName,
                withExtension: sound.fileExtension
            )
        } else {
            // Check downloaded files
            let localFile = soundsDirectory.appendingPathComponent("\(sound.id).\(sound.fileExtension)")
            if FileManager.default.fileExists(atPath: localFile.path) {
                return localFile
            }
        }
        return nil
    }
    
    func downloadSound(_ sound: NatureSound) async throws {
        guard !sound.isLocal, let supabasePath = sound.supabasePath else {
            throw NatureSoundError.invalidSound
        }
        
        // Check if already downloaded
        if isSoundDownloaded(sound) {
            return
        }
        
        // Set up local file path
        let localFile = soundsDirectory.appendingPathComponent("\(sound.id).\(sound.fileExtension)")
        
        // Start download
        downloadProgress[sound.id] = 0.0
        
        do {
            // Download from Supabase
            try await supabaseManager.downloadAudioFile(from: supabasePath, to: localFile)
            
            // Mark as downloaded
            downloadProgress[sound.id] = nil
            downloadedSounds.insert(sound.id)
            saveDownloadedSounds()
        } catch {
            downloadProgress[sound.id] = nil
            // Clean up partial download
            try? FileManager.default.removeItem(at: localFile)
            throw NatureSoundError.downloadFailed
        }
    }
    
    // MARK: - Persistence
    
    private func loadDownloadedSounds() {
        let fileURL = documentsDirectory.appendingPathComponent("downloaded_sounds.json")
        guard let data = try? Data(contentsOf: fileURL),
              let sounds = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return
        }
        downloadedSounds = sounds
    }
    
    private func saveDownloadedSounds() {
        let fileURL = documentsDirectory.appendingPathComponent("downloaded_sounds.json")
        guard let data = try? JSONEncoder().encode(downloadedSounds) else {
            return
        }
        try? data.write(to: fileURL)
    }
}

// MARK: - Errors

enum NatureSoundError: Error {
    case invalidSound
    case downloadFailed
    case fileNotFound
}

