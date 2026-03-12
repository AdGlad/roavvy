# Roavvy — Next Tasks

Concrete tasks to turn the working photo scanning spike into the first shippable Roavvy feature: offline scanning, reliable persistence, and a clean domain model throughout.

**Scope boundary:** Firebase sync, world map view, achievements, sharing cards, and the Shopify store are explicitly out of scope for this milestone. Each task below is self-contained and unblocked unless a dependency is noted.

---

## ~~Task 1~~ — Build `packages/country_lookup` ✓ COMPLETE

**Fixes spike limitation:** CLGeocoder requires a network connection, is rate-limited, and returns locale-dependent country names instead of ISO codes. (ADR-009)

**Why this is the most important task:** It is the structural privacy guarantee in code, not policy. Until this exists, the app cannot fulfil the core claim that scanning works offline.

### What to build

A pure Dart package with a single public function:

```dart
// packages/country_lookup/lib/country_lookup.dart
String? resolveCountry(double latitude, double longitude);
```

Returns an ISO 3166-1 alpha-2 code (e.g. `"GB"`), or `null` if the coordinate is over open water, poles, or otherwise unresolvable.

### Subtasks

1. **Choose and process geodata.** Natural Earth 1:10m land polygons are the baseline. Export as a compact binary format (e.g. flatbuffers or a custom packed format); raw GeoJSON is too large to traverse per lookup. Target: < 15 MB asset, < 5 ms per lookup on iPhone XR equivalent.

2. **Implement point-in-polygon lookup.** Use ray-casting algorithm. Apply coordinate bucketing (same 0.5° grid as the spike) as a first-pass filter before per-polygon checks. Pre-process polygons into a spatial index (grid cells or R-tree) baked into the asset at build time to avoid runtime indexing cost.

3. **Bundle the processed geodata as a Flutter asset.** Loaded once at startup into memory. No runtime download, no CDN, no fallback.

4. **Write the `resolveCountry` function.** Pure function — takes lat/lng, returns ISO code or null. No side effects. Stateless except for the loaded geodata.

5. **Unit tests at 100% coverage.** Mandatory test cases:
   - Known cities resolve to correct country codes (London → GB, Tokyo → JP, New York → US, Paris → FR)
   - Coordinate on open ocean returns null
   - North/South Pole coordinates return null
   - Coordinate exactly on a land border resolves to one of the two neighbouring countries (no crash, no null)
   - All ISO codes returned by the function are valid ISO 3166-1 alpha-2

6. **Replace CLGeocoder in `AppDelegate.swift`.** The Swift bridge calls `resolveCountry` through the Flutter asset bundle or a separate Dart isolate invoked from Swift. Simplest integration: move coordinate resolution entirely to the Flutter layer (Swift passes raw `{lat, lng, capturedAt}` per photo; Flutter calls `resolveCountry`). This also unblocks Task 4.

7. **Delete all CLGeocoder code** from `AppDelegate.swift`. Remove `geocoder`, `geocodeQueue`, `geocodeSerially()`, and the adaptive delay. Remove the `CoreLocation` framework import if it is no longer needed.

8. **Update `scan_mapper.dart`** to no longer expect `DetectedCountry.name` (CLGeocoder-only field). The name field on `InferredCountryVisit` is not needed — the app shows ISO codes.

### Acceptance criteria

- [x] `resolveCountry('51.5', '-0.12')` returns `"GB"` in a test with no network access
- [ ] Scanning 500 photos completes with no CLGeocoder calls, no network permission required  *(deferred to Task 3+4)*
- [x] `packages/country_lookup` has zero external dependencies (check `pubspec.yaml`)
- [x] `dart test` passes at 100% coverage for the package
- [x] All 99 existing tests continue to pass (now 129)

**Deferred from Task 1:** subtasks 6–8 (CLGeocoder removal, Swift bridge update) merged into Task 3+4.  
**Outstanding (pre-production):** inner-ring handling in `build_geodata.py`; smallest-polygon-first ordering in `resolve()` (enclave fix).
**`ne_countries.bin` generated** — bundled as Flutter asset; `main.dart` calls `initCountryLookup` at startup.

### Dependencies

None. This task can start immediately and proceed in parallel with Task 2.

---

## ~~Task 2~~ — Replace `shared_preferences` with Drift SQLite ✓ COMPLETE

**Fixes spike limitation:** The current JSON blob has no querying, no schema migration, and cannot support the sync metadata (`isDirty`, `syncedAt`) needed for future Firestore sync. (ADR-011)

