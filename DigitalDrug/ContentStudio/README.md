# ZenWave Content Studio

A separate, offline Mac app for creating videos from ZenWave’s mantra recordings. The iPhone project does not include the studio or its new visualizers.

## Make a video

Open **ZenWave Content Studio.app** from your Desktop shortcut or `~/Applications`.

1. Click a recording and press Play.
2. Choose one of **34 visualizers**. Signature Waves now uses layered flowing ribbons; Signature Mark retains the original logo. Tidal Flow adds drifting, fluid contours. The **Sacred geometry** section adds Merkaba, Metatron’s Cube, Flower of Life, Seed of Life, Vesica Piscis, and Octahedral Halo. The **Chakras** section includes Root, Sacral, Solar Plexus, Heart, Throat, Third Eye, Crown and the animated Chakra Column using the app’s original artwork. Chakra colors stay recognizable while the selected palette colors the surrounding atmosphere. Four portal fields—Prismatic Wormhole, Aurora Wormhole, Cosmic Vortex, and Liquid Portal—add depth and inward/outward travel. Crystal Lotus and Radiant Iris extend the layered bloom collection.
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

1. Choose a batch size (1–50), output shape, and allowed **Manifestations**, **Visuals** and **Colors**. **Use checked queue** imports the recordings checked in the main library. Visual shortcuts select blooms/wormholes or sacred geometry. You can enable any of the 34 visuals and nine palettes.
2. Optionally enter a caption footer or your hashtags. This is included in companion posting-text files, not drawn over the video.
3. **Generate batch** creates a review list. Manifestations are balanced across the batch, with less-used visuals and colors preferred; each recording/visual/palette/beat/nature combination is unique. With enough choices, neighboring clips also vary their manifestation and visual. Small pools require a smaller batch; the studio never silently fills the batch with duplicate combinations.
4. Click each row to preview the exact visual, full audio and captions. Lock favorites, then **Reshuffle unlocked** to create more choices around them. A locked clip must remain in the allowed pools and batch size. Locking preserves its recording/visual/palette combination and built-in beat/nature layers; global format and imported music settings are captured again when generating.
5. **Save batch MP4s + ZIP…** and choose a folder. The app creates a uniquely named subfolder and a ZIP beside it. **Show clips** opens the folder; **Show ZIP** selects the archive for easy transfer to another computer or phone. Each MP4 already contains its voice and optional background audio.

The main studio's motion, caption offset, caption/branding switches, heading, and optional imported music are captured when generating. The batch has its own beat/nature controls, initialized from the main studio when opening a new batch. Batch output shape has its own picker, defaulting to portrait. Edits to settings or pools do not change the reviewed list until you generate or reshuffle again. Estimated captions should be reviewed by listening before posting. Full recordings keep each mantra intact; this mode does not use the main studio's selected-line clip trim.

Every clip includes a numbered filename, settings receipt, editable `.txt` posting copy and an SRT when captions are enabled. `batch.json` records the seed, full pools, chosen combinations, settings and completed files. The ZIP contains the whole batch. Enter the same seed and pools under **Reproducible shuffle** to recreate an unlocked batch; the manifest also records the actual choices. The reviewed plan stays in memory while the app is open; the exported manifest is the durable record.

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

Clone the repository and check out the `content-studio` branch, or switch to that branch and pull in an existing clean checkout:

```sh
git clone --branch content-studio https://github.com/CLOVETHEDESTROYER/digitaldrugs.git
cd digitaldrugs/DigitalDrug/ContentStudio
./Tools/build-app.sh
open "dist/ZenWave Content Studio.app"
```

For an existing checkout, run `git switch content-studio` and `git pull --ff-only origin content-studio`, then build from `DigitalDrug/ContentStudio` as above. Preserve any local changes before switching branches.

Use macOS 14+ with Xcode and its command-line tools installed. The default build uses the bundled recordings, chakra loops, nature sounds and logo; it does not require uncommitted iPhone artwork or audio. `--sync` is only for intentionally refreshing these snapshots from the iPhone source and is unnecessary on the other machine. Generated apps, exports and ZIPs are excluded from Git and rebuilt locally. User preferences, live playlists and imported music are also local; copy/reselect any imported tracks you want to reuse.

## Build and test

Requires Xcode and command-line tools. The packaged app requires macOS 14+ and Metal. Build on the destination architecture: the supplied app is Apple silicon; an Intel build must be made on Intel.

```sh
./Tools/test.sh
./Tools/build-app.sh
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

Use a new output path. Verification writes a PNG for every style, exports a movie, then checks its audio/video tracks, dimensions, duration, decoded picture, and audible decoded PCM. Without `--production`, smoke export uses 360×640; without `--full`, it uses three seconds. Optional `--format square|landscape` and `--style 0…33`, `--palette 0…8`, `--seconds 8`, or `--visual-only` to omit captions, heading, and branding from a review movie. Verification also writes a Prismatic Bloom PNG for every palette.

Workflow tests also cover full-recording batches, cancellation, frequency-band isolation, anti-phase stereo, every style’s movement and sound response, all 234 style/palette combinations, distinct portal patterns, stable frame snapshots, deterministic seeking, background looping, and backward-compatible settings.

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
