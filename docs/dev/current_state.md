# Roavvy — Development State (as of 2026-03-17, through Task 32)

## What Works

The Flutter mobile app runs on a real iPhone with a complete navigation shell, offline world map, and interactive country detail sheets.

**Confirmed working end-to-end:**
- Photo library permission request (iOS Photos framework)
- PhotoKit asset fetch with `fetchLimit` and `sinceDate` incremental-scan predicate
- GPS coordinate extraction from EXIF metadata — streamed as per-photo records via `EventChannel('roavvy/photo_scan/events')`
- **CLGeocoder fully removed** — all country resolution is now offline, via `packages/country_lookup`
- Swift streams `{lat, lng, capturedAt}` per photo in batches of 50; Dart resolves coordinates to ISO codes on a background `Isolate`
- Scan stats display: assets inspected, with/without location, geocode successes/failures, unique countries
- Progress indicator during scanning (indeterminate `LinearProgressIndicator` + processed-photo counter)
- Per-country photo counts and `firstSeen`/`lastSeen` ranges populated from `capturedAt`
- Country visit persistence via Drift SQLite — three typed tables — survives app restart
- Review screen: remove a detected country, manually add a country, save the corrected list
- User edits (add / remove) written as typed records; removals create `UserRemovedCountry` tombstones
- **World map**: offline flutter_map canvas showing all country polygons; visited countries highlighted green; Antarctica suppressed
- **Country tap → detail sheet**: tapping any polygon opens a bottom sheet with visit details (name, dates, photo count, manually-added badge); tapping unvisited country shows "Add to my countries" action; open water taps do nothing
- **Bottom navigation shell**: Map tab (default) and Scan tab; `IndexedStack` keeps both alive; after scan completes, app auto-navigates to Map tab
- **Riverpod provider graph**: `geodataBytesProvider`, `roavvyDatabaseProvider`, `visitRepositoryProvider`, `polygonsProvider`, `effectiveVisitsProvider`, `travelSummaryProvider` in `lib/core/providers.dart`
- **`RoavvySpike` fully retired** — renamed to `RoavvyApp`; app title is "Roavvy"
- **Stats strip**: `StatsStrip` ConsumerWidget overlaid at bottom of `MapScreen`; shows country count, earliest year, latest year; "—" when no date metadata; watches `travelSummaryProvider`
- **Delete travel history**: `PopupMenuButton` (⋮, top-right) on `MapScreen` with a single "Delete Travel History" item; shows `AlertDialog` confirmation; on confirm calls `VisitRepository.clearAll()` and invalidates `effectiveVisitsProvider` + `travelSummaryProvider`; clears `lastScanAt` so next scan is a full scan
- **Map empty state**: `_EmptyStateOverlay` widget shown in the `MapScreen` Stack when no countries are visited; copy invites user to scan; "Scan Photos" button navigates to the Scan tab via `onNavigateToScan` callback wired from `MainShell._goToScan()`
- **Firebase Auth**: `firebase_core` + `firebase_auth` initialised in `main()` (parallel with geodata + DB init); anonymous sign-in on first launch; `authStateProvider` (`StreamProvider<User?>`) in `lib/core/providers.dart`
- **Sign in with Apple**: `sign_in_with_apple` + `crypto` packages; SHA-256 nonce flow; anonymous credential upgrade via `linkWithCredential`; "Sign in with Apple" / "Signed in with Apple ✓" in `MapScreen` overflow menu; handles `credential-already-in-use` by signing in directly (ADR-028)
- **Firestore sync**: `cloud_firestore ^5.4.0`; `isDirty`/`syncedAt` columns on all three Drift tables (schema v3); `FirestoreSyncService.flushDirty(uid, repo)` pushes dirty rows to `users/{uid}/inferred_visits`, `users/{uid}/user_added`, `users/{uid}/user_removed`; called fire-and-forget after Apple sign-in (Task 19) and after each scan/review-save (Task 20); `NoOpSyncService` stub used in widget tests; `firestore.rules` scaffold at repo root (ADR-029, ADR-030)
- 94 flutter tests passing; 56 package tests passing; 150 total

