import AVFoundation
import CryptoKit

/// Pre-generated speech only: no network calls, credentials or system-voice fallback at runtime.
struct BreathVoicePack: Decodable {
    struct Clip: Decodable {
        let text: String
        let file: String
        let sha256: String
    }
    let schemaVersion: Int
    let provider: String
    let model: String
    let voice: String
    let aiGenerated: Bool
    let clips: [Clip]
    static var root: URL { StudioResources.root.appendingPathComponent("BreathVoice", isDirectory: true) }
    static let title: String = { (try? load().voice.capitalized).map { "OpenAI · \($0)" } ?? "OpenAI · Marin" }()
    static func load(from root: URL = Self.root) throws -> Self {
        let url = root.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudioError.message("The OpenAI breathing voice pack has not been generated. Run ContentStudio/Tools/generate-breath-voice.py with a locally configured OpenAI API key, then rebuild the studio. No Apple voice will be substituted.")
        }
        let pack = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard pack.schemaVersion == 1, pack.provider == "OpenAI", pack.aiGenerated,
              Set(pack.clips.map(\.text)).count == pack.clips.count else {
            throw StudioError.message("The breathing voice pack metadata is invalid. Regenerate the complete OpenAI pack.")
        }
        for clip in pack.clips {
            guard clip.file == URL(fileURLWithPath: clip.file).lastPathComponent, !clip.file.isEmpty, clip.file.hasSuffix(".wav") else {
                throw StudioError.message("The breathing voice pack contains an invalid audio filename.")
            }
            let data = try Data(contentsOf: root.appendingPathComponent(clip.file))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == clip.sha256 else { throw StudioError.message("A breathing voice file is missing or damaged. Regenerate the complete OpenAI pack.") }
        }
        return pack
    }
    func file(for text: String, root: URL = Self.root) throws -> URL {
        guard let clip = clips.first(where: { $0.text == text }) else {
            throw StudioError.message("The OpenAI voice pack is missing the cue “\(text)”. Regenerate the complete pack.")
        }
        return root.appendingPathComponent(clip.file)
    }
}
