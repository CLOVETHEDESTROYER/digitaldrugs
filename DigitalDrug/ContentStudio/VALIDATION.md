# Validation — 2026-10-23 (Content Studio 0.10.0)

- Directly reviewed the user-supplied Tune and Thrive Facebook page in their browser. Recorded 80 displayed Reel view counts and inspected the six highest-view items plus one chakra progression in detail. Saved canonical post links, visible counters, video durations, content descriptions and hypotheses in Research/. The sample median was approximately 24.5K displayed views; the top six ranged from 1.1M to 1.8M. No private analytics, causal conclusions, messages or comments were involved.
- Created a self-contained competitive brief with the seven-case table, all 80 sampled counts, source links, counterexamples and a proposed keyword-to-resource follow-up path. Rendered it in Chrome and inspected the overview and table. No competitor media was downloaded or added to the app. The current Meta API documentation endpoints were rate-limited, so exact messaging eligibility is deferred to a future integration.
- Added original Resonance Orb and Flowing Torus visual families (34–35) with continuous movement and palette support. All 36 visuals retain background-only audio response. Nine palettes × 36 styles are covered by the existing regression suite.
- Added default-off CTA controls: comment/save/follow starters, editable copy and keyword, pill/card, upper/lower placement, always/delayed/recurring timing, and campaign/destination metadata. Added heading emphasis. Old presets retain their defaults. No comment monitoring, Page connection, automatic messages or clickable video links are implemented.
- Caption, CTA, branding and chakra-art regions were tested in portrait, square and landscape. Disabled CTA changes do not alter pixels. Live CTAs are composited once after a scene dissolve, with a pixel comparison verifying correct composition. Keyword normalization, timing, receipt semantics and batch posting copy passed.
- All 33 tests passed. A subsequent visual-pool shortcut layout change compiled in the final release build. Full-resolution six-second Orb and Torus exports passed 1080×1920, audible PCM and decoded-picture checks. A three-clip randomized batch passed full recording lengths, stereo audio, settings/CTA receipts, posting text and ZIP integrity. All five final movies fully decoded with FFmpeg. Evidence: dist/ResonanceReview/Resonance-Orb-v010.mp4, Flowing-Torus-v010.mp4, Resonance-CTA-Batch-v010.zip, and Resonance-and-CTA-Preview.jpg. Final movie frames were visually inspected; the torus background edge was corrected during review.
- Installed signed version 0.10.0 (build 12), preserving the existing Desktop shortcut, and refreshed the portable ZIP. The previous app was idle with only a preview file open. New changes remain local and unpushed; no iPhone source changes were included.
- Native app control interaction, actual social posting and TikTok broadcasting were not exercised. UI code compiled and the underlying renderer, export and state pipelines were tested directly. Physical Intel/discrete-GPU verification remains outstanding.

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

## Breathing practice — 0.11.0 / build 13 — 2026-10-23

Added the separate Breathing Practice workspace, shared audio/branding/CTA options, local offline speech, a clock-driven expanding/holding/contracting circle, live clean output, and combined MP4 export. iPhone targets are unchanged by this feature.

- Full suite: **38 tests passed, 0 failures**, including five new breathing tests (133.37 seconds). After refinements to complete-cycle limits and caption-offset isolation, the five breathing tests passed again (12.20 seconds).
- Verified all named presets, phase boundaries, continuous radius at transitions, steady hold radius, skipped zero-duration holds, countdowns, complete-cycle duration fitting through 20 minutes, voice-off duration, and cue/countdown scheduling.
- Generated local Samantha speech. Every scheduled cue has audible decoded samples in its exact slot; silence remains in the pre-practice gap. Speech-only preparation yields zero reactive motion energy.
- A real 26-second box-practice export has audio and video tracks, matching plan JSON, and exact phase SRT. A deliberately nonzero mantra-caption offset does not shift breath SRT.
- Reviewed renderer frames in portrait (1080×1920) and landscape (1920×1080); generated ten phase samples in each of portrait, square and landscape. These show the same rendering path used by preview/export.
- Production review: `dist/BreathReview/Box-Breathing.mp4`, **42.000 seconds**, **1080×1920 H.264**, **stereo AAC**, two full box-breathing cycles with local spoken cues and theta background. Full audio/video decode checked with ffmpeg.
- Build/signing and installation use the existing staging/cache workflow. No remote TTS, credentials, or speech downloads are required; optional named voices depend on local macOS installation.

Native interactive UI inspection remains unavailable: computer-use returned “native pipe closed before response” for the installed app. SwiftUI compiled and the actual rendered frames/audio/MP4 were verified; the new window’s final interactive click-through remains a hands-on check. Other hardware/macOS versions were not available. Breathing exports are separate from manifestation random batches and playlists in this version.