**`packages/country_lookup` — implemented and wired into the app:**
- Offline GPS → ISO 3166-1 alpha-2 resolution via point-in-polygon lookup
- Custom compact binary format (`ne_countries.bin`) with 1° grid spatial index — 1.2 MB, 233 countries, 1580 polygons
- `initCountryLookup(Uint8List)` + `resolveCountry(double, double)` + `loadPolygons()` public API
- Zero external dependencies; pure Dart
- 27 tests passing

## Domain Model

`packages/shared_models` defines the canonical domain types:

| Type | Role |
|---|---|
| `InferredCountryVisit` | Country detected from photo GPS by the scan pipeline |
| `UserAddedCountry` | Country explicitly added by the user |
| `UserRemovedCountry` | Permanent tombstone — suppresses inference forever |
| `EffectiveVisitedCountry` | Computed read model; one per code; never stored |
| `TravelSummary` | Aggregate stats: countryCount, earliestVisit, latestVisit |

`CountryVisit`, `VisitSource`, and `effectiveVisits()` have been fully retired (Task 5).

## Key Files

```
apps/mobile_flutter/
  lib/main.dart                           ProviderScope with geodataBytes + DB overrides → RoavvyApp
  lib/app.dart                            RoavvyApp (MaterialApp → MainShell)
  lib/core/providers.dart                 Six Riverpod providers (ADR-018)
  lib/core/country_names.dart             kCountryNames static map (ADR-019)
  lib/features/shell/main_shell.dart      NavigationBar + IndexedStack (Map/Scan tabs)
  lib/features/map/map_screen.dart        ConsumerStatefulWidget; reads polygonsProvider + effectiveVisitsProvider; Stack with StatsStrip
  lib/features/map/stats_strip.dart       StatsStrip ConsumerWidget; watches travelSummaryProvider
  lib/features/map/country_detail_sheet.dart  Bottom sheet: visit details + manual add action
  lib/features/scan/scan_screen.dart      ConsumerStatefulWidget; scan + review flow
  lib/features/visits/review_screen.dart  Review / edit / add / remove countries
  lib/photo_scan_channel.dart             startPhotoScan() / ScanBatchEvent / ScanDoneEvent / PhotoRecord
  lib/data/db/roavvy_database.dart        Drift table definitions (three tables, schema v3 with isDirty/syncedAt)
  lib/data/visit_repository.dart          VisitRepository — typed upsert/load/clear + dirty-load + mark-clean
  lib/data/firestore_sync_service.dart    SyncService interface + FirestoreSyncService + NoOpSyncService
  ios/Runner/AppDelegate.swift            Swift PhotoKit bridge — EventChannel streaming, no CLGeocoder
  assets/geodata/ne_countries.bin         Offline country lookup binary (1.2 MB)

  test/widget_test.dart                   ScanScreen widget + channel unit tests (ProviderScope)
  test/data/visit_repository_test.dart    VisitRepository unit tests (in-memory Drift DB)
  test/data/firestore_sync_service_test.dart  FirestoreSyncService unit tests (FakeFirebaseFirestore)
  test/features/map/map_screen_test.dart  MapScreen widget tests (ProviderScope)
  test/features/map/stats_strip_test.dart StatsStrip widget tests (4 tests)
  test/features/map/country_detail_sheet_test.dart  CountryDetailSheet widget tests (9 tests)
  test/features/shell/main_shell_test.dart  Navigation tab switching tests (3 tests)
  test/features/visits/                   ReviewScreen widget tests
```

## Architecture Decisions

