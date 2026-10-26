# ZenWave Content Studio

A separate, offline Mac app for creating videos from ZenWave’s mantra recordings. The iPhone project does not include the studio or its new visualizers.

## Make a video

Open **ZenWave Content Studio.app** from your Desktop shortcut or `~/Applications`.

1. Click a recording and press Play.
2. Choose one of **36 visualizers**. Signature Waves now uses layered flowing ribbons; Signature Mark retains the original logo. Tidal Flow adds drifting, fluid contours. The **Sacred geometry** section adds Merkaba, Metatron’s Cube, Flower of Life, Seed of Life, Vesica Piscis, and Octahedral Halo. The **Chakras** section includes Root, Sacral, Solar Plexus, Heart, Throat, Third Eye, Crown and the animated Chakra Column using the app’s original artwork. Chakra colors stay recognizable while the selected palette colors the surrounding atmosphere. Four portal fields—Prismatic Wormhole, Aurora Wormhole, Cosmic Vortex, and Liquid Portal—add depth and inward/outward travel. Crystal Lotus and Radiant Iris extend the layered bloom collection.
3. Choose **Colors**: Original, Opal Spectrum, Rose Gold, Solar Flare, Emerald Tide, Glacier, Ultraviolet, Candy Nebula, or Ocean Sunset. Each palette works with every visualizer and is saved with the export settings. Captions keep their neutral white treatment.
4. Adjust **Pace**, **Flow & swell**, and **Sound response**. Reset movement restores the new defaults. A zero sound response keeps the ambient animation while removing audio-driven deformation.
5. Under **BINAURAL BEATS & NATURE**, optionally choose Delta, Theta or Alpha and a bundled nature sound. Each has its own level. You can also **Add music or ambient audio…** and set its level. Short tracks loop with crossfades; the bed fades in and out. The voice and background share gain headroom. Preview pauses briefly while a new mix is prepared.
6. Choose captions, a heading, branding, and a video shape. Under **TEXT & BRANDING**, enable **Show ZenWave branding** and choose **Logo + wordmark**, **Official logo**, or **Wordmark only**. The official app/website brand mark is bundled unchanged; size and opacity controls apply to the logo. It sits below captions and retains its original colors on every visual palette. Export one recording, one timed line, or a checked queue of full recordings.

Default destination: `~/Movies/ZenWave Content Studio`. Each run creates a new folder. **Show videos** opens it. Exports include MP4, JSON source/settings receipt, and an SRT companion when captions are enabled. Background receipts contain the filename, not the full private path. Your selected background file stays on disk and must remain available; choose it again if moving to another Mac.

Audio-driven movement follows **background layers only**: the selected binaural beat, nature sound and optional imported music. The mantra remains audible in previews and exported videos but never contributes to motion analysis. Without active background layers, visuals retain gentle time-driven ambient movement. Bass drives broad swells, mids shape the field, and highs add fine detail. Analysis smooths attacks and releases and interpolates between samples. Accumulated energy influences the flow speed without abrupt phase changes. Seeking, preview, and export use the same timeline, independent of frame rate. Stereo analysis measures each channel’s power to preserve opposite-phase material.

Captions use the app’s line timestamps for the original six mantras and estimated timings for morning/evening recordings. Listen before posting. Caption offset shifts all lines; it does not align individual words. Turn off captions and use the editable SRT companion in another editor if desired. Single-recording exports retain the original recording timing. Live Session adds adjustable rests between complete repetitions.

Preview is 360×640 (or the corresponding square/landscape size) at up to 30 fps. Exports are 1080×1920, 1080×1080, or 1920×1080 at 30 fps. The renderer uses a private Metal target, GPU copy, and shared or synchronized managed readback for unified-memory and discrete GPUs. Actual Intel hardware still needs verification.

## Binaural beats and nature layers

The **BINAURAL BEATS & NATURE** controls appear in the main studio and Random Batch. Choose fixed layers or leave either set to **None**. They are mixed under the complete manifestation recording and can coexist with imported music. Previews, video exports and prepared live sessions play the full mix. Their visualizers analyze a separate background-only signal with the mantra track physically removed.