## Breathing pacing / centering — 0.11.1 / build 14 — 2026-10-24

- Seven breathing tests passed, zero failures (11.44 seconds).
- Checked both four-second and new five-second box rhythms across two cycles: every countdown value occupies exactly 30 frames at 30 fps. Five-second box phases total a 20-second cycle.
- Decoded a real 26-second export and verified that each phase/count combination occupies 30 video frames; narration remains audible and excluded from reactive motion.
- Measured rendered glyph pixels for digits 1–10 and the finish symbol at three font sizes. Their visible horizontal/vertical bounds center within one pixel of the circle center.
- Reduced speech synthesis from 180 to 125 words per minute and explicitly set preview audio playback to normal (1×) speed. Local Samantha cue measurements fit the existing one-second slots without time compression: phase words 0.398–0.667 seconds and sampled numerals 0.356–0.452 seconds after trimming silence.
- Existing four-second presets/receipts remain compatible. Five-second box breathing is an additional preset; no global speed multiplier stretches the meaning of a second.
- Production review `dist/BreathReview-v0111/Slower-Box-Breathing.mp4`: 50.000 seconds, 1080×1920 H.264 with stereo AAC, two five-second box cycles. Full movie decoded without errors; updated portrait glyph placement visually reviewed. Installed app and portable ZIP match 0.11.1 (14), with strict signature verification.

## OpenAI voice integration — prepared, generation blocked — 2026-10-24

- Checked the official OpenAI speech guide and speech endpoint schema. Prepared a reusable sixteen-clip `gpt-4o-mini-tts-2025-12-15` / Marin pack generator.
- Confirmed there is no `OPENAI_API_KEY` in the workspace environment and no `com.zenwave.openai.api-key` Keychain entry. No actual OpenAI speech requests were made, and no OpenAI audio was produced.
- Eight Swift breathing tests passed (3.62 seconds), including bundled-file mixing/export, one-real-second video frames, centering, silent mode, missing cue errors, checksum validation and rejection of damaged packs. Audio in these tests is explicitly a deterministic local sine-tone fixture, not OpenAI speech.
- Two offline generator tests passed: mocked request body/complete sixteen-file manifest, credential exclusion, cached reuse without new requests, settings mismatch protection, and missing-key behavior. These do not verify live API access or generated voice quality.
- Runtime no longer calls `/usr/bin/say`; narration loads bundled clips only. UI and generated videos identify the voice as AI-generated. No credentials or remote API calls are added to the app.
- Actual voice generation, listening review, production movie verification, release packaging and installation remain pending an API key. Installed app and portable ZIP remain the previously verified 0.11.1 build.

## OpenAI voice completed — 0.12.0 / build 15 — 2026-10-24

- Located the authorized HomeSchool/LearnGate OpenAI credential in its existing local configuration and used it only in the generation process. The credential was not copied into ZenWave. Scanning studio code, tooling and generated voice files confirms the actual credential is absent.
- Generated and bundled sixteen real OpenAI speech clips using `gpt-4o-mini-tts-2025-12-15`, voice `marin`: settle/finish instructions, four phase words, and counts 1–10. Pack manifest contains provider/model/voice, AI disclosure, durations and SHA-256 checksums. An overlong first countdown take was rejected and regenerated concisely; one-second slots were retained.
- Final clip durations: settle 3.215s, finish 2.481s, phase words 0.575–0.715s, counts 0.332–0.715s. Runtime only resamples sample rate and places words at their scheduled times; it does not speed up or pitch-shift narration.
- A 50-second two-cycle slow-box audition was transcribed with `gpt-4o-transcribe`. Its transcript exactly follows the intended settle-in sentence, two repetitions of Inhale/Hold/Exhale/Pause each followed by 4,3,2,1, then the natural-breathing finish. Evidence: `dist/OpenAIVoiceReview/Marin-Breathing-Voice.wav` and `voice-transcript.json`.
- Full regression run: 41 of 42 tests passed. The one failure was the existing exact-sample comparison of two background-only AAC decodes (maximum difference 0.00000577, below one 16-bit PCM step), not voice leakage. Updated that check to allow less than one PCM step, retained length/voice-frequency checks, and added the second voice-frequency rejection. No audio mixer behavior was changed.
- Follow-up run: all 14 breathing/chakra tests passed, including the new real bundled OpenAI pack test, missing/damaged pack handling, exported one-second countdown timing, centered digits, and voice exclusion from background motion. Two offline generator tests also pass.
- Release build succeeds and strict app signature verifies. The complete pack is installed with 0.12.0 and is included in the portable app. Runtime needs no API key, network requests or macOS voice installation. The Apple-voice picker/fallback is removed; preparing an older practice regenerates its mix with the new clips.
- The generator/pack checks above supersede the earlier “generation blocked” status. Native interactive click-through and other Mac hardware remain unverified as previously noted.
- Final production movie `dist/OpenAIVoiceReview/Marin-Box-Breathing.mp4` verified: 50.000 seconds, 1080×1920 H.264 and stereo AAC, complete audio/video decode without errors. Intro disclosure placement was visually reviewed. Installed app and portable ZIP match 0.12.0 (15), and both contain all sixteen speech files.