### What to build

A Drift database in `apps/mobile_flutter/lib/data/` with three tables matching the typed domain model from `packages/shared_models`. A repository layer wraps the tables and exposes typed methods.

### Schema

```
inferred_country_visits
  countryCode   TEXT PRIMARY KEY
  inferredAt    TEXT NOT NULL   (ISO 8601 UTC)
  photoCount    INTEGER NOT NULL
  firstSeen     TEXT            (nullable)
  lastSeen      TEXT            (nullable)
  isDirty       INTEGER NOT NULL DEFAULT 1  (sync flag — 1 = dirty)
  syncedAt      TEXT            (nullable)

user_added_countries
  countryCode   TEXT PRIMARY KEY
  addedAt       TEXT NOT NULL
  isDirty       INTEGER NOT NULL DEFAULT 1
  syncedAt      TEXT

user_removed_countries
  countryCode   TEXT PRIMARY KEY
  removedAt     TEXT NOT NULL
  isDirty       INTEGER NOT NULL DEFAULT 1
  syncedAt      TEXT
```

### Subtasks

1. **Add Drift and `drift_flutter` dependencies** to `apps/mobile_flutter/pubspec.yaml`. Add `build_runner` and `drift_dev` to dev dependencies.

2. **Define the three Drift table classes** in `lib/data/db/roavvy_database.dart`. Run `dart run build_runner build` to generate the companion classes.

3. **Write `VisitRepository`** in `lib/data/visit_repository.dart`:
   - `Future<void> saveInferred(InferredCountryVisit)` — upsert; set `isDirty = 1`
   - `Future<void> saveAdded(UserAddedCountry)` — upsert; set `isDirty = 1`
   - `Future<void> saveRemoved(UserRemovedCountry)` — upsert; set `isDirty = 1`
   - `Future<List<InferredCountryVisit>> loadInferred()`
   - `Future<List<UserAddedCountry>> loadAdded()`
   - `Future<List<UserRemovedCountry>> loadRemoved()`
   - `Future<void> clearAll()` — for testing and full-reset flows

4. **Migrate `scan_screen.dart` and `review_screen.dart`** to use `VisitRepository` instead of `VisitStore`. The `_scan()` method writes `InferredCountryVisit` records; the review save writes `UserAddedCountry` / `UserRemovedCountry` tombstones.

5. **One-time migration from the v1 JSON blob.** On first launch after the upgrade, read `roavvy.visits.v1` from SharedPreferences, parse the `CountryVisit` list, convert to the three typed records, write to Drift, then delete the SharedPreferences key.

6. **Delete `visit_store.dart`** once migration is complete. Remove `shared_preferences` from `pubspec.yaml`.

7. **Update all tests** that currently use `SharedPreferences.setMockInitialValues({})` to use Drift's in-memory database: `NativeDatabase.memory()` in test setup.

### Acceptance criteria

- [x] Scan result persists across cold app restart, retrieved from SQLite not SharedPreferences
- [x] Manual add and remove persist and survive restart
- [x] Removing `shared_preferences` from `pubspec.yaml` does not break the build
- [x] `VisitRepository` has unit tests using in-memory Drift database (18 tests)
- [x] All existing widget tests pass with the mocked Drift database
- [ ] `isDirty = 1` is set on every insert/upsert — **deferred:** `isDirty`/`syncedAt` columns not added; deferred until Firestore sync is in scope

### Dependencies

None. Can proceed in parallel with Task 1. Coordinate with Task 5 if refactoring the app layer at the same time.

---

## ~~Task 3~~ — Extend the Swift bridge to return per-photo `capturedAt` ✓ COMPLETE

**Fixes spike limitation:** `InferredCountryVisit.firstSeen` and `lastSeen` are always null because the Swift bridge currently returns only country-level aggregates, not per-photo timestamps. (ADR-013)

### What to build

Change the coordinate-accumulation pass in the Swift bridge to track the min/max `creationDate` per country bucket. Return these as `firstSeen` / `lastSeen` in the country payload.

### Subtasks

1. **Update the bucket accumulator in `AppDelegate.swift`** to carry `(CLLocation, count: Int, firstSeen: Date, lastSeen: Date)` instead of `(CLLocation, Int)`. On each enumerated asset, update `firstSeen = min(existing.firstSeen, asset.creationDate)` and `lastSeen = max(existing.lastSeen, asset.creationDate)`.

