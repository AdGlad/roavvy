# Architecture Decision Records

Lightweight ADRs for Roavvy. Each decision records **what** was chosen, **why**, and **what it costs**. Superseded decisions are kept for historical context and marked with their replacement.

---

## ADR-001 — iOS-first mobile app in Flutter with a Swift platform bridge

**Status:** Accepted

**Context:** The core feature (scanning the photo library) requires PhotoKit, which is an iOS-only framework written in Objective-C/Swift. React Native, Capacitor, and pure Flutter all require a native Swift layer to access PhotoKit. The web app target (travel map, sharing) is independent of the scanning capability.

**Decision:** Build the mobile app in Flutter. All PhotoKit access lives in a Swift `AppDelegate` implementation, exposed to Flutter over a `MethodChannel`. The Flutter layer owns scan orchestration, data persistence, and UI.

**Consequences:**
- Android support requires an equivalent Java/Kotlin MediaStore bridge — doable but not scheduled.
- The Swift bridge is tested via Flutter widget tests using `TestDefaultBinaryMessengerBinding`; no unit tests run inside Swift directly.
- The channel contract (method names, payload shapes) is the critical interface boundary — any change requires updating both sides.

---

## ADR-002 — Photos never leave the device; only derived metadata synced

**Status:** Accepted

**Context:** The core user-trust concern: will Roavvy upload my photos? Privacy must be a structural guarantee, not a policy one — "we say we won't" is weaker than "the code cannot."

**Decision:** The Swift bridge reads only `CLLocation` and `creationDate` from `PHAsset`. Image data is never accessed. GPS coordinates are streamed from Swift to the Dart layer via `EventChannel` for offline resolution by `packages/country_lookup`. After `resolveCountry()` returns, coordinates are released from memory — they are never written to the local database and never sent over any network connection. Only `{countryCode, firstSeen, lastSeen}` crosses any persistence boundary.

**Consequences:**
- Cannot re-resolve historical GPS data if the geodata is updated; requires a re-scan.
- Cannot produce a precise travel map (city-level, route-level) without revisiting this constraint.
- App Store usage string must accurately describe metadata-only access.
- Firestore security rules and local DB schema can be audited for this constraint — reviewers have a clear falsifiable claim to check.

See: [Privacy Principles](privacy_principles.md)

---

## ADR-003 — Local SQLite (Drift) as the mobile source of truth; Firestore as sync target

**Status:** Accepted (Drift not yet implemented — see ADR-011 for current spike state)

**Context:** The app must work fully offline. If Firestore were the source of truth, any cloud read failure would block the user from viewing their own travel data.

**Decision:** All mutations write to local SQLite first. The UI always reads from local state. Firestore is updated asynchronously in the background when connectivity is available. Conflict resolution is deterministic (see ADR-006), so no interactive conflict UI is needed.

**Consequences:**
- Schema migrations must be managed with Drift's migration system as the model evolves.
- The sync layer needs `isDirty` / `syncedAt` columns that are not part of the shared domain model.
- Multi-device edits can conflict; the deterministic merge rules mean the device with the later `updatedAt` wins rather than asking the user.
- First sync after offline edits must push all dirty records in one pass.

See: [Offline Strategy](offline_strategy.md)

---

## ADR-004 — `packages/country_lookup` bundles geodata; zero network dependency

**Status:** Accepted (package not yet implemented — CLGeocoder used in spike, see ADR-009)

