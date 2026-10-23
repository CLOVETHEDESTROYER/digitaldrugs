import SwiftUI

struct ChakraControls: View {
    @Binding var layer: StudioChakraLayer?
    var showLevel = false
    private var value: Binding<StudioChakraLayer> {
        Binding(get: { layer ?? StudioChakraLayer() }, set: { layer = $0 })
    }
    var body: some View {
        DisclosureGroup("Chakra sounds · \(layer?.selected.count ?? 0) selected") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Playback", selection: value.mode) {
                    ForEach(StudioChakraMode.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Button("All seven") { value.wrappedValue.selected = Set(StudioChakra.all.map(\.id)) }
                    Button("Clear") { value.wrappedValue.selected = [] }
                }
                ForEach(StudioChakra.all) { chakra in
                    Toggle(chakra.label, isOn: Binding(get: { value.wrappedValue.selected.contains(chakra.id) }, set: { enabled in
                        var next = value.wrappedValue
                        if enabled { next.selected.insert(chakra.id) } else { next.selected.remove(chakra.id) }
                        value.wrappedValue = next
                    }))
                }
                if value.wrappedValue.mode == .column {
                    HStack { Text("Add next layer every"); Spacer(); Text("\(Int(value.wrappedValue.step)) sec") }.font(.caption)
                    Slider(value: value.step, in: 5...60, step: 1).accessibilityLabel("Chakra column step in seconds")
                    Text("Selected chakras join from root to crown and keep looping. Use longer live sessions to hear the full build.").font(.caption).foregroundStyle(.secondary)
                }
                Text("Original recordings crossfade. The pitch-preserving column loops keep a 10-second cadence; a brief edge fade softens each join.").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 8)
        }
        if !(layer?.selected.isEmpty ?? true) || showLevel {
            HStack { Text("Chakra level"); Spacer(); Text(value.wrappedValue.volume, format: .percent.precision(.fractionLength(0))) }.font(.caption)
            Slider(value: value.volume, in: 0...0.6).accessibilityLabel("Chakra background level")
        }
    }
}
