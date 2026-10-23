# Git transfer validation — 2026-10-23

- Archived only staged `DigitalDrug/ContentStudio` files into a fresh cache directory, without any iPhone sources or uncommitted assets. The standalone release build and strict app signature verification passed.
- The packaging script now creates its app icon from the bundled official logo. All 25 recordings, all 34 visualizers, and a two-second chakra/background-mixed MP4 passed the media verifier (360×640, 88,200 audible PCM samples, decoded video).
- Added clone/pull/build instructions for another Mac. Default builds require no library sync; bundled assets travel with Git. Generated apps and videos, local preferences, and imported music are not part of the commit.

# Validation — 2026-10-22 (Content Studio 0.9.0)

- Added the app’s seven animated chakra mandalas (styles 26–32) and original Chakra Column artwork (33) to the shared preview/export renderer. All 34 styles move, react to background sound, retain stable snapshots, and seek deterministically; all nine palettes remain supported. Canonical chakra colors and symbol orientations are preserved. Column captions and branding sit below the complete artwork.
- Bundled seven original recordings and seven pitch-preserving 10-second loops plus their provenance manifest. Every copied audio asset matches its source bytes. Tests verify exact loop duration, legacy settings/receipt decoding, column layer onsets, stable per-layer headroom, original/loop/column playback, and combinations with binaural beats, nature and the audible voice.
- Chakra background analysis is identical after changing the voice. Audio routing physically excludes narration before motion analysis. Chakra selection is independent of the visual. Ascending column loops join every 5–60 seconds and keep playing; short recordings naturally end before later layers join.
- Added fixed multi-chakra selection and per-clip chakra randomization (seven individual choices plus full column), level/mode/interval controls, a chakra visual-pool shortcut, audio uniqueness keys and optional backward-compatible metadata. Batch generation stores separate visual and audio pools instead of materializing over a million combinations. A 50-clip all-pools test completes in under three seconds; deterministic shuffles, locks, count limits and legacy plans pass.
- The complete 27-test suite passed. After final changes, 23 relevant regression tests passed including the additional all-seven-layer original/loop test (28 unique tests covered overall). Both affected rendering tests passed again after correcting Canvas/CoreGraphics Y-axis orientation.
- Inspected the eight-style contact sheet and final root symbol. Evidence: dist/ChakraReview/Chakra-Visuals-v09.jpg. Eight-second column and three-second final mandala movies passed 1080×1920, duration, audible PCM and decoded-picture checks, followed by full FFmpeg audio/video decoding. All 25 manifestation recordings passed verification.
- Random batch evidence: dist/ChakraReview/Chakra-Batch-v09.zip and its expanded folder. Three full-length 1080×1920 movies combine manifestations with randomized chakra, beat and nature audio. Stereo channels, complete FFmpeg decoding, receipt choices and ZIP CRC/contents passed.
- Installed and opened signed version 0.9.0 (build 11), checked strict signature, retained the Desktop shortcut, and refreshed the portable ZIP. Installed version and portable archive CRC/resources passed. Previous app was idle with no active export before replacement. No iPhone files changed for this feature. Work remains local and unpushed.
- Native UI interaction and real TikTok streaming were not exercised: the known computer-use pipe issue remains. Preview/export rendering, model/state and media pipelines were exercised directly; physical Intel/discrete-GPU verification remains outstanding.

# Validation — 2026-10-22 (Content Studio 0.8.0)

- Fourteen relevant regression tests passed: all visualizer tests, background-only motion checks, and randomized-batch workflow/cancellation. Brand-disabled renders remain unaffected, and voice-independent movement still passes across all 26 styles.
- Bundled the exact existing app/website brand mark. Source, website and bundled bytes match SHA-256 1265e77bba6e9bb763e1ea1dcf3e50faa8731c193f59d22e171e788d19360c2b. Artwork/colors are unchanged; the original dark starfield is presented with rounded corners.
- TEXT & BRANDING now offers a master branding toggle, Logo + wordmark / Official logo / Wordmark only, logo size and opacity, and a preview of the actual asset. Old branding-off settings remain off. Settings propagate through existing batch/live snapshots and JSON receipts.
- Generated nine review images covering three branding modes in portrait, square and landscape. Visually inspected portrait/square combined branding and landscape logo-only output; the logo remains below captions. Evidence: dist/BrandReview/brand-*.png.
- A three-second 1080×1920 Prismatic Bloom/Opal movie with logo + wordmark passed decoded picture, audio, dimensions and duration checks (132,300 audible PCM samples). Evidence: dist/BrandReview/Official-Logo-v08.mp4. All 25 recordings and 26 shaders passed the smoke verifier.
- Installed and opened signed 0.8.0 after checking that the prior app was idle without active exports. Strict signature and version verification passed; Desktop shortcut retained and portable ZIP refreshed.
- Native UI click-through and physical Intel/discrete-GPU verification remain unavailable as previously documented. No iPhone source was changed. Changes remain local and uncommitted/unpushed.

