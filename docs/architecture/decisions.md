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

---

## ADR-020 — Country tap detection via MapOptions.onTap + resolveCountry()

**Status:** Accepted

**Context:** Task 8 requires tapping a country polygon on the world map to open a detail bottom sheet. Two approaches were evaluated:

1. **`Polygon.hitValue` + `PolygonLayer.hitNotifier`** — flutter_map v7's built-in hit-testing layer. Requires attaching a `hitValue` (ISO code) to each `Polygon` and listening to a `LayerHitResult` notifier. Adds state complexity; also untestable via `tester.tap()` in the widget test runner.
2. **`MapOptions.onTap(TapPosition, LatLng)` + `resolveCountry(lat, lng)`** — uses the same offline point-in-polygon function already used in the scan pipeline. Returns an ISO code or `null` (open water). Zero additional flutter_map API surface.

**Decision:** Use `MapOptions.onTap` to receive tap coordinates, then call `resolveCountry(lat, lng)` (or `tapResolverOverride` in tests) to resolve the ISO code. If `null` → do nothing. If non-null → look up `_visitedByCode[code]` and open `CountryDetailSheet` via `showModalBottomSheet<bool>`. If the sheet returns `true` (user added a country), call `_init()` to refresh visited state.

**Consequences:**
- No `Polygon.hitValue` or `PolygonLayer.hitNotifier` is used; polygon objects remain simple.
- `resolveCountry()` is ~1 ms per tap (point-in-polygon over ~250 polygons); imperceptible.
- Open water taps naturally return `null` — no special casing required.
- `_visitedByCode` is kept as a `Map<String, EffectiveVisitedCountry>` field on `_MapScreenState` for O(1) lookup after resolution.
- Tap-through-FlutterMap is not testable via `tester.tap()` in the widget test runner; the `tapResolverOverride` hook on `MapScreen` exists for future integration test use. `CountryDetailSheet` is tested in isolation in `country_detail_sheet_test.dart`.

---

## ADR-021 — Open iOS Settings via MethodChannel; no `permission_handler` package

**Status:** Accepted

**Context:** Task 11 requires a "Open Settings" button in the `denied` permission state so users can re-grant photo access. The only way to deep-link into iOS Settings from Flutter is either:

1. **`permission_handler` package** — comprehensive cross-platform permission API with `openAppSettings()`. Pulls in platform-specific permission declarations even for permissions Roavvy never requests (location, camera, contacts, etc.). Adds ~80 KB to the app and requires `NSPhotoLibraryUsageDescription` entries the app already provides natively.
2. **`app_settings` package** — lightweight, just opens settings. Still an extra dependency and maintenance surface for a single use.
3. **Custom MethodChannel call** — add an `openSettings` method to the existing `roavvy/photo_scan` MethodChannel. Swift implementation: `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`. Zero new dependencies; consistent with ADR-001 (all platform interaction via Swift bridge).

**Decision:** Add `openSettings` as a new method on the existing `roavvy/photo_scan` MethodChannel. No new Flutter package is introduced. The Swift handler calls `UIApplication.openSettingsURLString`. The Dart side exposes `openAppSettings()` as a top-level function in `lib/photo_scan_channel.dart`, alongside `requestPhotoPermission()` and `startPhotoScan()`.

**Also decided:** The `restricted` state (parental controls / MDM policy) is treated the same as `denied` in the UI, but without the "Open Settings" button — because the restriction cannot be changed from within the app. The UI copy for `restricted` should reflect this: "Access is restricted by your device settings."

**Consequences:**
- `lib/photo_scan_channel.dart` gains one new function: `Future<void> openAppSettings()`.
- `ios/Runner/AppDelegate.swift` gains one new case in the `MethodChannel` handler: `"openSettings"`.
- `_PermissionStatus` widget in `ScanScreen` (or the `ScanScreen` state itself) calls `openAppSettings()` from the `denied` branch only.
- Widget tests mock the MethodChannel; `openSettings` call can be asserted via `TestDefaultBinaryMessengerBinding` the same way `requestPermission` is tested today.
- No new pubspec dependency. `permission_handler` and `app_settings` are explicitly rejected.

---

## ADR-022 — `lastScanAt` stored in Drift `ScanMetadata` table; no `shared_preferences`

**Status:** Accepted

**Context:** Task 12 (incremental scan) requires the Flutter layer to persist the timestamp of the last successful scan so it can be passed as `sinceDate` to the Swift bridge (ADR-012). The backlog flagged storage location as a risk: SharedPreferences vs Drift metadata table.

Two options evaluated:
1. **`shared_preferences`** — simple key/value store; would reintroduce a package explicitly removed after the spike (ADR-011); mixes two persistence mechanisms for closely related data.
2. **Drift `ScanMetadata` table** — consistent with ADR-003 (Drift as sole persistence layer); atomic with `clearAll()` in Task 14 (delete history); no new package; schema migration is manageable.

**Decision:** Add a `ScanMetadata` table to the Drift schema. The table always contains at most one row (singleton pattern, `id INTEGER PRIMARY KEY DEFAULT 1`). `lastScanAt` is a nullable `TEXT` column storing an ISO 8601 UTC string. `VisitRepository` gains three methods: `loadLastScanAt()`, `saveLastScanAt(DateTime)`, `clearLastScanAt()`. Schema version bumps from 1 → 2; `onUpgrade` creates the table.

**Passing `sinceDate` to Swift:** The existing `startPhotoScan` function in `photo_scan_channel.dart` calls `_eventChannel.receiveBroadcastStream(args)`. The args map gains a `'sinceDate'` key (ISO 8601 string or absent/null). The Swift `onListen(withArguments:)` handler in `AppDelegate.swift` must be verified or updated to parse this key and construct the `NSPredicate` per ADR-012. The Builder must check the current Swift implementation before writing new code.

**Rescan (full scan) flow:** A user-initiated full rescan passes `sinceDate: null` explicitly, bypassing the stored `lastScanAt`. `lastScanAt` is not cleared on rescan — it is overwritten with the new completion timestamp when the rescan succeeds.

**`lastScanAt` update rule:** Written only on successful scan completion (i.e. after `ScanDoneEvent` is received without error). Not written on user cancellation or on any error path.

**Consequences:**
- `RoavvyDatabase.schemaVersion` bumps to 2; a `Drift MigrationStrategy.onUpgrade` step is required. All existing tests with in-memory databases must set `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` (already set in `widget_test.dart`). In-memory databases re-run all migrations, so no test breakage is expected.
- `VisitRepository.clearAll()` (Task 14) must also call `clearLastScanAt()` so the next post-delete scan is a full scan.
- `shared_preferences` is explicitly rejected for this use case. It must not be added to `pubspec.yaml`.

---

## ADR-023 — Scan limit increased from 500 to 2,000 photos

**Status:** Accepted

**Context:** The initial scan limit of 500 was a conservative spike-era default. The Task 4 streaming architecture (50-photo batches, background isolate resolution) handles large libraries efficiently; 500 photos is too low for users with substantial travel archives.

**Decision:** Increase `limit` to 2,000 everywhere: `startPhotoScan(limit: 2000)` in `scan_screen.dart`, the default parameter in `photo_scan_channel.dart`, and the Swift `?? 500` fallback in `AppDelegate.swift`. Button copy updates to "Scan 2,000 Most Recent Photos". The `fetchLimit` cap in `PHFetchOptions` continues to prevent PhotoKit reading beyond this value. No architectural change is required.

**Consequences:**
- Background isolate processing time increases proportionally for users with > 500 geotagged photos; this is acceptable given the offline-first, background-isolate design.
- All tests that assert the button label "Scan 500 Most Recent Photos" must be updated.
- The `scanStarter` default in tests uses `{int limit = 2000}` going forward.

---

## ADR-024 — Task 13 post-scan result summary: inline in `ScanScreen`

**Status:** Accepted

**Context:** After an incremental scan finds no new countries, the UI is silent. The backlog flagged placement (inline vs separate screen) as a risk requiring UX Designer input. The Architect is resolving this to unblock the Builder.

**Two options evaluated:**
1. **Separate result screen** — navigated to after scan completes; requires new `Route`, passing data, and back-navigation wiring.
2. **Inline in `ScanScreen`** — replaces the current `_StatsCard`/`_VisitList` post-scan section with a result summary widget driven by a `_ScanResult` value.

**Decision:** Inline in `ScanScreen`. The post-scan result is transient feedback, not a destination. The scan screen already has a post-scan state branch (`_lastScanStats != null`); extending this branch is the minimal change. No new navigation, no new packages.

**Result states (three cases):**
1. **Nothing new** — scan completed with geotagged photos, but no new countries vs the pre-scan snapshot → copy: *"You're up to date"*.
2. **New countries found** — net-new country codes detected → copy: *"N new countries detected"* + list of country names (via `kCountryNames`, fallback to code).
3. **No geotagged photos** — scan completed but no photos had GPS metadata → existing `_EmptyResultsHint` behaviour, no change needed.
4. **First scan** (pre-scan snapshot was empty, got countries) → show full country list as before; this is not a distinct result state, it falls under "new countries found".

**Determining "new countries":** `_ScanScreenState._scan()` snapshots `_effectiveVisits` immediately before the scan stream starts. After `clearAndSaveAllInferred` and `loadEffective`, the new effective set is diffed against the snapshot to produce `_newCountryCodes: List<String>`. A `_ScanResult` sealed class carries the outcome and drives the build method.

**`_ScanResult` shape:**
```dart
sealed class _ScanResult {}
class _NothingNew extends _ScanResult {}
class _NewCountriesFound extends _ScanResult {
  final List<String> newCodes; // ISO 3166-1 alpha-2
  _NewCountriesFound(this.newCodes);
}
```
`_NoGeotaggedPhotos` is not a separate class — it maps to the existing condition `_effectiveVisits.isEmpty && _lastScanStats != null`.

**Consequences:**
- `ScanScreen` gains one new field `_ScanResult? _scanResult`; cleared at scan start, set on success.
- No new packages, no new routes, no schema changes.
- Widget tests must cover: `_NothingNew` (scan finds same countries as before), `_NewCountriesFound` (new codes list), and no-geotagged-photos path (existing coverage extended).
- The `kCountryNames` map (ADR-019, `lib/core/country_names.dart`) is used for display names in `_NewCountriesFound` view.

---

## ADR-025 — Delete history entry point: `PopupMenuButton` overlay on `MapScreen`

**Status:** Accepted — implemented

**Context:** Task 14 requires a "Delete Travel History" action. No settings screen exists. Three entry-point options evaluated:

