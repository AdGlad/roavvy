# Mobile Scan Flow

## Overview

The scan flow reads GPS metadata from the photo library, resolves it to country codes on-device, and produces `CountryVisit` records — all without network access and without touching image data.

---

## Full Scan Flow

```
User taps "Scan Photos"
        │
        ▼
Check photo library permission
  ├── Not determined ──► Show rationale UI, request permission
  ├── Denied / restricted ──► Show Settings deep-link, abort
  └── Authorised (full or limited) ──► continue
        │
        │  [incremental scans: PhotoKit filters to assets since lastScanDate]
        ▼
Swift PhotoKit Bridge
  For each photo asset with location data:
  ├── Read CLLocation (lat, lng)
  ├── Read creationDate
  ├── Hold PHAsset.localIdentifier in memory (deduplication only)
  └── Stream batch of {assetId, lat, lng, capturedAt} to Flutter
        │  (no image data, no filenames)
        ▼
Flutter Scan Service  [runs on background isolate]
  For each record in batch:
  ├── Skip if assetId already processed this session (dedup)
  ├── country_lookup.resolveCountry(lat, lng)
  │     └── null → skip (open water or unresolvable)
  ├── Discard lat, lng, assetId
  └── Accumulate: Map<countryCode, {firstSeen, lastSeen}>
        │  [emit progress event per batch → UI progress bar]
        ▼
Merge with local DB (Drift transaction — atomic per batch)
  ├── countryCode not in DB ──► INSERT CountryVisit (source: auto)
  ├── In DB, source = auto  ──► UPDATE firstSeen/lastSeen if range widens
  └── In DB, source = manual ──► SKIP — never overwrite user edits
        │
        ▼
Write lastScanDate to local DB
        │
        ▼
Compute achievement deltas (locally, from updated visit set)
        │
        ▼
Update UI: map, achievements, scan summary
        │
        ▼  [background, when online]
Sync dirty records to Firestore
```

---

## Platform Channel Contract

The Swift bridge sends batches over the method channel. Each record:

```json
{
  "assetId": "8F3A2B1C-...",
  "latitude": 35.6762,
  "longitude": 139.6503,
  "capturedAt": "2023-08-14T10:22:00Z"
}
```

`assetId` is the `PHAsset.localIdentifier`. It is used for within-session deduplication only — it is never written to local DB or Firestore.

Batch size: 500 records. A progress event is emitted after each batch. Scan runs on a background isolate; the UI thread is never blocked.

---

## Incremental Scans

After the first full scan:
- PhotoKit is queried with a date predicate: `creationDate > lastScanDate`.
- Only new assets are processed.
- Results are merged additively using the same rules as full scans.
- Full re-scans (clearing `lastScanDate`) are available from Settings.

---

## Permission States

| State | Behaviour |
|---|---|
| Not determined | Show one-sentence rationale, then request |
| Authorised (full) | Scan all assets with location data |
| Authorised (limited) | Scan available assets; show a notice that results may be incomplete |
| Denied | Show Settings deep-link; do not scan |
| Restricted | Show message explaining system restriction; do not scan |

---

## Error Handling

| Error | Behaviour |
|---|---|
| Permission revoked mid-scan | Stop batch; save partial results committed so far; notify user |
| `resolveCountry` returns null | Skip coordinate silently (open water, poles, edge cases) |
| DB write failure | Drift rolls back the batch transaction; surface error in UI; scan can be retried |
| Platform channel exception | Log; abort scan; surface error in UI |

---

## Performance Targets

- `resolveCountry`: < 5 ms per coordinate on iPhone XR equivalent.
- Channel batching: 500 records per IPC call to minimise serialisation overhead.
- Memory: `assetId` and coordinates are discarded immediately after resolution; peak memory does not grow with photo library size.
