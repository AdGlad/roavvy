# apps/mobile_flutter

Flutter (Dart) + Swift PhotoKit bridge. iOS-first.

## Stack

| Layer | Tech |
|---|---|
| UI / state | Flutter + Riverpod (providers alongside feature, not in global folder) |
| Persistence | Drift SQLite (source of truth) |
| Native bridge | Swift MethodChannel + EventChannel (`roavvy/photo_scan`) |
| Sync | Cloud Firestore (derived metadata only) |
| Auth | Firebase Auth (anonymous → Apple Sign-In upgrade) |
| Country lookup | `packages/country_lookup` (offline, bundled asset) |
| Region lookup | `packages/region_lookup` (offline, bundled binary) |

## Hard rules

1. Platform channel carries only `{lat, lng, capturedAt, assetId}` — never photo binary data.
2. Photo permission requested lazily (on user-initiated scan only).
3. Firestore writes: `{countryCode, firstSeen, lastSeen}` + achievement state + share tokens only.
4. App must be fully usable offline (read, browse, edit). Sync is opportunistic.
5. User edits (add/remove) written to Drift first; Firestore is secondary.

## Structure

```
lib/
  features/   Feature-first (scan, map, cards, achievements, merch, …)
  core/       Routing, theme, providers.dart, services
  data/       Repository layer, Firestore adapters
ios/
  Runner/
    PhotoScanPlugin/   Swift EventChannel implementation
    AiTitlePlugin.swift
```

## Testing

- Unit tests for all repository + domain logic.
- Widget tests for non-trivial UI.
- Integration tests for scan flow (mock platform channel).
- No golden tests unless explicitly requested.
- Run: `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