1. **New Settings tab in the bottom nav** — over-engineering; a full settings screen for one destructive action.
2. **AppBar with overflow menu** — `MapScreen` has no `AppBar` by design (full-bleed map). Adding one reduces map real estate.
3. **`Positioned` `PopupMenuButton` overlaid in the Stack** — ⋮ icon pinned top-right; no AppBar; full-bleed map preserved; standard Material overflow pattern.

**Decision:** A `Positioned(top: 8, right: 8)` `PopupMenuButton<_MapMenuAction>` overlaid in the `MapScreen` Stack. Single item: "Delete Travel History". On select: show `AlertDialog` confirmation; on confirm call `VisitRepository.clearAll()`, invalidate `effectiveVisitsProvider` + `travelSummaryProvider`, call `_init()`.

**Consequences:**
- No new screen, no new tab, no AppBar.
- `VisitRepository.clearAll()` already purges all three Drift tables plus `ScanMetadata` in one transaction (ADR-022). No new repository method required.
- Both `effectiveVisitsProvider` and `travelSummaryProvider` must be invalidated so `MapScreen` and `StatsStrip` reset simultaneously.
- After invalidation, `_init()` re-reads `effectiveVisitsProvider.future` from the now-empty repo; `_visitedByCode` becomes empty; `_EmptyStateOverlay` appears.
- `PopupMenuButton` is positioned above the `_EmptyStateOverlay` in the Stack so it remains tappable even when the overlay is visible.

---

## ADR-026 — Firebase SDK initialization: `Firebase.initializeApp()` in `main()` before `runApp()`

**Status:** Proposed

**Context:** Milestone 8 adds `firebase_core` and `firebase_auth` to the Flutter app. `Firebase.initializeApp()` must complete before any Firebase service (Auth, Firestore) is called. Two initialization strategies evaluated:

1. **`FutureProvider` with a loading splash** — `main()` calls `runApp()` immediately; a Riverpod `FutureProvider` calls `Firebase.initializeApp()`. App shows a spinner until the future resolves. Adds an async provider to the core graph.
2. **Synchronous startup in `main()`** — `Firebase.initializeApp()` is `await`-ed in `main()` alongside the existing geodata and DB initialization, before `runApp()`. No new provider; consistent with the existing startup pattern.

**Decision:** Await `Firebase.initializeApp()` in `main()` alongside `rootBundle.load()` and `RoavvyDatabase()`. Firebase initialization can run in parallel with geodata loading using `Future.wait([...])`. `runApp()` is not called until all three complete.

**Consequences:**
- `main()` remains the single synchronous startup sequencer. No new `FutureProvider` for Firebase init.
- A cold-start Firebase initialization failure (e.g. malformed `GoogleService-Info.plist`) crashes the app at startup — acceptable; this is a developer/configuration error, not a user-facing error.
- `GoogleService-Info.plist` is already present at `apps/mobile_flutter/ios/Runner/GoogleService-Info.plist` with the production Firebase project (`roavvy-prod`).
- `firebase_core` and `firebase_auth` are added to `apps/mobile_flutter/pubspec.yaml` only. They must not appear in any package.
- `FlutterFire CLI` (`flutterfire configure`) was not used — `GoogleService-Info.plist` was provided directly. The `firebase_options.dart` generated file is therefore not used; `Firebase.initializeApp()` is called with no arguments (reads from the plist automatically on iOS).

---

## ADR-027 — Anonymous Firebase Auth as the identity baseline; `authStateProvider` as a `StreamProvider`

**Status:** Proposed

**Context:** Firestore security rules require an authenticated `request.auth.uid` for all user-scoped reads and writes. Requiring the user to sign in with Apple before the app is usable contradicts the offline-first principle. Three options:

1. **No auth required** — Firestore rules are open (insecure). Rejected — violates privacy_principles.md.
2. **Require Apple sign-in on first launch** — blocks offline use and creates onboarding friction before any value is delivered.
3. **Anonymous auth automatically** — on first launch, `FirebaseAuth.instance.signInAnonymously()` gives every install a stable Firebase UID immediately. The user is signed in with zero friction; Firestore rules can enforce `uid` ownership from day one.

**Decision:** On app startup, if `FirebaseAuth.instance.currentUser` is `null`, call `signInAnonymously()` before any Firestore write. This is transparent to the user — no UI, no prompt. The anonymous UID is never surfaced in the UI or logged.

**Auth state is exposed via a Riverpod `StreamProvider`:**
```dart
// lib/core/providers.dart
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);
```
A derived `currentUidProvider` (`Provider<String?>`) reads `authStateProvider` and returns `user?.uid`. The sync layer reads `currentUidProvider` to decide whether to write to Firestore.

**Anonymous auth is triggered once in `main()`,** after `Firebase.initializeApp()`, if no current user exists. It is not re-triggered on subsequent launches (Firebase persists the anonymous session across restarts).

**Consequences:**
- Every install creates an anonymous Firebase Auth record. Firebase auto-purges anonymous users inactive for 30+ days (configurable in Firebase Console).
- The anonymous UID must never appear in the UI, in logs at INFO level or above, or in any Firestore document field other than the document path (`users/{uid}`).
- Anonymous sessions survive app restarts but not reinstalls. After reinstall, a new anonymous UID is created — the user's Drift data is local and unaffected; Firestore data from the prior anonymous session is orphaned (unreachable without the old UID). This is acceptable for anonymous users. It is the primary motivation for Apple sign-in (Task 3).
- `authStateProvider` replaces manual `FirebaseAuth.instance.currentUser` calls everywhere in the app layer. No feature code touches `FirebaseAuth` directly.

---

## ADR-028 — Sign in with Apple as the sole persistent identity provider for Phase 1; credential upgrade from anonymous

**Status:** Proposed

**Context:** Anonymous UIDs don't survive reinstalls (ADR-027). A persistent identity requires a full sign-in provider. Options:

1. **Apple + Google** — App Store guideline 4.8 requires apps offering third-party social sign-in to include Apple as an option. On iOS, Apple alone satisfies this; Google is additive but not required.
2. **Apple only** — minimal package surface, satisfies App Store rules, covers all iOS users.
3. **Email/password** — high friction; poor UX for a consumer app; no benefit over Apple on iOS.

**Decision:** Sign in with Apple only for Phase 1. The `sign_in_with_apple` package is used (BSD licence, no third-party server dependencies for iOS native flow).

**Credential upgrade (anonymous → Apple):** When the user signs in with Apple for the first time, the anonymous account is upgraded via `FirebaseAuth.instance.currentUser!.linkWithCredential(appleCredential)`. This preserves the anonymous UID — no orphaned Firestore documents, no data loss. If the Apple ID is already linked to a different Firebase account (e.g. prior reinstall where the user signed in), catch `FirebaseAuthException(code: 'credential-already-in-use')` and call `FirebaseAuth.instance.signInWithCredential(appleCredential)` instead, then migrate Firestore documents from the old anonymous UID to the Apple-linked UID.

**Entry point for the sign-in UI:** TBD by UX Designer. The Architect constraint: sign-in must not be required to use the app; it must be presented as an enhancement ("sync and protect your data").

**Consequences:**
- `sign_in_with_apple` added to `apps/mobile_flutter/pubspec.yaml`. No other sign-in package.
- "Sign in with Apple" capability must be enabled in Xcode (`Runner.entitlements`).
- Apple Developer account required to test on device (capability requires a provisioning profile with Sign In with Apple entitlement).
- `OAuthProvider('apple.com')` must be configured in Firebase Console under Authentication → Sign-in providers.
- `nonce` must be used in the Apple credential flow (SHA-256 hashed nonce passed to Apple, raw nonce stored for Firebase verification). This is handled by `sign_in_with_apple`'s `AuthorizationRequest` and must not be skipped.
- Signed-in state is reflected immediately in `authStateProvider` (ADR-027); downstream sync triggers fire automatically on the auth state change.

---

## ADR-029 — Firestore schema: three subcollections under `users/{uid}`, one document per country code

**Status:** Proposed

**Context:** Drift uses three tables (ADR-016): `inferred_country_visits`, `user_added_countries`, `user_removed_countries`. The Firestore schema must be decided before any sync code is written. Three structural options:

1. **One document per user** — `users/{uid}` contains a single map field `visits: {countryCode: {...}}`. Simple but: document size limit is 1 MiB; a user with thousands of photos and 50 countries hits this at ~20 KB — well within limits, but the entire document is written on every change.
2. **One subcollection per record type** — `users/{uid}/inferred_visits/{countryCode}`, `users/{uid}/user_added/{countryCode}`, `users/{uid}/user_removed/{countryCode}`. Maps 1:1 to Drift schema. Individual document writes are granular. Security rules can scope to `users/{uid}` path prefix.
3. **Flat collection** — `visits/{uid}_{countryCode}` top-level. Breaks the natural `users/{uid}` ownership model; security rules are harder to write correctly.

**Decision:** Option 2 — three subcollections under `users/{uid}`:

```
users/{uid}/
  inferred_visits/{countryCode}   → { inferredAt, photoCount, firstSeen?, lastSeen?, syncedAt }
  user_added/{countryCode}        → { addedAt, syncedAt }
  user_removed/{countryCode}      → { removedAt, syncedAt }
```

Field types: all ISO 8601 strings (Firestore `Timestamp` is not used — Dart `DateTime` serialisation to string is already established in the Drift schema). `syncedAt` is set by the client to `DateTime.now().toUtc().toIso8601String()` at write time.

**Privacy constraint (ADR-002):** No GPS coordinates, no photo filenames, no `PHAsset` identifiers appear in any Firestore document. The sync layer must be auditable for this constraint — a Reviewer checklist item.

**Firestore security rules scaffold** (to be written in `firestore.rules`):
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
Rules are scaffolded in this milestone; a dedicated security review milestone validates and tightens them before production.

**Consequences:**
- Firestore reads during "pull from cloud" (future milestone) are three parallel collection reads, not a single document fetch. Acceptable for Phase 1 sync (push-only).
- `firestore.rules` and `firestore.indexes.json` are added to the repo root (or `infra/firestore/`). Deployment is manual for Phase 1.
- `cloud_firestore` package is added to `apps/mobile_flutter/pubspec.yaml`.
- The `syncedAt` field written to Firestore is the client timestamp, not a Firestore server timestamp, to avoid an extra round-trip. This is acceptable for Phase 1 — server timestamps are needed only when the server write time must be authoritative (e.g. for ordering).

---

