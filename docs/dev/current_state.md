# Roavvy — Development State (as of 2026-03-19, through Task 49)

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
- **4-tab navigation shell**: Map · Journal · Stats · Scan (ADR-052); `IndexedStack` keeps all tabs alive; after scan completes, app auto-navigates to Map tab; tab indices locked (Map=0, Journal=1, Stats=2, Scan=3)
- **Riverpod provider graph**: `geodataBytesProvider`, `roavvyDatabaseProvider`, `visitRepositoryProvider`, `polygonsProvider`, `effectiveVisitsProvider`, `travelSummaryProvider`, `tripRepositoryProvider`, `regionRepositoryProvider`, `achievementRepositoryProvider`, `regionCountProvider` in `lib/core/providers.dart`
- **`RoavvySpike` fully retired** — renamed to `RoavvyApp`; app title is "Roavvy"
- **Stats strip**: `StatsStrip` ConsumerWidget overlaid at bottom of `MapScreen`; shows country count, earliest year, latest year; "—" when no date metadata; watches `travelSummaryProvider`
- **Delete travel history**: `PopupMenuButton` (⋮, top-right) on `MapScreen` with a single "Delete Travel History" item; shows `AlertDialog` confirmation; on confirm calls `VisitRepository.clearAll()` and invalidates `effectiveVisitsProvider` + `travelSummaryProvider`; clears `lastScanAt` so next scan is a full scan
- **Map empty state**: `_EmptyStateOverlay` widget shown in the `MapScreen` Stack when no countries are visited; copy invites user to scan; "Scan Photos" button navigates to the Scan tab via `onNavigateToScan` callback wired from `MainShell._goToScan()`
- **Firebase Auth**: `firebase_core` + `firebase_auth` initialised in `main()` (parallel with geodata + DB init); anonymous sign-in on first launch; `authStateProvider` (`StreamProvider<User?>`) in `lib/core/providers.dart`
- **Sign in with Apple**: `sign_in_with_apple` + `crypto` packages; SHA-256 nonce flow; anonymous credential upgrade via `linkWithCredential`; "Sign in with Apple" / "Signed in with Apple ✓" in `MapScreen` overflow menu; handles `credential-already-in-use` by signing in directly (ADR-028)
- **Firestore sync**: `cloud_firestore ^5.4.0`; `isDirty`/`syncedAt` columns on all three Drift tables (schema v3); `FirestoreSyncService.flushDirty(uid, repo)` pushes dirty rows to `users/{uid}/inferred_visits`, `users/{uid}/user_added`, `users/{uid}/user_removed`; called fire-and-forget after Apple sign-in (Task 19) and after each scan/review-save (Task 20); `NoOpSyncService` stub used in widget tests; `firestore.rules` scaffold at repo root (ADR-029, ADR-030)
- **Trip intelligence**: `TripRecord` domain model; `TripInference.inferTrips()` clusters photo records by country + 30-day gap; `TripRepository` persists inferred trips; `TripEditSheet` for manual trip date edits; schema v5 `trips` table
- **Region detection**: `packages/region_lookup` — offline ISO 3166-2 admin1 polygon lookup; custom compact binary (`ne_admin1.bin`, 3.5 MB); `RegionVisit` domain model; `RegionRepository`; region count + expandable region list in `CountryDetailSheet`; schema v7 `region_visits` table
- **Bootstrap service**: `BootstrapService` re-derives trips and region visits from existing photo scan records on app launch (catches up users who scanned before these features existed)
- **Journal screen**: `JournalScreen` (tab 1); chronological trip list grouped by year; country flag emoji; taps open `CountryDetailSheet`; empty state with "Scan Photos" CTA
- **Stats screen**: `StatsScreen` (tab 2); stats panel (countries, regions, since year) with "—" fallback; achievement gallery grid (unlocked first, sorted by unlock date; then locked); amber trophy icon for unlocked, grey lock for locked; unlock date shown on unlocked cards
- **Web map** (`apps/web_nextjs`): Next.js 15 app; `/sign-in` (Sign in with Google + Apple via Firebase Auth JS SDK); `/map` authenticated route (guard → redirect); reads `users/{uid}/inferred_visits`, `user_added`, `user_removed` from Firestore; computes effective visits client-side; renders world map via Leaflet; `/share/[token]` share page
- 291 flutter tests passing; 83 package tests passing; 374 total

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
| `TripRecord` | Inferred or manually-edited trip: id, countryCode, startedOn, endedOn, photoCount |
| `RegionVisit` | Sub-national region visit: tripId, countryCode, regionCode, firstSeen, lastSeen, photoCount |
| `PhotoDateRecord` | Per-photo record from scan pipeline: lat, lng, capturedAt, regionCode |
| `Achievement` | Achievement definition: id, title, description |
| `AchievementEngine` | Pure static `evaluate()` → Set of unlocked achievement IDs |

