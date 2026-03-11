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

## Task 3 — Extend the Swift bridge to return per-photo `capturedAt`

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

## Task 4 — Background isolate and per-photo streaming from Swift to Dart

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

### Acceptance criteria

- [ ] Scanning 500 photos shows incremental progress (not just a spinner)
- [ ] Scan completes with correct results on a library with 1,000+ photos
- [ ] The Flutter main thread is not blocked during scanning (frame rate does not drop)
- [ ] All resolution happens on a background isolate — verifiable by checking isolate IDs in debug output
- [ ] All existing scan-flow tests pass against the new contract

### Dependencies

Depends on Task 1 (country_lookup must exist before resolution moves to Dart). Task 3 (per-photo capturedAt) should be implemented simultaneously since both change the Swift enumeration loop.

---

## Task 5 — Migrate the app layer to the typed domain model; retire `CountryVisit`

**Fixes spike limitation:** `CountryVisit` encodes three distinct domain kinds via `source + isDeleted` flags, which allows invalid combinations. Two merge functions exist in parallel. (ADR-008)

This task is the clean-up pass after Tasks 1–4 are done. It retires the legacy code paths.

### Subtasks

1. **Update `scan_mapper.dart`** to produce `InferredCountryVisit` directly from the scan output, not `CountryVisit`. The mapper currently converts `DetectedCountry → CountryVisit(source: auto)` — change it to `DetectedCountry → InferredCountryVisit`.

2. **Update `review_screen.dart`** to operate on `UserAddedCountry` and `UserRemovedCountry` directly instead of building `CountryVisit` with `source: manual` and `isDeleted` flags.

3. **Update `scan_screen.dart`** to call `effectiveVisitedCountries()` (the typed merge function) instead of `effectiveVisits()` (the legacy flat merge). The `_effectiveVisits: List<CountryVisit>` state field becomes `List<EffectiveVisitedCountry>`.

4. **Update `_VisitList`** in `scan_screen.dart` to consume `EffectiveVisitedCountry` instead of `CountryVisit`. The `hasPhotoEvidence` field replaces the `source == VisitSource.manual` check for showing the manual icon.

5. **Delete `visit_source.dart`**, `visit_merge.dart`, and `country_visit.dart`** from `packages/shared_models/lib/src/` once no consumer references them. Remove their exports from `shared_models.dart`.

6. **Update all tests** that construct `CountryVisit` to use the three typed factory helpers instead.

7. **Remove `shared_models` exports** for the deleted files. Run `dart analyze` across both packages and the app to confirm no remaining references.

### Acceptance criteria

- [ ] `grep -r "CountryVisit" apps/ packages/` returns zero results
- [ ] `grep -r "VisitSource" apps/ packages/` returns zero results
- [ ] `grep -r "effectiveVisits(" apps/ packages/` returns zero results (only `effectiveVisitedCountries` is used)
- [ ] All tests pass
- [ ] `dart analyze` reports zero warnings

### Dependencies

Depends on Task 2 (Drift) being complete, since the Drift repository already writes typed records. Tasks 1, 3, and 4 should be done first to avoid mid-task channel contract conflicts.

---

## Suggested execution order

```
Task 1 (country_lookup)  ──────────────────────────────────────────► done
                                                                        │
Task 2 (Drift)           ──────────────────────────────────────────► done
                                                                        │
Task 3 (capturedAt)  ─┐                                                 │
                       ├──► both done ──► Task 4 (streaming) ──────────┤
Task 1 ───────────────┘                                                 │
                                                                        │
                                                         all done ──► Task 5 (typed model)
```

Tasks 1 and 2 are fully independent and can be worked in parallel. Tasks 3 and 4 share changes to the Swift bridge and should be done together. Task 5 is the final integration and clean-up pass.

---

## Out of scope for this milestone

The following are the subsequent milestones and must not be started until the five tasks above are complete:

- TypeScript counterpart in `packages/shared_models/ts/`
- Firebase Auth integration
- Firestore sync (`isDirty` flush)
- World map view
- Achievements engine
- Sharing cards
- Shopify integration