**Context:** Country resolution must work offline. CLGeocoder (Apple's geocoder) requires a network connection and is rate-limited. A bundled dataset eliminates both problems.

**Decision:** `packages/country_lookup` ships Natural Earth polygon data as a Flutter asset. The public API is a single pure function: `String? resolveCountry(double lat, double lng)`. The package has zero dependencies — no network, no file I/O, no Flutter SDK. It is tested in complete isolation.

**Consequences:**
- Binary size increases by the size of the geodata asset (estimated ~10–30 MB compressed depending on precision chosen).
- Border changes and newly recognised countries require an app update.
- The package boundary is the privacy perimeter for coordinate handling — no dependency that can make a network call may ever be added.

See: [Package Boundaries](../engineering/package_boundaries.md)

---

## ADR-005 — Coordinate bucketing at 0.5° before geocoding

**Status:** Accepted

**Context:** A photo library can contain thousands of photos taken within metres of each other (e.g. a beach holiday). Geocoding every unique GPS coordinate is wasteful and, with CLGeocoder, triggers rate limiting.

**Decision:** GPS coordinates are rounded to a 0.5° grid (~55 km at the equator) before geocoding. Only one geocode call is made per unique bucket. Photos within the same bucket are assumed to be in the same country.

**Consequences:**
- A photo taken near a land border (<55 km) could be attributed to the wrong country. Acceptable for a country-level product; unacceptable for a city-level one.
- The deduplication ratio in practice is very high for typical photo libraries (90%+ reduction in CLGeocoder calls observed in spike testing).
- `ScanSummary.geocodeAttempts` reflects the deduplicated bucket count, not `assetsWithLocation`. The Swift bridge does not yet report this separately — both are currently the same value.

---

## ADR-006 — Merge precedence: `manual` beats `auto`; later `updatedAt` wins same-source

**Status:** Accepted

**Context:** The scan pipeline and the user can both produce records for the same country code. The system needs a deterministic rule for which record wins — without user-facing conflict resolution UI.

**Decision:**
1. `manual` source always beats `auto` source for the same country code, regardless of timestamps.
2. Among two records with the same source, the one with the later `updatedAt` wins.
3. A `UserRemovedCountry` tombstone (manual, deleted) suppresses any `InferredCountryVisit` for the same code — including future scan results. Only an explicit user un-delete lifts the suppression.

**Consequences:**
- Once a user manually edits or removes a country, automatic re-scans cannot overwrite it. This is the intended user experience.
- If a user's manual edit is wrong (e.g. they removed a country they did visit), they must manually re-add it. The app cannot self-correct.
- The rules apply identically during scan-time merging and Firestore sync conflict resolution — one code path covers both.

Implemented in: `packages/shared_models/lib/src/effective_visit_merge.dart`, `packages/shared_models/lib/src/visit_merge.dart`

---

## ADR-007 — `packages/shared_models` is a zero-dependency dual-language package

**Status:** Accepted (TypeScript side not yet implemented)

**Context:** The mobile app (Dart) and web app (TypeScript) both need the same data model. Duplicating models creates drift and bugs.

**Decision:** `packages/shared_models` contains Dart models in `lib/` and TypeScript equivalents in `ts/`. Both must be updated in the same PR when any field changes. The package has no external dependencies — only Dart SDK primitives and the `test` package in dev dependencies.

**Consequences:**
- Every model change requires updating two languages. This overhead is the cost of a single source of truth.
- The TypeScript side does not yet exist; it must be created before the first `apps/web_nextjs` usage.
- No code generation (`freezed`, `json_serializable`) is used currently — manual `fromJson`/`toJson` to keep the dependency graph clean. This can be revisited when the model stabilises.

See: [Package Boundaries](../engineering/package_boundaries.md)

---

## ADR-008 — Three typed input kinds + one read model for the domain visit model

**Status:** Accepted

**Context:** The initial `CountryVisit` model used a single class with `source: VisitSource` and `isDeleted: bool` to encode three distinct domain concepts. This encoding allows invalid combinations (`source: auto, isDeleted: true` is semantically impossible) and forces callers to check flags manually.

**Decision:** Introduce three typed write-side records and one read-side projection:

| Type | Role |
|---|---|
| `InferredCountryVisit` | Produced by the scan pipeline; carries photo count and date range |
| `UserAddedCountry` | User explicitly added in the review screen |
| `UserRemovedCountry` | Permanent tombstone — user removed; suppresses future inference |
| `EffectiveVisitedCountry` | Computed read model; never stored; one per code in the effective set |

`CountryVisit` remains as the storage serialisation format until Drift replaces `shared_preferences`. Migration: `source: auto` → `InferredCountryVisit`; `source: manual, !isDeleted` → `UserAddedCountry`; `source: manual, isDeleted` → `UserRemovedCountry`.

**Consequences:**
- Invalid combinations are prevented by the type system — no `isDeleted` flag to forget to check.
- `effectiveVisitedCountries()` takes three typed parameters; callers cannot accidentally pass a mixed list.
- `CountryVisit` is now a leaky abstraction that persists through the spike; two merge functions exist in parallel (`effectiveVisits` and `effectiveVisitedCountries`) until the migration is complete.

Implemented in: `packages/shared_models/lib/src/`

---

## ADR-009 — CLGeocoder used in spike; to be replaced by `country_lookup`

**Status:** Accepted (spike); Superseded by ADR-004 (production path)

**Context:** `packages/country_lookup` does not yet exist. The spike needed a working geocoder to validate the end-to-end scan flow on real hardware.

**Decision:** Use `CLGeocoder` in the Swift bridge for the spike. One shared `CLGeocoder` instance is reused (instantiating per-request triggered Apple's rate limiter immediately). A serial `DispatchQueue` serialises geocoder calls. Adaptive delay: 0.2 s normal, 1.0 s on `CLError.network`.

**Consequences:**
- Scanning requires a network connection in the spike. This is an explicit spike limitation.
- CLGeocoder rate-limit is approximately 50 calls/minute sustained; `limit: 500` + bucketing brings this under the threshold for typical libraries.
- CLGeocoder returns country names in the device locale, not ISO codes. The Swift bridge must map name → ISO code (currently using `Locale` API: `NSLocale(localeIdentifier: "en_US").displayName(forKey: .countryCode, value: name)`).
- All CLGeocoder code is deleted when `country_lookup` is implemented; no production code depends on it.

---

## ADR-010 — Scan result is a single aggregate IPC call in the spike

**Status:** Accepted (spike); To be superseded by streaming architecture

**Context:** The production scan design (ADR-001, [Mobile Scan Flow](mobile_scan_flow.md)) calls for streaming `{assetId, lat, lng, capturedAt}` records per photo on a background isolate with progress events. This architecture is correct for large libraries (10,000+ photos) but adds Flutter isolate complexity that is not needed to validate the core scanning logic.

**Decision:** In the spike, `scanPhotos()` is a single `invokeMethod` call that returns one aggregate map: `{inspected, withLocation, geocodeSuccesses, countries: [...]}`. No streaming, no progress events, no background isolate.

**Consequences:**
- The UI is blocked for the duration of the scan. Acceptable for a developer spike.
- The channel contract (aggregate map) is different from the production contract (stream of per-photo records). Migrating requires changes to both Swift and Dart sides.
- `ScanSummary.geocodeAttempts` cannot be accurately populated until per-photo streaming is implemented; currently set equal to `assetsWithLocation`.

---

## ADR-011 — `shared_preferences` used for spike persistence; Drift SQLite is the target

**Status:** Accepted (spike); To be superseded

**Context:** Drift (SQLite) is the correct persistence layer — it supports querying, schema migrations, and the sync metadata columns (`isDirty`, `syncedAt`) needed for Firestore sync. However, Drift adds setup complexity (code generation, migration management) that is disproportionate to a one-screen spike.

**Decision:** Use `shared_preferences` for the spike, storing the full `List<CountryVisit>` as a single JSON blob under key `roavvy.visits.v1`. The API surface (`VisitStore.load()`, `VisitStore.save()`, `VisitStore.clear()`) is narrow enough to swap behind an interface when migrating to Drift.

**Consequences:**
- No querying — the full list must be loaded and saved atomically each time.
- No schema migration path; `roavvy.visits.v1` key is abandoned and data is lost on schema change.
- Sync metadata columns (`isDirty`, `syncedAt`) cannot be added without migrating to Drift.
- All visit data is held in memory; not viable for libraries with hundreds of countries.

---

## ADR-012 — Per-scan `fetchLimit` and `sinceDate` predicate in PhotoKit

**Status:** Accepted

**Context:** A full scan of a large photo library (100,000+ photos) could run for minutes and exhaust the geocoder. Incremental scans (only new photos since last scan) are the production design but require tracking `lastScanDate`.

**Decision:** The Swift bridge accepts two parameters:
- `limit: Int` — maps to `PHFetchOptions.fetchLimit`, capping at the DB level (not post-fetch). Current spike value: 500.
- `sinceDate: Date?` — when non-null, adds `creationDate > sinceDate` to the `NSPredicate`. Null triggers a full scan.

**Consequences:**
- `fetchLimit` on `PHFetchOptions` is applied at the PhotoKit DB level — O(1) cost regardless of library size.
- `sinceDate` predicate is compound with the location-required predicate; both must be satisfied.
- The Flutter layer is responsible for tracking and passing the correct `sinceDate`; the Swift bridge is stateless.
- First launch and user-initiated full rescans pass `sinceDate: null`.

---

## ADR-013 — `ScanSummary` placed in `shared_models`; `ScanStats` in channel layer is spike-only

**Status:** Accepted

**Context:** The scan statistics (`assetsInspected`, `withLocation`, `geocodeSuccesses`) originated as `ScanStats` in `photo_scan_channel.dart` — the app-layer channel wrapper. As a domain concept, scan stats are potentially useful to both the mobile app and (via sync history) the web app.

**Decision:** `ScanSummary` is defined in `packages/shared_models`. It owns the full picture: pipeline metrics plus the `List<InferredCountryVisit>` produced by the scan. The channel-layer `ScanStats` in `photo_scan_channel.dart` is a spike artifact; it will be replaced by `ScanSummary` when the channel contract is updated for streaming.

**Consequences:**
- `ScanSummary` is the only model in `shared_models` that has an operational flavour (scan metadata) rather than a pure domain flavour. If scan history is never synced to Firestore, this may belong in the app layer instead.
- `ScanSummary.geocodeAttempts` is a distinct field from `assetsWithLocation` to correctly model the bucketing deduplication — but both are set to the same value in the spike until the Swift bridge reports them separately.

---

## ADR-014 — Map rendering library: flutter_map

**Status:** Accepted

**Context:** The world map view must render country polygons from a local dataset, highlight visited countries, and support tap-to-detail. Three options were evaluated:

1. **flutter_map** (BSD-3-Clause) — OSM-based tile map with a `PolygonLayer` for vector overlays. Accepts any lat/lng polygon list; no proprietary shape files.
2. **Syncfusion Flutter Maps** — commercial library with a built-in world map shape file. Requires a Syncfusion licence for commercial use; ships its own polygon dataset independent of Natural Earth.
3. **Custom `CustomPainter`** — render polygons directly on a `Canvas`. Full control, zero dependencies, but requires implementing projection, zoom, pan, and hit-testing from scratch.

**Decision:** Use **flutter_map**. Pass country polygons derived from the same Natural Earth dataset used by `packages/country_lookup`.

**Reasons:**
- BSD-3-Clause licence — no commercial restriction.
- `PolygonLayer` accepts `List<LatLng>` directly; no proprietary shape format required.
- Using the same Natural Earth source as `country_lookup` guarantees that a coordinate classified as country A by the scanner is rendered inside country A's polygon on the map. Syncfusion's independent shape files cannot guarantee this border consistency.
- Custom `CustomPainter` would require implementing zoom, pan, and projection — disproportionate effort for the current milestone.

**Consequences:**
- `flutter_map` is added as a dependency in `apps/mobile_flutter/pubspec.yaml` only. It must not appear in any package.
- The map widget receives a `List<CountryPolygon>` (app-layer value object) and a `Set<String>` of visited country codes. It owns no data loading.
- Tile network access is disabled — the map is used in vector-only mode (no tile layer). This keeps the offline guarantee intact.
- flutter_map's `PolygonLayer` renders all polygons each frame; performance must be validated on a full Natural Earth dataset before the milestone is marked done.

---

## ADR-015 — Country polygon data source: single Natural Earth 1:50m asset

**Status:** Accepted

**Context:** Both `packages/country_lookup` (point-in-polygon lookup) and the map rendering widget need country boundary data. Using two different datasets creates a correctness risk: a coordinate near a border could be classified as country A by `country_lookup` but rendered inside country B on the map.

Three format options were evaluated for the bundled asset:
1. **Raw GeoJSON** — human-readable, large (~25 MB at 1:10m), must be parsed at runtime.
2. **FlatBuffers** — compact binary, fast zero-copy access, but requires a code-generation dependency and schema definition.
3. **Custom compact binary** — packed vertices and a pre-built 2D grid spatial index, no external dependencies, parsed in a single pass.

**Decision:**
- **Single source:** Natural Earth 1:50m admin-0 (`ne_50m_admin_0_countries`), public domain. One asset serves both consumers.
- **Precision:** 1:50m, not 1:10m. Coordinate bucketing at 0.5° (ADR-005) means ~55 km effective resolution. Sub-kilometre polygon detail from 1:10m is wasted and roughly doubles asset size.
- **Format:** Custom compact binary. A build script (documented in `packages/country_lookup/GEODATA.md`) processes the Natural Earth shapefile into a packed format: a 2D grid cell index mapping `(lat_cell, lng_cell)` → candidate polygon indices, followed by packed `Int32` vertex arrays and a country code string table. No external runtime dependencies.
- **Asset location:** `apps/mobile_flutter/assets/geodata/ne_countries.bin`. Declared in the app's `pubspec.yaml` assets section. Packages do not declare or load Flutter assets.

**Consequences:**
- `packages/country_lookup` exposes `void initCountryLookup(Uint8List geodataBytes)` as a required initialisation call. The app layer calls `rootBundle.load(...)` and passes the bytes before calling `resolveCountry`. This preserves the package's zero-Flutter-dependency constraint.
- The same bytes are passed to the map rendering layer for polygon extraction. Two separate in-memory representations are built from one asset: a spatial index (for lookup) and a vertex list (for rendering).
- The build script must be re-run when Natural Earth publishes a new release. The output binary is checked into the repository; the source shapefile is not.
- Asset size target: < 8 MB compressed (1:50m GeoJSON is ~4 MB; the binary format should be smaller).
- Border changes and newly recognised countries require an app update — accepted, same as ADR-004.

---

## ADR-016 — Drift schema: one row per country code for `inferred_country_visits`

**Status:** Accepted

**Context:** When the scanner detects the same country across multiple scan runs, the Drift `inferred_country_visits` table must decide whether to store one row per country code (merged across scans) or one row per scan run per country.

**Decision:** One row per country code (`countryCode TEXT PRIMARY KEY`). On each scan, upsert: extend the date range (`firstSeen = min(existing, new)`, `lastSeen = max(existing, new)`), accumulate `photoCount`, update `inferredAt` to the latest scan time, set `isDirty = 1`.

**Reasons:**
- Scan history UI is out of scope for this milestone. The extra schema complexity of a `scan_runs` table is not justified.
- `effectiveVisitedCountries()` merges across scan runs at the compute layer. Storing the already-merged result in the DB makes `VisitRepository.loadInferred()` a direct table read — no join or aggregation query needed.
- One row per code is consistent with `UserAddedCountry` and `UserRemovedCountry`, which are also keyed by `countryCode`.

**Consequences:**
- Per-scan history is not queryable from the DB. If the product later requires "you found France in 3 separate scan sessions", the schema must be migrated to a `(countryCode, scanId)` composite key with a `scan_runs` table. This is an explicit future cost.
- A full rescan with `sinceDate: null` accumulates `photoCount` on top of prior scans rather than replacing it. The `VisitRepository` must expose a `clearInferred()` method for full-rescan flows to reset the table before writing new results.
- `isDirty = 1` is set on every upsert, ensuring the sync layer picks up both new and updated records.

---

## ADR-017 — `country_lookup` exposes polygon geometry via `loadPolygons()`

**Status:** Accepted

**Context:** The world map view (Milestone 6) needs country polygon vertices to render country outlines with `flutter_map`. `CountryPolygon` is already defined in `binary_format.dart` and fully populated during `initCountryLookup()`, but the `_polygons` list is package-private and inaccessible to the app layer.

ADR-015 anticipated this need: *"The same bytes are passed to the map rendering layer for polygon extraction. Two separate in-memory representations are built from one asset."* It left the extraction mechanism unresolved. Two options were considered:

1. **App layer re-parses the binary** — requires either exporting `GeodataIndex` (package internals leak) or duplicating the binary format parser in the app.
2. **`country_lookup` exposes `loadPolygons()`** — the pre-built `_polygons` list is exposed as a public function alongside `resolveCountry()`.

The previous documentation constraint "exactly one public function" was a documentation artefact from before the rendering requirement existed. It was never a hard architectural rule (unlike "no network calls"). The actual hard constraints are: no network, no file I/O, no Flutter/platform deps, no side effects — none of which are violated by exposing pre-built polygon data.

**Decision:** Add `List<CountryPolygon> loadPolygons()` to `country_lookup.dart`. Export `CountryPolygon` as part of the package's public API. The function returns the polygon list built during `initCountryLookup()` and asserts if called before initialisation — matching the contract of `resolveCountry()`.

**Consequences:**
- The public surface of `country_lookup` grows to three callable symbols: `initCountryLookup`, `resolveCountry`, `loadPolygons`, plus the exported `CountryPolygon` type.
- No new dependencies are introduced. The polygon list is already built; this is a zero-cost accessor.
- Multi-ring countries (US, RU, archipelagos) produce multiple `CountryPolygon` entries sharing the same `isoCode`. The app layer is responsible for grouping by `isoCode` for tap detection.
- `package_boundaries.md` and `country_lookup/CLAUDE.md` must be updated to reflect the expanded API.
- `CountryPolygon` vertices are `(lat, lng)` pairs in decimal degrees — the app layer converts to flutter_map `LatLng` objects; the package has no `flutter_map` dependency.

---

## ADR-018 — Riverpod as the app-layer state management solution; core provider graph

**Status:** Accepted

**Context:** `apps/mobile_flutter/CLAUDE.md` specifies Riverpod as the state management solution but no provider structure exists. Task 9 (app navigation redesign) is the first use. Three resources need app-wide access without being passed through widget constructors: the Drift database instance, the geodata bytes, and the derived effective-visits list.

**Decision:** Use `flutter_riverpod`. The core provider graph is:

```
geodataBytesProvider      Provider<Uint8List>
  — overridden in ProviderScope at startup with the loaded asset bytes

roavvyDatabaseProvider    Provider<RoavvyDatabase>
  — overridden in ProviderScope at startup with the opened DB instance

visitRepositoryProvider   Provider<VisitRepository>
  — reads roavvyDatabaseProvider; constructs VisitRepository

polygonsProvider          Provider<List<CountryPolygon>>
  — reads geodataBytesProvider; calls loadPolygons() once

effectiveVisitsProvider   FutureProvider<List<EffectiveVisitedCountry>>
  — reads visitRepositoryProvider; loads all three record types then calls effectiveVisitedCountries()

travelSummaryProvider     FutureProvider<TravelSummary>
  — reads effectiveVisitsProvider; calls TravelSummary.fromVisits()
```

`main()` initialises the DB and loads the geodata asset before `runApp`, then passes both into `ProviderScope` via `overrides`. This avoids async startup providers and keeps the provider graph synchronous for the two startup resources.

**Consequences:**
- The `geodataBytes` constructor chain through `RoavvySpike` → `ScanScreen` is removed.
- After scan completion, `ScanScreen` calls `ref.invalidate(effectiveVisitsProvider)` to trigger a rebuild of `MapScreen` and the stats strip — no manual state passing.
- Core providers live in `lib/core/providers.dart`. Feature-scoped providers (e.g. scan progress state) live alongside their feature in `lib/features/`.
- `roavvyDatabaseProvider` and `geodataBytesProvider` have no default value — any test that uses them must provide an override. This is enforced at runtime.
- `flutter_riverpod` is added to `apps/mobile_flutter/pubspec.yaml` only; not added to any package.

---

## ADR-019 — Country display names from a static lookup map in the app layer

**Status:** Accepted

**Context:** The country tap detail panel (Task 8) needs human-readable display names for ISO 3166-1 alpha-2 codes. Three options were evaluated:

1. **`dart:ui` `Locale`** — does not expose country display names; only language subtags.
2. **`intl` package** — provides locale-aware display names but requires ICU data overhead, a `initializeDateFormatting()` pattern, and adds a significant dependency for what is effectively a 250-entry static mapping.
3. **Static `const Map<String, String>` in the app layer** — all ISO 3166-1 entries, English names, zero dependencies.

**Decision:** A `const Map<String, String> kCountryNames` in `lib/core/country_names.dart`. Display name lookup falls back to the ISO code itself when the code is absent (covers any edge cases from the geodata).

**Consequences:**
- Display names are English-only for this milestone; localisation is deferred.
- ISO 3166-1 country name changes require an app release (e.g. if a country renames itself). This is acceptable — such changes are rare and app releases are already required for geodata updates (ADR-004).
- `kCountryNames` must not be placed in `shared_models` — it is a display/presentation concern, not a domain model. It belongs in the app layer.
- The map is ~250 entries; it is a one-time copy task, not an ongoing maintenance burden.
