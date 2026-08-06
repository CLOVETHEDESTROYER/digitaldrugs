# ZenWave App Store Release Checklist

Current project version: **3 (build 5)**
Bundle identifier: **com.hyperlabsAI.DigitalDrug**

## Verified in Code

- [x] Signed generic iOS device build succeeds.
- [x] App display name is ZenWave.
- [x] App icon catalog is configured and the required iPhone/iPad icons compile.
- [x] Background audio mode is enabled.
- [x] Privacy manifest is bundled with the app.
- [x] Free users land on the binaural/pulsed generator.
- [x] Premium and legacy users land on the ritual Home experience.
- [x] Persistent player and labeled bottom navigation use the same layout on every tab.
- [x] Settings shows access state, restore/manage subscription actions, reminder controls, version/build, Privacy, Terms, and Support.
- [x] Paywall includes monthly/annual choices, restore purchases, Privacy, Terms, and a product-loading retry state.
- [x] Gateway, Quantum Code, chakra, manifestation, nature, and guided-voice audio assets are included in the app bundle.
- [x] Unused legacy background assets were removed from the shipping asset catalog.

## Runtime QA Before Archive

- [ ] Fresh install: complete onboarding and confirm the free generator is the first tab.
- [ ] Free access: test binaural, pulsed, presets, sliders, timer, ocean sound, and education pages.
- [ ] Premium gates: Chakra, Gateway, Quantum Codes, manifestation rituals, challenges, and journal open the paywall for a free user.
- [ ] Premium access: complete one Chakra, Gateway, Quantum Code, manifestation, and ritual-preset session.
- [ ] Audio continuity: switch tabs, lock the screen, and background the app while audio is playing.
- [ ] Guided audio: confirm voice enters after the intended delay, the bed is quieter than the narration, and stop/pause ends every audio layer.
- [ ] Nature sounds: confirm each bundled ambience starts, loops, switches cleanly, and stops.
- [ ] Layout: check one compact iPhone, one large iPhone, and an iPad for clipping, scroll reachability, and footer placement.
- [ ] Accessibility: test larger text, VoiceOver labels on playback/navigation controls, Reduce Motion, and Reduce Transparency.
- [ ] Notifications: test permission accepted and denied, reminder scheduling, and the Settings deep link.

## StoreKit and TestFlight

- [ ] Test monthly purchase and annual purchase using StoreKit/TestFlight sandbox accounts.
- [ ] Test Restore Purchases after reinstalling.
- [ ] Confirm an original paid user receives Legacy Premium automatically.
- [ ] Confirm both products use the exact IDs in the app:
  - `com.hyperlabsAI.DigitalDrug.premium.monthly`
  - `com.hyperlabsAI.DigitalDrug.premium.annual`
- [ ] Attach the subscription group/products to this app version if they are being submitted for their first review.

## App Store Connect

- [ ] Create or select App Store version **3.0** to match the project marketing version.
- [x] Build number incremented to **5** for the next TestFlight upload.
- [ ] Confirm the app price is Free.
- [ ] Add current screenshots for all required device sizes.
- [ ] Verify description and screenshots distinguish the free generator from premium rituals.
- [ ] Confirm Privacy Policy URL, Support URL, Terms, age rating, app privacy answers, and export-compliance answers.
- [ ] Add review notes explaining where the free generator, paywall, Restore Purchases, and premium ritual content are located.
- [ ] Archive using Any iOS Device, Validate App, then upload to App Store Connect.

## Final Submission Gate

Do not submit until the signed build, runtime QA, StoreKit sandbox purchase/restore, and App Store Connect metadata checks above all pass on the exact build being uploaded.