## ADR-030 — Sync architecture: `FirestoreSyncService` called after each `VisitRepository` write; fire-and-forget

**Status:** Proposed

**Context:** When and how does local Drift data get pushed to Firestore? Options:

1. **Sync inside `VisitRepository`** — repository methods call Firestore directly. Couples local persistence and network sync in one class; violates single responsibility; breaks existing tests that use `VisitRepository` with in-memory Drift.
2. **Sync in a Riverpod provider that watches `effectiveVisitsProvider`** — triggers on every state change. Risks double-firing; hard to test; the provider's `build` method is not a natural place for side-effecting writes.
3. **`FirestoreSyncService` called at the call site** — after each `VisitRepository` write in `ScanScreen` and `ReviewScreen`, the caller also calls `FirestoreSyncService.instance.flushDirty()`. Fire-and-forget Future. Clean separation; easy to test by injecting a fake service.

**Decision:** Option 3. `FirestoreSyncService` is a simple class with a single method:

```dart
// lib/data/firestore_sync_service.dart
class FirestoreSyncService {
  Future<void> flushDirty(String uid, VisitRepository repo) async {
    // Load isDirty=1 rows from each table, write to Firestore, mark clean.
  }
}
```

Called after `VisitRepository.clearAndSaveAllInferred()` and after `VisitRepository.saveUserAdded/saveUserRemoved()`. The call is fire-and-forget: `unawaited(syncService.flushDirty(uid, repo))`. If Firestore is unreachable, the write fails silently — `isDirty` remains 1, and the next call to `flushDirty` retries all dirty rows.

**Sign-out:** On sign-out, `flushDirty` is not called. The UID becomes null; `authStateProvider` emits `null`; call sites skip the sync call.

**`isDirty` flag:** Already present in the Drift schema (ADR-003, ADR-016). The sync service reads `WHERE isDirty = 1`, writes to Firestore, then updates `isDirty = 0` and `syncedAt` in Drift. This is not atomic (Drift update could fail after Firestore write) — acceptable for Phase 1. A future milestone can add idempotent write semantics.

**No background sync:** No `WorkManager`, no `BGTaskScheduler`. Sync only runs when the user actively uses the app and a Dart call site triggers it. This is the minimum viable sync for Phase 1.

**Consequences:**
- `FirestoreSyncService` has no Riverpod provider in Phase 1 — it is instantiated directly at call sites or injected as a constructor parameter for testing.
- `isDirty` flag is already in the schema; no migration needed.
- `cloud_firestore` is accessed only in `FirestoreSyncService` and nowhere else in the app layer — the sync boundary is explicit and auditable.
- Tests for `ScanScreen` and `ReviewScreen` that mock `VisitRepository` must also provide a fake `FirestoreSyncService` to prevent real Firestore calls during tests. A simple `NoOpSyncService` stub satisfies this.
- Firestore write failures are silent in Phase 1. A future milestone adds a retry queue or error surface.

---

## ADR-031 — Startup dirty-row flush in `main()` closes the offline gap

**Status:** Accepted

**Context:** ADR-030 calls `flushDirty` fire-and-forget at three call sites: Apple sign-in, scan completion, review-save. When the app is offline, `await FirebaseFirestore.set()` blocks until connectivity is restored (Firestore SDK offline persistence holds the write in an internal queue). If the app is killed while that await is blocking (e.g. user scans offline, force-quits, comes back online later), the SDK loses the pending Future. `isDirty = 1` persists in Drift. On the next launch, no code path calls `flushDirty` unless the user scans or edits again — breaking the "sync when app comes online" promise of ADR-003.

**Decision:** In `main()`, after Firebase is initialised and auth is confirmed, call `flushDirty` fire-and-forget if a UID is available and before `runApp`. `VisitRepository(db)` is instantiated in `main()` for this sole purpose; the Riverpod `visitRepositoryProvider` continues to produce its own instance from `roavvyDatabaseProvider`. Two `VisitRepository` instances wrapping the same SQLite file is safe — Drift serialises all writes through a single connection pool. The startup flush is a read-then-write-to-Firestore pass; it does not conflict with provider-driven writes.

```
main()
  await Firebase.initializeApp()            ← existing
  await signInAnonymously() if needed       ← existing
  final db = RoavvyDatabase(...)            ← existing
  final repo = VisitRepository(db)          ← NEW (startup flush only)
  final uid = currentUser?.uid
  if (uid != null)
    unawaited(FirestoreSyncService().flushDirty(uid, repo))  ← NEW
  runApp(ProviderScope(...))                ← existing
```

**Consequences:**
- Dirty rows from any previous killed-while-offline session are flushed on the next launch. The "sync when app comes online" promise of ADR-003 is now fully honoured for single-device use.
- The startup flush runs in parallel with the Flutter widget tree build (fire-and-forget). It does not delay `runApp` or add to cold-start time.
- If there are no dirty rows (the common case after a successful previous session), `flushDirty` exits immediately after three empty-table reads — negligible cost.
- No new package dependency. `FirestoreSyncService` already exists.
- Widget tests are unaffected: they override `visitRepositoryProvider` and never reach `main()`.

---

## ADR-032 — Firestore offline persistence must be explicitly configured; default-reliance rejected

**Status:** Accepted

**Context:** The current sync implementation (`FirestoreSyncService.flushDirty`) relies on Firestore SDK offline persistence being active. On iOS, `persistenceEnabled` defaults to `true` — but this is an implicit dependency. Any future change to `FirebaseFirestore.instance.settings` (by any developer, for any reason such as debugging) would silently break the offline-sync contract. ADR-003 states Drift is the source of truth and Firestore is updated "when connectivity is available" — this promise requires offline persistence to hold writes in the SDK queue until delivery.

**Decision:** In `main()`, before any Firestore call, explicitly set:

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

This is called once at startup, after `Firebase.initializeApp()` and before `flushDirty` or any other Firestore access. Setting it explicitly:
- Documents the architectural dependency in code, not just in ADRs.
- Prevents accidental disabling.
- `CACHE_SIZE_UNLIMITED` avoids the SDK silently evicting cached writes under storage pressure (the default is 100 MB; country visit data is measured in kilobytes and should never be evicted).

**Consequences:**
- No behaviour change for users — iOS default was already `persistenceEnabled: true`. This only formalises what was already implicitly relied upon.
- Widget tests call `FirebaseFirestore.instance.settings = ...` on a mock Firestore instance (via `fake_cloud_firestore`) — this is a no-op on the fake and does not require test changes.
- The settings call must appear before any `FirebaseFirestore.instance` collection/document access. The builder must place it immediately after `Firebase.initializeApp()` in `main()`.

---

## ADR-033 — Delete travel history does not propagate to Firestore in Phase 1; known gap

**Status:** Accepted

**Context:** `VisitRepository.clearAll()` wipes all three Drift tables and the scan metadata row. It does not delete the corresponding Firestore documents under `users/{uid}/{inferred_visits,user_added,user_removed}`. For single-device use this is invisible — the UI reads from Drift, which is empty. For multi-device sync or reinstall-then-pull scenarios (both deferred to backlog), the stale Firestore documents would cause deleted data to reappear.

**Decision:** Accept this gap for Phase 1. Rationale:
1. Multi-device pull (the scenario where this causes visible harm) is explicitly deferred in `backlog.md`.
2. Adding Firestore deletion to `clearAll()` would require a new `SyncService.clearRemote(uid, repo)` method with its own offline gap (what happens if the device is offline when deleting?), adding complexity that is disproportionate until pull sync exists.
3. For single-device users, Firestore data is write-only in Phase 1 — no pull ever happens, so stale Firestore documents are inert.

**Constraints recorded here for the multi-device milestone:**
- When pull sync is implemented (Milestone 9+), `clearAll()` must propagate to Firestore — either via a deletion tombstone in a `user_events` collection, or by deleting the subcollection documents directly at call time.
- The Firestore security rules must allow authenticated users to delete their own documents in all three subcollections.
- This ADR must be superseded before any multi-device feature ships.

---

## ADR-034 — Achievement domain model and rules engine in `packages/shared_models`

**Status:** Accepted

**Context:** Milestone 9 awards travel achievements based on visited countries. The rules engine must run offline (ADR-004 pattern: zero network dependency) and must be reusable by both the Flutter app and, eventually, the Next.js web app (ADR-007: dual-language). The achievement definitions (names, descriptions, unlock criteria) must be authoritative in one place.

**Decision:** Add two types and one function to `packages/shared_models`:

```dart
// Achievement definition — static, never stored
class Achievement {
  final String id;          // stable identifier, e.g. 'countries_1'
  final String title;       // e.g. 'First Stamp'
  final String description; // e.g. 'Visit your first country'
}

// AchievementEngine — stateless, pure function
class AchievementEngine {
  static Set<String> evaluate(List<EffectiveVisitedCountry> visits);
}
```

`evaluate()` returns the set of achievement IDs unlocked by the given visit list. It is a pure function with no I/O — the same input always produces the same output. The complete `Achievement` catalogue is a `const List<Achievement>` defined alongside `AchievementEngine`.

**Initial achievements (minimum 8):**

| ID | Criterion |
|----|-----------|
| `countries_1` | ≥ 1 country visited |
| `countries_5` | ≥ 5 countries visited |
| `countries_10` | ≥ 10 countries visited |
| `countries_25` | ≥ 25 countries visited |
| `countries_50` | ≥ 50 countries visited |
| `countries_100` | ≥ 100 countries visited |
| `continents_3` | ≥ 3 distinct continents visited |
| `continents_all` | All 6 inhabited continents visited (see ADR-035) |

**Consequences:**
- `shared_models` gains two new source files; its public API surface grows accordingly.
- No external dependencies added; the engine uses only `EffectiveVisitedCountry` (already exported) and the continent map (ADR-035).
- The TypeScript counterpart of these types is not yet built (ADR-007 accepted this debt). A future milestone must add `achievement_engine.ts`.
- `evaluate()` is called after scan completion and after review save — never inside the scan loop. The result replaces the stored achievement set.

---

## ADR-035 — Continent mapping: static `const Map<String, String>` in `packages/shared_models`

**Status:** Accepted

**Context:** The `continents_3` and `continents_all` achievements (ADR-034) require mapping ISO 3166-1 alpha-2 country codes to continents. The mapping must be offline, deterministic, and consistent between the mobile app and the future web app. Options evaluated:

1. **App-layer map (like `kCountryNames`)** — would not be available to the TypeScript web app; duplicated across platforms.
2. **Static map in `shared_models`** — single authoritative source; reusable by both Dart and TypeScript (once TS side is built).
3. **Derive from geodata at runtime** — `packages/country_lookup` has no continent metadata; adding it increases binary size; over-engineering for a static fact.

