//
//  DigitalDrugTests.swift
//  DigitalDrugTests
//
//  Created by Carlos Alvarez on 1/9/25.
//

import Testing
@testable import DigitalDrug

struct DigitalDrugTests {

    @Test func generatedManifestationUsesSelectedThemeAndTone() {
        let affirmation = ManifestationAffirmation.generated(
            theme: .abundance,
            tone: .grounded,
            intention: "a sustainable creative business"
        )

        #expect(affirmation.theme == .abundance)
        #expect(affirmation.text.contains("a sustainable creative business"))
        #expect(affirmation.text.contains("grounded action"))
    }

    @Test func manifestationConvertsToSharedGuidedRitual() {
        let affirmation = ManifestationAffirmation.generated(
            theme: .confidence,
            tone: .direct,
            intention: "sharing my work"
        )
        let ritual = GuidedRitual.manifestationRitual(affirmation: affirmation)

        #expect(ritual.module == .manifestation)
        #expect(ritual.intent == .manifestation)
        #expect(ritual.durationMinutes == 3)
        #expect(ritual.frequencyLabel == "10 Hz beat")
        #expect(ritual.steps.first?.startTime == 0)
        #expect(ritual.steps.contains { $0.startTime == 15 })
    }

}
