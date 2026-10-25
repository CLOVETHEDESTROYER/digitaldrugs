# Updating ZenWave Content Studio

## First installation of the updater (0.14.0)

Older studios do not have an update button. On the rendering Mac:

1. Let the current batch finish, then quit every copy of the studio.
2. Download **ZenWave-Content-Studio-Mac.zip** from [the 0.14.0 release](https://github.com/CLOVETHEDESTROYER/digitaldrugs/releases/tag/content-studio-v0.14.0).
3. Unzip it and replace **ZenWave Content Studio.app in its existing location**. Keep the same app name and any existing shortcut target. Do not create a second running renderer.
4. Open it. In **History & Agent Jobs**, confirm the selected exchange is your existing Google Drive exchange and local processing is enabled. Do not prepare a different Drive folder or reset history.
5. Confirm the existing catalog/instruction files remain accessible to Muse. Review one small, unpublished test request and replay its ID: the replay should return the same output. Do not change any posting schedules for this test.

The ZIP includes Intel and Apple silicon, recordings, sound layers and the OpenAI breathing voice pack. macOS 14 or newer is required; no Xcode, ChatGPT account, Muse desktop app or runtime API key is needed for the existing Drive exchange workflow. This is an ad-hoc-signed personal build, not notarized. If macOS blocks opening it, use System Settings → Privacy & Security → Open Anyway after trying to open it.

## Future updates

Open **App Updates…** in the sidebar, or **Check for Updates…** in the ZenWave menu.

1. **Check for Updates** reads this repository's published Content Studio releases.
2. **Download Update** downloads and verifies the package while current work continues.
3. **Install & Relaunch** stops starting new jobs, waits for active batches/exports to finish, snapshots history/preferences, retains the previous app, replaces the app at its current path and relaunches it. Queued Drive requests remain available afterward. **Cancel waiting** resumes normal work before installation.

Keep only one studio copy running. Installation requires a writable app and parent folder; the updater explains when a manual replacement is needed. No background automatic installation occurs. The studio must remain open and the Mac awake to process requests.

## Preserving the Muse / Drive workflow

The existing exchange selection, Requests/Status/Ready/Reports directories, request/result schema version 1, content IDs, output names, request replay behavior and duplicate-combination history remain compatible. No Muse schedules, account permissions, posting logic, or Drive folder IDs are changed by the updater.

The studio refreshes changed catalog/instruction contents in place using coordinated file access, skipping unchanged bytes. Existing local file identities are retained; Google Drive's actual remote identity/sync behavior must be confirmed on the rendering Mac after installation. Requests and status outputs keep their existing atomic-write behavior.

A separate **studio-info.json** advertises app version, compatibility, runtime app path and catalog checksum. This is optional metadata; existing Muse instructions do not need to start reading it. The existing catalog format is unchanged.

Publication acknowledgements now retain additional fields such as **postedAt**, **captionVariant**, and future supplied metadata. Previously accepted reports can be replayed once to enrich missing details. Original publication identity records stay unchanged, including for compatibility with older studios. A changed report under the same already-enriched ID is rejected. These are agent-supplied acknowledgements; the studio does not independently verify social-platform posts.

## Recovery and storage

Before installation, backups are saved under:

`~/Library/Application Support/ZenWave Content Studio/Update Recovery/`

**Open recovery folder** shows the previous app, consistent history snapshot and saved preferences. After an in-app update, **Restore previous app & relaunch** uses the same checked installer. A failed startup automatically restores the previous app. Startup confirmation checks bundled content, voice files, the renderer and history access; it cannot guarantee every future action or external account connection.

**Rollback never replaces current history with an older database.** New content/publication records must remain protected. Only packages declaring compatible exchange/history versions are accepted. Keep database recovery manual and deliberate. The updater refuses unknown newer database schemas instead of downgrading them.

Downloaded staging files are removed after a successful update. **Discard prepared update** releases a download before installation. Previous-app/history recovery copies are retained; after confirming an update works, older recovery folders can be removed manually to recover space. Keep the latest useful backup. Source checkout, local history, selected exchange and generated media are separate; Git pull alone updates source, not an already-installed app.

## Publishing a studio update

Use `Sources/ZenWaveStudio/Resources/studio-update.json` as the package version/build/compatibility source. Bump version and build for each release; keep compatibility versions unchanged only while the contracts remain compatible. The app's unbundled development fallback version should also be updated in StudioBuild.swift.

Run the Swift tests, build the universal app with Tools/build-app.sh, verify the extracted ZIP, and publish it as **content-studio-vX.Y.Z** on CLOVETHEDESTROYER/digitaldrugs with asset **ZenWave-Content-Studio-Mac.zip** and its checksum companion. GitHub must finish uploading and expose its SHA-256 asset digest. Drafts, prereleases, unrelated tags, missing digests and invalid packages are ignored/rejected. The updater validates digest, size, app identity/signature, both CPU slices, macOS minimum and version 1 compatibility before replacement. Repository release access remains the trust boundary; these personal builds do not use Developer ID notarization.