2. **Update `geocodeSerially()`** to propagate `firstSeen` / `lastSeen` per bucket through the recursion and into `countryMap`.

3. **Update the channel payload** to include `firstSeen` and `lastSeen` as ISO 8601 UTC strings on each country entry:
   ```json
   {
     "code": "GB",
     "name": "United Kingdom",
     "photoCount": 42,
     "firstSeen": "2019-03-14T10:22:00Z",
     "lastSeen": "2024-08-07T15:30:00Z"
   }
   ```

4. **Update `DetectedCountry` in `photo_scan_channel.dart`** to parse `firstSeen` and `lastSeen` as `DateTime?`.

5. **Update `scan_mapper.dart`** to populate `InferredCountryVisit.firstSeen` and `lastSeen` from the parsed values.

6. **Update widget tests** in `widget_test.dart` to include `firstSeen` / `lastSeen` in the mock `scanPhotos` response where the test exercises date-related behaviour.

### Acceptance criteria

- [ ] After a scan, `InferredCountryVisit.firstSeen` and `lastSeen` are non-null for countries with geotagged photos
- [ ] The dates reflect the actual earliest and latest photo creation dates (verifiable against known photos in the test library)
- [ ] `capturedAt` is never stored beyond the bridge — it is used to compute date ranges only
- [ ] All existing tests pass

### Dependencies

Depends on Task 1 if the coordinate resolution is moved fully to the Flutter layer (Task 1 subtask 6). If CLGeocoder is still in place when this task starts, it can proceed independently.

---

## ~~Task 4~~ — Background isolate and per-photo streaming from Swift to Dart ✓ COMPLETE

**Fixes spike limitation:** The current single `invokeMethod` call blocks Flutter's perspective for the full scan duration. No progress is reported. The approach does not scale to large libraries (10,000+ photos). (ADR-010)

### What to build

Replace the single aggregate `scanPhotos` response with a streaming architecture: Swift sends batches of per-photo records; Flutter processes them on a background isolate; the UI receives progress events.

### New channel contract

```
// Flutter → Swift
invokeMethod('startScan', {'limit': 500, 'sinceDate': '...'})

// Swift → Flutter (event channel, streamed)
EventChannel('roavvy/photo_scan/events')
  // per-batch event:
  {
    'type': 'batch',
    'photos': [
      {'lat': 51.5, 'lng': -0.12, 'capturedAt': '2023-08-14T10:22:00Z'},
      ...
    ]
  }
  // terminal event:
  {
    'type': 'done',
    'inspected': 500,
    'withLocation': 320
  }
```

### Subtasks

1. **Add a `FlutterEventChannel`** to `AppDelegate.swift` alongside the existing `FlutterMethodChannel`. Swift streams photo batches (500 records per batch) as it enumerates `PHAsset.fetchAssets`.

2. **Move coordinate-to-country resolution to a Dart background isolate.** The isolate receives `{lat, lng, capturedAt}` records from the event channel, calls `resolveCountry()` (from Task 1) for each unique bucket, and emits `InferredCountryVisit` records to the main isolate.

3. **Emit progress events** from the background isolate to the main isolate: `{processed: int, total: int, latestCountry: String?}`. The UI uses these to update a progress indicator.

4. **Remove `CLGeocoder` entirely** (this is also Task 1 subtask 7 — coordinate the two tasks to avoid doing it twice).

5. **Update `scan_screen.dart`** to listen to progress events and show a progress bar instead of the current indefinite spinner.

6. **Update tests** to mock the `EventChannel` instead of the `MethodChannel` for the scan flow.

### What was built (Tasks 3+4 combined)

- `AppDelegate.swift`: CLGeocoder and `geocodeQueue` fully removed. `FlutterEventChannel('roavvy/photo_scan/events')` streams `{type:'batch', photos:[{lat,lng,capturedAt},...]}` in batches of 50, followed by `{type:'done', inspected:N, withLocation:M}`.
- `photo_scan_channel.dart`: `startPhotoScan()` returns `Stream<ScanEvent>`; `ScanBatchEvent`, `ScanDoneEvent`, `PhotoRecord` are the typed event types. Legacy `ScanResult`/`DetectedCountry` retained for Task 5 retirement.
- `scan_screen.dart`: `_scan()` processes the event stream with `await for`; each `ScanBatchEvent` is resolved on `Isolate.run(_resolvePhotos)` with 0.5° coordinate bucketing; `firstSeen`/`lastSeen` populated from `capturedAt`; indeterminate progress bar + processed-photo counter during scan.
- `widget_test.dart`: EventChannel mock wiring replaced with injectable `ScanScreen.scanStarter` (plain `Stream.fromIterable`) — avoids FakeAsync deadlock. 18 tests pass.

