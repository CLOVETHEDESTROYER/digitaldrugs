import SwiftUI

struct CallToActionControls: View {
    @Binding var cta: StudioCallToAction
    var body: some View {
        GroupBox("CALL TO ACTION") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show call-to-action box", isOn: $cta.enabled)
                if cta.enabled {
                    HStack {
                        Button("Comment") { cta.headline = "Comment {keyword}"; cta.detail = "Share your intention below" }
                        Button("Save") { cta.headline = "Save this for later"; cta.detail = "Return when you need a quiet moment" }
                        Button("Follow") { cta.headline = "Follow ZenWave"; cta.detail = "Make space for your daily practice" }
                    }.controlSize(.small)
                    TextField("Headline · use {keyword}", text: $cta.headline, axis: .vertical).lineLimit(1...3)
                    if cta.headline.contains("{keyword}") { TextField("Comment keyword", text: $cta.keyword) }
                    TextField("Optional supporting line", text: $cta.detail, axis: .vertical).lineLimit(1...3)
                    Picker("Box style", selection: $cta.style) { ForEach(StudioCTAStyle.allCases) { Text($0.title).tag($0) } }
                    Picker("Placement", selection: $cta.placement) { ForEach(StudioCTAPlacement.allCases) { Text($0.title).tag($0) } }
                    Picker("Show", selection: $cta.timing) { ForEach(StudioCTATiming.allCases) { Text($0.title).tag($0) } }
                    if cta.timing != .always {
                        Stepper("Start after \(Int(cta.delay)) sec", value: $cta.delay, in: 0...120, step: 1)
                    }
                    Text("Timing starts at the beginning of each clip or live session. A clip shorter than the delay will not show the box.").font(.caption).foregroundStyle(.secondary)
                    if cta.timing == .recurring {
                        Stepper("Repeat every \(Int(cta.interval)) sec", value: $cta.interval, in: 15...300, step: 5)
                        Stepper("Show for \(Int(cta.visibleSeconds)) sec", value: $cta.visibleSeconds, in: 3...min(60, cta.interval - 1), step: 1)
                    }
                    DisclosureGroup("Follow-up details · saved with export") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Campaign name (optional)", text: $cta.campaign)
                            TextField("Website / app destination (optional)", text: $cta.destinationURL)
                            Text("Destination is saved in the settings receipt, not drawn on the video. Add your actual link to the post or your follow-up tool.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 6)
                    }
                    Text("On-video graphics are not clickable buttons. This studio does not monitor comments or send messages. A separate authorized Page/Messenger integration can use your keyword and destination later. Make sure any promised resource is ready before posting.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.textFieldStyle(.roundedBorder).padding(8)
        }.onChange(of: cta.interval) { _, value in cta.visibleSeconds = min(cta.visibleSeconds, value - 1) }
    }
}