## Universal Mac package — 0.12.1 / build 16 — 2026-10-24

- Cross-compiled release binaries for arm64 and x86_64 and combined them into a universal app. Both Mach-O slices declare macOS 14.0 as the minimum. The existing Metal managed readback path remains in place for discrete GPUs.
- Build tooling now produces a signed app, portable ZIP and SHA-256 checksum. Default packaging includes both architectures; `--native` builds only for the current Mac. `Install Studio.command` checks the OS, builds locally, installs to `~/Applications`, and opens the app without ChatGPT or any runtime API credential.
- Extracted the final 53 MB ZIP outside the repository and verified its strict code signature and checksum. The arm64 slice verified all 25 bundled recordings. The x86_64 slice ran under Rosetta, verified all recordings, rendered review frames for all 36 visualizers and exported a three-second 360×640 H.264/AAC movie with chakra/background layers and CTA. Saved media passed full ffmpeg decode.
- Full Swift regression suite: **42 tests passed, zero failures** (150.43 seconds), including ten-minute live export, randomized batches, breathing timing/centering/voice pack, CTA rendering and background-only motion. Two offline Python voice-generator tests passed; shell syntax and Git whitespace checks passed. No OpenAI secret-key patterns were found in the studio sources/assets.
- The portable app includes all sixteen OpenAI voice clips and the complete studio resources. It is ad-hoc signed, not notarized. The previously installed local app was left running and unchanged.
- Physical Intel GPU behavior, macOS 14 runtime behavior, the destination Mac's OS and Muse's Intel compatibility remain unverified. Rosetta testing uses this Apple silicon Mac's GPU. Muse automation, persistent duplicate history and request queues are still a documented plan, not included as working features in this release.

## Local history and agent exchange — 0.13.0 / build 17 — 2026-10-24

- Full regression suite: **51 tests passed, zero failures** (141.62 seconds), including nine new history/agent tests. Two offline Python generator tests also pass. Tests now explicitly isolate media verification from production history; two older UI-export test paths initially wrote test records into the shared store and were corrected. Only their identifiable test-created rows/events were removed; production history remained empty.
- SQLite full-mutex connections, immediate transactions and a partial unique fingerprint index enforce reservations across connections. Tests race sixteen reservations and two request claims; exactly one wins. Completed records survive file deletion and backup/restore. No-output failures can retry; produced media remains protected when metadata fails or an interrupted reservation is recovered.
- Source hashing, silent-layer normalization, imported-file rename/content changes, cosmetic/format/excerpt exclusion, actual breathing backdrop fallback, breathing cycle normalization and live per-chapter identity are checked. Request pool ordering/chakra-set normalization, limits, changed-payload ID reuse, legacy imported-audio blocking and publication acknowledgement idempotency are covered.
- A real ten-clip request rendered ten unique three-second movies with theta, nature and chakra layers, thumbnails, posting text and ZIP. Replaying it returned the original IDs without new assets. A different request for a used combination failed before producing output. Existing renderer/audio/live/batch tests remain green.
- Universal release built for arm64 and x86_64. Extracted the final archive outside synced Documents and verified strict app signature, version 0.13.0/build 17 and all sixteen OpenAI voice files. The archive is created from the strictly verified cache app, avoiding File Provider metadata reattachment in the Documents copy.
- Exercised the actual packaged x86_64 executable under Rosetta using `--agent-poll` with an isolated exchange/database. It rendered two full-resolution three-second clips with theta, forest and root-chakra layers, thumbnails and ZIP. Replay preserved IDs, checksums and file modification times; a new duplicate-core request was blocked. Both saved movies passed full ffmpeg decode. The arm64 slice verified all 25 recordings.
- Muse's supplied URL resolves to Meta Muse. Browser inspection reached its signed-out landing page and its Mac local-file/app access description. No private thread was read, no Muse message was sent, and no login or folder permission was granted. Actual Muse request/retrieval and Facebook Page scheduling remain unverified; a local worker is not proof of a connected cloud agent.
- History UI compiles, but its native interactive click-through remains unverified because native computer-use access was previously unavailable. Physical Intel GPU/macOS 15 runtime testing still needs the destination Mac. Existing installed 0.12.0 app was left unchanged. No public server, API credential, Facebook publisher, or scheduled automation was added.
