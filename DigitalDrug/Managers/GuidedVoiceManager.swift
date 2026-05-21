//
//  GuidedVoiceManager.swift
//  DigitalDrug
//

import AVFoundation
import SwiftUI

struct GuidedVoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    
    var isSystemDefault: Bool {
        id == GuidedVoiceManager.systemDefaultVoiceID
    }
}

enum GuidedVoiceProfile: String, CaseIterable, Identifiable {
    case softGuide
    case deepCalm
    case brightClear
    case oracle
    case system
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .softGuide: return "Soft Guide"
        case .deepCalm: return "Deep Calm"
        case .brightClear: return "Bright Clear"
        case .oracle: return "Oracle"
        case .system: return "Natural"
        }
    }
    
    var subtitle: String {
        switch self {
        case .softGuide: return "Warm, slow, and gentle"
        case .deepCalm: return "Lower pitch for sleep and grounding"
        case .brightClear: return "Clearer for focus and codes"
        case .oracle: return "Slow mystical cadence"
        case .system: return "Closest to the selected system voice"
        }
    }
    
    var iconName: String {
        switch self {
        case .softGuide: return "moon.stars.fill"
        case .deepCalm: return "water.waves"
        case .brightClear: return "sun.max.fill"
        case .oracle: return "sparkles"
        case .system: return "speaker.wave.2.fill"
        }
    }
    
    var rateOffset: Double {
        switch self {
        case .softGuide: return -0.03
        case .deepCalm: return -0.06
        case .brightClear: return 0.02
        case .oracle: return -0.08
        case .system: return 0
        }
    }
    
    var pitchMultiplier: Double {
        switch self {
        case .softGuide: return 0.96
        case .deepCalm: return 0.82
        case .brightClear: return 1.02
        case .oracle: return 0.9
        case .system: return 0.94
        }
    }
    
    static func fromStoredValue(_ value: String) -> GuidedVoiceProfile {
        GuidedVoiceProfile(rawValue: value) ?? .softGuide
    }
}

@MainActor
final class GuidedVoiceManager: NSObject, ObservableObject {
    nonisolated static let systemDefaultVoiceID = "zenwave.system.default.voice"
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @AppStorage("guidedVoiceEnabled") var isVoiceEnabled = true
    @AppStorage("guidedVoiceRate") var rate = 0.44
    @AppStorage("guidedVoiceVolume") var volume = 0.85
    @AppStorage("guidedVoiceIdentifier") var selectedVoiceIdentifier = GuidedVoiceManager.systemDefaultVoiceID
    @AppStorage("guidedVoiceProfile") var selectedProfileRawValue = GuidedVoiceProfile.softGuide.rawValue
    
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    var selectedProfile: GuidedVoiceProfile {
        get { GuidedVoiceProfile.fromStoredValue(selectedProfileRawValue) }
        set { selectedProfileRawValue = newValue.rawValue }
    }
    
    var selectedVoiceName: String {
        Self.availableVoiceOptions()
            .first { $0.id == selectedVoiceIdentifier }?
            .name ?? "System Default"
    }
    
    static func availableVoiceOptions() -> [GuidedVoiceOption] {
        let defaultOption = GuidedVoiceOption(
            id: systemDefaultVoiceID,
            name: "System Default",
            detail: "Best available English voice"
        )
        
        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("en") }
            .sorted { left, right in
                if left.quality != right.quality {
                    return left.quality.sortRank > right.quality.sortRank
                }
                if left.language != right.language {
                    return left.language < right.language
                }
                return left.name < right.name
            }
            .map { voice in
                GuidedVoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    detail: "\(voice.language) · \(voice.quality.displayName)"
                )
            }
        
        var seen = Set<String>()
        let uniqueVoices = englishVoices.filter { option in
            seen.insert(option.id).inserted
        }
        
        return [defaultOption] + uniqueVoices
    }
    
    func speak(
        _ text: String,
        module: GuidedRitualModule? = nil,
        intent: RitualIntent? = nil,
        isCodePrompt: Bool = false
    ) {
        guard isVoiceEnabled else {
            AppLog.info("GuidedVoice speak skipped because voice is disabled")
            return
        }
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        AppLog.info("GuidedVoice speak requested: \(cleanText), voice=\(selectedVoiceName), profile=\(selectedProfile.title)")
        
        synthesizer.stopSpeaking(at: .immediate)
        
        let speechText = isCodePrompt ? cleanText.withMeditativePauses : cleanText
        let utterance = AVSpeechUtterance(string: speechText)
        let style = speechStyle(module: module, intent: intent, isCodePrompt: isCodePrompt)
        utterance.rate = Float(style.rate)
        utterance.volume = Float(volume)
        utterance.pitchMultiplier = Float(style.pitch)
        utterance.preUtteranceDelay = style.preDelay
        utterance.postUtteranceDelay = style.postDelay
        
        if let voice = resolvedVoice() {
            utterance.voice = voice
        }
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func previewSelectedVoice() {
        let sample: String
        switch selectedProfile {
        case .softGuide:
            sample = "Settle in. Let the sound become the edge of your attention."
        case .deepCalm:
            sample = "Let the body become heavier, calmer, and fully supported."
        case .brightClear:
            sample = "Choose one clear intention. Keep it simple and steady."
        case .oracle:
            sample = "The code is one two, five seven, nine zero one. Let each number land slowly."
        case .system:
            sample = "This is the selected ZenWave guided voice."
        }
        speak(sample, module: .gateway, intent: .meditate, isCodePrompt: selectedProfile == .oracle)
    }
    
    func stop() {
        AppLog.info("GuidedVoice stop requested")
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if selectedVoiceIdentifier != Self.systemDefaultVoiceID,
           let selectedVoice = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier) {
            return selectedVoice
        }
        
        return AVSpeechSynthesisVoice(language: "en-US")
    }
    
    private func speechStyle(
        module: GuidedRitualModule?,
        intent: RitualIntent?,
        isCodePrompt: Bool
    ) -> (rate: Double, pitch: Double, preDelay: Double, postDelay: Double) {
        var finalRate = rate + selectedProfile.rateOffset
        var finalPitch = selectedProfile.pitchMultiplier
        var postDelay = 0.24
        
        if isCodePrompt || module == .quantumCodes {
            finalRate -= 0.06
            finalPitch -= 0.02
            postDelay = 0.45
        }
        
        switch intent {
        case .sleep:
            finalRate -= 0.05
            finalPitch -= 0.04
        case .astral, .manifestation:
            finalRate -= 0.03
        case .focus:
            finalRate += 0.02
            finalPitch += 0.02
        case .chakra, .meditate, .none:
            break
        }
        
        return (
            rate: finalRate.clamped(to: 0.28...0.58),
            pitch: finalPitch.clamped(to: 0.76...1.08),
            preDelay: 0.06,
            postDelay: postDelay
        )
    }
}

extension GuidedVoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            AppLog.info("GuidedVoice finished utterance")
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            AppLog.info("GuidedVoice cancelled utterance")
        }
    }
}

private extension AVSpeechSynthesisVoiceQuality {
    var displayName: String {
        switch self {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        case .default: return "Default"
        @unknown default: return "Available"
        }
    }
    
    var sortRank: Int {
        switch self {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension String {
    var withMeditativePauses: String {
        replacingOccurrences(of: " ... ", with: ", ")
            .replacingOccurrences(of: "...", with: ", ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