- **Delta:** 100 Hz left / 103 Hz right, a 3 Hz difference (the app's Deep Sleep Delta preset).
- **Theta:** 200 Hz left / 207 Hz right, a 7 Hz difference (7Hz Theta Meditation).
- **Alpha:** 400 Hz left / 410 Hz right, a 10 Hz difference (Manifestation Visualization).
- **Nature:** Continuous River, Forest Ambience, River Valley, Thunderstorm, Tropical Rain, Underwater and Ocean, using the existing local recordings. No external download or account is required.

These are separate left/right sine tones, not a mono pulsing effect. Stereo headphones preserve that channel separation; mono playback combines the tones. Tone phase remains continuous, with fades only at the beginning/end. Nature and imported music loop with crossfades. Beat and nature levels are independent. Background levels share a combined gain budget of at most 60%, reserving at least 40% of the nominal mix for the voice. Different original nature recordings have different loudness; adjust their level to taste.

In **Random Batch → Randomize background layers**, enable **Randomize beat per clip** and/or **Randomize nature per clip**, then select the allowed pools. Random choices replace the fixed selection for that layer; they keep the selected level. The shuffle favors less-used beats and nature sounds, along with varied manifestations, visuals and colors. Locks take precedence and preserve the clip's selected built-in layers and their levels. Click **Generate batch** or **Reshuffle unlocked** to apply edits. Each review row identifies its assigned beat/nature combination; select it and press Play to hear the actual mix before rendering. MP4s and batch ZIPs already include the complete mix, and settings/receipts record the audio choices.

Uniqueness covers manifestation, visual, palette, beat and nature sound together. This lets you create audio variants of a favorite visual while avoiding exact repeats. The requested batch size stays fixed. Older settings and exported batch manifests load with beats and nature disabled.

## Randomized batches for social posts

Open **Random Batch…** in the studio sidebar. The default is a seven-clip week, full recordings, portrait 1080×1920 at 30 fps, and a pool of flowing visuals, blooms, portals and sacred geometry.

1. Choose a batch size (1–50), output shape, and allowed **Manifestations**, **Visuals** and **Colors**. **Use checked queue** imports the recordings checked in the main library. Visual shortcuts select blooms/wormholes or sacred geometry. You can enable any of the 36 visuals and nine palettes.
2. Optionally enter a caption footer or your hashtags. This is included in companion posting-text files, not drawn over the video.
3. **Generate batch** creates a review list. Manifestations are balanced across the batch, with less-used visuals and colors preferred; each recording/visual/palette/beat/nature combination is unique. With enough choices, neighboring clips also vary their manifestation and visual. Small pools require a smaller batch; the studio never silently fills the batch with duplicate combinations.
4. Click each row to preview the exact visual, full audio and captions. Lock favorites, then **Reshuffle unlocked** to create more choices around them. A locked clip must remain in the allowed pools and batch size. Locking preserves its recording/visual/palette combination and built-in beat/nature layers; global format and imported music settings are captured again when generating.
5. **Save batch MP4s + ZIP…** and choose a folder. The app creates a uniquely named subfolder and a ZIP beside it. **Show clips** opens the folder; **Show ZIP** selects the archive for easy transfer to another computer or phone. Each MP4 already contains its voice and optional background audio.

The main studio's motion, caption offset, caption/branding switches, heading, and optional imported music are captured when generating. The batch has its own beat/nature controls, initialized from the main studio when opening a new batch. Batch output shape has its own picker, defaulting to portrait. Edits to settings or pools do not change the reviewed list until you generate or reshuffle again. Estimated captions should be reviewed by listening before posting. Full recordings keep each mantra intact; this mode does not use the main studio's selected-line clip trim.

Every clip includes a numbered filename, settings receipt, editable `.txt` posting copy and an SRT when captions are enabled. `batch.json` records the seed, full pools, chosen combinations, settings and completed files. The ZIP contains the whole batch. With unchanged history, enter the same seed and pools under **Reproducible shuffle** to recreate an unlocked batch; the manifest also records the actual choices. The reviewed plan stays in memory while the app is open; the exported manifest is the durable record.

Exports run locally and sequentially. Stopping keeps completed clips and marks the manifest as stopped, without publishing a partial ZIP. Existing batches are never overwritten. Posting to social accounts is handled separately.

## Make a live session

Open **Live Session…** in the left sidebar. Use **Use a 10-minute starter journey** for Abundance → Love → Wellbeing, or build your own playlist. This is a separate desktop workspace; it does not change the iPhone app.

Two features work together:

1. **Manifestation playlist.** Add recordings in order (duplicates are allowed), move them up/down, and choose the time for each chapter. Default chapters last four minutes. **10 / 15 / 20 min** divides that total equally across your current playlist. The actual total is shown below. Each chapter repeats its complete recording with adjustable rests; any remaining time becomes reflection time. A chapter must fit the complete recording. Play, pause, restart, seek, next manifestation and optional looping give the host control.
2. **Evolving journey.** Choose a starting visual and palette for each chapter, optionally evolve through six scenes, and set a 30–180 second scene interval. Motion responds to background layers only; chapter changes and caption timing remain scheduled independently. Visuals dissolve over 0–20 seconds; the selected transition is capped to half the scene/chapter length. Optional breathing/reflection text appears in rests when captions are enabled. The chapter title stays visible. These settings also apply to exported movies.

Choose your format, motion, branding, captions, optional binaural/nature layers and imported background track in the main studio first. **Prepare / update session** takes a snapshot of those settings and builds the full audio mix. Playlist edits require preparing again. The plan is saved on this Mac. Pauses have silence if no background layers were selected; with background audio, the crossfaded bed continues through rests and chapter boundaries.

**Open clean output**, then **Play**. The output window contains only the video; controls stay in Live Session. Live output renders at 720×1280 portrait (or 720 square / 1280×720 landscape), up to 30 fps, and plays audio through the Mac's selected output. Closing the clean window pauses playback. Keep the session window available to pause or advance. Ordinary preview audio should remain paused during capture.

For OBS, use **macOS Screen Capture → Window Capture → ZenWave Live Output**, and configure application audio capture for ZenWave Content Studio. Check the picture and audio in OBS before broadcasting. See the official [screen capture source guide](https://obsproject.com/kb/macos-screen-capture-source) and [Mac audio capture guide](https://obsproject.com/kb/macos-desktop-audio-capture-guide). Resize/crop your scene for portrait delivery. Streaming software, TikTok access and starting/ending the broadcast are managed separately; the studio does not connect to a TikTok account.

Alternatively choose **Export full MP4…**, then add that file as a media source in your streaming software ([OBS sources guide](https://obsproject.com/kb/sources-guide)). Export renders one full cycle at the main studio's 1080 output size and 30 fps, independently of playback speed. It includes SRT when captions are enabled, settings JSON, and a `playlist.json` timeline with chapter choices and exact repetition/caption times. Export does not overwrite existing files. Long sessions require more render time and local disk space. Loop the media source in your streaming software if desired.

A useful starting session is three manifestations fitted to 10 minutes, 15-second rests, an 8-second dissolve, a new visual every 60 seconds and optional ambient audio. The session can loop during host-controlled playback. Review estimated captions and the full audio mix before using it live.

## Sacred geometry

Choose a form under **Visualizer → Sacred geometry**. The shared color, pace, flow, and audio-response controls apply to all six.

- **Merkaba:** two inverted regular tetrahedra with a shared rigid 3D rotation, perspective, translucent faces, and depth-lit edges. The compound retains its interlocking shape rather than counter-rotating its tetrahedra independently. Topology reference: [Wolfram MathWorld’s stella octangula](https://mathworld.wolfram.com/StellaOctangula.html).
- **Metatron’s Cube:** thirteen equal circles with every pair of centers connected (78 segments), rotating as one planar construction.
- **Flower of Life / Seed of Life:** nineteen or seven equal overlapping circles on a triangular lattice. Breathing scales circle radii and spacing together.
- **Vesica Piscis:** two equal circles whose centers are one radius apart, with a softly illuminated overlap and construction diamond.
- **Octahedral Halo:** a rotating regular octahedron with twelve edges and decorative orbital halos.

Sacred fields bypass the liquid coordinate warp. Audio changes global breath, light, and small glints while straight edges remain straight and circles retain their proportions. They fit portrait, square, and landscape output.

## Set up on another Mac

The portable **0.13.0** ZIP includes both **Intel (x86_64)** and **Apple silicon (arm64)**. It requires **macOS 14 Sonoma or newer** and a Metal-capable GPU. An Intel chip alone is not a problem; a Mac limited to macOS 13 or earlier cannot run this version. Actual Intel hardware still needs a render/playback check.

For the easiest installation, download `ZenWave-Content-Studio-Mac.zip` from this repository's [GitHub Releases](https://github.com/CLOVETHEDESTROYER/digitaldrugs/releases), unzip it, and drag the app into Applications. No Xcode, ChatGPT account, OpenAI key, Python packages, or additional audio downloads are needed to run it. This personal-use build is ad-hoc signed, not notarized. If macOS blocks opening it, use **System Settings → Privacy & Security → Open Anyway** after attempting to open the downloaded app.

Clone the repository and check out the `content-studio` branch, or switch to that branch and pull in an existing clean checkout:

```sh
git clone --branch content-studio https://github.com/CLOVETHEDESTROYER/digitaldrugs.git
cd digitaldrugs/DigitalDrug/ContentStudio
./"Install Studio.command"
```

For an existing checkout, run `git switch content-studio` and `git pull --ff-only origin content-studio`, then build from `DigitalDrug/ContentStudio` as above. Preserve any local changes before switching branches.

You can also double-click **Install Studio.command** in Finder. Building from source requires Xcode with Swift 5.10 or newer. The installer builds for the current Mac, installs into `~/Applications`, and opens the app. Close the app before updating. The build uses the bundled recordings, chakra loops, nature sounds, breathing voice and logo; it does not require uncommitted iPhone artwork or audio. `--sync` is only for intentionally refreshing snapshots from the iPhone source and is unnecessary on the other machine. Generated apps, exports and ZIPs are excluded from Git; portable binaries are distributed as release assets. User preferences, live playlists and imported music are local; copy/reselect any imported tracks you want to reuse.

On the Intel Mac, start with one short export before a batch or a long live session. Rendering is sequential, and long exports can take longer than their playback duration. Keep the Mac connected to power and awake during a render. For live broadcasting, a pre-exported MP4 avoids rendering the visualizer while streaming.

Muse runs separately. Installing this studio does **not** install Muse or enable an automatic Muse connection. Version 0.13 implements SQLite history, duplicate-safe exports and a local JSON request-folder worker. Open **History & Agent Jobs…** to prepare/start the exchange and copy the Muse connection-test prompt. Muse still needs separately authorized local folder access or a verified synced-folder connector; that external connection and actual Facebook publishing/scheduling have not been tested. The [integration plan](Research/meta-muse-local-studio-plan-2026-10-24.md) records the remaining account-side work. Muse's Mac hardware/account requirements must be checked on the destination machine; using its browser interface remains a separate option.

## Build and test

Requires Xcode with Swift 5.10 or newer and command-line tools. The packaged app requires macOS 14+ and Metal. The default build cross-compiles both architectures and combines them into one universal app. Use `--native` for a faster build for the current machine.

```sh
./Tools/test.sh
./Tools/build-app.sh
./Tools/build-app.sh --native
./Tools/build-app.sh --sync
```

Build and test stage plain source/resource bytes under `~/Library/Caches/ZenWaveContentStudio`, outside synced Documents. This avoids File Provider clonefile stalls and inherited signing metadata. Scripts currently use SwiftPM’s legacy native build engine for predictable local packaging; the toolchain warns that it is deprecated.

`--sync` refreshes the recording/catalog snapshot from the iPhone source, preserving the studio-specific shader. The app model remains the source for recording-to-caption mappings and unavailable variants. No script writes back into the iPhone app.

To run media verification after a build:

```sh
"dist/ZenWave Content Studio.app/Contents/MacOS/ZenWaveStudio" --verify-library
"dist/ZenWave Content Studio.app/Contents/MacOS/ZenWaveStudio" \
  --smoke-export --production --full --style 12 \
  --mantra career-confidence-morning --background /path/to/music.m4a \
  --output /tmp/studio-test.mp4
```

Liquid Constellations keeps scrolling through both completed shapes, with an independent travel cycle that eases into a direction reversal. Its liquid trails turn with the flow.

Prismatic Bloom retains its faceted twelve-petal structure, with stronger breathing, layer twists, and traveling swells. The movement sliders control the amount and pace.

Use a new output path. Verification writes a PNG for every style, exports a movie, then checks its audio/video tracks, dimensions, duration, decoded picture, and audible decoded PCM. Without `--production`, smoke export uses 360×640; without `--full`, it uses three seconds. Optional `--format square|landscape` and `--style 0…35`, `--palette 0…8`, `--seconds 8`, or `--visual-only` to omit captions, heading, and branding from a review movie. Verification also writes a Prismatic Bloom PNG for every palette.

Workflow tests also cover full-recording batches, cancellation, frequency-band isolation, anti-phase stereo, every style’s movement and sound response, all 324 style/palette combinations, distinct portal patterns, stable frame snapshots, deterministic seeking, background looping, and backward-compatible settings.

Copy the entire `.app` to another compatible Mac; all mantra recordings, nature sounds, the official logo and shaders are bundled. Imported background audio is not bundled. This is a local ad-hoc-signed build, not a notarized distribution.

For a condensed live-journey media check (two 45-second chapters), use a new output path:

```sh
"dist/ZenWave Content Studio.app/Contents/MacOS/ZenWaveStudio" \
  --live-review --production --output /tmp/ZenWave-Live-Review.mp4
```

This also writes review frames and the exact playlist/caption timeline beside the movie.

To verify a three-clip randomized batch at full portrait resolution, use a new folder:

```sh
"dist/ZenWave Content Studio.app/Contents/MacOS/ZenWaveStudio" \
  --random-batch-review --output /tmp/ZenWave-Random-Review
```

Add `--with-soundscape` to `--random-batch-review` to verify a full-resolution batch with all three beat presets and three bundled nature sounds.

As of 0.7.1, the mantra never drives visual movement. This applies automatically to individual previews/exports, Random Batch and live sessions. Regenerate already-exported videos to apply the new behavior; prepare an existing live session again after updating. Video and batch receipts label the motion source `background-only`.

As of 0.8.0, branding defaults to the official logo plus the ZenWave wordmark when branding is enabled. Existing branding-off settings stay off. Logo size adapts to the caption area in portrait, square and landscape. The original logo artwork includes its dark starfield background and is presented as a rounded badge; no recoloring or background removal is applied. Random Batch captures these branding settings on generation, and live sessions capture them on preparation. Re-render older videos to add the logo.

The bundled logo lives at `Sources/ZenWaveStudio/Resources/Brand/ZenWaveLogo.png`. Its source is the app's `DigitalDrug/Assets.xcassets/ZenWaveBrandMark.imageset/ZenWaveBrandMark.png`, identical to the current website asset. `Tools/sync-library.py` refreshes the bundled copy without editing the iPhone source.


## Chakra visuals and background audio (0.9.0)

In the main studio, open the **Visualizer → Chakras** section to select one of seven animated mandalas or **Chakra Column**. In **Background Sound Layers → Chakra sounds**, choose any subset of the seven original recordings. Chakra sound selections are independent of the visual, and can layer beneath any manifestation alongside binaural beats, nature and imported music. The chakra level controls the group; all background layers share headroom. Only background audio drives reactive movement.

Playback options:
- **Original recordings:** loop the app’s recordings with crossfades.
- **Synchronized 10-second loops:** use the app’s pitch-preserving loop assets at their exact cadence, with brief edge fades.
- **Build column · root to crown:** selected loops join in ascending order and continue together. Set the interval from 5–60 seconds (default 10). A full seven-chakra build takes six intervals to reach the crown; shorter manifestation clips include only the layers that have started. Live sessions allow the full build.

In **Random Batch**, the **Chakras** visual shortcut selects all eight new visuals. Under **Randomize background layers**, enable **Randomize chakra per clip** and choose allowed individual chakras and/or **Full chakra column**. This replaces the fixed chakra selection for each generated clip; the level, original/loop mode for individual chakras, and column interval are retained. Leave it off to use a fixed multi-chakra blend in every clip. Beat and nature randomization can run alongside it. The requested 1–50 clip limit, locks, review, combined MP4 export and ZIP download apply as usual. Generate again after editing settings.

The column artwork keeps all seven nodes visible above the caption area. Turning captions off enlarges the artwork. For a clean column-only video, also clear the optional heading. All chakra assets are bundled in the desktop studio; no iPhone target changes are required.

## Resonance visuals, hooks and calls to action (0.10.0)

Choose **Visualizer → Resonance → Resonance Orb** or **Flowing Torus**. Both are original procedural visuals with continuous motion, compatible with all nine palettes and the existing movement controls. Background layers drive their response; the voice remains excluded. **Random Batch → Visuals → Resonance** selects both for the allowed visual pool. Live chapters can use either as their starting visual.

Under **Text & Branding**, enter a short optional heading and use **Heading size** to give it more emphasis. Keep the hook concise and preview it at your export shape.

The main inspector’s **Call to Action** section has an independent **Show call-to-action box** toggle (off by default). Start with **Comment**, **Save**, or **Follow**, then edit the text. Use `{keyword}` in the headline to insert the comment keyword, for example `Comment {keyword}` with keyword `CALM`. Supporting text is optional. Choose a filled card or outlined pill and upper/lower placement. Captions, branding and the chakra artwork reserve separate areas when a CTA is enabled.

Timing options:
- **Throughout clip:** always visible.
- **After a delay:** fades in after the chosen number of seconds, measured from the start of the exported clip or prepared live session. Clips shorter than the delay do not show it.
- **Repeat during live session:** appears for the selected duration at the selected interval, after the initial delay. This runs on the live timeline and restarts when playback loops or restarts.

CTA settings are captured when generating a Random Batch or preparing a Live Session. Generate/prepare again to apply edits. The live compositor draws the CTA once after a scene dissolve, so text remains crisp. For short social clips, try a 2–3 second delay; for lives, a 10–12 second appearance every 60 seconds is a starting point to test.

**Follow-up details** stores an optional campaign and website/app destination. These do not open links or send messages. Every CTA-enabled export includes a `.cta.json` companion with the rendered copy, campaign, destination and a comment keyword only when the headline uses `{keyword}`. The receipt explicitly marks `clickableInVideo: false` and `automationConnected: false`. Randomized posting-text files also include the CTA copy, and batch ZIPs include the receipts. The destination URL is not drawn on the video or automatically added to the public posting text.

The box is an on-video graphic, not an interactive Facebook/TikTok/Instagram button. Actual comment recognition and replies require a separate authorized social-platform integration. Match each published post to its exported keyword/campaign/destination there; connect it only after the promised resource exists and current messaging rules have been verified. No Page connection, comment collection, automatic DMs or website backend was added in this version.

Research and the proposed follow-up path are saved in `Research/zenwave-tune-and-thrive-2026-10-23.html`, with an 80-Reel public-counter sample and seven inspected case records. The brief distinguishes observed content from explanations to test. It does not establish causal engagement effects, verify medical/financial frequency claims, or use private analytics.

For media verification, add `--with-cta` to `--smoke-export` or `--random-batch-review`. The latter renders the new resonance styles with the captured CTA and posting-text/receipt companions. Visual style IDs now run from 0 through 35.

## Breathing practice (0.11.0)

Open **Breathing Practice…** in the main studio’s left sidebar. Choose a rhythm:

- **Gentle 5 in / 5 out:** no holds; a timed adaptation of the [NHS gentle five-count exercise](https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/).
- **Equal 4 in / 4 out:** an equal-length inhale/exhale pace inspired by [sama vritti instruction from yoga teacher Jeanne Heileman](https://yogainternational.com/article/view/why-breath-matters-and-how-to-breathe-well-in-yoga-class/). Four seconds is the studio’s starting pace, not a claim that every yoga tradition uses that exact timing.
- **Box 4 / 4 / 4 / 4:** inhale, hold, exhale, pause, as described by the [VA breathing guide](https://veteranshealthlibrary.va.gov/Encyclopedia/3,84803).
- **Custom:** set inhale/exhale from 2–10 seconds and each hold from 0–8 seconds. Custom edits are labeled as custom, rather than attributed to a traditional pattern.

Keep breathing comfortable and unforced. Choose a no-hold practice if holds are uncomfortable; stop and breathe normally if dizzy. This is a pacing/content tool, with no treatment claims.

Set the complete-cycle count, or use the 1/3/5/10/15/20-minute buttons. These fit complete cycles within the requested length, including six seconds to settle in and four seconds to return to natural breathing. The exact total is shown. The circle grows smoothly on inhale, holds its size during retention, and shrinks smoothly on exhale; a moving outer light continues during holds. The visible countdown always shows seconds remaining. Circle size follows the breath timeline exactly, regardless of background energy or motion-speed settings.

Choose **Phase cues + countdown**, **Phase cues only**, or **No voice**. Speech uses locally installed macOS voices and is rendered offline before playback. At each phase boundary, the voice says “Inhale”, “Hold”, “Exhale”, or “Pause”; the remaining seconds count down from the next second (e.g. “Hold … 4 … 3 … 2 … 1”). The first displayed number accompanies the phase word. No remote voice service is required. System voice is the portable default; the available named choices depend on the Mac’s installed voices.

Choose a quiet background, any of the nine palettes, and vertical/square/landscape output. Nature, binaural and chakra layers work beneath the cues, as does music already imported in the main studio. Mantra narration is replaced by the breathing voice. Only background audio drives the background animation; speech never changes its motion. Logo and CTA settings come from the main studio, with separate safe areas around the guide. Optional headings and mantra caption-offset controls do not replace or shift the breath instructions.

Click **Prepare / update practice**, then **Play** to review. Preparation snapshots the rhythm, voice, visual and audio settings; prepare again after editing. Pause, restart and seeking all use the same prepared audio clock as the visual. **Clean output** opens “ZenWave Breathing Output” for window capture, and the voice/background play through this Mac’s audio output. Enable app/system audio capture in streaming software. Closing the clean output pauses playback. Repeat applies to preview/live playback, including the settle-in and finish; export saves one complete practice.

**Export breathing MP4…** renders an H.264 MP4 with the circle, labels, countdown, branding/CTA and combined audio. It includes settings JSON, an exact phase SRT when captions are enabled, a `.breathing.json` plan, and a `.cta.json` when enabled. The guide labels/countdown always remain visible; the main caption toggle only controls the companion SRT. A prepared movie can be posted directly or looped as a media source for live sessions. Breathing practices are currently their own export workflow, rather than entries in the manifestation randomizer or live playlist.

For reproducible media review:

```sh
"dist/ZenWave Content Studio.app/Contents/MacOS/ZenWaveStudio" --breath-review --output /new/path/Breathing.mp4 --production
```

This generates a two-cycle box-breathing movie with local narration and a theta background, plus full-resolution phase frames in all three formats. Generated review media is ignored by Git.

### Breathing pacing and number alignment (0.11.1)

**Slow box breathing · 5 / 5 / 5 / 5** adds a gentler box rhythm: each phase lasts five actual seconds, making a complete cycle 20 seconds. The original four-second box preset remains available. All countdowns use real seconds, independent of visual motion controls. The exported video holds each number for exactly 30 frames at 30 fps; preview playback explicitly uses normal speed. Spoken cues now use a slower 125-word-per-minute local voice setting. Prepare again to regenerate older audio.

The countdown uses the visible glyph outlines to center each digit horizontally and vertically inside the circle, including narrow digits, two-digit counts, and the finish symbol. Re-export previously created clips to apply these changes. To render the slower review, add `--slow-box` to `--breath-review`.

### OpenAI breathing voice pack (0.12.0)

Version 0.12.0 replaces macOS speech synthesis with bundled OpenAI audio. The runtime has no network requests, credentials, or Apple-voice fallback. It reads a verified pack of sixteen reusable clips: the settle/finish sentences, four phase words and counts 1–10. Phase slots remain aligned to real seconds. An “AI-generated voice” notice appears during the settle-in/finish and in the studio’s voice controls.

The generation tool uses OpenAI’s speech endpoint, model `gpt-4o-mini-tts-2025-12-15`, and the `marin` voice with calm delivery instructions. See the [official OpenAI speech guide](https://developers.openai.com/api/docs/guides/text-to-speech). Generation needs an OpenAI API key configured locally as `OPENAI_API_KEY` or a macOS generic-password entry with service `com.zenwave.openai.api-key`. Never paste the key into chat, source, receipts, or a Git commit. Playback and export need no key after generation.

```sh
python3 ContentStudio/Tools/generate-breath-voice.py --dry-run
# After configuring the key locally:
python3 ContentStudio/Tools/generate-breath-voice.py
bash ContentStudio/Tools/build-app.sh
```

The output is `Sources/ZenWaveStudio/Resources/BreathVoice/`, with a complete manifest and content hashes. Interrupted runs retain completed clips; voice/settings mismatches are rejected rather than mixing packs. Silent padding is trimmed. If a cue needs a minor timing adjustment, the development tool uses ffmpeg to preserve pitch; the runtime never rushes the voice to fit a slot. Excessively long cues are rejected for regeneration. ffmpeg is not a runtime app dependency. Generated audio can be bundled and checked into Git; credentials cannot.

The complete Marin pack is now bundled in the source and desktop app. Generation used the existing HomeSchool/LearnGate OpenAI configuration without copying its credential into this project. The studio uses those clips automatically after **Prepare / update practice**; no key or voice download is needed on another Mac. Earlier references to Mac voices describe versions 0.11.x and no longer apply to current playback. The build script prevents packaging an app with a missing pack.


## History and local agent jobs — 0.13

For the destination Mac, follow [the no-code setup guide](MUSE-SETUP.md).

Every new manual, random-batch, breathing and live video export reserves its core combination in local SQLite history before rendering. Completed media remains blocked even when moved, deleted or rejected. Actual source-file hashes identify audio; renaming a file, changing gain/motion, captions, branding, CTA, clip length or aspect ratio does not make a core new. The randomizer now filters previously used combinations; the exporter is the final guard against concurrent duplicates. A competing export can stop a partially completed batch without deleting its completed clips. Use a new request for only the missing content after review.

Open **History & Agent Jobs…** in the sidebar:

1. **Import old exports…** before a production batch. Select your prior ZenWave export folder. Movies with readable receipts/source assets are reconstructed; old imported-audio receipts conservatively block the matching core with any imported background. The report identifies movies that could not be reconstructed. Reconstruction uses current bundled sources; audio changed since the original export cannot be verified from old receipts alone. Missing/deleted exports and missing receipts cannot be recovered from chat.
2. Choose a dedicated exchange folder (default `~/Movies/ZenWave Exchange`) and **Prepare exchange**. It contains instructions, the current catalog and an example request. Preparation never submits the example or starts a render.
3. **Start local processing**. The worker watches `Requests/`, saves atomic replies in `Status/`, and renders requested batches into `Ready/` with combined MP4/audio, posting text, thumbnails, optional subtitles, settings receipts and a ZIP. Choose 1–50 videos; request ten for a week rather than every combination. This version accepts manifestation batches; breathing and live exports participate in history but do not yet have agent job schemas.
4. **Copy Muse connection prompt**, paste into your Muse task, and grant the Muse Mac app access to this dedicated folder. Muse must demonstrate writing the supplied three-second test request and reading the completed result. A browser-only Muse task cannot assume access to a local Mac path; a connected synced folder is a fallback only after read/write/video retrieval works in that account. No public server or hosting is enabled.
5. Repeat the same request ID to get the same result. Changed parameters under that ID are rejected. Failed/partial/interrupted requests are retained rather than silently rerendered. Review retained clips, then request only the needed replacements under a new ID. **Recover interrupted renders…** checks abandoned reservations; stop processing and close every other Studio process first.

Keep the app open and the Mac awake while rendering. Processing resumes when the app next opens if it was left enabled. Closing the app stops the worker; this is not a system daemon. Muse's actual account handoff and Facebook Page upload/scheduling remain unverified. The studio never publishes; optional `Reports/` acknowledgements store actual platform IDs/times supplied by the agent without independently verifying them.

History lives in `~/Library/Application Support/ZenWave Content Studio/history.sqlite`, with a `history-backup.sqlite` snapshot. Use **Export history…** for a readable JSON audit, including requests, assets, publication acknowledgements and events/settings. Use **Open database folder** to locate the files. Keep one authoritative rendering Mac. Stop both apps before moving `history.sqlite` to another Mac, or copy the backup as `history.sqlite`; never sync a live SQLite database between two renderers. Copy/reselect imported music separately. Downloading the repository does not transfer your private history or exports.

The complete agent schema and test procedure are bundled as [AgentInstructions.md](Sources/ZenWaveStudio/Resources/AgentInstructions.md) and copied into the exchange folder. No API key is required for the local worker.

## App updater — 0.14.0

Open **App Updates…** in the sidebar to check, download and install compatible GitHub releases. Installation waits for current work, backs up history/preferences, preserves the current app path and exchange, and retains the previous app for rollback. Older versions need one manual ZIP replacement to gain the updater. See [UPDATES.md](UPDATES.md) for installation and recovery.

For the existing cloud Muse workflow, keep using the same Google Drive exchange. The Muse desktop app is not needed when its cloud agent already reads/writes that Drive folder. The original 0.13 setup discussion above describes the earlier, unverified connection options. No posting schedules or permissions are changed here.

## Butterchurn Visual Lab — 0.15.0

Open **Visual Lab…** in the main sidebar. **Try ambient demo** prepares a short forest/theta comparison without changing saved studio settings. Or choose a recording, sound layers and imported music in the main studio, then use **Prepare from main studio** in the lab. Preparation is capped at 90 seconds. Press **Play comparison**; both engines share the same audio clock and background mix. **Background only** lets you listen without the mantra; the mantra is excluded from visual analysis regardless of this switch.

The left panel shows an existing Metal visual; choose any current style. The right panel shows six community MilkDrop presets through bundled Butterchurn 2.6.7: Julia Fractal, Molten Neon, Prismatic Tunnel, Aurora Trails, Origami Fractal and Mandala Passage. Original author/preset names and MIT notices are preserved. Pick a 0/3/6/12-second blend, slow/original/flowing movement, light/balanced/high resolution, or automatic changes every 45 seconds. **Compare with Metal** can be turned off to give Butterchurn more room. **Restart** resets feedback; this first lab has no seeking. Captions/logo/CTA are omitted from both comparison panels so the underlying visuals can be judged fairly.

This release is a **preview comparison**, not Butterchurn export support. These presets are not assigned production visual IDs and cannot yet be selected for MP4 exports, Random Batch, live playlists, breathing output or Muse jobs. Current Metal exports/catalog IDs and schema version 1 stay unchanged. The lab runs offline, does not use microphone access, and needs WebGL 2 in the Mac's WebKit. Physical Intel performance still needs testing. No iOS app changes are included.

For a lab-only launch without starting the agent worker, run the app executable with `--visual-lab`. For isolated integration verification, use `--visual-lab-review --output /new/review/folder`; add `--with-movie --background /path/to/background-only.m4a` to save a 36-second sequence of PNG frames for review. These verification commands do not reserve content or touch production history/Drive. A browser-only copy of Resources/Butterchurn/index.html includes a generated ambient fixture and optional local audio picker; all engine/preset files are bundled beside it.

## Space / wormhole collection — 0.16.0

Visual Lab now starts in **Space / wormholes**, with four original ZenWave themes in both engines:

- **Event Horizon:** a dark central aperture, luminous lens/disc and spiraling filaments.
- **Aurora Slipstream:** flowing multicolored curtains winding through a tunnel.
- **Crystal Stargate:** a hexagonal corridor with sharp gates and twisting light ribs.
- **Nebula Drift:** open cloud fields and sparse forward-moving stars.

Use **Try ambient demo → Play comparison**. With **Match space theme** enabled, choosing a Butterchurn space preset also selects the matching Metal style. Turn it off to pick any Metal style independently. Switching Collection to **Classic MilkDrop** retains all six previous community presets; **All visuals** shows all ten. Automatic evolution stays within the chosen collection. Both engines share the background-only audio feed and playback clock; their analysis, color treatment, animation speed and feedback rendering differ, so these are aesthetic comparisons rather than pixel-matched output. Metal uses the main studio's selected palette/motion settings.

All four **Metal** styles are also available in the main studio, Random Batch, live/background choices and agent catalogs as appended IDs **36–39**. Existing IDs 0–35 and version 1 requests remain unchanged; current agent requests do not gain extra variations unless their allowed style pool includes the new IDs. Butterchurn remains a lab preview and is not an MP4/randomizer/agent export option yet.

The new Butterchurn presets are original ZenWave shaders, separate from the six community presets. Their scene math is generated from Resources/SpaceJourneys.metal by `python3 Tools/generate-space-presets.py`. The build checks for stale generated GLSL before packaging. They use restrained feedback so the same structures leave softer trails while Metal stays crisp. No external assets or runtime downloads are needed. No iOS target changes are included.

An isolated side-by-side review can be reproduced with `--visual-lab-review --comparison --with-movie --background /path/to/background-only.m4a --output /new/review/folder`. It saves four eight-second scenes as labeled comparison PNG sequences without touching production history or Drive. `--space-only` tests just the new Butterchurn presets; the default review tests all ten.