---

# Validation — 2026-10-22 (Content Studio 0.7.1)

- All 23 tests passed. New regression tests replace a loud, pulsed, high-frequency voice with a quiet low-frequency voice while keeping background settings fixed. Background motion envelopes and rendered pixels remain identical across all 26 styles, separately for beats, nature, imported music, and combined layers. Playback still contains the voice.
- Voice-only and fully muted-background cases produce zero reactive energy while ambient animation continues. A main-actor preview test confirms that switching mantra recordings leaves ambient geometry identical at the same time. Two real MP4 exports with different audible mantras also have identical decoded picture frames when background/caption/branding settings are held constant.
- Playback and motion now use separate signals. The audible mix retains the mantra. Before exporting the background analysis mix, the composition physically removes the mantra track. Audio gains, loops and fades for the background layers are retained. No-background/prepared-audio fallbacks use a silent envelope and never analyze the narration. The prepared background envelope is carried into live playback and live movie export.
- The ten-minute live-session/movie regression passed with Theta, Continuous River, imported background audio and repeated manifestations. All prior stereo-frequency, nature assets, audio-mix headroom, batching, cancellation, caption and visualizer checks continue to pass.
- Rendered three full-resolution 1080×1920, 30 fps randomized clips with native beats/nature. Full FFmpeg audio/video decode, stereo track checks, ZIP CRC/contents and `background-only` motion-source receipts passed. Evidence: dist/BackgroundMotionReview/Background-Only-v071.zip and its expanded folder.
- Installed and opened signed 0.7.1 after checking the prior app was idle without active exports; strict signature and version verification passed. Desktop shortcut retained and portable app ZIP refreshed. Existing exported movies require re-rendering; prepared live sessions require preparation again.
- Native UI automation and physical Intel/discrete-GPU checks remain unavailable as previously documented. No iPhone source was changed. Changes remain local and uncommitted/unpushed.

---

# Validation — 2026-10-22 (Content Studio 0.7.0)

- All 20 tests passed, including the ten-minute movie test updated to include generated Theta, Continuous River, imported audio and repeated manifestations. After extending combination uniqueness to include beat/nature choices, all seven soundscape/random-batch tests passed again against final source.
- The three generated presets match the app's existing ritual sessions: Delta 100/103 Hz, Theta 200/207 Hz, Alpha 400/410 Hz. Measured correct channel-specific spectral peaks and low cross-channel leakage for all three, fade-in/out behavior, and preserved binaural separation after MP4 muxing. The tone writer synthesizes in fixed-size chunks with continuous sample phase.
- All seven existing nature assets decode and mix successfully. Max-level voice + imported music + beat + nature tests retain the voice and stay below digital full scale. The test exposed AAC preroll briefly using unity gain on the second background-loop track; explicitly initializing both loop tracks to zero fixed that spike. Old music-only behavior remains covered by the regression suite.
- Final production review: three complete original recordings at 1080×1920, 30 fps, with randomized Delta/Theta/Alpha and three nature tracks. Fully decoded each MP4 with FFmpeg, verified two audio channels and both expected binaural frequencies in the left-minus-right signal, and validated the batch ZIP's CRC and contents. Evidence: dist/SoundscapeReview/Final-Soundscape-v07.zip and its expanded folder.
- Randomized layers are reproducible, recorded per clip, reviewable, and retained by locks. Pools avoid exact manifestation/visual/palette/beat/nature repeats while allowing multiple audio versions of a single visual. Old settings and manifests decode with layers off. Cancellation and completed-clip preservation still pass.
- Installed and opened signed 0.7.0 after checking the previous app was idle with no active exports; strict signature and version checks passed. The Desktop shortcut is retained and the portable app ZIP refreshed. All nature recordings are bundled for offline use; imported music remains external.
- Native UI automation and physical Intel/discrete-GPU verification remain unavailable as documented previously. No iPhone source was changed. Studio work remains local and uncommitted/unpushed.

