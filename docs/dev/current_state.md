# Roavvy — Development State (as of 2026-03-11)

## What Works

The Flutter mobile app runs on a real iPhone and successfully scans the photo library to detect visited countries.

**Confirmed working end-to-end:**
- Photo library permission request (iOS Photos framework)
- PhotoKit asset fetch with `fetchLimit` and `sinceDate` incremental-scan predicate
- GPS coordinate extraction from EXIF metadata
- Reverse geocoding via CLGeocoder with coordinate bucketing (0.5° grid, ~55 km) to minimise API calls
- Aggregate result returned over `MethodChannel('roavvy/photo_scan')` to Flutter
- Scan stats display: assets inspected, with/without location, geocode successes/failures, unique countries
- Per-country photo counts in the visit list
- Country visit persistence via Drift SQLite — three typed tables (`inferred_country_visits`, `user_added_countries`, `user_removed_countries`) — survives app restart
- Review screen: remove a detected country, manually add a country (2-letter ISO code), save the corrected list
- User edits (add / remove) are written as typed records; removals create `UserRemovedCountry` tombstones that suppress future scan results
- 129 tests passing (55 shared_models + 54 Flutter + 20 country_lookup)

**`packages/country_lookup` — implemented and wired into the app:**
- Offline GPS → ISO 3166-1 alpha-2 resolution via point-in-polygon lookup
- Custom compact binary format (`ne_countries.bin`) with 1° grid spatial index — 1.2 MB, 233 countries, 1580 polygons
- `initCountryLookup(Uint8List)` + `resolveCountry(double, double)` public API
- Zero external dependencies; pure Dart
- Python build script (`tool/build_geodata.py`) processes Natural Earth 1:50m shapefile into binary asset
- `tool/source/` (shapefile) and `tool/.venv/` (Python env) are gitignored per `GEODATA.md`
- 20 tests passing; all known-city, null-return, out-of-range, and binary format cases covered
- **Wired into the app** — `ne_countries.bin` bundled as Flutter asset; `main.dart` calls `initCountryLookup` at startup before `runApp`
- CLGeocoder still active for scanning — removal is Task 3+4

## Domain Model

`packages/shared_models` defines the canonical domain types. The model is split into three write-side input records and two read-side projections:

| Type | Role | File |
|---|---|---|
| `InferredCountryVisit` | Country detected from photo GPS by the scan pipeline | `src/inferred_country_visit.dart` |
| `UserAddedCountry` | Country explicitly added by the user | `src/user_added_country.dart` |
| `UserRemovedCountry` | Permanent tombstone — suppresses inference forever | `src/user_removed_country.dart` |
| `EffectiveVisitedCountry` | Computed read model; one per code; never stored | `src/effective_visited_country.dart` |
| `ScanSummary` | Pipeline metrics + inferred visits from one scan run | `src/scan_summary.dart` |

The effective set is computed by `effectiveVisitedCountries()` (`src/effective_visit_merge.dart`):
1. Build a removal set from all `UserRemovedCountry` records — these suppress everything.
2. Merge `InferredCountryVisit` records by country code across scan runs (earliest `firstSeen`, latest `lastSeen`, summed `photoCount`).
3. Apply `UserAddedCountry` records for any code not in the removal set.

`CountryVisit` (the original flat model) is retained in `shared_models` for legacy mapper tests only. It will be retired in Task 5.

## Key Files

```
apps/mobile_flutter/
  ios/Runner/AppDelegate.swift           Swift PhotoKit + CLGeocoder bridge (spike — to be replaced)
  lib/photo_scan_channel.dart            Dart MethodChannel wrapper + ScanStats types
  lib/scan_screen.dart                   Main scan UI (permission, scan, stats, list)
  lib/features/scan/scan_mapper.dart     DetectedCountry → CountryVisit / InferredCountryVisit conversion
  lib/data/db/roavvy_database.dart       Drift table definitions (three tables, @DataClassName row types)
  lib/data/visit_repository.dart         VisitRepository — typed upsert/load/clear/close
  lib/features/visits/review_screen.dart Review / edit / add / remove countries (writes delta to VisitRepository)
  test/widget_test.dart                  ScanScreen widget + channel unit tests
  test/data/visit_repository_test.dart   VisitRepository unit tests (18 tests, in-memory Drift DB)
  test/features/visits/                  ReviewScreen widget tests
  assets/geodata/ne_countries.bin        Offline country lookup binary (1.2 MB, 233 countries)

packages/country_lookup/                 ✓ Implemented and wired into app
  lib/country_lookup.dart                Public API: initCountryLookup + resolveCountry
  lib/src/lookup_engine.dart             Parses binary + orchestrates lookup
  lib/src/binary_format.dart             Binary parser + 1° grid spatial index
  lib/src/point_in_polygon.dart          Ray-casting algorithm
  test/country_lookup_test.dart          20 tests
  test/test_geodata_builder.dart         In-process binary builder for tests
  tool/build_geodata.py                  Converts Natural Earth shapefile → ne_countries.bin
  GEODATA.md                             Build pipeline documentation

packages/shared_models/
  lib/src/inferred_country_visit.dart    Scan pipeline output record
  lib/src/user_added_country.dart        User-initiated add
  lib/src/user_removed_country.dart      User-initiated removal (tombstone)
  lib/src/effective_visited_country.dart Read model — computed effective set entry
  lib/src/scan_summary.dart              Per-run pipeline metrics + inferred visits
  lib/src/effective_visit_merge.dart     effectiveVisitedCountries() merge function
  lib/src/country_visit.dart             Legacy flat model (storage format, spike only)
  lib/src/visit_merge.dart               effectiveVisits() — legacy merge for CountryVisit
  test/effective_visit_merge_test.dart   22 tests for the typed merge function

docs/architecture/
  decisions.md                           16 ADRs covering all key design decisions
```