**Decision:** A `const Map<String, String> kCountryContinent` in `packages/shared_models/src/continent_map.dart`, mapping ISO 3166-1 alpha-2 code → continent name string. Continent names use six inhabited regions: `'Africa'`, `'Asia'`, `'Europe'`, `'North America'`, `'South America'`, `'Oceania'`. Antarctica is excluded from achievements (no tourist visits tracked). Territories are mapped to the continent of their administering country (e.g. `GP` → `'North America'`, `RE` → `'Africa'`).

**`continents_all` definition:** All 6 inhabited continents means at least one country in Africa, Asia, Europe, North America, South America, and Oceania.

**Consequences:**
- ~250-entry const map; negligible memory cost.
- Territories with ambiguous continental assignment are decided by the administering country's continent — this is documented in the file header. Any future dispute is resolved by editing one file.
- `kCountryContinent` is exported from `shared_models.dart` alongside `kCountryNames`-equivalent usage (it is used by `AchievementEngine`, not directly by app UI).
- Countries absent from the map (edge cases from geodata) are treated as continent-unknown and do not count toward continent achievements. `AchievementEngine` must handle missing keys gracefully.

---

## ADR-036 — Achievement Drift table: `unlocked_achievements` in schema v4; `AchievementRepository`

**Status:** Accepted

**Context:** Unlocked achievements must survive app restarts (ADR-003: Drift as source of truth) and be flushed to Firestore when connectivity is available (ADR-030 pattern). The existing dirty-flag pattern (`isDirty`/`syncedAt`) is established and must be applied consistently.

**Decision:** Add `unlocked_achievements` table to `RoavvyDatabase`:

```dart
class UnlockedAchievements extends Table {
  TextColumn get achievementId => text()();         // PK — stable achievement ID
  IntegerColumn get unlockedAt => integer()();      // ms since epoch, UTC
  IntegerColumn get isDirty => integer().withDefault(const Constant(1))();
  IntegerColumn get syncedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {achievementId};
}
```

Schema version bumps from 3 → 4. `MigrationStrategy.onUpgrade` adds a `CREATE TABLE IF NOT EXISTS unlocked_achievements (...)` step for version 3 → 4.

`AchievementRepository` exposes:
- `upsertAll(Set<String> ids, DateTime unlockedAt)` — inserts or replaces; marks dirty
- `loadAll()` → `List<String>` (achievement IDs)
- `loadDirty()` → `List<UnlockedAchievementRow>`
- `markClean(String id, DateTime syncedAt)` — sets `isDirty = 0`, `syncedAt`

`achievementRepositoryProvider` is added to `lib/core/providers.dart`, reading from `roavvyDatabaseProvider`.

**Consequences:**
- All tests that open a `RoavvyDatabase` (in-memory) benefit from the migration running automatically; no test breakage expected given the `IF NOT EXISTS` guard.
- The `upsertAll` function uses `INTO OR REPLACE` semantics — safe for idempotent re-evaluation (re-evaluating after the same visit list upserts the same rows with the same `unlockedAt`).
- `VisitRepository.clearAll()` does **not** purge `unlocked_achievements` — achievements are not travel history. They are a derived milestone that persists even if the user deletes and re-scans. (If the user rescans and re-earns the same achievements, `upsertAll` is idempotent.)

---

## ADR-037 — `flushDirty` signature: `AchievementRepository` as an optional named parameter

**Status:** Accepted

**Context:** Task 24 extends `FirestoreSyncService.flushDirty` to also flush achievement dirty rows. The existing abstract `SyncService` interface and three callers (`main.dart`, `scan_screen.dart`, `review_screen.dart`) must be updated. Two options:

1. **Required second positional parameter** — `flushDirty(String uid, VisitRepository repo, AchievementRepository achievementRepo)`. All callers must be updated atomically. Breaks `NoOpSyncService` if not updated simultaneously.
2. **Optional named parameter** — `flushDirty(String uid, VisitRepository repo, {AchievementRepository? achievementRepo})`. Existing callers compile without change during the build; the builder updates callers as each write site gains achievement evaluation. Omitting `achievementRepo` silently skips achievement sync — this is safe because achievements are evaluated and dirtied at the call sites, not in `main()` startup.

**Decision:** Option 2 — optional named parameter. The abstract class becomes:

```dart
abstract class SyncService {
  Future<void> flushDirty(String uid, VisitRepository repo,
      {AchievementRepository? achievementRepo});
}
```

`FirestoreSyncService.flushDirty` flushes achievement dirty rows under `users/{uid}/unlocked_achievements/{achievementId}` if `achievementRepo` is non-null. `NoOpSyncService` accepts the parameter and ignores it.

All three callers must pass `achievementRepo` in Task 24: they have an `AchievementRepository` instance available from the provider or a direct instantiation.

**Firestore document shape** for `users/{uid}/unlocked_achievements/{achievementId}`:
```json
{ "unlockedAt": "<ISO 8601 UTC string>", "syncedAt": "<ISO 8601 UTC string>" }
```

**Firestore rules:** `firestore.rules` already covers `users/{userId}/{document=**}` with a wildcard match — the new subcollection is automatically covered by the existing rule. No rule change required.

**Consequences:**
- `NoOpSyncService` gains the named parameter; widget tests that inject it continue to compile and pass without changes.
- Achievement sync is skipped in `main()` startup flush if the call site does not pass `achievementRepo` — this is acceptable only if `main()` is updated in Task 24 to pass the repo (which it must be). The builder must not leave `main()` without `achievementRepo`.
- The optional parameter is a temporary affordance during the build. After Task 24 is complete, all callers pass it; there is no ongoing "optional" use case.

---

## ADR-038 — `TravelSummary.achievementCount`: populated in the app-layer provider, not in `shared_models`

**Status:** Accepted

**Context:** Task 25 requires the `StatsStrip` to display an achievement count. `TravelSummary` (in `shared_models`) is the current stats carrier. Options:

1. **`TravelSummary.fromVisits()` computes achievements inline** — requires `AchievementEngine` to be called inside `shared_models` (already possible since both are in the package), but `fromVisits()` returns after a single-pass computation over visits. Achievement evaluation is O(1) given visit counts, so cost is negligible. However, it couples two separate computations in one factory.
2. **Add `achievementCount: int` field (default 0); `travelSummaryProvider` populates it** — `fromVisits()` is unchanged; the app-layer provider reads from `achievementRepositoryProvider` and builds a `TravelSummary` with the count. Separation of concerns: `TravelSummary.fromVisits()` computes geographic stats; the provider composes them with the persisted achievement count.

**Decision:** Option 2. `TravelSummary` gains `final int achievementCount` (default `0` for backward compatibility):

```dart
class TravelSummary {
  final int countryCount;
  final DateTime? earliestVisit;
  final DateTime? latestVisit;
  final int achievementCount;  // NEW

  const TravelSummary({
    required this.countryCount,
    this.earliestVisit,
    this.latestVisit,
    this.achievementCount = 0,
  });
}
```

`TravelSummary.fromVisits()` is unchanged — it always returns `achievementCount: 0`. The provider overrides it:

```dart
final travelSummaryProvider = FutureProvider<TravelSummary>((ref) async {
  final visits = await ref.watch(effectiveVisitsProvider.future);
  final achievementIds = await ref.watch(achievementRepositoryProvider).loadAll();
  final base = TravelSummary.fromVisits(visits);
  return TravelSummary(
    countryCount: base.countryCount,
    earliestVisit: base.earliestVisit,
    latestVisit: base.latestVisit,
    achievementCount: achievementIds.length,
  );
});
```

**Achievement evaluation trigger:** `AchievementEngine.evaluate()` is called only at two write sites: after scan completion (in `ScanScreen`) and after review save (in `ReviewScreen`). It is **not** called in `main()` startup — the startup `flushDirty` only pushes already-dirty achievement rows written by previous scan/review sessions. Re-evaluation at startup is unnecessary and would produce no new unlocks since visits have not changed.

**Newly-unlocked detection (for SnackBar in Task 25):** At each write site, call `achievementRepo.loadAll()` before evaluation, then compare with the result of `evaluate()` to find newly added IDs. Pass these to the UI for SnackBar display.

**Consequences:**
- `TravelSummary` field addition is backward-compatible (default `achievementCount = 0`); existing tests that construct `TravelSummary` without the field continue to compile.
- The TypeScript counterpart of `TravelSummary` (ADR-007, not yet built) will need to add `achievementCount` when the TS side is implemented — low impact, noted here.
- `travelSummaryProvider` now reads from two async providers (`effectiveVisitsProvider` + `achievementRepositoryProvider`). Both are `FutureProvider`-compatible; `await` both before constructing `TravelSummary`.
- Widget tests for `StatsStrip` must override `travelSummaryProvider` to include a non-zero `achievementCount` to verify the stat renders.

---

## ADR-039 — Auth session persistence: remove forced sign-out; shared Apple sign-in helper; sign-out action

**Status:** Accepted

**Context:** `main.dart` contains `// TEMP: force sign-out` which calls `FirebaseAuth.instance.signOut()` on every launch. This defeats Firebase Auth's built-in iOS Keychain session persistence — every user sees `SignInScreen` on every launch regardless of prior sign-in. Additionally, `SignInScreen` contains an email/password form that was never part of the intended user flow (ADR-028 accepts Sign in with Apple as the sole persistent identity provider) and was never planned by the Architect. Both must be corrected before Milestone 10 ships.

Two independent sign-in paths now exist that both require the Apple nonce flow:
1. `SignInScreen` — first-time user, or user who signed out, choosing Apple from the start.
2. `MapScreen` overflow — anonymous user upgrading their credential mid-session (existing Task 18 flow).

Duplicating the nonce logic in two files is a maintenance risk. A shared helper is the correct structural answer.

**Decision:**

1. **Remove the forced sign-out** from `main.dart`. The `// TEMP: force sign-out` call and its comment are deleted. `FirebaseAuth`'s built-in persistence (Keychain on iOS) now correctly keeps the session alive across launches.

2. **Strip email/password from `SignInScreen`**. The `signInWithEmailAndPassword` method, its text controllers, and associated UI fields are removed. `SignInScreen` becomes two-button: "Sign in with Apple" and "Continue anonymously". The email/password form was never part of an ADR and is not an intended user flow.