### Acceptance criteria

- [x] Scanning 500 photos shows incremental progress (LinearProgressIndicator + counter)
- [x] `firstSeen` / `lastSeen` populated from per-photo `capturedAt`
- [x] No CLGeocoder calls — all resolution offline via `country_lookup`
- [x] All scan-flow tests pass against the new contract (18 tests)

---

## ~~Task 5~~ — Migrate the app layer to the typed domain model; retire `CountryVisit` ✓ COMPLETE

**Fixes spike limitation:** `CountryVisit` encoded three distinct domain kinds via `source + isDeleted` flags, allowing invalid combinations. Two merge functions existed in parallel. (ADR-008)

### What was done

- Deleted `country_visit.dart`, `visit_source.dart`, `visit_merge.dart` from `packages/shared_models/lib/src/`
- Deleted their test files (`country_visit_test.dart`, `visit_merge_test.dart`)
- Deleted `scan_mapper.dart` and `scan_mapper_test.dart` — scan_screen.dart already built `InferredCountryVisit` directly from accumulators
- Removed `ScanResult` and `DetectedCountry` legacy spike types from `photo_scan_channel.dart`
- Removed legacy test groups for those types from `widget_test.dart`
- Updated `TravelSummary.fromVisits` to accept `List<EffectiveVisitedCountry>` (removed `CountryVisit` dependency)
- Updated `travel_summary_test.dart` to use `EffectiveVisitedCountry`
- Removed legacy exports from `shared_models.dart`

### Acceptance criteria

- [x] `grep -r "CountryVisit" apps/ packages/` returns zero results
- [x] `grep -r "VisitSource" apps/ packages/` returns zero results
- [x] `grep -r "effectiveVisits(" apps/ packages/` returns zero results
- [x] All tests pass (77 total across shared_models + app)
- [x] `dart analyze` reports zero warnings

---

## Suggested execution order (Milestone 1–5)

```
Task 1 (country_lookup)  ──────────────────────────────────────────► done
Task 2 (Drift)           ──────────────────────────────────────────► done
Task 3 (capturedAt)      ──────────────────────────────────────────► done (combined with Task 4)
Task 4 (streaming)       ──────────────────────────────────────────► done
Task 5 (typed model)     ──────────────────────────────────────────► done
```

---

## Milestone 6 — World Map View

**Goal:** After scanning, the user sees a world map with all their visited countries highlighted. Tapping a country shows visit details.

**Scope boundary:** Continent count, map zoom-to-country, tile background, and vertex simplification are explicitly out of scope for this milestone.

---

## Task 6 — Expose polygon geometry from `packages/country_lookup`

**Why:** `CountryPolygon` and the full polygon list already exist inside `GeodataIndex._polygons` — the data is there but not accessible externally. The map screen needs it to render country outlines.

### Deliverable

A `loadPolygons()` public function in `country_lookup.dart` that returns all `CountryPolygon` records from the loaded binary. `CountryPolygon` exported as part of the package's public API.

### Acceptance criteria

- [ ] `loadPolygons()` returns a non-empty list (≥ 200 entries) after `initCountryLookup()` is called
- [ ] Multiple entries exist for the same `isoCode` (multi-ring countries: US, RU, archipelagos)
- [ ] All returned `isoCode` values are valid ISO 3166-1 alpha-2 (2 uppercase ASCII characters)
- [ ] Calling `loadPolygons()` before `initCountryLookup()` asserts — same contract as `resolveCountry()`
- [ ] All 20 existing `country_lookup` tests continue to pass
- [ ] `country_lookup/CLAUDE.md` updated to document the expanded public API

### Dependencies

None. Can start immediately.

---

## Task 7 — `MapScreen`: world map with visited/unvisited polygon rendering

**Why:** Core product moment — user can see their countries on a map.

### Deliverable

A `MapScreen` widget displaying all country polygons on an offline `flutter_map` canvas, with visited countries in a distinct highlight colour.

### Acceptance criteria