## Architecture Decisions

All decisions are recorded with context and consequences in [docs/architecture/decisions.md](decisions.md). Summary:

| ADR | Decision | Status |
|---|---|---|
| 001 | iOS-first Flutter app with Swift MethodChannel bridge | Accepted |
| 002 | Photos never leave device; only derived metadata synced | Accepted |
| 003 | Drift SQLite as mobile source of truth; Firestore as sync target | Accepted — Drift built (Task 2); Firestore sync deferred |
| 004 | `country_lookup` bundles geodata; zero network dependency | Accepted — package built, binary generated and bundled |
| 005 | Coordinate bucketing at 0.5° before geocoding | Accepted |
| 006 | Merge precedence: `manual` > `auto`; later `updatedAt` wins same-source | Accepted |
| 007 | `shared_models` is zero-dependency and dual-language (Dart + TS) | Accepted — TS side not yet built |
| 008 | Three typed input kinds + one read model for the domain visit model | Accepted |
| 009 | CLGeocoder in spike; superseded by `country_lookup` for production | Spike only |
| 010 | Single aggregate IPC call in spike; superseded by streaming | Spike only |
| 011 | `shared_preferences` for spike persistence; superseded by Drift | Superseded — removed (Task 2) |
| 012 | `fetchLimit` + `sinceDate` predicate in PhotoKit bridge | Accepted |
| 013 | `ScanSummary` in `shared_models`; channel-layer `ScanStats` is spike-only | Accepted |
| 014 | flutter_map as the polygon rendering library for the world map view | Accepted |
| 015 | Single Natural Earth 1:50m asset in custom compact binary; app layer loads bytes | Accepted |
| 016 | Drift `inferred_country_visits`: one row per country code; scan history deferred | Accepted |

## Test Coverage

| Layer | Count | Framework |
|---|---|---|
| `packages/shared_models` — `CountryVisit` + `TravelSummary` | 21 | `dart test` |
| `packages/shared_models` — `effectiveVisits` (legacy merge) | 12 | `dart test` |
| `packages/shared_models` — `effectiveVisitedCountries` (typed merge) | 22 | `dart test` |
| `packages/country_lookup` — known cities, null returns, border cases, binary format | 20 | `dart test` |
| `apps/mobile_flutter` — channel unit tests | 8 | `flutter test` |
| `apps/mobile_flutter` — `VisitRepository` unit tests | 18 | `flutter test` |
| `apps/mobile_flutter` — `ReviewScreen` widget tests | 13 | `flutter test` |
| `apps/mobile_flutter` — `ScanScreen` widget tests | 15 | `flutter test` |
| **Total** | **129** | |

```bash
cd packages/shared_models && dart test
cd packages/country_lookup && dart test
cd apps/mobile_flutter && flutter test
```

## Next Milestones (priority order)

1. ~~**Generate `ne_countries.bin`**~~ — ✓ Complete. Binary generated (1.2 MB), bundled as Flutter asset, `initCountryLookup` called in `main.dart` at startup.

2. ~~**Drift SQLite persistence**~~ — ✓ Complete (Task 2). Three Drift tables, `VisitRepository`, `scan_mapper` updated, `shared_preferences` removed.

3. **Background isolate + streaming + CLGeocoder removal** — stream `{lat, lng, capturedAt}` per photo over EventChannel; Dart background isolate calls `resolveCountry`; progress events to UI; delete all CLGeocoder code. (Tasks 3+4 combined — requires `ne_countries.bin` to exist)

4. **Typed domain model migration** — retire `CountryVisit`, `VisitSource`, `effectiveVisits()`; all app-layer code uses the three typed records throughout. (Task 5 — depends on Task 2)

5. **TypeScript counterpart in `shared_models`** — `packages/shared_models/ts/` types required before first `apps/web_nextjs` usage.

6. **Firebase sync**, **world map view**, **achievements**, **sharing cards**, **Shopify** — each depends on the layers above.

## Spike Limitations (explicit — to be fixed before shipping)

| Limitation | ADR | Replacement | Status |
|---|---|---|---|
| CLGeocoder: network-required, rate-limited, locale-dependent country names | ADR-009 | `packages/country_lookup` | Package built and wired; CLGeocoder removal is Task 3+4 |
| `shared_preferences`: single JSON blob, no querying, no migration | ADR-011 | Drift SQLite | ✓ Done (Task 2) |
| Single aggregate IPC call: no streaming, no progress | ADR-010 | Background isolate + EventChannel | Not started (Task 4) |
| `CountryVisit` as storage format: invalid combinations possible | ADR-008 | Retire after Drift migration | Not started (Task 5) |
| `firstSeen` / `lastSeen` not populated | ADR-013 | Extend Swift bridge contract | Not started (Task 3+4) |
| `geocodeAttempts` == `assetsWithLocation` | ADR-013 | Extend Swift bridge contract | Not started (Task 3+4) |