3. **Extract Sign in with Apple logic to `lib/features/auth/apple_sign_in.dart`** — a top-level async function `Future<void> signInWithApple({required VisitRepository repo})`. It handles nonce generation, Apple credential request, Firebase credential creation, `linkWithCredential` with `credential-already-in-use` fallback, and the fire-and-forget `flushDirty` call. Both `SignInScreen` and `MapScreen` call this function. The `signInWithAppleOverride` test hook in `MapScreen` continues to work (it is passed through to the call site and bypasses the real implementation).

4. **Sign-out in `MapScreen` overflow**: a new "Sign out" menu item calls `FirebaseAuth.instance.signOut()`. `authStateProvider` emits `null`; `RoavvyApp.build()` routes to `SignInScreen`. No additional routing logic required — the existing reactive pattern handles it.

**Data behaviour on sign-out:**
- Anonymous users: local SQLite data is untouched. The new anonymous session created on next "Continue anonymously" will not have the prior Firestore-synced data (since that was under the old UID). This is accepted per ADR-027 — anonymous identity is ephemeral by design.
- Apple-authenticated users: local SQLite data is untouched. Re-signing-in with the same Apple ID restores the same Firebase UID. Firestore sync will resume on next flush.

**Consequences:**
- `SignInScreen` becomes simpler and testable without the Apple platform channel (anonymous button exists; Apple button test can use a mock).
- The Apple sign-in logic lives in one file; if the nonce scheme changes (e.g. SHA-512 upgrade), one file changes.
- `MapScreen` loses the inline Apple sign-in implementation; `signInWithAppleOverride` test hook is preserved via the call site.
- New test file `test/features/auth/sign_in_screen_test.dart` validates UI shape (no email field; two buttons present).
- No new Firebase Auth providers introduced; ADR-028 unchanged.

---

## ADR-040 — Travel card widget and share: pure widget + RepaintBoundary capture + share_plus

**Status:** Accepted

**Context:** Milestone 10 requires users to share a travel card showing their stats. Two design choices require Architect decision: (1) what the card contains and how it is rendered, and (2) how the rendered card is captured and shared.

**Card content decision — text stats only, no map screenshot:**
A map screenshot would require capturing the `FlutterMap` widget's render output. `FlutterMap` renders tile-layer-free (offline polygons only in this app), but `RenderRepaintBoundary.toImage()` on a live `FlutterMap` widget produces an unpredictable capture depending on timing, polygon paint phase, and device DPR. More importantly, the map as rendered is not a designed shareable artefact — it is a navigation UI. A purpose-built card (text stats + branding) is simpler, fully controllable, and trivially testable.

The card contains: country count, year range, achievement count (`🏆 N`), and the "Roavvy" brand name. No GPS data, no photos, no filenames — fully ADR-002 compliant.

**Capture decision — `Offstage` + `RepaintBoundary`, no extra package:**
`RenderRepaintBoundary.toImage(pixelRatio: 3.0)` is a stable Flutter framework API. It requires the widget to be in the widget tree and laid out. Two options:
1. **`screenshot` package** — wraps the same API; adds a pub dependency for a three-line wrapper.
2. **`Offstage` + `RepaintBoundary` directly** — the `TravelCardWidget` is placed in the `MapScreen` widget tree inside `Offstage(offstage: true, child: RepaintBoundary(key: _cardKey, child: TravelCardWidget(...)))`. Capture is triggered on share tap. No extra package.

Option 2 is chosen. `Offstage` keeps the widget laid out at a fixed size without showing it. The `GlobalKey<State<RepaintBoundary>>` is held on `_MapScreenState`.

**Share decision — `share_plus` + `path_provider` temp file:**
`share_plus` is the standard Flutter package for iOS/Android share sheet. It requires a file path (not raw bytes) via `XFile`. `path_provider` provides `getTemporaryDirectory()`. Both packages are well-maintained and widely used in Flutter.

**Decision:**

```
TravelCardWidget (lib/features/sharing/travel_card_widget.dart)
  — pure StatelessWidget; accepts TravelSummary; fixed 3:2 aspect ratio; no Riverpod
  — renders: country count, year range, achievements, "Roavvy" brand label

MapScreen (_MapScreenState)
  — holds GlobalKey<State<RepaintBoundary>> _cardKey
  — Offstage(offstage: true) wraps RepaintBoundary wraps TravelCardWidget(summary)
  — "Share my map" overflow item visible only when travelSummaryProvider has data
    and summary.visitedCodes.isNotEmpty
  — on tap: capture → temp file → Share.shareXFiles

lib/features/sharing/travel_card_share.dart
  — captureAndShare(GlobalKey key, String subject) async function
  — handles toImage → PNG bytes → temp file → shareXFiles
  — MapScreen calls this; no direct Riverpod dependency
```

**Consequences:**
- `share_plus` and `path_provider` added to `apps/mobile_flutter/pubspec.yaml`.
- `TravelCardWidget` has no Riverpod dependency — it is fully testable with `pumpWidget(TravelCardWidget(summary))`.
- `Offstage` ensures the card is always laid out, so capture is instantaneous (no async layout settle needed before capture).
- The `TravelCardWidget` inside `MapScreen` consumes the same `TravelSummary` already available from `travelSummaryProvider` — no additional async load.
- Widget test for "Share my map" overflow item: override `travelSummaryProvider` with a summary that has `visitedCodes.isNotEmpty` → item visible; empty → item absent. The `captureAndShare` call itself is not exercised in widget tests (requires a real renderer).
- `path_provider` must be initialised in test with `setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized())` if exercised in unit tests — but since capture is not tested at widget level, this constraint does not apply here.

---

## Architect sign-off — Task 26 + Milestone 10

**Plan validated with two corrections:**

**Correction 1 (Task 26):** The Planner identified the Apple sign-in migration risk but left the solution open ("authStateProvider listener in RoavvyApp or MainShell"). The correct answer is a shared helper (`apple_sign_in.dart`) called from both sites — not a listener. A listener in `RoavvyApp` would create a side-effecting observer on an auth stream, coupling the root widget to sync concerns. The helper approach is adopted in ADR-039.

**Correction 2 (Task 28):** The Planner specified "off-screen" capture without defining how. The `Offstage` + `RepaintBoundary` pattern is adopted (ADR-040). The builder must not use a separate `screenshot` package.

**Build order:** Task 26 → Task 27 → Task 28. Task 27 can begin once Task 26 is complete (no dependency on sharing infra). Task 28 depends on Task 27 (`TravelCardWidget` must exist before capture logic is wired).

---

## ADR-041 — Share token: dedicated Drift table, UUID v4 via dart:math, denormalised Firestore snapshot

**Status:** Accepted

**Context:** Task 29 (Milestone 11) requires a stable, opaque, user-specific URL token for the public share page (`https://roavvy.app/share/{token}`). The token must survive app restarts, must not change on re-share, and must not be destroyed when the user clears their travel history. The Planner proposed a general-purpose `app_settings (key TEXT PK, value TEXT)` table; this ADR supersedes that choice.

**Decision:**

1. **Storage — dedicated `ShareTokens` Drift table** (not a column on `ScanMetadata`, not a generic key-value store).
   - Schema: `token TEXT NOT NULL` (sole column, no explicit PK — Drift adds `rowid`; or use a fixed-id singleton pattern `id INTEGER PK DEFAULT 1`).
   - `VisitRepository.clearAll()` must **not** delete this table. `ScanMetadata` is currently cleared by `clearAll()` (via `DELETE FROM scan_metadata`), so a column on `ScanMetadata` would be destroyed on history-clear — invalidating any URL the user has shared. A separate table is the correct structural boundary.
   - Schema bump: v4 → v5. Migration: `CREATE TABLE IF NOT EXISTS share_tokens (id INTEGER NOT NULL PRIMARY KEY, token TEXT NOT NULL)`.

2. **Token generation — UUID v4 via `dart:math` + `dart:convert`.**
   - `Random.secure()` is the OS CSPRNG on iOS (SecRandomCopyBytes under the hood). Sufficient entropy for a v4 UUID (122 random bits). No new package dependency.
   - Format: standard 8-4-4-4-12 hex with dashes and version/variant bits set per RFC 4122.

3. **`ShareTokenService`** lives in `lib/features/sharing/share_token_service.dart`.
   - `getOrCreateToken(VisitRepository)` — reads stored token; if absent, generates UUID v4, persists, returns it.
   - `publishVisits(String token, String uid, List<EffectiveVisitedCountry> visits)` — writes `sharedTravelCards/{token}` to Firestore. Fire-and-forget (consistent with ADR-030). Logs errors, does not throw.
   - Does **not** extend or use `FirestoreSyncService` — the `sharedTravelCards` collection has different semantics (public read, denormalised snapshot, not a sync target).

4. **Firestore document schema** — `sharedTravelCards/{token}`:
   ```
   {
     uid: String,            // Firebase UID — required by the write security rule
     visitedCodes: [String], // ISO 3166-1 alpha-2 list
     countryCount: int,
     createdAt: String       // ISO 8601 UTC
   }
   ```
   - `uid` is exposed in a publicly-readable document. Acceptable: Firebase UIDs are opaque identifiers, not user-visible names or contact details. The user opted in by initiating the share.

5. **Firestore security rules** — new `sharedTravelCards` match block:
   ```
   match /sharedTravelCards/{token} {
     allow read: if true;
     allow write: if request.auth != null
                  && request.auth.uid == request.resource.data.uid;
   }
   ```
   - **Known gap (Phase 1):** The write rule is satisfied by anonymous auth (`request.auth != null` is true for any Firebase user). The app-layer gate (`!isAnonymous && hasVisits`) prevents anonymous writes in practice. Tightening to exclude anonymous sign-in providers is deferred to the Milestone 11 security review.

6. **"Share my map link" overflow menu item** — visible only when `!isAnonymous && hasVisits`. Label: "Share my map link" (not "URL" — UX Designer finding). Icon: `Icons.link`. Placed between "Share travel card" and "Clear travel history".

**Consequences:**
- `clearAll()` in `VisitRepository` must be updated to skip the `share_tokens` table — the user's share URL must remain stable across history resets.
- No new pub.dev package required.
- The `sharedTravelCards` collection is permanently public-read. Any token holder (or guesser) can read the document. UUID v4's 122-bit search space makes guessing infeasible.
- `share_plus` (already a dependency from ADR-040) is reused for the URL share sheet — no additional dependency.

---

## ADR-042 — Privacy settings screen as the entry point for sharing management and account deletion

**Status:** Proposed

