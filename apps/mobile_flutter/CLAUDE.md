# apps/mobile_flutter — CLAUDE.md

## Purpose

The Flutter mobile app. iOS-first. Bridges to Swift PhotoKit via a platform channel to scan photo metadata without uploading images. Handles offline country detection, local persistence, Firebase sync, and user-facing features (map, achievements, sharing).

## Stack

- **Flutter** (Dart) — UI, state management, business logic
- **Swift / PhotoKit** — native photo library access (iOS)
- **Firebase Auth** — anonymous auth, optional sign-in
- **Cloud Firestore** — sync of derived metadata only
- **`packages/country_lookup`** — offline GPS → country resolution
- **`packages/shared_models`** — shared data types

## Key Rules

1. **Never pass photo binary data through the platform channel.** Only GPS coordinates, timestamps, and asset identifiers.
2. **Request photo permissions lazily** — only when the user initiates a scan, never on app launch.
3. **All Firestore writes are derived metadata only** — no filenames, no thumbnails, no EXIF beyond GPS and date.
4. **Offline-first state**: the app must be fully usable (read, browse, edit) without a network connection. Sync happens opportunistically.
5. **User edits are the source of truth.** Store edits locally first; sync to Firestore as a secondary step.

## Directory Conventions (once scaffolded)

```
lib/
  features/          Feature-first organisation (scan, map, achievements, sharing)
  core/              App-wide services, routing, theme
  data/              Repository layer, local DB, Firestore adapters
ios/
  Runner/
    PhotoScanPlugin/ Swift platform channel implementation
```

## State Management

Use Riverpod. Providers live alongside their feature, not in a global `providers/` folder.

## Testing

- Unit tests for all repository and domain logic.
- Widget tests for any non-trivial UI component.
- No golden tests unless explicitly requested.
- Integration tests for the scan flow (mock the platform channel).

## Related Docs

- [Mobile Scan Flow](../../docs/architecture/mobile_scan_flow.md)
- [Privacy Principles](../../docs/architecture/privacy_principles.md)
- [Offline Strategy](../../docs/architecture/offline_strategy.md)
