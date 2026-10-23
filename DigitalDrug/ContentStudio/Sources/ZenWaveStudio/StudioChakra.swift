import Foundation
import CoreGraphics

struct StudioChakra: Identifiable {
    let id: String
    let title: String
    let frequency: Int
    let file: String
    let petals: Int
    let cadence: Double
    let rgb: [CGFloat]
    var color: CGColor { CGColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1) }
    var label: String { "\(title) · \(frequency) Hz" }
    var recordingURL: URL { StudioResources.root.appendingPathComponent("Chakra/\(file).m4a") }
    var loopURL: URL { StudioResources.root.appendingPathComponent("Chakra/ColumnLoops/\(file)_column_10s.wav") }
    static let all: [Self] = [
        .init(id: "root", title: "Root", frequency: 396, file: "root_chakra", petals: 4, cadence: 8, rgb: [1, 0.32, 0.43]),
        .init(id: "sacral", title: "Sacral", frequency: 417, file: "sacral_417", petals: 6, cadence: 9, rgb: [1, 0.56, 0.22]),
        .init(id: "solar", title: "Solar Plexus", frequency: 528, file: "solar_plexus_528", petals: 10, cadence: 8, rgb: [1, 0.83, 0.30]),
        .init(id: "heart", title: "Heart", frequency: 639, file: "heart_639", petals: 12, cadence: 10, rgb: [0.32, 0.90, 0.57]),
        .init(id: "throat", title: "Throat", frequency: 741, file: "throat_741", petals: 16, cadence: 8, rgb: [0.35, 0.75, 1]),
        .init(id: "thirdEye", title: "Third Eye", frequency: 852, file: "third_eye_852", petals: 2, cadence: 12, rgb: [0.62, 0.51, 1]),
        .init(id: "crown", title: "Crown", frequency: 963, file: "crown_963", petals: 24, cadence: 12, rgb: [0.82, 0.61, 1])
    ]
    static let randomIDs = all.map(\.id) + ["column"]
    static func randomTitle(_ id: String) -> String { id == "column" ? "Full chakra column" : all.first { $0.id == id }?.label ?? id }
}

enum StudioChakraMode: String, Codable, CaseIterable, Identifiable {
    case recordings, loops, column
    var id: String { rawValue }
    var title: String { switch self {
    case .recordings: "Original recordings"
    case .loops: "Synchronized 10-second loops"
    case .column: "Build column · root to crown"
    } }
}

struct StudioChakraLayer: Codable, Equatable {
    var selected: Set<String> = []
    var mode: StudioChakraMode = .loops
    var volume = 0.18
    var step = 10.0
    var ordered: [StudioChakra] { StudioChakra.all.filter { selected.contains($0.id) } }
    var active: Bool { !selected.isEmpty && volume > 0 }
    var signature: String { selected.isEmpty ? "none" : "\(mode.rawValue):\(selected.sorted().joined(separator: "+")):sequence\(mode == .column ? step : 0)" }
    var randomID: String? { mode == .column && selected == Set(StudioChakra.all.map(\.id)) ? "column" : selected.count == 1 ? selected.first : nil }
    var summary: String { selected.isEmpty ? "" : mode == .column ? "Chakra column · \(ordered.count) layers" : ordered.map(\.title).joined(separator: " + ") + " chakra" }
    func activeIDs(at time: Double) -> Set<String> {
        Set(ordered.enumerated().filter { mode != .column || time >= Double($0.offset) * step }.map { $0.element.id })
    }
    func randomized(_ id: String) -> Self {
        var next = self
        next.selected = id == "column" ? Set(StudioChakra.all.map(\.id)) : [id]
        if id == "column" { next.mode = .column }
        else if next.mode == .column { next.mode = .loops }
        return next
    }
    func validate() throws {
        guard selected.isSubset(of: Set(StudioChakra.all.map(\.id))), volume.isFinite, (0...0.6).contains(volume), step.isFinite, (5...60).contains(step) else {
            throw StudioError.message("Choose bundled chakra sounds, a level up to 60%, and a column step of 5–60 seconds.")
        }
    }
}
