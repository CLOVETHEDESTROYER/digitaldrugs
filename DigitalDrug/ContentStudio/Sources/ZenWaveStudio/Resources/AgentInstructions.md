# ZenWave local content exchange

This folder is a structured local bridge, not an internet API. Muse must have separately authorized local file access through its Mac app, or verified read/write access through a synced-folder connector. A cloud browser cannot assume it can read this Mac's filesystem.

The operator opens ZenWave Content Studio → History & Agent Jobs → Start local processing. Keep the app open and the Mac awake. Processing resumes on the next app launch if it was left enabled. No Facebook publishing or scheduling is performed by ZenWave.

## First connection test

1. Read catalog.json and this document through your authorized folder access.
2. Copy Examples/first-test.json to Requests/first-test.json. Write a temporary non-json file and rename it when complete. This creates ONE three-second test clip. The example is never automatically submitted.
3. Read Status/first-test.json. Wait for status complete; rendering, failed, interrupted and error are not ready-to-post signals.
4. Retrieve only the returned assets or ZIP after completion. Each asset includes id, source output path, SHA-256 checksum and combination fingerprint. In a synced/cloud folder, resolve the Ready/requestId files relative to THIS exchange folder, rather than treating the Mac's absolute path as a cloud path.
5. Submit the same request again. It must return the existing result without producing another video. Reusing the requestId with different parameters is an error.
6. Verify the exact Facebook Page's upload/scheduling permissions separately before asking for a weekly posting workflow. Never call a proposed time a confirmed schedule.

## Request schema 1

Every request file must be named requestId.json. requestId uses 1–80 ASCII letters, numbers, hyphens or underscores, starting with a letter or number. Choose stable IDs; a repeated ID returns its original result even if the video was deleted or moved. New parameters require a new requestId. Failed/partial/interrupted jobs are not automatically rerendered: review retained files and request only missing content under a new ID.

Required fields:
- schemaVersion: 1
- kind: "manifestation-batch"
- requestId: unique stable ID
- brief: original human request, up to 10,000 characters
- count: exact number of videos, 1–50
- manifestationIds: allowed catalog recording IDs
- visualStyles: allowed numeric visual IDs
- paletteIds: allowed numeric palette IDs

Optional fields:
- requestedBy, campaign, postFooter: text retained with the original request
- format: portrait (default), square or landscape
- allowedBeats: nonempty subset of delta/theta/alpha; omit for the settings' fixed beat (off by default)
- natureIds: nonempty allowed catalog nature IDs; omit for fixed/none
- chakraIds: nonempty allowed chakra IDs, including column; omit for fixed/none
- clipSeconds: 3–180 seconds from the start of the recording; omit for the whole recording (shorter recordings are not extended)
- settings: studio ExportSettings object, including captions, heading, branding, soundscape and callToAction. The exported plan shows the resolved settings. No arbitrary imported-audio paths, commands, SQL, upload credentials or server endpoints are accepted.

Example ten-video request (replace the manifestation ID with a value from your catalog):

```json
{
  "schemaVersion": 1,
  "kind": "manifestation-batch",
  "requestId": "weekly-calm-001",
  "brief": "Create 10 unique calm manifestation videos for review this week.",
  "count": 10,
  "manifestationIds": ["career-confidence-morning"],
  "visualStyles": [10, 14, 17, 34, 35],
  "paletteIds": [1, 4, 5, 8],
  "allowedBeats": ["theta", "alpha"],
  "natureIds": ["forest_ambience", "ocean"],
  "format": "portrait",
  "campaign": "weekly-calm"
}
```

The studio selects unused combinations and renders sequentially. It does not enumerate/render every variation. If it cannot fill the requested number with unused combinations, it reports failure instead of silently producing fewer clips. Two concurrent requests cannot reserve the same combination. A concurrent collision can stop a partially completed batch; retain completed media, review status, and request the missing count with a new ID.

## Outputs and history

Requests/ contains input. Status/ contains atomic status replies. Ready/requestId/ contains request.json, the resolved plan.json, MP4s, settings receipts, posting text, thumbnails, optional SRT/CTA receipts, and ready.json. Ready/requestId.zip packages the completed batch. Do not consume a partial folder merely because an MP4 appears; require Status/requestId.json to say complete. No social schedule is implied.

The authoritative SQLite database and its backup live in ~/Library/Application Support/ZenWave Content Studio, outside Git and the exchange. Use one designated rendering Mac. Do not sync a live SQLite file between computers. Stop the studio before copying history.sqlite to a new authoritative Mac; alternatively copy history-backup.sqlite as history.sqlite while both apps are closed. Import existing export folders before the first production batch. Missing/deleted historical files cannot be reconstructed from chat.

Every manual, random batch, breathing and live video export is checked. Core identity includes source audio content, visual, palette, active beats/nature/chakra and breathing/live sequence. Filenames, aspect ratio, captions, CTA, branding, gains, motion settings and clip length do not make a reused core new. Completed or produced-but-needing-review content stays blocked even if rejected/deleted. Failed renders without output may be retried. Interrupted reservations need explicit recovery in the UI after all other studio processes are closed.

Old receipts without imported-audio content hashes conservatively block the matching core for any imported background. The import report identifies movies it could not reconstruct. Review those before relying on a complete historical duplicate record.

## Publication acknowledgements (optional, never a posting command)

After an authorized platform action returns a real post ID, write Reports/publication-id.json with:

```json
{
  "id": "facebook-actual-post-id",
  "assetId": "asset UUID returned by ZenWave",
  "platform": "facebook",
  "accountId": "actual Page ID",
  "postId": "actual platform post ID",
  "status": "scheduled",
  "scheduledAt": "2026-11-01T18:00:00-07:00",
  "url": "https://www.facebook.com/actual-post"
}
```

The report must reference a produced asset and is idempotent by id. Reusing a report ID with changed details is rejected; use a new event ID for a subsequent published acknowledgement. The accepted/error text beside the report confirms local recording only, not independent platform verification. This version does not fetch Facebook analytics or automatically schedule posts.