- [ ] `flutter_map` added to `apps/mobile_flutter/pubspec.yaml` only (not in any package)
- [ ] All country polygons rendered; no tile layer (vector-only, offline guarantee preserved)
- [ ] Visited country codes sourced from `VisitRepository` → `effectiveVisitedCountries()`
- [ ] Antarctica (`AQ`) suppressed from rendering
- [ ] No crash on multi-ring countries (US, RU, archipelagos render as multiple polygons)
- [ ] Acceptable scroll/zoom frame rate on a real device (manual validation — document result)
- [ ] Widget test: `MapScreen` renders with a mocked `VisitRepository` returning 0 countries; no crash

### Dependencies

Task 6 (polygon API).

---

## Task 8 — Country tap → detail bottom sheet

**Why:** Turns the map from a display into an interactive record — users can tap any country for visit details.

### Deliverable

Tapping any country polygon opens a `showModalBottomSheet` with visit details.

### Acceptance criteria

- [ ] Tapping a visited country shows: display name, `firstSeen` date, `lastSeen` date, photo count, "manually added" badge when `hasPhotoEvidence == false`
- [ ] Tapping an unvisited country shows: display name only, with a "manually add" action
- [ ] Display name derived from ISO code via `Locale` (offline); falls back to ISO code itself if `Locale` returns null
- [ ] Tapping open water (outside any polygon) does nothing
- [ ] Widget test: tapping a visited polygon in a mocked map shows the expected country name

### Dependencies

Task 7.

---

## Task 9 — App navigation redesign and rename

**Why:** Map is now the primary screen; the app is no longer a spike.

### Deliverable

Bottom navigation bar with Map and Scan tabs. `RoavvySpike` renamed to `RoavvyApp`. Riverpod introduced as the app's state management solution.

### Acceptance criteria

- [ ] Bottom nav: Map tab (default on launch) and Scan tab
- [ ] `RoavvySpike` → `RoavvyApp` everywhere (`main.dart`, widget tests, app title)
- [ ] Map screen shows persisted visit data immediately on launch (no scan required)
- [ ] After scan completes, app navigates to Map tab automatically
- [ ] `geodataBytes` widget constructor arg replaced with a Riverpod provider (`flutter_riverpod` added to `pubspec.yaml`)
- [ ] All existing widget tests pass; new navigation tests cover tab switching

### Dependencies

Task 7. Architect sign-off on Riverpod provider structure required before Builder starts.

---

## Task 10 — Travel stats strip on the map screen

**Why:** Gives users an at-a-glance summary of their travel history without leaving the map screen.

### Deliverable

A fixed stats strip on the `MapScreen` showing aggregate travel stats from the current effective visit set.

### Acceptance criteria

- [ ] Displays: total countries visited, earliest year, latest year (shows "—" when no date metadata)
- [ ] Stats computed from `TravelSummary.fromVisits(effectiveVisitedCountries(...))`
- [ ] Strip updates immediately after a scan completes (no restart required)
- [ ] Continent count explicitly absent — no country→continent mapping exists yet
- [ ] Widget test: strip shows correct counts and year range given mocked visits

### Dependencies

Task 9 (for live refresh after scan).

---

## Suggested execution order (Milestone 6)

```
Task 6 (polygon API) ──► Task 7 (map render) ──► Task 8 (tap detail)
                                             ──► Task 9 (navigation) ──► Task 10 (stats strip)
```

Tasks 8 and 9 can proceed in parallel once Task 7 is done.

---

## Risks / open questions (Milestone 6)

1. **`country_lookup` API contract** — `country_lookup/CLAUDE.md` currently states "exactly this one public function." Adding `loadPolygons()` widens the surface. Architect must confirm before Task 6 starts.
2. **Rendering performance** — ADR-014 explicitly flags this as needing validation. Russia and the US have high vertex counts. If frame rate is unacceptable, vertex simplification must be added to `build_geodata.py` before Task 7 is done.
3. **Multi-ring tap detection** — The binary stores one `CountryPolygon` per ring; the map widget must group by `isoCode` for tap detection. Architect should confirm grouping strategy.
4. **Riverpod introduction (Task 9)** — First use of Riverpod in the app. Architect should define the provider structure before the Builder starts.
5. **Country display names** — `Locale` API is offline but may return null for small territories. Fallback strategy (hardcoded map vs ISO code passthrough) to be decided by Architect.

---

## Out of scope for Milestone 6

- TypeScript counterpart in `packages/shared_models/ts/`
- Firebase Auth integration
- Firestore sync (`isDirty` flush)
- Achievements engine
- Sharing cards
- Shopify integration