**Context:** Task 31 (share revocation) and Task 32 (account deletion) both require UI entry points. The Planner scoped both to the `MapScreen` overflow menu — adding "Stop sharing" and "Delete account" items inline. The UX Designer reviewed this and objected on information-architecture grounds: destructive account-level actions do not belong in a map action overflow; `docs/ux/navigation.md` already specifies these flows belong in a **Profile → Privacy settings** push screen. A further concern: the overflow menu already has five to six items; adding two more makes it unwieldy.

Two structural options evaluated:

1. **Full Profile tab now** — add the fourth tab (Profile) from `navigation.md`, with nested screens. Correct long-term IA, but Profile tab scope is Phase 5; building it now pulls in onboarding, account display, and legal screens that are not part of M12.
2. **Minimal `PrivacyAccountScreen` push screen, reachable from overflow** — a single push screen, navigated to via a new "Privacy & account" overflow item. Contains only what M12 needs. When the Profile tab is built in Phase 5, this screen migrates there — no content change required.

**Decision:** Option 2. A new `PrivacyAccountScreen` in `lib/features/settings/privacy_account_screen.dart` is a standard Flutter push screen (no tab, no bottom nav). It is navigated to via a new "Privacy & account" `PopupMenuItem` in the `MapScreen` overflow, always visible to signed-in users.

**Scope of `PrivacyAccountScreen` at M12:**

- **Task 31 delivers:** the screen shell + Sharing section only (sharing status, revoke flow). No account section yet.
- **Task 32 delivers:** the Account section (delete account flow) appended to the same screen.

The overflow menu after M12 changes as follows:

```
Before (Task 29 state):
  Sign in with Apple / Signed in with Apple ✓
  Share travel card
  Share my map link          ← Task 31 removes this
  Clear travel history
  Sign out

After Task 31:
  Sign in with Apple / Signed in with Apple ✓
  Share travel card
  Clear travel history
  Privacy & account          ← new; navigates to PrivacyAccountScreen
  Sign out
```

"Share my map link" is removed from the overflow. All sharing management (creating and revoking a link) moves inside `PrivacyAccountScreen`.

**Firestore rule note:** `sharedTravelCards` delete is currently impossible from the client (see ADR-043). This is a prerequisite for Task 31; it must be fixed as the first step.

**Consequences:**

- The overflow menu becomes shorter (net −1 item after the swap). Discoverability of the sharing feature decreases slightly — acceptable because privacy actions should require deliberate navigation.
- `PrivacyAccountScreen` is a standard `Scaffold` with a `ListView` of `ListTile` rows grouped by section header. No custom components needed.
- When Phase 5 adds the Profile tab, `PrivacyAccountScreen` is moved to that tab without content change. The overflow "Privacy & account" item is removed at that point.
- Widget tests: `MapScreen` tests must assert "Privacy & account" item exists; `PrivacyAccountScreen` tests cover sharing section (Task 31) and account section (Task 32) independently.

---

## ADR-043 — Account deletion: deletion sequence, auth.delete() ordering, and sharedTravelCards delete rule fix

**Status:** Proposed

**Context:** Two related decisions are bundled here because they share the same root issue — the Firestore `sharedTravelCards` delete rule is broken, and the account deletion sequence must be defined before implementation begins.

### Part A — sharedTravelCards Firestore delete rule bug

The current rule in `firestore.rules`:

```
match /sharedTravelCards/{token} {
  allow read: if true;
  allow write: if request.auth != null
      && request.auth.uid == request.resource.data.uid;
}
```

On a Firestore **delete** operation, `request.resource` is `null` — it represents the document being written, which does not exist on deletion. Therefore `request.resource.data.uid` throws a null-dereference in rule evaluation, and all client-side deletions are rejected. This blocks both token revocation (Task 31) and account deletion (Task 32).

**Fix:** Split `write` into `create, update` (using `request.resource.data.uid`) and `delete` (using `resource.data.uid` — the data of the *existing* document):

```
match /sharedTravelCards/{token} {
  allow read: if true;
  allow create, update: if request.auth != null
      && request.auth.uid == request.resource.data.uid;
  allow delete: if request.auth != null
      && request.auth.uid == resource.data.uid;
}
```

### Part B — Account deletion sequence

**The core tension:** Firestore document deletion requires a valid auth token. `FirebaseAuth.currentUser.delete()` invalidates the token immediately on success and can throw `requires-recent-login` before any data is deleted. The two orderings have asymmetric failure modes:

| Order | If auth.delete() fails with requires-recent-login |
|---|---|
| Firestore first, then auth.delete() | Firestore data is already gone; auth account persists (orphaned with no data) |
| auth.delete() first, then Firestore | auth.delete() fails before any deletion; user retries; no data loss |

**Decision:** **auth.delete() first.** This is the safer ordering for the user. If `auth.delete()` throws `requires-recent-login`, the flow aborts cleanly — no data has been touched. The cost is that if auth.delete() succeeds but a subsequent Firestore delete fails (e.g. network loss mid-sequence), some Firestore data may linger. This is an acceptable gap for M12: the user's auth account is deleted, the app routes to SignInScreen, and orphaned Firestore documents are unreachable (the UID no longer exists in Firebase Auth).

**Full deletion sequence:**

```
1. Show loading state (non-dismissable)
2. await FirebaseAuth.instance.currentUser!.delete()
   → on requires-recent-login: show error dialog; abort (no data deleted)
   → on other FirebaseAuthException: sign out anyway; show generic error; navigate to SignInScreen
   → on success: proceed to step 3
3. Attempt share token revocation (if token exists):
   unawaited(ShareTokenService().revokeFirestoreOnly(token, uid))
   — does NOT clear local token (local DB cleared in step 4)
4. await VisitRepository.clearAll()  — wipes all local Drift tables
5. Delete Firestore subcollections (batched WriteBatch, max 500 per batch):
   - users/{uid}/inferred_visits/*
   - users/{uid}/user_added/*
   - users/{uid}/user_removed/*
   - users/{uid}/unlocked_achievements/*  (path per ADR-037)
   Each batch: fetch all document refs → commit WriteBatch → repeat until empty
   Errors are logged; individual batch failures do not abort the sequence
6. authStateProvider emits null (auth deletion already triggered this) → RoavvyApp
   navigates to SignInScreen
```

**`ShareTokenService.revokeFirestoreOnly()`:** A new internal method that deletes the Firestore document only — it does not call `VisitRepository.clearShareToken()`. This is needed because during account deletion, `clearAll()` already wipes the local Drift DB atomically (step 4); calling `clearShareToken()` separately would be redundant or could race.

**`requires-recent-login` handling:**

For Sign In with Apple users: the error occurs when the user's auth session is old (more than ~5 minutes since credential was used). The dialog copy from the UX design is correct: "For security, Apple requires you to sign in again before deleting your account. Sign in with Apple, then return to delete your account." The user must return to the MapScreen, tap "Sign in with Apple" to refresh the credential, and then retry deletion. Full re-authentication UX within the deletion flow is deferred.

For anonymous users: anonymous auth does not require recent sign-in for `delete()`. `requires-recent-login` should not occur for anonymous users. If it does (unexpected Firebase behaviour), treat as a generic error.

**Subcollection enumeration limit:** For typical users (< 250 countries, < 50 achievements), all documents fit in a single 500-document WriteBatch. The enumeration loop is included as a correctness guarantee for edge cases. The Firestore Flutter SDK `collection.get()` returns all documents in one call for collections of this size — no pagination needed.

**Consequences:**

- No new pub.dev package required. `cloud_firestore` already available.
- `AccountDeletionService` in `lib/features/account/account_deletion_service.dart` — injectable (takes `FirebaseAuth`, `FirebaseFirestore`, `VisitRepository`, `ShareTokenService` as constructor parameters). Fully testable with `FakeFirebaseFirestore` and in-memory Drift.
- `firestore.rules` fix is a prerequisite for Task 31 and Task 32 — it must be the first file changed.
- The `users/{userId}/{document=**}` wildcard rule already permits authenticated users to delete their own subcollection documents (`write` includes `delete` in Firestore rules). No additional rule change needed for step 5.
- `clearAll()` already exists and is tested. It must be called in step 4 — not skipped.
- Schema version remains at v5; no migration needed.

---

## ADR-044 — Web identity provider: email/password

**Status:** Accepted

**Context:** M13 requires authenticated web sign-in. Firebase Auth is already initialised in the web app. The mobile app uses Sign in with Apple (ADR-028). Options considered for web:

1. **Email/password** — `signInWithEmailAndPassword` / `createUserWithEmailAndPassword`. No OAuth redirect or popup handling required. Works in all browsers. Must be enabled in the Firebase console under Authentication → Sign-in methods.
2. **Google OAuth** — `signInWithPopup`. Requires Google provider enabled in Firebase console; can be blocked by popup blockers. Deferred.
3. **Apple OAuth on web** — Requires redirect callback handling, nonce management, and a registered redirect URI in the Apple Developer portal. Deferred.

**Decision:** Use **email/password** for M13 web sign-in and sign-up.

**Reasons:**
- No external OAuth provider setup required — only the Firebase console Email/Password toggle.
- Works in all browsers without popup considerations.
- A single `/sign-in` page handles both sign-in and sign-up by toggling mode.

**Known limitation — mobile/web UID alignment:**
The mobile app uses Sign in with Apple which issues a separate Firebase UID. A web user who signs in via email/password will have a different UID from their Apple-authenticated mobile session unless they also registered that email on mobile. Account linking is deferred.

**`AuthContext` persistence:** `setPersistence` is removed from `AuthContext.tsx` — Firebase web SDK defaults to `browserLocalPersistence`. The removal also fixes a timing race where `onAuthStateChanged` was registered only after the async `setPersistence` resolved, potentially missing the first cached-session emission. The `onAuthStateChanged` subscription is registered synchronously in `useEffect`.

**Consequences:**
- Email/Password must be enabled in Firebase console: Authentication → Sign-in methods → Email/Password.
- `signInWithEmailAndPassword` and `createUserWithEmailAndPassword` used in `src/app/sign-in/page.tsx`.
- `firebase/auth` already in the web app's dependencies — no new packages.

---

## ADR-045 — `AuthContext` and `ProtectedRoute` retained; `ProtectedRoute` redirect target corrected

**Status:** Proposed

**Context:** The existing `AuthContext.tsx` and `ProtectedRoute.tsx` are spike artefacts but are structurally sound. The Planner called for "rewrite if needed" — an evaluation is required before deciding.

**Evaluation:**