---

# Validation — 2026-10-22 (Content Studio 0.6.0)

- All 16 tests passed. After refining visual/color balancing, all three randomized-batch tests passed again against the final source. Coverage includes stable seeds, pool limits, combination uniqueness, balanced manifestations/visuals/colors, locked favorites, shrinking batches with locks, real MP4/audio/SRT/text/ZIP export, and cancellation after the first completed movie.
- The final three-clip production sample rendered complete original recordings at 1080×1920, 30 fps, with different visuals and palettes (Prismatic Wormhole/Rose Gold, Merkaba/Glacier, Prismatic Bloom/Opal). All three movies fully decoded with FFmpeg and had audible PCM (RMS 0.0836–0.0840). Archive CRC/integrity and three included MP4s passed. Evidence: dist/RandomReview/Social-Sample-v06.zip and Social-Batch-Preview.jpg; visually inspected the contact sheet.
- Each batch includes reviewed combinations, numbered movies with original audio already muxed, per-clip settings JSON, posting-text TXT, optional SRT, and a batch.json receipt with seed, pools, settings, completed files and completion status. Completed clips survive stopping; a partial ZIP is not published.
- Installed and opened 0.6.0 after checking the running app was idle and had no active exports. The installed app passed strict signature verification, the Desktop shortcut remains valid, and the portable application ZIP was refreshed.
- Packaging now signs the app in the local cache before copying to dist. This avoids File Provider reattaching Finder/resource-fork metadata in synced Documents during signing.
- Native UI automation remains unavailable as noted for 0.5.0; layout and playback controls compile, and the main-actor batch workflow has end-to-end tests. Physical Intel/discrete-GPU testing remains outstanding.
- No iPhone source was changed. Studio changes remain local and uncommitted/unpushed.

---

# Validation — 2026-10-22 (Content Studio 0.5.0)

- The existing twelve-test suite passed after adding the live timeline and audio pipeline. The additional main-actor session-control test then passed against the final build: 13 unique tests verified. New coverage includes 10/15/20-minute presets, exact chapter boundaries, complete voice repetitions, deterministic scene dissolves, pending edits, seeking, next/loop behavior, cancellation and preparation without a background track.
- Rendered an entire ten-minute 168×300, 30 fps movie with two five-minute chapters, continuous background audio, evolving scenes and captions. Verified the full 600-second duration, audio track, captions after the chapter boundary, final decoded frame and playlist receipt.
- Generated a separate 90-second **1080×1920, 30 fps** review movie with two 45-second chapters, 30-second visual changes and eight-second dissolves. The shortened chapter lengths make transitions easy to review. Evidence: dist/LiveReview/Live-Journey-v05.mp4 and Live-Journey-Preview.jpg.
- Visually inspected captured frames through the scene dissolve, chapter boundary, Merkaba and reflection prompt. FFmpeg fully decoded the review movie; checked audible voice in both chapters and an actual silent rest when no background was selected.
- Installed and opened the signed 0.5.0 desktop app, verified its signature and version, retained the Desktop shortcut and refreshed the portable ZIP.
- Clean live output is 720×1280 portrait (or the corresponding square/landscape size); file export retains 1080 output. The output window, host controls, pause on close and sleep prevention compile; native UI automation remains unavailable because the computer-use pipe closes before responding. Real TikTok broadcasting and end-to-end streaming-software capture have not been exercised. Physical Intel/discrete-GPU verification remains outstanding.
- No iPhone source was changed. These and earlier studio improvements remain local and uncommitted/unpushed.

---

# Validation — 2026-10-22 (Content Studio 0.4.0)