`CountryVisit`, `VisitSource`, and `effectiveVisits()` have been fully retired (Task 5).

## Key Files

```
apps/mobile_flutter/
  lib/main.dart                           ProviderScope with geodataBytes + DB overrides → RoavvyApp
  lib/app.dart                            RoavvyApp (MaterialApp → MainShell)
  lib/core/providers.dart                 Six Riverpod providers (ADR-018)
  lib/core/country_names.dart             kCountryNames static map (ADR-019)
  lib/features/shell/main_shell.dart      NavigationBar + IndexedStack (Map/Journal/Stats/Scan tabs, ADR-052)
  lib/features/map/map_screen.dart        ConsumerStatefulWidget; reads polygonsProvider + effectiveVisitsProvider; Stack with StatsStrip
  lib/features/map/stats_strip.dart       StatsStrip ConsumerWidget; watches travelSummaryProvider
  lib/features/map/country_detail_sheet.dart  Bottom sheet: visit details + manual add action
  lib/features/scan/scan_screen.dart      ConsumerStatefulWidget; scan + review flow
  lib/features/journal/journal_screen.dart  Trip list grouped by year; country flag; opens CountryDetailSheet
  lib/features/stats/stats_screen.dart    Stats panel + achievement gallery (ADR-052 Decision 3)
  lib/features/visits/review_screen.dart  Review / edit / add / remove countries
  lib/photo_scan_channel.dart             startPhotoScan() / ScanBatchEvent / ScanDoneEvent / PhotoRecord
  lib/data/db/roavvy_database.dart        Drift table definitions (schema v7: visits + trips + regions + achievements + scan_meta)
  lib/data/visit_repository.dart          VisitRepository — typed upsert/load/clear + dirty-load + mark-clean
  lib/data/trip_repository.dart           TripRepository — upsert, loadAll, loadByCountry, clear
  lib/data/region_repository.dart         RegionRepository — upsert, loadByCountry, loadByTrip, countUnique, clearAll
  lib/data/achievement_repository.dart    AchievementRepository — upsertAll, loadAll, loadAllRows, loadDirty, markClean
  lib/data/bootstrap_service.dart         BootstrapService — re-derives trips + region visits from existing scan data
  lib/data/firestore_sync_service.dart    SyncService interface + FirestoreSyncService + NoOpSyncService
  lib/core/region_names.dart              kRegionNames — ISO 3166-2 → English name (~400 entries)
  ios/Runner/AppDelegate.swift            Swift PhotoKit bridge — EventChannel streaming, no CLGeocoder
  assets/geodata/ne_countries.bin         Offline country lookup binary (1.2 MB)

  test/widget_test.dart                   ScanScreen widget + channel unit tests (ProviderScope)
  test/data/visit_repository_test.dart    VisitRepository unit tests (in-memory Drift DB)
  test/data/firestore_sync_service_test.dart  FirestoreSyncService unit tests (FakeFirebaseFirestore)
  test/features/map/map_screen_test.dart  MapScreen widget tests (ProviderScope)
  test/features/map/stats_strip_test.dart StatsStrip widget tests (4 tests)
  test/features/map/country_detail_sheet_test.dart  CountryDetailSheet widget tests (9 tests)
  test/features/shell/main_shell_test.dart  Navigation tab switching tests (6 tests)
  test/features/journal/journal_screen_test.dart  JournalScreen widget tests (11 tests)
  test/features/stats/stats_screen_test.dart      StatsScreen widget tests (8 tests)
  test/features/visits/                   ReviewScreen + TripEditSheet widget tests
  test/data/trip_repository_test.dart     TripRepository unit tests
  test/data/region_repository_test.dart   RegionRepository unit tests
  test/data/achievement_repository_test.dart  AchievementRepository unit tests
  test/data/bootstrap_service_test.dart   BootstrapService unit tests

packages/region_lookup/
  lib/region_lookup.dart                  initRegionLookup() / resolveRegion(lat, lng) / loadRegionPolygons()
  assets/geodata/ne_admin1.bin            Offline admin1 binary (3.5 MB, ISO 3166-2)
  test/region_lookup_test.dart            Region lookup unit tests

apps/web_nextjs/
  src/app/sign-in/page.tsx               Firebase Auth sign-in (Google + Apple)
  src/app/map/page.tsx                   Authenticated world map (Leaflet + Firestore)
  src/app/share/[token]/page.tsx         Public share page
  src/lib/firebase/effectiveVisits.ts    Client-side effective-visits merge logic
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
| 031 | Startup dirty-row flush on launch | Accepted — implemented |
| 032 | Explicit Firestore offline persistence settings | Accepted — implemented |
| 034 | Achievement domain model in `shared_models`; 8 achievements; `kAchievements` catalogue | Accepted — implemented |
| 035 | `kCountryContinent` map; 6 inhabited continents; territories mapped to administering country | Accepted — implemented |
| 036 | `unlocked_achievements` Drift table; `isDirty`/`syncedAt` columns | Accepted — implemented |
| 037 | Achievement evaluation at scan + review-save + startup flush write sites | Accepted — implemented |
| 038 | Achievement Firestore sync; SnackBar unlock notification | Accepted — implemented |
| 039 | Auth persistence: remove forced sign-out; add sign-out action to MapScreen overflow menu | Accepted — implemented |
| 040 | Travel card: `TravelCardWidget` + screenshot-to-share via iOS share sheet | Accepted — implemented |
| 041 | Share token: Firestore `share_tokens` collection; `/share/[token]` web route | Accepted — implemented |
| 042 | Privacy settings screen; share token revocation | Accepted — implemented |
| 043 | Account deletion: two-confirm dialog; purge auth + Firestore + local data | Accepted — implemented |
| 049 | `packages/region_lookup`: custom compact binary format for admin1 polygons | Accepted — implemented |
| 051 | `RegionVisit` + `region_visits` Drift table; schema v7; region resolution in scan pipeline | Accepted — implemented |
| 052 | 4-tab shell index contract (Map=0, Journal=1, Stats=2, Scan=3); no numeric literals outside `MainShell` | Accepted — implemented |

## Test Coverage

| Layer | Count | Framework |
|---|---|---|
| `packages/shared_models` — merge, TravelSummary, AchievementEngine, TripInference | 56 | `dart test` |
| `packages/country_lookup` — lookup + loadPolygons | 27 | `dart test` |
| `packages/region_lookup` — region lookup | ~10 | `dart test` |
| `apps/mobile_flutter` — all flutter tests | 291 | `flutter test` |
| **Total** | **~374** | |

`flutter test` covers: channel unit tests, VisitRepository, ReviewScreen, ScanScreen, FirestoreSyncService, MapScreen, StatsStrip, CountryDetailSheet, MainShell (6), JournalScreen (11), StatsScreen (8), TripRepository, RegionRepository, AchievementRepository, BootstrapService, TripEditSheet, SignInScreen, AccountDeletionService, ShareTokenService, TravelCardWidget, providers, and achievement evaluation.

```bash
cd packages/shared_models && dart test
cd packages/country_lookup && dart test
cd packages/region_lookup && dart test
cd apps/mobile_flutter && flutter test
```

## Phase / Milestone Completion

| Dev Milestone | Product Phase | Status |
|---|---|---|
| M1–7 (Tasks 1–15) | Phase 1 — Core Scan & Map | ✅ Complete |
| M8 (Tasks 16–21) | Phase 2 — Firebase Auth + Firestore sync | ✅ Complete |
| M9 (Tasks 22–26) | Phase 2 — Achievements | ✅ Complete |
| M10 (Tasks 27–28) | Phase 3 — Travel card image + share sheet | ✅ Complete |
| M11 (Tasks 29–30) | Phase 3 — Web share page (`/share/[token]`) | ✅ Complete |
| M12 (Tasks 31–32) | Phase 2/3 Closeout — token revocation + account deletion | ✅ Complete |
| M13 (Tasks 33–37) | Phase 4 — Authenticated web map (`/sign-in`, `/map`) | ✅ Complete |
| M15 (Tasks 38–41) | Phase 5 — Trip intelligence (TripRecord, TripInference, TripRepository, TripEditSheet) | ✅ Complete |
| M16 (Tasks 42–46) | Phase 6 — Region detection (`region_lookup`, RegionVisit, RegionRepository, CountryDetailSheet) | ✅ Complete |
| M17 (Tasks 47–49) | Phase 7 — 4-tab shell, JournalScreen, StatsScreen + achievement gallery | ✅ Complete |

**Phases 1–7 are complete.** Deferred items: Phase 4 web sign-up (M14), achievement unlock animation (absorbed into Phase 8), Phase 6 continent overlay and city detection.

**Next milestone:** M18 — Phase 8: Celebrations & Delight. See `docs/dev/backlog.md`.
