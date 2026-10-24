# Install and connect ZenWave on your Intel Mac

Your Core i9 Mac running Sequoia 15.7.7 meets the studio's macOS 14 minimum. Physical Intel graphics still needs one short export test. Muse's own Intel requirements and account permissions must be verified separately.

## Install the studio

The easiest route needs no Git or Xcode: download ZenWave-Content-Studio-Mac.zip from the 0.13 release, unzip it, drag the app to Applications, and open it. The ZIP includes Intel and Apple silicon. It includes the recordings, sound layers and OpenAI breathing voice; no ChatGPT account or API key is needed. This personal-use build is ad-hoc signed, not notarized; use System Settings → Privacy & Security → Open Anyway if macOS blocks the downloaded app after an opening attempt.

If you prefer an existing source checkout, switch to content-studio and pull it, then double-click DigitalDrug/ContentStudio/Install Studio.command. Building this way requires Xcode with Swift 5.10 or newer. Git pull updates source; it does not automatically install the app. You do not need to download a separate source portion when using the ready-built ZIP.

## Set up history before production

1. Open History & Agent Jobs in the studio sidebar.
2. If an earlier studio has already made videos, use Import old exports and choose the folder containing those MP4s and JSON receipts. Review its import report. Old receipts are reconstructed using current bundled sources; source audio that changed since export, missing receipts and deleted files cannot provide a complete historical guarantee.
3. Designate the Intel Mac as the authoritative renderer. The local SQLite history is private, outside Git. Pulling this repository does not transfer old history or media.
4. If moving existing history, close the studio on both Macs and copy ~/Library/Application Support/ZenWave Content Studio/history.sqlite to the same folder on the Intel Mac. A closed database is preferable; the consistent history-backup.sqlite snapshot can alternatively be copied as history.sqlite. Do not sync a live database between two rendering Macs. Copy/reselect imported music separately.

## Connect Muse without writing code

1. In History & Agent Jobs, use Prepare exchange. The default folder is ~/Movies/ZenWave Exchange.
2. Click Start local processing. Keep the studio open and the Mac awake while rendering. If left enabled, processing resumes when the app next opens.
3. Install/sign in to Muse for Mac if it supports this Intel machine, using your Muse account. Grant the necessary access for the dedicated exchange folder. Signing into the browser alone is not proof of local file access.
4. Click Copy Muse connection prompt in the studio and paste it into your Muse conversation. The prompt asks Muse to read the instructions/catalog, submit one provided three-second test, retrieve the finished clip and repeat the request to prove it does not generate twice. It does not authorize posting the test.
5. Confirm that the video and status actually come back to Muse. Only after that succeeds, ask for a batch of ten using your desired manifestations, visuals, colors and sound layers.
6. Separately verify access to the correct Facebook Page, upload/scheduling, and returned post IDs before relying on weekly posting. ZenWave does not publish or schedule posts itself.

If Muse for Mac is unavailable on Intel or cannot access local files, use a dedicated synced exchange folder only if Muse's connected storage can create JSON requests AND retrieve finished videos. Choose that folder in the studio while processing is stopped and repeat the test. The renderer and SQLite history remain on the Mac. This route has not yet been verified in your account. No public server or hosted studio has been added.

## What is automatic now

The local worker accepts 1–50 manifestation clips per request, selects unused core combinations, renders them sequentially, and returns MP4/audio, thumbnails, posting text, optional subtitles/CTA receipts, a manifest and ZIP. Repeating a request ID returns its existing result; changing that ID's parameters is rejected. Manual, randomized, breathing and live exports all use the history guard. Breathing/live agent request schemas are not included yet.

Completed videos remain protected even when moved, deleted or rejected. Cosmetic changes and renaming do not make a core new. Failed renders without output may be retried; partial/interrupted jobs require review and a new request for the missing clips. Use Recover interrupted renders only after stopping processing and closing every other studio process.

The account-side Muse handoff has not been tested because the available browser is signed out. This package supplies the local endpoint Muse needs, but should not be described as already connected. No coding should be needed to operate the prepared local workflow; any adapter changes required after testing Muse's actual permissions can be made in the development repo and delivered as another package.