- Ten tests passed, zero failures. All 26 styles move, respond to sound, retain stable frame snapshots and reproduce their scene after seeking.
- All 234 style/palette combinations render. The six new sacred fields are pairwise distinguishable and fit portrait, square, and landscape boundaries at maximal flow/audio response.
- Visually inspected the six sacred constructions in dist/SacredReview/Sacred-Geometry-Collection.jpg. Merkaba retains two inverted tetrahedra under one 3D transform; planar constructions bypass fluid distortion.
- Ten-second 1080×1920 Merkaba/Opal and Metatron’s Cube review movies passed decoded video, duration and audible PCM checks (441,000 samples each). Evidence: dist/SacredReview/Merkaba/Merkaba-Opal-v04.mp4 and dist/SacredReview/Metatron/Metatrons-Cube-v04.mp4.
- Installed and opened version 0.4.0 after checking for active exports, and verified the installed signature. Desktop shortcut retained. The complete app ZIP was refreshed.
- Native window click-through and physical Intel/discrete-GPU testing remain unavailable. No iPhone source was changed. Source changes remain local.

---

# Validation — 2026-10-22 (Content Studio 0.3.1)

- Nine tests passed. The new image-correlation regression test measures continued scrolling inside both fully transitioned Liquid Constellations shapes and confirms opposite travel directions across the turn.
- Shape morphing no longer gates translation. Scrolling follows a smooth bounded path, and liquid trails turn continuously with its velocity.
- An 18-second 1080×1920 review movie passed duration, decoded video, and audible PCM verification (793,800 samples): dist/ConstellationReview/Continuous-Scroll-v031.mp4.
- Installed and opened version 0.3.1 after checking for active exports; installed signature verified. Changes remain local.

---

# Validation — 2026-10-22 (Content Studio 0.3.0)

- Eight tests passed, zero failures. Movement, audio response, seeking, stable snapshots, background loops, batch export, and cancellation still pass.
- All 20 styles render with all nine palettes (180 combinations). Tests confirm visible recoloring and settings persistence.
- The six new fields are pairwise visually distinct. Prismatic Bloom responds to Flow & swell with stronger deformation.
- Visually inspected the six new fields and all nine Prismatic Bloom palettes. Generated review sheets are in dist/PortalReview.
- Final 1080×1920 eight-second Prismatic Wormhole/Opal and Prismatic Bloom/Rose Gold movies passed decoded video, dimensions, duration, and audible PCM checks. Both include a mantra/river background mix.
- Installed version 0.3.0 and verified its ad-hoc signature. The Desktop shortcut still opens ~/Applications/ZenWave Content Studio.app.
- Preview/export share palette and motion settings; captions are composed after recoloring. Existing presets default to Original colors.
- No iPhone source was edited. Native window inspection and physical Intel/discrete-GPU verification remain unavailable, as documented below.

---

# Validation — 2026-10-22 (Content Studio 0.2.0)

Passed on this Apple silicon Mac:
- Six workflow/visual tests, zero failures. Every one of the 14 shader styles produces visible pixels, moves over time, responds to sound, retains independent image snapshots, and reproduces its scene after seeking.
- Bass/mid/high separation tested with 80/900/6500 Hz synthetic signals, including opposite-phase stereo.
- Background audio shorter than the voice loops with crossfades and remains audible throughout the recording. The voice remains in the mix and duration is preserved.
- Older presets retain their existing values and receive default movement controls.
- Full-recording square batches and cancellation preserve their prior guarantees.
- Release build and installed-app signature verification. The Desktop shortcut targets the updated app in ~/Applications.
- Full 1080×1920, 11.963-second Tidal Flow MP4 with the career-confidence morning mantra and river-valley background; decoded picture and audible PCM verified (527,583 samples).
- Visually inspected PNGs for Signature Waves, Tidal Flow, and Signature Mark. A shared soft caption scrim replaces the old rectangular panel.
- No iPhone source or target was changed. Library refresh preserves studio-specific shaders.

Evidence: `dist/FlowReview/Tidal-Flow-with-River.mp4` and `style-0.png` through `style-13.png`. These generated files are intentionally ignored by Git.

Remaining limits: native window inspection returned “native pipe closed before response,” so the final interactive layout/import dialog still needs hands-on review. Intel/discrete-GPU hardware was not available; the imported private-target/managed-readback path is retained. Tests and builds now stage plain file contents outside synced Documents, avoiding the prior File Provider clonefile stall. Background audio remains a referenced local file rather than being bundled into the portable app.

---

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