`AuthContext.tsx`: Uses `onAuthStateChanged` (correct), exposes `{ user, loading, signOut }` (correct interface). One issue: wraps `onAuthStateChanged` registration inside an `async` setup function to call `setPersistence` first — this creates a timing race (see ADR-044). Fix: remove `setPersistence`; register `onAuthStateChanged` directly in `useEffect`.

`ProtectedRoute.tsx`: Pattern is correct — reads `{ user, loading }` from `useAuth()`, redirects unauthenticated users. One bug: redirects to `"/"` (home page) instead of `"/sign-in"`. Fix: change `router.push("/")` to `router.push("/sign-in")`.

**Decision:** **Retain both components; apply targeted fixes only.** Do not rewrite.

**Reasons:**
- Both components implement the correct React + Firebase pattern.
- The bugs are single-line fixes, not structural issues.
- Rewriting would risk introducing new bugs and expand the scope of Task 33 unnecessarily.

**Consequences:**
- `AuthContext.tsx` loses `setPersistence` and the async setup wrapper; `onAuthStateChanged` is the only subscription.
- `ProtectedRoute.tsx` redirect target changes from `"/"` to `"/sign-in"`.
- No other changes to either file.

---

## ADR-046 — Web Firestore access: one-shot `getDocs` from three subcollections; pure `effectiveVisits()` function

**Status:** Proposed

**Context:** The web `/map` page must read the user's visited country set from Firestore. The mobile app stores data across three subcollections (ADR-029): `inferred_visits`, `user_added`, `user_removed`. The existing `useUserVisits.ts` hook has three compounding errors: wrong collection path (`visits`), real-time listener (`onSnapshot`), and no effective-country merge logic.

Two access patterns were considered:

1. **Real-time (`onSnapshot`)** — pushes updates when Firestore data changes. Keeps a persistent WebSocket connection open. Appropriate when the user is actively editing their country list in the browser. For M13, the web map is read-only — no edits happen in the browser.
2. **One-shot (`getDocs`)** — fetches current state once on page load. No persistent connection. Simpler cleanup (no unsubscribe).

**Decision:** Use **`getDocs` (one-shot)** for all three subcollection reads.

**Effective country computation (`effectiveVisits()` function):**

The merge rule from ADR-008 applies on web as on mobile: `(inferred ∪ added) − removed`. A pure TypeScript function `effectiveVisits(inferred: string[], added: string[], removed: string[]): string[]` implements this.

This function is the TypeScript counterpart of `effectiveVisitedCountries()` in `packages/shared_models` (Dart), per ADR-007's dual-language obligation. The semantics must be identical. The function has no Firestore or React dependencies — it is pure logic, testable with Jest independently of Firebase.

Document ID conventions (from ADR-029):
- `inferred_visits/{countryCode}` — doc ID is the ISO 3166-1 alpha-2 code.
- `user_added/{countryCode}` — doc ID is the code.
- `user_removed/{countryCode}` — doc ID is the code.

The hook reads all docs from all three subcollections, extracts doc IDs as country codes, then calls `effectiveVisits()`.

**Firestore rules — not tightened in M13:**
The current `users/{userId}/{document=**}` wildcard allows `read, write`. The web `/map` page only reads. Tightening the rule to `allow read` (and removing `write` from the web path) is deferred to a security review milestone. This is acceptable for M13 because: (a) no web write code paths exist, and (b) Firestore rules are evaluated server-side — a misconfigured client rule does not expose data to other users.

**Consequences:**
- `useUserVisits.ts` is a complete rewrite; the old `CountryVisit` interface and `visits` return value are removed.
- New return shape: `{ visitedCodes: string[], loading: boolean, error: string | null }`.
- `effectiveVisits.ts` is a new file with no framework dependencies — location: `src/lib/firebase/effectiveVisits.ts`.
- Jest tests for `effectiveVisits.ts` must cover: empty inputs, inferred only, added adds new codes, removed suppresses both inferred and added, deduplication, all three inputs simultaneously.
- `onSnapshot` is not used anywhere in the web app for authenticated data reads in M13.

---

## Architect sign-off — Milestone 13 (Tasks 33 + 34 + 35)

**Plan validated with the following corrections:**

**Correction 1 (Task 33):** `AuthContext.tsx` — retain, do not rewrite. Remove `setPersistence` call and the wrapping async setup function. Register `onAuthStateChanged` directly in `useEffect`. (ADR-044, ADR-045)

**Correction 2 (Task 33):** `ProtectedRoute.tsx` — retain, one-line fix only: `router.push("/")` → `router.push("/sign-in")`. (ADR-045)

**Correction 3 (Task 34):** `effectiveVisits()` must implement exactly `(inferred ∪ added) − removed` — matching the Dart `effectiveVisitedCountries()` semantics from ADR-008. Jest tests must include at least one test exercising all three inputs simultaneously. (ADR-046)

**Correction 4 (Task 34):** `useUserVisits.ts` must use `getDocs` (one-shot), not `onSnapshot`. (ADR-046)

**Build order:** Task 33 → Task 34 → Task 35. Task 34 depends on a stable `AuthContext`. Task 35 depends on both.

**No new packages required** for Tasks 33–35. Firebase JS SDK already present.

---

## Architect sign-off — Milestone 12 (Tasks 31 + 32)

**Plan validated with the following corrections:**

**Correction 1 (both tasks):** Entry point changes from overflow menu items to a new `PrivacyAccountScreen` push screen (ADR-042). "Share my map link" / "Stop sharing" overflow items are removed. "Privacy & account" overflow item is added. All sharing management and account deletion are accessed through the new screen.

**Correction 2 (Task 31):** The Planner's `PrivacyAccountScreen` scope was left open. ADR-042 defines it: Task 31 delivers the screen shell + Sharing section only. Task 32 adds the Account section. This avoids a half-built screen.

**Correction 3 (Task 32):** The deletion sequence ordering is `auth.delete()` first (ADR-043), not Firestore-first as the UX Designer noted was a concern. This gives the user a clean abort path if re-auth is needed. The UX Designer's copy for the `requires-recent-login` error case is adopted without change.

**Correction 4 (both tasks):** `firestore.rules` delete rule for `sharedTravelCards` is broken and must be fixed as the first step of Task 31. The fix is specified in ADR-043 Part A.

**Confirmed: achievement subcollection path** for deletion in Task 32 is `users/{uid}/unlocked_achievements/{achievementId}` per ADR-037.

**Build order:** Task 31 → Task 32. Task 32 depends on `PrivacyAccountScreen` existing and on `ShareTokenService.revokeFirestoreOnly()` being available.

---

## Architect sign-off — Task 29 (Milestone 11, Flutter side)

**Plan validated with two corrections:**

**Correction 1:** The Planner's `app_settings` table is replaced by a dedicated `share_tokens` singleton table (ADR-041, Finding 3). The key reason is that `ScanMetadata` is cleared by `clearAll()`, which would destroy the user's share URL on history reset.

**Correction 2:** Menu item label changed from "Share my map URL" to "Share my map link" (UX Designer recommendation — "link" matches iOS share sheet conventions).

**Updated acceptance criteria delta (builder must apply):**
- Table name: `share_tokens` (not `app_settings`)
- Columns: `id INTEGER PK` (fixed value 1), `token TEXT NOT NULL`
- `VisitRepository`: add `getShareToken() → Future<String?>` and `saveShareToken(String token) → Future<void>` operating on `share_tokens`
- `VisitRepository.clearAll()`: must **not** delete `share_tokens`
- Menu item label: "Share my map link"; icon: `Icons.link`

**Build order:** Task 29 is self-contained. Task 30 (web share page) can begin as soon as Task 29 writes its first token to Firestore (independently testable).

---

## ADR-047 — Trip record identity: natural key for inferred trips; prefixed random hex for manual trips

**Status:** Accepted

**Context:** M15 introduces `TripRecord` with an `id` field used as both the Drift primary key and the Firestore document ID. The Planner flagged trip ID stability as a risk: if the ID is derived from `startedOn`, editing a trip's start date would orphan the old Firestore document. Two strategies were considered:

1. **Random UUID at creation** — stable forever; requires tracking the original UUID across re-inference. Problem: when `inferTrips()` re-runs after a subsequent scan, newly inferred trips have no way to recover the UUID assigned in a prior run. The scan pipeline would have to load existing trip IDs from the DB before running inference, creating a stateful dependency on a pure function.

2. **Deterministic natural key** — `"${countryCode}_${startedOn.toIso8601String()}"` for inferred trips. `inferTrips()` remains a pure function. The key is stable across incremental re-scans because: incremental scans only add photos *after* `sinceDate`, so new photos extend `endedOn` and increment `photoCount` — they do not shift `startedOn`. The start date of an inferred trip is anchored to the earliest photo in that cluster, which only moves backward on a full re-scan of the same date range.

**Decision:** Use deterministic natural keys.

- **Inferred trips:** `id = "${countryCode}_${startedOn.toIso8601String()}"` (e.g. `"FR_2023-07-14T00:00:00.000Z"`). `TripRecord.id` IS the Drift primary key. `upsertAll()` uses `insertOrReplace` semantics — on re-inference, the row is replaced with updated `endedOn` and `photoCount`.
- **Manual trips:** `id = "manual_${8-char random hex}"` (same RNG approach as share tokens per ADR-041). The `"manual_"` prefix guarantees no collision with inferred keys.
- **Firestore document ID** equals `TripRecord.id` for both kinds.
- **Manual trip edit that changes `startedOn`:** `TripRepository.delete(oldId)` + upsert with new id. The app layer (Task 40) is responsible for deleting the old Firestore document before or alongside writing the new one.

**Consequences:**
- `inferTrips()` remains a pure function with no DB reads — it can be called with any `List<PhotoDateRecord>` and produces stable IDs.
- Full re-scan (not incremental) may shift a trip's `startedOn` if an earlier photo is found. The old Firestore document is orphaned. This is an acceptable edge case — full re-scan is rare and the orphan is a harmless document with no user-visible effect.
- Task 36 must remove the "UUID v4" language from the inference description. The `id` field in `TripRecord` is a `String`, typed to accept both formats.

---

## ADR-048 — `photo_date_records` table design; Drift schema v6; bootstrap strategy

**Status:** Accepted

**Context:** The Planner specified a new `photo_date_records` Drift table with no primary key and called the migration "schema v4". Two issues need resolution before the Builder starts.

**Issue 1 — Schema version.** The current `RoavvyDatabase.schemaVersion` is **5** (not 3). The v4 migration added `unlocked_achievements`; the v5 migration added `share_tokens`. M15 adds two tables: `photo_date_records` and `trips`. The migration condition must be `if (from < 6)` and `schemaVersion` must increment to **6**.

