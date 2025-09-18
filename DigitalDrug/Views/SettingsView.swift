//
//  SettingsView.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("enableSounds") private var enableSounds = true
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @State private var selectedColorScheme = "system"

    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Enable Sounds", isOn: $enableSounds)

                Picker("Appearance", selection: $selectedColorScheme) {
                    Text("System Default").tag("system")
                    Text("Light Mode").tag("light")
                    Text("Dark Mode").tag("dark")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedColorScheme) { _, newValue in
                    colorSchemeManager.setColorScheme(newValue)
                }
                .onAppear {
                    // Sync picker selection with saved preference
                    selectedColorScheme = colorSchemeManager.selectedScheme == .light ? "light" :
                                          colorSchemeManager.selectedScheme == .dark ? "dark" :
                                          "system"
                }
            }

            Section(header: Text("About")) {
                Text("DigitalDrug")
                    .font(.headline)
                Text("Version 1.0")
                    .font(.caption)
                Text("DigitalDrug uses binaural beats and nature sounds to help improve focus, relaxation, and sleep.")
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
        }
        .navigationTitle("Settings")
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ColorSchemeManager())
    }
}
