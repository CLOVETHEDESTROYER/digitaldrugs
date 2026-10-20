# Validation — 2026-10-18

Built and run on this Apple silicon Mac. Minimum deployment target: macOS 14.

Passed:
- Release build and ad-hoc app signature verification.
- All 25 catalog entries have unique IDs, available and decodable recordings, nonempty captions, ordered cues, and cue ranges within recording duration.
- All 12 original Metal shader styles compile and produce images.
- A 3-second 360×640 MP4 contains decoded video and audible decoded audio.
- A full morning recording exports at 1080×1920, 11.963 seconds, with decoded picture and audible audio (527,583 decoded samples).
- A 3-second 1920×1080 landscape MP4 passes dimensions, duration, audio, and picture checks.
- The packaged app’s command-line verification loads the bundled resources without reading the source repository.
- End-to-end batch test exports two full recordings as 1080×1080 MP4s, with audio and JSON/SRT companion files (2 tests passed, 0 failures).
- Cancellation test leaves no partial MP4 and preserves an existing file unchanged.
- App process launches successfully. Desktop shortcut points to the self-contained app in ~/Applications.

Limitations:
- A visual click-through of the native window could not be completed because the computer-use service returned “native pipe closed before response.” The generated shader frames were visually inspected; the SwiftUI interface compiles, but its final window layout still needs hands-on review.
- Estimated morning/evening caption timing is inherited from the app. It has not been aligned against a fresh transcription. The studio labels it, provides preview and a global offset, and allows captions to be disabled.
- Other Macs, Intel, and macOS 14 have not been tested. Current bundle is arm64 and locally ad-hoc signed, not notarized.

Evidence movies and style PNGs are in dist/Verification. These are checks of the actual renderer and saved media, not screen recordings. The first two XCTest attempts failed because of filesystem signing metadata and differing SwiftPM bundle layouts; the resource lookup was repaired and both workflow tests then passed using a build directory outside synced Documents.