**Issue 2 — `photo_date_records` primary key.** Without a primary key, incremental re-scans would insert duplicate `(countryCode, capturedAt)` pairs, causing trip inference to overcount `photoCount` and produce duplicate inferred trips on re-run. Fix: define a composite primary key `{countryCode, capturedAt}` using Drift's `@override Set<Column> get primaryKey`. Since `capturedAt` is the photo's creation timestamp (UTC, millisecond precision from the device clock), collisions within the same country are extremely rare and acceptable; the PK constraint is a safety net for the common case.

**Issue 3 — Bootstrap flag.** Task 38 requires a flag to prevent the existing-user bootstrap (one trip per country from `firstSeen`/`lastSeen`) from re-running on subsequent launches. Location: add a `bootstrapCompletedAt TEXT nullable` column to the existing `ScanMetadata` table in the v6 migration (`await m.addColumn(scanMetadata, scanMetadata.bootstrapCompletedAt)`). `VisitRepository` gains `saveBootstrapCompletedAt(DateTime)` and `loadBootstrapCompletedAt() → Future<DateTime?>`.

**Issue 4 — `clearAll()` scope.** `VisitRepository.clearAll()` must wipe `photo_date_records` and ALL `trips` rows (including `isManual = true` trips). Rationale: "Delete travel history" is a full reset of the user's derived travel record. Manual trips are part of that record. This mirrors the treatment of `UserAddedCountries` (also cleared). `bootstrapCompletedAt` is also cleared so the bootstrap re-runs on the next launch (the user effectively re-upgrades from scratch).

**Decision summary:**
- `schemaVersion` → **6**. Migration block: `if (from < 6) { createTable(photoDateRecords); createTable(trips); addColumn(scanMetadata, scanMetadata.bootstrapCompletedAt); }`
- `photo_date_records` composite PK: `{countryCode, capturedAt}`
- Bootstrap flag: `bootstrapCompletedAt` column on `ScanMetadata`
- `clearAll()` wipes `photo_date_records`, `trips`, and nulls `bootstrapCompletedAt`

**Privacy check:** `photo_date_records` stores `{countryCode TEXT, capturedAt DATETIME}` — no GPS coordinates. This is within the derived-metadata-only constraint of ADR-002. ✓

**Consequences:**
- Task 36's acceptance criteria and file list are correct; only the schema version number and the `from3to4` migration block reference need updating to v6.
- `ScanMetadata` Drift table gains a third column (`bootstrapCompletedAt`); `ScanMetadataRow` data class regenerates automatically.
- All references to "schema v4" in the M15 task descriptions are errata — the correct version is v6.

---

## ADR-049 — `packages/region_lookup`: standalone offline admin1 polygon lookup package

**Status:** Accepted

**Context:** M16 adds region-level (ISO 3166-2 admin1) geographic resolution to the scan pipeline. The same offline polygon lookup approach used in `packages/country_lookup` applies here. The question is whether to extend `country_lookup` or create a new package.

**Decision:** Create `packages/region_lookup` as a standalone Dart package, structurally identical to `packages/country_lookup`. It ships a compact binary of Natural Earth admin1 1:10m boundary data and exposes two public functions:
```dart
void initRegionLookup(Uint8List geodataBytes);
String? resolveRegion(double latitude, double longitude);
```
`packages/country_lookup` is unchanged.

**Consequences:**
- `country_lookup` remains focused and stable. Its public API does not grow.
- Two separate binary assets are loaded at startup (`ne_countries.bin` + `ne_admin1.bin`). Estimated combined size ≤ 6 MB.
- The two packages do not depend on each other — the DAG constraint is preserved.
- Border changes at both country and admin1 level require an app update.
- Countries with no admin1 subdivisions (Monaco, Vatican, Singapore) correctly return null — no special-casing needed.

---

## ADR-050 — regionCode is derived metadata; extends ADR-002 persistence scope

**Status:** Accepted

**Context:** ADR-002 specifies that only `{countryCode, firstSeen, lastSeen}` crosses the persistence boundary. M16 adds `regionCode` to `PhotoDateRecord`. The question is whether this violates the spirit of ADR-002.

**Decision:** `regionCode` is derived metadata — it is resolved from GPS coordinates by an offline function, never stored as a raw coordinate, and carries no more privacy risk than `countryCode`. Storing it in `PhotoDateRecord` is consistent with the principle of ADR-002 (photos never leave device; only derived metadata persists). ADR-002's specific field list (`{countryCode, firstSeen, lastSeen}`) is extended to include `regionCode` in `photo_date_records` and `{tripId, countryCode, regionCode, firstSeen, lastSeen, photoCount}` in `region_visits`.

**Consequences:**
- GPS coordinates remain in-memory only; they are still discarded after resolution. ✓
- No raw location data is written to SQLite or Firestore. ✓
- Firestore sync for `region_visits` is deferred to a future milestone — when added, the same privacy check applies: only region codes (not coordinates) are synced.

---

## ADR-051 — Region resolution uses the same 0.5° bucketed coordinates as country resolution; schema v7 is a single atomic migration

**Status:** Accepted

**Context:** ADR-005 buckets GPS coordinates to a 0.5° grid (~55 km) before calling `resolveCountry`. The bucketing was originally introduced to reduce CLGeocoder call volume; with an offline lookup, the rationale is deduplication efficiency. For region resolution two questions arise:

1. Should `resolveRegion` use bucketed or raw coordinates?
2. M16 adds two schema changes (a column to `photo_date_records` and a new `region_visits` table). Should these be one or two migration steps?

**Decision — coordinate bucketing:** `resolveRegion` is called with the **same bucketed (lat, lng) as `resolveCountry`** — i.e., the coordinate already rounded to 0.5°. This guarantees that the resolved `regionCode` is always consistent with the resolved `countryCode`: if a bucketed point is inside Country A, the region resolved from that same bucketed point will be a region of Country A (or null if it falls outside all admin1 polygons). Using a different (unbucketed) coordinate for region resolution could produce mismatches (country = "FR", regionCode = "ES-CT") at borders, which would be silently wrong.

Known limitation: photos taken within 55 km of a region border may be attributed to the wrong region. This is acceptable for a first implementation. If finer resolution is needed in future, unbucketing (with coordinate-level caching) can be introduced and existing `photo_date_records` re-resolved via a re-scan.

**Decision — schema migration:** Both schema v7 changes — `photoDateRecords.regionCode TEXT nullable` column and the new `region_visits` table — are created in a **single `if (from < 7)` migration block**. This prevents any partial schema state. The Builder creates the full migration in Task 43 (even though `region_visits` is not used until Task 44).

**Consequences:**
- Country/region consistency is guaranteed by using the same bucketed point. ✓
- The 55 km bucketing limitation now applies to both country and region attribution — documented here, not a surprise.
- Schema v7 is atomic; a device cannot be in a state where `regionCode` exists but `region_visits` does not, or vice versa.
- Task 43 writes the complete v7 migration; Task 44 adds only Dart code (no additional schema changes).

---

## ADR-052 — 4-tab navigation shell: tab index contract and data access pattern for Journal and Stats screens

**Status:** Accepted

**Context:** M17 extends the app from a 2-tab shell (Map=0, Scan=1) to a 4-tab shell. The new assignment is Map=0, Journal=1, Stats=2, Scan=3. The Planner and UX Designer produced specs for Tasks 47–49. Three structural questions require architectural decisions before the Builder starts:

1. What is the canonical tab index allocation, and how is it communicated to all code that navigates programmatically?
2. How does `JournalScreen` obtain an `EffectiveVisitedCountry?` when it only holds a `TripRecord` (country code)?
3. How does `StatsScreen` obtain achievement unlock dates, given that `AchievementRepository.loadAll()` returns only IDs (`List<String>`)?

**Decision 1 — Tab index allocation (Map=0, Journal=1, Stats=2, Scan=3):**

The tab indices are centralised in `MainShell` as named constants or documented clearly at the top of the state class. No other file hardcodes a tab index numeric literal. Callbacks (`onNavigateToScan`, `onScanComplete`) are the only cross-screen navigation hooks — screens do not call `setState` on the shell directly. `_goToScan()` and `_goToMap()` remain the canonical navigation methods and must be updated to reflect the new index assignment.

**Decision 2 — Journal → CountryDetailSheet via `effectiveVisitsProvider`:**

`JournalScreen` watches `effectiveVisitsProvider` (already a `FutureProvider`). On tap, it looks up the matching `EffectiveVisitedCountry?` by `countryCode` from the cached result. This is the correct approach. `effectiveVisitsProvider` reads from local SQLite — the resolved `AsyncValue` is already in the Riverpod cache after first load and does not re-query on each tap. No separate provider or repository call is needed.

`CountryDetailSheet` is called with `isoCode: trip.countryCode` and `visit: effectiveVisits.firstWhereOrNull((v) => v.countryCode == trip.countryCode)`. The `visit` parameter is nullable — the sheet already handles the unvisited case.

**Decision 3 — Achievement gallery requires unlock dates; `AchievementRepository` gains `loadAllRows()`:**

`AchievementRepository.loadAll()` returns `List<String>` (IDs only). The Stats screen must display unlock dates ("Unlocked 14 Jan 2024") for unlocked achievements. A new method `loadAllRows() → Future<List<UnlockedAchievementRow>>` is added to `AchievementRepository`. It returns the full Drift row (id + unlockedAt) for every unlocked achievement. `StatsScreen` uses this to build a `Map<String, DateTime>` keyed by achievement ID, then merges with `kAchievements` for the full gallery.

This is a minimal, non-breaking addition. `loadAll()` is kept for existing callers (`travelSummaryProvider`).

**Consequences:**
- The tab index contract (Map=0, Journal=1, Stats=2, Scan=3) is locked. Any future tab reorder requires updating this ADR.
- `IndexedStack` continues to keep all four screens alive — state (scroll position, map viewport) is preserved on tab switch.
- Scan moving from index 1 → 3 breaks any existing widget test that references Scan by raw index. Builder must audit all shell tests before shipping Task 47.
- `effectiveVisitsProvider` is watched (not `ref.read`) in `JournalScreen` so that the country list stays current if a manual add/remove occurs while the Journal tab is open.
- `AchievementRepository.loadAllRows()` must be added in Task 49. Its test is added in `achievement_repository_test.dart`.
- `RegionRepository.countUnique()` must be added in Task 49 (already in the Planner's acceptance criteria).
