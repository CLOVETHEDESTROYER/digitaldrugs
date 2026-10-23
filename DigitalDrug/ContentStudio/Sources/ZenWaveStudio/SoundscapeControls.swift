import SwiftUI

struct SoundscapeControls: View {
    @Binding var soundscape: StudioSoundscape
    var showBeatLevel = false
    var showNatureLevel = false
    var showChakraLevel = false
    var body: some View {
        GroupBox("BACKGROUND SOUND LAYERS") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Binaural beat", selection: $soundscape.beat) {
                    ForEach(StudioBeat.allCases) { Text($0.title).tag($0) }
                }
                if soundscape.beat != .off {
                    Text("Left \(Int(soundscape.beat.left)) Hz · Right \(Int(soundscape.beat.left + soundscape.beat.difference)) Hz")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if soundscape.beat != .off || showBeatLevel { level("Beat level", value: $soundscape.beatVolume, maximum: 0.25) }
                Picker("Nature sound", selection: $soundscape.natureID) {
                    Text("None").tag(Optional<String>.none)
                    ForEach(StudioNature.all) { Text($0.title).tag(Optional($0.id)) }
                }
                if soundscape.natureID != nil || showNatureLevel { level("Nature level", value: $soundscape.natureVolume, maximum: 0.6) }
                ChakraControls(layer: $soundscape.chakra, showLevel: showChakraLevel)
                Text("Optional layers beneath the voice, alongside any imported music. Visuals follow these background layers; the mantra does not affect movement. Nature loops with crossfades. Layers share headroom to keep the voice clear. Stereo headphones preserve the separate left/right tones.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(8)
        }
    }
    private func level(_ label: String, value: Binding<Double>, maximum: Double) -> some View {
        VStack(spacing: 5) {
            HStack { Text(label); Spacer(); Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))) }.font(.caption)
            Slider(value: value, in: 0...maximum).accessibilityLabel(label)
        }
    }
}