| ADR | Decision | Status |
|---|---|---|
| 001 | iOS-first Flutter app with Swift MethodChannel bridge | Accepted |
| 002 | Photos never leave device; only derived metadata synced | Accepted |
| 003 | Drift SQLite as mobile source of truth; Firestore as sync target | Accepted — Drift built; Firestore sync deferred |
| 004 | `country_lookup` bundles geodata; zero network dependency | Accepted |
| 005 | Coordinate bucketing at 0.5° before geocoding | Accepted |
| 006 | Merge precedence: `manual` > `auto`; later `updatedAt` wins same-source | Accepted |
| 007 | `shared_models` zero-dependency, dual-language (Dart + TS) | Accepted — TS side not yet built |
| 008 | Three typed input kinds + one read model | Accepted |
| 009 | CLGeocoder → `country_lookup` | ✓ Done |
| 010 | Single IPC call → EventChannel streaming | ✓ Done |
| 011 | `shared_preferences` → Drift | ✓ Done |
| 012 | `fetchLimit` + `sinceDate` predicate in PhotoKit bridge | Accepted |
| 013 | `ScanSummary` in `shared_models`; `ScanStats` spike-only | Accepted |
| 014 | flutter_map as polygon rendering library | Accepted |
| 015 | Natural Earth 1:50m in custom compact binary | Accepted |
| 016 | Drift `inferred_country_visits`: one row per country code | Accepted |
| 017 | `country_lookup` exposes polygon geometry via `loadPolygons()` | Accepted |
| 018 | Riverpod as app-layer state management; core provider graph | Accepted — implemented |
| 019 | Country display names from static `kCountryNames` map | Accepted — implemented |
| 020 | Country tap via `MapOptions.onTap` + `resolveCountry()` | Accepted — implemented |
| 021 | Bottom nav shell; ConsumerWidget migration for MapScreen + ScanScreen | Accepted — implemented |
| 025 | Delete history entry point: `PopupMenuButton` overlay on `MapScreen` | Accepted — implemented |
| 026 | Firebase init in `main()`, parallel with geodata + DB | Accepted — implemented |
| 027 | Anonymous auth + `authStateProvider` StreamProvider | Accepted — implemented |
| 028 | Sign in with Apple credential upgrade; `credential-already-in-use` handled | Accepted — implemented |
| 029 | Firestore schema: `users/{uid}/{inferred_visits,user_added,user_removed}/{countryCode}` | Accepted — implemented |
| 030 | Sync architecture: fire-and-forget, silent failure, `NoOpSyncService` in tests | Accepted — implemented |

## Test Coverage

| Layer | Count | Framework |
|---|---|---|
| `packages/shared_models` — merge + TravelSummary | 29 | `dart test` |
| `packages/country_lookup` — lookup + loadPolygons | 27 | `dart test` |
| `apps/mobile_flutter` — channel unit tests | 8 | `flutter test` |
| `apps/mobile_flutter` — VisitRepository | 18 | `flutter test` |
| `apps/mobile_flutter` — ReviewScreen | 13 | `flutter test` |
| `apps/mobile_flutter` — ScanScreen | 11 | `flutter test` |
| `apps/mobile_flutter` — FirestoreSyncService | 6 | `flutter test` |
| `apps/mobile_flutter` — MapScreen | 10 | `flutter test` |
| `apps/mobile_flutter` — StatsStrip | 4 | `flutter test` |
| `apps/mobile_flutter` — CountryDetailSheet | 9 | `flutter test` |
| `apps/mobile_flutter` — MainShell navigation | 3 | `flutter test` |
| **Total** | **145** | |

```bash
cd packages/shared_models && dart test
cd packages/country_lookup && dart test
cd apps/mobile_flutter && flutter test
```

## Phase / Milestone Completion

| Dev Milestone | Product Phase | Status |
|---|---|---|
| M1–7 (Tasks 1–15) | Phase 1 — Core Scan & Map | ✅ Complete |
| M8 (Tasks 16–21) | Phase 2 — Firebase Auth + Firestore sync | ✅ Complete |
| M9 (Tasks 22–25) | Phase 2 — Achievements | ✅ Complete |
| M10 (Tasks 27–28) | Phase 3 — Travel card image + share sheet | ✅ Complete |
| M11 (Tasks 29–30) | Phase 3 — Web share page (`/share/[token]`) | ✅ Complete |
| M12 (Tasks 31–32) | Phase 2/3 Closeout — token revocation + account deletion | ✅ Complete |

**Phases 1, 2, and 3 are fully complete.** The one deferred Phase 2 item (achievement unlock animation) is low priority and has been moved to Phase 5 polish.

**Next milestone:** M13 — Phase 4: Authenticated Web Map. See `docs/dev/backlog.md`.
