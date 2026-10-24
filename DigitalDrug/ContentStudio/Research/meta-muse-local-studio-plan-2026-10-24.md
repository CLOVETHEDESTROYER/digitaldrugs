# Meta Muse + local ZenWave Content Studio

Status: implementation plan, 24 October 2026. Muse is not connected. No studio update, external listener, cloud deployment, publication, or recurring job was enabled for this plan.

## Decision

Keep ZenWave rendering, bundled assets, audio mixing and the authoritative content database on one designated Mac. Test Muse for Mac as the access bridge first. Muse may still reason in Meta's cloud; keeping the studio local does not make Muse itself an offline agent. Muse must receive selected job details and finished media to carry out the user's social tasks.

Meta confirms desktop app/computer access in its [Connect 2026 announcement](https://about.fb.com/de/news/2026/09/meta-connect-2026/), including controlling Mac apps with permission. Its [Muse download page](https://ai.meta.com/muse/download/) describes access to desktop files/apps. Its [connector documentation](https://www.meta.com/help/artificial-intelligence/1687253048996149/) confirms custom connectors, but does not document a local MCP setup, a terminal tool for the consumer agent, or guaranteed Facebook Page video scheduling capabilities. Do not confuse Muse, Muse Code, and Manus.

No Muse desktop app was found in /Applications or the user's Applications folder during this check. Browser-only access does not by itself establish a connection to the Mac's local files or renderer.

## Routes

| Route | Local work | What connects it | Decision |
|---|---|---|---|
| Muse for Mac | Rendering, history, queues, source assets | Muse's authorized local file/app access | Test first; no public studio endpoint required |
| Browser-only Muse + shared folder | Rendering, history, source assets | A connected storage service passes request files, status and completed media | Fallback if file creation/download works in the user's connector; small handoff files/media are synced, the studio is not hosted |
| Browser-only Muse + custom remote connector | Rendering/history on Mac | Authenticated HTTPS bridge or cloud queue with an outbound Mac worker | Later option; adds a reachable service and authentication, so not the first choice for this local-only setup |

Meta lists Dropbox and Box among its business connectors in its [small-business announcement](https://about.fb.com/news/2026/09/introducing-muse-small-business/). The exact read/write/video transfer actions still need a test in the user's account. Do not promise shared-folder automation until that round trip succeeds.

## First proof of connection

1. Install/sign in to Muse for Mac with the account used in the browser.
2. Create a dedicated ZenWave exchange folder and test Muse writing one small request file and reading a reply. Confirm whether the same task can be initiated from the browser. If the desktop can only control the UI, the handoff can initially be a studio import action rather than an assumed terminal command.
3. Run one short content job through ZenWave's actual renderer and let Muse retrieve its MP4 and caption file.
4. Submit the same request again: it must return its existing job/result, not render again.
5. Submit a new request ID asking for the same creative combination: it must be blocked before encoding.
6. Only then scale to a 10-video batch. Separately test the target Facebook Page's upload/schedule flow; a linked personal Facebook account is not proof of Page publishing access.

The Mac must be awake and its local worker/authorized desktop connection must be running to render. If it is offline, requests wait or report unavailable; do not claim they are rendering. After Facebook has accepted a scheduled upload, local rendering should no longer be part of that post's execution path. Confirm actual scheduling behavior in the Page test.

## Local job interface to add

The app should expose one narrow, structured job interface used by both its own UI and an agent adapter. GUI scripting should not have to set dozens of controls for every video.

Proposed actions (these names are a design, not commands that exist today):

- list_catalog: available manifestations, breathing presets, visuals, palettes and sound layers.
- request_batch: original brief, exact clip count, allowed pools, aspect ratio, duration policy, CTA/branding, and optional campaign/weekly window.
- get_request: queued/rendering/complete/failed status and progress, with recoverable errors.
- list_ready_assets: completed MP4s, captions, thumbnails, settings and combination IDs.
- record_publication: selected asset, Facebook Page/platform, scheduled time, returned platform post ID, URL and actual publication status.

Muse can request and retrieve content through this interface. Only the studio writes recipes and reservation records. Publication callbacks must reference an existing asset ID. Muse does not need arbitrary SQL, shell access or direct edits to the database for this workflow.

Possible folder handoff:

```text
ZenWave Exchange/
  Requests/      # one complete request JSON per unique request ID
  Status/        # atomic status replies; progress is advisory
  Ready/         # completed media and a batch manifest
  Reports/       # scheduling/publication acknowledgements
```

Write temporary files then rename them atomically so partially synced requests/movies are never treated as complete. Downloads/reads should only expose assets whose status is ready.

Example request, to be validated against the eventual schema:

```json
{
  "schemaVersion": 1,
  "requestId": "zenwave-week-001",
  "requestedBy": "Meta Muse",
  "brief": "Create 10 unique calm and manifestation videos for the coming week.",
  "count": 10,
  "format": "portrait",
  "manifestationIds": ["from-the-studio-catalog"],
  "visualStyles": [10, 14, 34, 35],
  "paletteIds": [1, 4, 5, 8],
  "allowedBeats": ["theta", "alpha"],
  "allowNature": true,
  "neverRepeatCombination": true,
  "campaign": "weekly-calm",
  "publishingTimeZone": "America/Denver"
}
```

Retain the current controlled batch size (1–50); ten or more is supported within that limit. If a request exceeds the remaining unique pool, report the available count and choices that could expand it. Never silently create fewer videos or repeat a combination. Manifestation clips and breathing practices need distinct recipe types; add both to the agent catalog, rather than interpreting a breathing request as a mantra.

## Persistent history

Use a small SQLite database in the studio's Application Support directory, separate from Git and source assets. Back it up after completed batches. One Mac is the initial authoritative renderer; do not have two Macs write to independently synced copies of a SQLite file.

Suggested tables:

- requests: stable client request ID, original Muse/user brief, normalized parameters and their hash, campaign, requested count, requester, creation/update times, status, requested publishing window and errors.
- recipes: canonical visual/audio recipe and version, combination fingerprint, source-asset hashes, render parameters and studio/renderer versions.
- render_attempts: asset ID, request/recipe link, reserved/rendering/complete/failed state, output path, content checksum, timestamps, error/recovery information.
- publications: asset link, platform, Page/account ID, proposed/scheduled/actual times, timezone, platform post ID, URL and status.
- events: append-only changes needed to audit retries, rejection, scheduling and publishing callbacks.

The record of a published video does not disappear if its output file is deleted. A content request is not a social post; retain both identities. An asset can have multiple platform-publication records if cross-posting is desired, without re-rendering it or treating it as new content.

## Enforce no duplicates in the studio

Existing RandomBatchPlan currently avoids duplicates only within a generated batch. Cross-batch history and atomic reservation are not implemented yet.

Use two checks:

1. Creative-combination fingerprint: actual narration/mantra or breathing program/voice identity, visual style, palette, imported background content, active binaural/nature/chakra selections and material sequencing. Treat cosmetic captions, logos, CTA copy, filenames, timestamps and aspect-ratio changes as the same underlying combination. Decide explicitly whether duration/excerpt changes create a new variant; default conservatively to keeping the core combination blocked.
2. Export checksum: SHA-256 of the finished movie, used to identify copied/renamed files and verify transfers.

Use the actual source-file content hashes, not filenames, to identify imported audio. Normalize silent/off layers and unordered chakra selections. Keep the full settings alongside the fingerprint so decisions can be explained later.

Before encoding, reserve the combination in a database transaction protected by a unique constraint. That prevents simultaneous Muse jobs or manual exports from producing the same combination. Apply the same check to manual exports, random batches, live renders and breathing exports; Muse's memory/prompt is not the enforcement mechanism.

Keep completed and rejected-but-already-produced combinations blocked. Preserve failed attempts in history, but allow a safe retry when no completed movie exists. If an encoder finished a movie before a sidecar error, protect that combination and recover its metadata instead of producing another movie. Handle crashes/stale reservations explicitly; do not clear them automatically without checking the job/output. A repeat request ID with identical parameters returns/resumes the existing job. Reusing an ID with different parameters is an error.

## Existing content and review

Import existing batch manifests and MP4/JSON/SRT companions from the user's export folders. Earlier exports sometimes record an imported background by filename only, so some old combinations cannot be reconstructed exactly without their original audio. Label these unresolved/legacy rather than claiming a complete backfill. Deleted media and missing receipts cannot be reconstructed reliably from chat alone.

Add a History/Content Library screen showing the original brief, visual/audio combination, preview, creation time, campaign, and ready/scheduled/published status. Allow search/filter and reveal/export records. The default catalog should show unused combinations or ready-but-unpublished assets separately.

## Weekly use

A typical request is ten unique videos with specified themes, visual/audio pools and a campaign. ZenWave renders them locally and returns MP4s, caption text, thumbnails, a manifest and a proposed weekly posting list. Ten posts over seven days is roughly one or two per day; exact dates, timezone and posting windows belong in the request rather than being guessed or described as engagement-optimized.

Muse retrieves the assets, performs the supported Facebook scheduling steps, and reports the returned post IDs/times. Distinguish a proposed slot from a confirmed Facebook schedule. Retry polling/acknowledgement using the same IDs so it cannot double-post. If fewer than ten eligible unpublished videos remain, generate only the requested shortfall; never recreate already-ready assets for the same request.

Later improvements: theme/visual diversity across adjacent posts, a configurable unpublished inventory target, one-click rejected-asset replacement using a genuinely different recipe, and storing real platform performance alongside each recipe when Muse can retrieve it. No automatic performance claims or publishing integration are assumed in the first build.

## Build order

1. Prove Muse-for-Mac local file/app access and finished-video retrieval with this account; choose the shared-folder fallback only if needed.
2. Implement SQLite history, source fingerprints, historical import and duplicate-safe reservations.
3. Add structured request handling and rendering/status/ready manifests, reusing VideoExporter and RandomBatchExporter. Add the adapter only after route 1 is validated.
4. Add the studio History/Content Library UI and a bounded 10-video integration test, including repeat-request/concurrent-request/crash recovery tests.
5. Verify one Facebook Page upload/schedule/callback round trip, then test a weekly ten-video handoff. Configure a recurring cadence only when the user chooses its timing.

This is a plan, not a live connection. Installed studio remains 0.12.0. No Page access or Muse access has been granted by this document.
