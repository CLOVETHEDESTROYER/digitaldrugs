//
//  ColorSchemeManager.swift
//  DigitalDrug
//
//  Created by Carlos Alvarez on 1/9/25.
//

import SwiftUI

class ColorSchemeManager: ObservableObject {
    @AppStorage("colorScheme") private var colorScheme: String = "system" // Default to system
    @Published var selectedScheme: ColorScheme?

    init() {
        applyColorScheme()
    }

    func setColorScheme(_ scheme: String) {
        colorScheme = scheme
        applyColorScheme()
    }

    private func applyColorScheme() {
        switch colorScheme {
        case "light":
            selectedScheme = .light
        case "dark":
            selectedScheme = .dark
        default:
            selectedScheme = nil // System default
        }
    }
}

