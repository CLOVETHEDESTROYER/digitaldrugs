# ZenWave Content Studio

A separate, offline Mac app for making videos from ZenWave’s existing mantra recordings and Metal visualizers. The iOS project and app bundle do not include this tool.

## Open it

Double-click **ZenWave Content Studio.app** in `dist`, or the Desktop shortcut created during setup. Requires macOS 14 or newer and Metal support. The supplied build is for Apple silicon; build from source on an Intel Mac to create an Intel version.

1. Click a recording title to preview it. Press Play to hear the original recording.
2. Choose a visualizer and video shape. Preview is lower resolution; exports are 1080×1920, 1080×1080, or 1920×1080 at 30 fps.
3. Toggle captions, branding, and an optional heading. The settings are remembered between launches.
4. Choose **Export this video**, or check several recordings and use **Export queue**.
5. Click **Show videos** after export. The default destination is `~/Movies/ZenWave Content Studio`. Each run gets its own folder, so earlier files are preserved.

Each export includes an MP4, a JSON settings/source receipt, and (when captions are on) an SRT subtitle file. Captions are burned into the video; the SRT is an editable companion. Batch export uses full recordings in library order and applies the current visual/text settings to every item. Single exports can also use one spoken line from the original six timestamped mantras.

**Caption timing:** the six original mantras use the app’s explicit timestamps. Morning/evening recordings use the app’s estimated line timing. Preview those recordings before posting. Caption offset shifts all lines together; it does not correct individual word or line estimates. You can turn captions off and add/edit them in a video editor using the SRT companion. The audio is the existing recording, without an added tone or music bed. This version does not reproduce session pauses, repeat-after-me scheduling, or binaural mixing from the iPhone app.

Rendering does not record your screen, need the iPhone app running, or play audio during export. You can use other windows while an export runs; keep the studio open. Stop cancels the current render while preserving earlier completed videos. Search, queue selection, and clip selection are session-only.

## Build or refresh

Xcode and its command-line tools are required to build, but not to run the packaged app.

```sh
./Tools/build-app.sh          # build the bundled snapshot
./Tools/build-app.sh --sync   # refresh from current app recordings, models, and shader first
```

The source snapshot lives in `Sources/ZenWaveStudio/Resources`. Updating it is explicit; the studio never writes to the iPhone app. The sync tool reads Swift model values directly, preserving the app’s intended morning/evening recording mappings and unavailable-variant exclusions.

To move it to another Apple silicon Mac, copy the **entire .app**. It carries all audio, catalog entries, and shader code. No account, API key, subscription, network connection, or repository path is needed. This local build is ad-hoc signed, not notarized; another Mac may require approving it in Privacy & Security. Intel builds and other Macs have not been tested.

## Verification

```sh
swift build
# Keep test build products outside iCloud-synced Documents to avoid signing metadata errors.
swift test --scratch-path "$HOME/Library/Caches/ZenWaveStudioTests"
.build/debug/ZenWaveStudio --verify-library
.build/debug/ZenWaveStudio --smoke-export --output /tmp/studio-test.mp4
.build/debug/ZenWaveStudio --smoke-export --production --full \
  --mantra career-confidence-morning --output /tmp/studio-full.mp4
```

Verification checks catalog uniqueness, audio decoding, caption bounds, all twelve shader styles, and an exported MP4’s audio/video tracks, dimensions, duration, audible decoded PCM, and a decoded picture. Test output paths must be new; existing videos are never overwritten. Optional flags: `--style 0…11`, `--format square|landscape`. Without `--production`, smoke exports use 360×640 for speed.
