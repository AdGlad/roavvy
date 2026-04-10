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

---

## ADR-053 — Onboarding persistence: `hasSeenOnboarding` on `ScanMetadata`; schema v8

**Status:** Accepted

**Context:** M18 requires tracking whether the user has completed or skipped the onboarding flow so that it is shown only on first launch. Two options:

1. **SharedPreferences** — simple boolean flag; available in the Flutter layer without a schema migration.
2. **Drift `ScanMetadata` column** — consistent with ADR-003 (Drift is the single local persistence mechanism on mobile); no new dependency; covered by the existing migration infrastructure.

**Decision:** Add a nullable `TextColumn hasSeenOnboardingAt` to `ScanMetadata` (null = not seen; non-null = ISO 8601 timestamp of when onboarding was dismissed). Schema becomes v8. SharedPreferences is not introduced.

The onboarding is suppressed (bypassed without writing the flag) when `effectiveVisitsProvider` returns a non-empty list — this covers reinstall scenarios where the user already has data on the device or Firestore. `hasSeenOnboardingAt` is only written when the user completes or explicitly skips onboarding with no pre-existing visits.

A new `onboardingCompleteProvider` (`FutureProvider<bool>`) reads from the DB and is watched by `RoavvyApp` (`lib/app.dart`) to decide whether to route to `OnboardingFlow` or `MainShell`. The provider returns `true` if `hasSeenOnboardingAt != null` OR if `effectiveVisitsProvider` is non-empty.

**Consequences:**
- Schema migration from v7 → v8 required; column is nullable so the migration is additive and safe.
- `RoavvyApp` becomes a `ConsumerWidget` (or `ConsumerStatefulWidget`) to watch `onboardingCompleteProvider`.
- The `ScanMetadata` upsert that writes `hasSeenOnboardingAt` must go through `VisitRepository` or a dedicated `MetadataRepository` — Builder must not write raw Drift calls from the UI layer.
- `onboardingCompleteProvider` must be overridden with a constant in all widget tests that pump `RoavvyApp` or `MainShell`.

---

## ADR-054 — Scan summary: delta computation pattern and navigation contract

**Status:** Accepted

**Context:** `ScanSummaryScreen` (Task 51) must display which countries are *new this scan* — i.e. not present before the save. Two sub-questions:

**A) How to compute the delta:**

The `ReviewScreen` already watches `effectiveVisitsProvider`. Before calling save, the current value is available synchronously via `ref.read(effectiveVisitsProvider).valueOrNull`. The delta is computed as:

```
preSaveCodes = ref.read(effectiveVisitsProvider).valueOrNull
               ?.map((v) => v.countryCode).toSet() ?? {}

// ... perform save ...

newCountries = effectiveVisitsAfterSave
               .where((v) => !preSaveCodes.contains(v.countryCode))
               .toList()
```

After save, `effectiveVisitsProvider` is invalidated by the repository write. `ReviewScreen` must `await` the re-read of `effectiveVisitsProvider` before navigating — use `ref.refresh(effectiveVisitsProvider).future` to get the post-save list.

`newAchievementIds` is computed the same way from `achievementRepositoryProvider.loadAll()` before and after save.

**B) Navigation contract:**

`ScanSummaryScreen` is pushed as a full-screen `MaterialPageRoute` from `ReviewScreen` after save completes. It is not part of the `IndexedStack` — it lives above the shell in the navigation stack.

`ScanSummaryScreen` receives a `VoidCallback onDone` parameter. When the user taps "Explore your map" or "Back to map", `onDone` is called. `ReviewScreen` passes through its own `onScanComplete` callback (already wired from `MainShell`) as `onDone`. This pops the entire navigation stack back to `MainShell` and switches to the Map tab — identical to the existing post-scan flow.

**Decision:** Pre-save snapshot via `ref.read(...).valueOrNull`, post-save re-read via `ref.refresh(...).future`, delta by set difference. Navigation via `VoidCallback onDone` passed through from `MainShell`.

**Consequences:**
- `ReviewScreen` gains a `VoidCallback onScanComplete` parameter (it may already have this — Builder to verify and thread through to `ScanSummaryScreen`).
- The `await ref.refresh(...).future` call adds one async step after save. This is acceptable — local SQLite read, sub-millisecond.
- Widget tests for `ScanSummaryScreen` pass `newCountries` and `newAchievementIds` directly as constructor parameters — no provider dependency in the screen itself.
- Achievement SnackBar notifications are removed from `ReviewScreen` only. Achievement evaluation at other write sites (manual add, startup flush) is unchanged — those sites do not currently show a notification and remain that way.

---

## ADR-055 — Celebration animation: `confetti` package with size gate; stagger via `AnimationController`

**Status:** Accepted

**Context:** M18 requires a confetti animation on `ScanSummaryScreen`. Options:

1. **`confetti` pub.dev package** — maintained, well-tested, zero setup. Binary size impact unknown until measured.
2. **Custom `CustomPainter`** — 30–50 coloured circles with basic gravity simulation; ~60 lines of Dart; zero new dependency.

**Decision:** Use the `confetti` package, subject to a binary size gate: if `flutter build ipa --analyze-size` shows the package contributing > 200 KB to the compiled app, replace with a custom `CustomPainter` implementation before the task is marked complete. Builder must run the size check before opening the PR for Task 52.

Stagger animation for country list rows uses `AnimationController` + `FadeTransition` + `SlideTransition` within `ScanSummaryScreen`'s own `StatefulWidget` — no third-party dependency. Stagger delay: 80 ms × row index, capped after row 7 (560 ms max total).

`MediaQuery.disableAnimations`: when true, `ConfettiWidget` is omitted from the widget tree entirely (not just paused); row animations are skipped (render at full opacity, zero offset from the start).

`kContinentEmoji` (`Map<String, String>`) lives in `lib/core/continent_emoji.dart` in the app layer — it is purely presentational and has no place in `shared_models`.

**Consequences:**
- `pubspec.yaml` gains `confetti: ^0.7.0` (or latest stable) — Builder to verify current version.
- `ConfettiController` must be disposed in `dispose()`.
- If the size gate triggers, the custom `CustomPainter` implementation is the fallback; no further Architect approval needed.
- `kContinentEmoji` is not exported from `shared_models`; it imports from `lib/core/` only.

---

## ADR-056 — Local push notifications: `flutter_local_notifications`, prompt timing, and tap-routing

**Status:** Accepted

**Context:** M19 requires push notifications for achievement unlocks and a 30-day scan nudge. Two delivery strategies evaluated:

1. **Remote push (FCM + Cloud Functions)** — Requires a Cloud Functions backend to trigger notifications server-side. Adds infrastructure dependency, Firebase billing surface, and deploy complexity. The triggering events (achievement unlock, scan completion) are already detected on-device.
2. **Local notifications (on-device scheduling)** — `flutter_local_notifications` schedules and fires notifications from the device. No backend required. Both triggering events are on-device lifecycle events, so local notifications cover the use case completely.

**Decision:** Local notifications via `flutter_local_notifications`. Remote push (FCM Cloud Functions) is deferred to a future milestone.

**Package:** `flutter_local_notifications` (the de-facto standard; BSD licence; maintained by the community under MaikuB). No alternatives evaluated — the package choice is clear.

**Entitlements:** Local notifications on iOS do NOT require the `aps-environment` entitlement. `Runner.entitlements` is unchanged.

**Info.plist:** No new usage description key required for notifications on iOS. (Unlike photo library access, notification permission is granted via an API call at runtime, not declared in the plist.)

**`AppDelegate.swift`:** No changes needed. `FlutterAppDelegate` already satisfies `UNUserNotificationCenterDelegate` requirements that `flutter_local_notifications` relies on.

**Prompt timing:** Permission is requested exactly once, after the first successful scan completes — specifically, in `ScanSummaryScreen` after the new-countries-found state is confirmed (i.e. `newCountries.isNotEmpty`). Not at app launch. If the user denies, the denial is recorded via `flutter_local_notifications`'s iOS permission API return value; the app does not re-prompt.

**Tap routing pattern:** When a notification is tapped, the app must navigate to the appropriate tab (Stats for achievement; Scan for nudge). Pattern:

```
NotificationService (singleton)
  ├── pendingTabIndex: ValueNotifier<int?> — set by onDidReceiveNotificationResponse
  └── getLaunchTab() → int? — reads getNotificationAppLaunchDetails() for cold starts

MainShell.initState()
  ├── reads NotificationService.getLaunchTab() for cold-start notification tap
  └── subscribes to NotificationService.pendingTabIndex for foreground/background taps
```

`NotificationService` is a singleton (not a Riverpod provider) because `FlutterLocalNotificationsPlugin` uses static/global callback registration that lives outside the Riverpod graph. It is initialized in `main()` after `Firebase.initializeApp()`.

**Payload schema:** Each notification carries a plain-string `payload` with a tab index: `"tab:2"` for Stats, `"tab:3"` for Scan. The `NotificationService` parses this and updates `pendingTabIndex`.

**Consequences:**
- `flutter_local_notifications` added to `pubspec.yaml` (app layer only — not in any package).
- `lib/core/notification_service.dart` is the single point of interaction with the plugin.
- Achievement unlock notification is scheduled from `ScanSummaryScreen` (where the unlock list is already known).
- 30-day nudge is scheduled from `ScanSummaryScreen` via `NotificationService.scheduleNudge()`; the previous nudge is cancelled with `cancelAll()` before scheduling the new one.
- No notification is shown when the app is in the foreground (iOS default behaviour for local notifications, which is correct — the achievement sheet is already visible).
- Remote push (FCM) deferred; if added later, it runs alongside local notifications without conflict.

---

## ADR-057 — iPhone-only targeting for M19 App Store submission; bundle identity fix

**Status:** Accepted

**Context:** The Flutter scaffold created with `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad) and `CFBundleDisplayName = "Mobile Flutter"`. For App Store submission:

1. iPad targeting requires an adaptive layout that passes App Store Review on iPad. The current UI is designed for compact-width iPhone.
2. Bundle display name "Mobile Flutter" is a placeholder that would appear under the app icon and in App Store search.

**Decisions:**

**Device targeting:** Set `TARGETED_DEVICE_FAMILY = "1"` in all three build configuration blocks in `project.pbxproj` (Debug, Release, Profile). Remove `UISupportedInterfaceOrientations~ipad` from `Info.plist` (dead config once iPad is excluded). iPad support is deferred to a post-launch milestone.

**Bundle identity:** Update in `Info.plist`:
- `CFBundleDisplayName` → `"Roavvy"` (shown under the app icon)
- `CFBundleName` → `"Roavvy"` (internal bundle name)

`CFBundleIdentifier` remains `$(PRODUCT_BUNDLE_IDENTIFIER)` (set in Xcode build settings to the registered App ID, e.g. `com.roavvy.app`). `CFBundleShortVersionString` and `CFBundleVersion` remain as Flutter build variable references — correct.

**Consequences:**
- App cannot be installed on iPad after this change.
- App Store Connect listing will show "iPhone" only.
- `UISupportedInterfaceOrientations~ipad` section removed from `Info.plist`.
- This decision is reversible: re-enabling iPad support requires setting `TARGETED_DEVICE_FAMILY = "1,2"` and implementing adaptive layouts.
- Bundle display name "Roavvy" will appear under the home screen icon on test devices immediately after this change is built.

---

## ADR-058 — Trip inference: geographic sequence model replaces 30-day gap clustering

**Status:** Accepted

**Context:** The current `inferTrips()` algorithm groups `PhotoDateRecord`s by country code, then clusters within each country group by a 30-day time gap. This produces wrong trip boundaries: a user who visits Japan three times within 30 days of each visit — which is common for travellers with stopovers — gets a single aggregated Japan trip instead of three. The 30-day heuristic was a simplifying assumption that does not reflect how travel actually works.

The correct model follows the traveller's chronological movement through the photo stream: a trip to country X starts when the first photo from X appears, and ends when the last photo from X appears before the stream transitions to a different country.

**Options evaluated:**

1. **30-day gap (current):** Groups by country first, then splits on gaps ≥ 30 days. Fails when multiple trips to the same country occur close together. Does not use cross-country ordering at all.

2. **Geographic sequence (run-length encoding):** Sort all `PhotoDateRecord`s globally by `capturedAt`. Walk chronologically; when `countryCode` changes, close the current trip and open a new one. Each contiguous run of the same country = one trip.

3. **Hybrid: sequence + minimum gap:** Apply the sequence model but merge adjacent same-country runs separated by fewer than N days into a single trip. Avoids splitting a trip when a traveller makes a brief day-trip to a neighbouring country. Added complexity with unclear benefit — deferred to future work if users report false splits.

**Decision:** Geographic sequence model (Option 2).

**Algorithm:**
```
Sort all PhotoDateRecord by capturedAt ascending.
currentCountry = records[0].countryCode
runStart = records[0].capturedAt
runEnd   = records[0].capturedAt
count    = 1

for each subsequent record r:
  if r.countryCode == currentCountry:
    runEnd = r.capturedAt
    count++
  else:
    emit TripRecord(currentCountry, runStart, runEnd, count)
    currentCountry = r.countryCode
    runStart = r.capturedAt
    runEnd   = r.capturedAt
    count    = 1

emit final TripRecord(currentCountry, runStart, runEnd, count)
```

**Trip ID scheme:** Unchanged — `"${countryCode}_${startedOn.toUtc().toIso8601String()}"`. IDs will differ from the 30-day model because `startedOn` values change, so all existing inferred trips will be replaced by bootstrap on next launch. Manual trips (`isManual: true`) are never re-inferred and are unaffected.

**Impact on `inferRegionVisits()`:** No change needed. The function matches photos to trips by checking whether `capturedAt` falls within `[t.startedOn, t.endedOn]`. Under the new model, trip windows are tighter (covering only the actual run), so photos that previously fell outside a trip window (e.g. gap photos) are now more accurately placed. The existing logic is correct.

**Files to change:**
- `packages/shared_models/lib/src/trip_inference.dart` — replace per-country clustering with global sequence walk; remove `gap` parameter
- `packages/shared_models/test/trip_inference_test.dart` — update tests; add alternating-country, non-adjacent same-country cases

**Consequences:**
- All inferred trips are re-derived on next bootstrap run; Drift `trips` table is effectively reset for inferred rows.
- Manual trips are preserved; `BootstrapService` must skip `isManual = true` rows when re-inferring.
- Users may see more trips than before (good — more accurate); trip count in Stats screen will reflect real visit count.

---

## ADR-059 — Confetti: ScanSummaryScreen push moved from ReviewScreen to ScanScreen

**Status:** Accepted

**Context:** `ScanSummaryScreen` with confetti was intended to fire after every scan that produces new countries. The current wiring is:

1. `ScanScreen._scan()` saves scan results, calls `widget.onScanComplete()` → navigates to Map tab. No ScanSummaryScreen.
2. "Review & Edit" button opens `ReviewScreen`, which — when `onScanComplete != null` — pushes `ScanSummaryScreen` from `_save()`.

This means confetti only fires if: (a) the user taps "Review & Edit", AND (b) they make a manual change that shifts the effective country set. In practice (b) never happens for new countries because `initialVisits` already contains the post-scan countries — `preSaveCodes` equals the post-scan set, so `newCountries = effective − preSaveCodes = ∅`. Confetti never fires.

**Root cause:** The delta computation in `ReviewScreen._save()` uses `widget.initialVisits` as the pre-scan baseline. But `ScanScreen._openReview()` passes `_effectiveVisits` — the post-scan effective visits — so the baseline already contains the new countries.

**Options evaluated:**

1. **Pass `preScanCodes` into ReviewScreen:** Add a `preScanCodes: Set<String>?` parameter to ReviewScreen. ScanScreen captures codes before calling `clearAndSaveAllInferred()`, passes them in. ReviewScreen uses `preScanCodes ?? preSaveCodes` for the delta. Complex — ReviewScreen now carries two baselines.

2. **Move ScanSummaryScreen push to ScanScreen:** After `_scan()` computes `newCodes` and `effective`, push `ScanSummaryScreen` directly. `ScanSummaryScreen.onDone` calls the provided callback (originally `widget.onScanComplete` → goes to Map). ReviewScreen's `onScanComplete` path is removed — "Review & Edit" becomes a pure editor that pops on save.

**Decision:** Option 2. ScanScreen is the owner of the scan lifecycle. ScanSummaryScreen is a scan lifecycle concern, not a review concern.

**New scan flow:**
```
ScanScreen._scan()
  → saves scan results
  → computes newCountryCodes (preScanCodes ← loaded before clearAndSaveAllInferred)
  → computes newCountries (EffectiveVisitedCountry objects for new codes)
  → pushes ScanSummaryScreen(newCountries, newAchievementIds, onDone: widget.onScanComplete)

ScanSummaryScreen.onDone → widget.onScanComplete() → MainShell navigates to Map
```

**Review & Edit flow (unchanged from user perspective):**
```
ScanScreen "Review & Edit" button
  → opens ReviewScreen(initialVisits: _effectiveVisits, onScanComplete: null)
  → ReviewScreen._save() pops (no ScanSummaryScreen, no confetti)
```

Note: `onScanComplete` is no longer passed to ReviewScreen from `_openReview()`. ReviewScreen uses `onScanComplete` only to decide whether to push ScanSummaryScreen — removing it from the review-edit path is correct.

**Notification permission prompt:** Currently in `ScanSummaryScreen` (ADR-056). This remains correct — it fires when `newCountries.isNotEmpty` after a scan.

**Files to change:**
- `apps/mobile_flutter/lib/features/scan/scan_screen.dart`
  - In `_scan()`: capture `preScanCodes` before `clearAndSaveAllInferred`; push `ScanSummaryScreen` instead of calling `widget.onScanComplete()` at end
  - In `_openReview()`: remove `onScanComplete:` parameter (pass null or omit)
- `apps/mobile_flutter/lib/features/visits/review_screen.dart`
  - Remove `ScanSummaryScreen` push from `_save()` (the `if (widget.onScanComplete != null)` branch); replace with direct `Navigator.pop()`
  - Remove `_handleSummaryDone()` (no longer needed)
- `apps/mobile_flutter/test/features/scan/scan_screen_incremental_test.dart` — update
- `apps/mobile_flutter/test/features/visits/review_screen_test.dart` — remove ScanSummaryScreen tests; add pop-on-save test

**Consequences:**
- Confetti fires reliably after every scan that finds new countries.
- ReviewScreen is simplified: it is purely an editor, with no awareness of the scan lifecycle.
- `ScanSummaryScreen` is still imported by ScanScreen only (one call site).

---

## ADR-060 — PHAsset local identifiers stored in local SQLite; never in Firestore

**Status:** Accepted

**Context:** The photo gallery feature (Task 64) requires fetching thumbnails by `PHAsset.localIdentifier` at display time. The current privacy model (`docs/architecture/privacy_principles.md`) states that asset identifiers are "held in memory during scan for deduplication only. Never written to local DB or Firestore." Persisting them is a deliberate change to that model and requires explicit justification.

**Privacy assessment:**
- A `PHAsset.localIdentifier` is an opaque UUID (`"3B234F7C-..."`). It has no intrinsic meaning — it is not a filename, not a path, not an EXIF tag, and contains no GPS or date metadata.
- It cannot be used to reconstruct photo content without physical access to the same device with the same Photos library.
- It is already stored by the iOS OS in the Photos database on the same device. Writing it to a second local SQLite file adds no material privacy risk.
- It must never be written to Firestore or transmitted over any network. The asset ID is meaningless to any other device.

**Decision:** Store `PHAsset.localIdentifier` in the `photo_date_records` Drift table as a nullable `assetId TEXT` column. It is never synced to Firestore. `docs/architecture/privacy_principles.md` is updated to reflect this.

**Schema change:** Drift schema v9. New nullable column `assetId TEXT` on `PhotoDateRecords`. Migration: `ALTER TABLE photo_date_records ADD COLUMN asset_id TEXT;` — existing rows get NULL (acceptable; gallery simply shows nothing for pre-upgrade records until a fresh scan runs).

**Data flow:**
```
Swift PhotoKit bridge
  → includes localIdentifier in each photo record payload
  → Dart PhotoRecord.fromMap() parses assetId
  → resolveBatch() carries assetId through to PhotoDateRecord
  → ScanScreen._scan() writes PhotoDateRecord including assetId to Drift
  → PhotoDateRecord.assetId is available for gallery queries
```

**`PhotoDateRecord` model change:** Add `final String? assetId` field. This model lives in `packages/shared_models`. Because `PhotoDateRecord` is only used in Dart (not TypeScript), no TypeScript counterpart change is required.

**`PhotoRecord` (photo_scan_channel.dart) change:** Add `final String? assetId` field; parse from `m['assetId']` in `fromMap()`.

**Swift change:** `PhotoScanPlugin` must include `localIdentifier` in each photo batch map entry. Field key: `"assetId"`.

**`FirestoreSyncService`:** No change. Asset IDs are not in the sync payload. The Firestore document schema is unchanged.

**Consequences:**
- `photo_date_records` table grows by one nullable TEXT column — negligible storage impact.
- Historical records (pre-v9) have NULL assetId; gallery shows empty state for those countries until user rescans.
- Privacy principles doc is updated; the change is transparent to users (on-device only).
- `packages/shared_models` CLAUDE.md constraint "backwards-compatible changes only" is satisfied — `assetId` is a new optional field.

---

## ADR-061 — Photo gallery: `photo_manager` package for on-device thumbnail fetch

**Status:** Accepted

**Context:** The photo gallery (Task 64) needs to fetch photo thumbnails by `PHAsset.localIdentifier` and display them in a grid. Two approaches were evaluated:

1. **Extend custom Swift channel:** Add a `fetchThumbnails(assetIds: [String])` MethodChannel method to `PhotoScanPlugin.swift`. Returns `List<Uint8List>` (encoded PNGs). Keeps all PhotoKit interaction in the existing Swift bridge.

2. **`photo_manager` pub.dev package:** Cross-platform Flutter plugin wrapping PHAsset (iOS) and MediaStore (Android). `AssetEntity.id` maps directly to `PHAsset.localIdentifier`. Provides `AssetEntity.thumbnailDataWithSize()` for on-demand thumbnail fetch. Managed, tested, widely adopted.

**Decision:** `photo_manager` (Option 2).

**Rationale:**
- Extending the custom Swift channel requires significant new Swift code: batch fetching, image resizing, PNG encoding, and returning large binary blobs over a MethodChannel. This is non-trivial and re-implements what `photo_manager` already does correctly.
- `photo_manager` already holds PHPhoto library permission via its own `PhotoManager.requestPermissionExtend()` call. Since the user has already granted permission during scanning, the gallery will receive `.authorized` or `.limited` without prompting again.
- `photo_manager`'s `AssetEntity.id` on iOS is exactly `PHAsset.localIdentifier`. The stored `assetId` values from the scan pipeline map directly to `AssetEntity`.
- Future Android support (post App Store launch) is handled by `photo_manager` for free.

**Permission handling:** `photo_manager` checks permission before fetching. The app already has photo library permission from the scan; `photo_manager` will receive the existing grant. No additional permission prompt is shown to the user.

**Thumbnail API:** `AssetEntity.thumbnailDataWithSize(ThumbnailSize(150, 150))` returns `Uint8List?`. Display via `Image.memory()` in a `GridView`. Loading state per cell via `FutureBuilder`.

**Full-image view:** Tap on thumbnail → `AssetEntity.file` (returns a `File`) → display via `Image.file()` in a full-screen route with `InteractiveViewer` for pinch-to-zoom. This is fully on-device; no network call.

**Files to change:**
- `apps/mobile_flutter/pubspec.yaml` — add `photo_manager: ^3.x`
- `apps/mobile_flutter/lib/features/map/photo_gallery_screen.dart` — new widget
- `apps/mobile_flutter/lib/features/map/country_detail_sheet.dart` — add Photos tab
- `apps/mobile_flutter/ios/Podfile` — `pod install` will pick up `photo_manager`'s pod

**No Swift changes required.** The existing `PhotoScanPlugin.swift` is unchanged.

**Consequences:**
- `photo_manager` takes over PHAsset access for gallery display. The scan pipeline continues using the custom Swift `EventChannel` for streaming GPS records (different use case — not replaced).
- App binary size increases by the `photo_manager` framework (~200 KB compiled).
- Gallery is fully offline; no network call is ever made to fetch photos.
- Thumbnails are decoded lazily per visible cell — no upfront memory spike.

---

## ADR-062 — Commerce architecture: backend-mediated Shopify integration

**Status:** Accepted

**Context:** Roavvy Phase 10 requires a Shopify checkout flow where the user's visited country list and design configuration are attached to a cart before handoff. An initial architecture considered calling the Shopify Storefront API directly from the mobile app or web browser (client-side). This is rejected for the following reasons:

- The Shopify Admin API (required for order management and webhook verification) uses a private access token that must never be embedded in a client binary or web bundle — it would be trivially extractable.
- The `MerchConfig` document (the full design specification for a user's order) must be persisted in Firestore before the cart is created, so that a Shopify order webhook can later link back to it. This server-side write cannot happen from the mobile client without bypassing security rules.
- Cart custom attributes in Shopify are limited in size (~255 chars per value). A user with 100+ countries produces a `visitedCodes` string that exceeds this limit. The solution is to store the full config in Firestore and pass only a `merchConfigId` reference as the Shopify cart attribute.
- Centralising Shopify interaction in Firebase Functions makes it easier to add rate limiting, retry logic, and audit logging in one place.

**Decision:** Commerce uses a four-layer architecture:

```
Mobile app (Flutter / Next.js)
    │  POST /createMerchCart  {designPayload}
    ▼
Firebase Functions (backend orchestration layer)
    │  cartCreate mutation (Storefront API)
    ▼
Shopify (hosted checkout, order management)
    │  order fulfillment (Shopify app connection)
    ▼
Print-on-demand provider (Printful / Printify)
```

**Mobile app responsibilities (only):**
- Display product templates and design options
- Let the user configure their design (country selection, style, placement, colour, size)
- Send the design payload to the Firebase Functions `POST /createMerchCart` endpoint
- Open the returned `checkoutUrl` in `SFSafariViewController` (iOS) or redirect (web)

**Firebase Functions responsibilities:**
- Validate the user via Firebase Auth
- Save a `MerchConfig` document to Firestore (`users/{uid}/merch_configs/{configId}`)
- Create a Shopify cart via the Storefront API `cartCreate` GraphQL mutation
- Attach `merchConfigId` as a cart custom attribute
- Return `{ checkoutUrl, cartId, merchConfigId }` to the app
- Handle the Shopify `orders/create` webhook: link `orderId` to the `MerchConfig` document in Firestore

**`MerchConfig` document structure (Firestore):**

```
users/{uid}/merch_configs/{configId}
  userId: string
  templateId: string            // e.g. "flag-tee", "travel-poster"
  selectedCountryCodes: string[] // ISO 3166-1 alpha-2
  designStyle: string           // "world_map" | "flags" | "passport_stamps"
  placement: string             // "front_only" | "back_only" | "front_and_back"
  colour: string                // e.g. "black", "white", "navy"
  size: string                  // e.g. "M", "L", "XL"
  previewImageUrl: string?      // URL of the mockup image shown in the design studio
  shopifyCartId: string?        // populated after cart creation
  shopifyOrderId: string?       // populated after order webhook
  createdAt: timestamp
```

**Cart attribute strategy:**
- Shopify cart carries only: `{ "merchConfigId": "<Firestore doc ID>" }`
- Full design configuration stays in Firestore — no SKU explosion, no Shopify attribute size limit issues
- POD provider reads the order from Shopify; for the PoC the store owner manually attaches the print file

**Shopify API choice — Option A (Storefront API + cart + checkoutUrl):**
- Firebase Functions calls Shopify Storefront API using a public Storefront access token
- `cartCreate` mutation returns a `Cart` object with a `checkoutUrl`
- `checkoutUrl` is returned to the app and opened in `SFSafariViewController`
- Chosen over Draft Orders (Option B) because Draft Orders require Admin API and add complexity; the Storefront API cart flow is the standard Shopify headless checkout path

**Print-on-demand — Shopify app connection (not direct API):**
- The POD provider (Printful / Printify) connects to the Shopify store as a Shopify app
- POD receives orders automatically through Shopify's fulfilment app mechanism — no direct Roavvy→POD API call is needed for the PoC
- For the PoC, custom per-order print file generation (generating unique artwork from the country code list) is deferred. The store owner manually supplies or selects the print file per order.
- Post-PoC: Firebase Functions will generate the print file and submit it to the POD provider's API when an order arrives via the `orders/create` webhook

**Credentials:**
- Shopify Admin API token: Firebase Functions environment variables only — never in mobile app or web client
- Shopify Storefront API token (public): used by Firebase Functions for cart creation; could also be used client-side but is kept server-side for consistency and to avoid exposing the token in client bundles
- POD API key (if needed post-PoC): Firebase Functions environment variables

**Consequences:**
- A new Firebase Functions package is required (`functions/` directory or equivalent); Cloud Functions must be enabled on the Firebase project (Blaze/pay-as-you-go plan)
- The Firestore `users/{uid}/merch_configs` subcollection is a new collection; security rules must restrict reads/writes to the authenticated owner
- Admin API token never leaves Firebase Functions; reduces the attack surface for credential leakage
- The PoC defers custom per-order print file generation — POD fulfils from Shopify order data with a manually supplied print file
- `MerchConfig` in Firestore enables future features: order history screen, reorder, sharing a design link

---

## ADR-063 — Print-on-demand partner: Printful

**Status:** Accepted (Task 65 — 2026-03-20); fulfilment model revised (M21 — 2026-03-21, see below)

**Context:** Roavvy Phase 10 requires a print-on-demand provider that integrates with Shopify as a Shopify app, supports t-shirt and travel poster products, and allows a per-order workflow where the store owner can supply or attach a print file for the PoC. Two platforms were evaluated: Printful and Printify.

**Decision:** Printful.

**Rationale:**
- Printful integrates with Shopify as a native Shopify app — orders flow from Shopify to Printful automatically, matching the ADR-062 architecture.
- Printful supports the required product types: Gildan / Bella+Canvas t-shirts (multiple colours and sizes) and wall art / poster products.
- Printful provides a mockup generation API callable from Firebase Functions — required for the design studio live preview.
- Printful's per-order workflow allows the store owner to supply a custom print file per order in the PoC, with a path to automated file submission post-PoC via their API.
- Printful has clear API documentation, a sandbox/test environment, and is widely used in production Shopify integrations.

**PoC fulfilment model (M20 — superseded):**
- Printful connects to the Shopify store as a Shopify app.
- When a Shopify order is placed, Printful receives it automatically.
- For the PoC, the store owner manually supplies or selects the print file in the Printful dashboard per order.

**M21 revision — Printful Shopify app removed from critical path:**
From M21 onwards the Printful Shopify app is **not** the primary fulfilment mechanism for generated merch. The Printful API is used directly by Firebase Functions to create and submit orders. Reason: the Shopify app is designed for static synced-product workflows; it provides no control point at which to attach a dynamically generated per-order print file before the order is sent to production. Pure API orchestration gives full deterministic control over file attachment.

- **Primary path (M21+):** `shopifyOrderCreated` Firebase Function calls `POST /v2/orders` on the Printful API with the generated print file already attached to the line item. The Printful Shopify app integration is bypassed for custom-generated orders.
- **Fallback:** The Printful Shopify app may remain installed on the store for operational familiarity and manual fallback, but it must not be in the automated critical path for generated merch. Ensure the app does not auto-import the same orders that the Firebase Function is already fulfilling (disable auto-import in Printful app settings if needed).

**Consequences:**
- Task 68: Create a Printful account, install the Printful Shopify app, and link Shopify product variants to Printful SKUs.
- Mockup API: Printful's mockup generator endpoint is called from Firebase Functions. The Printful API key is stored in Firebase Functions environment variables only.
- If Printful pricing or product range is later found to be unacceptable, migration to Printify is feasible — only the product SKU mapping and API calls change.
- **M21:** Printful Shopify app auto-import must be disabled for the product variants handled by the generated-merch pipeline. Manual dashboard file attachment is fully retired.

---

## ADR-064 — Firebase Functions v2: project structure, function types, and Storefront token strategy

**Status:** Accepted (Task 70 — 2026-03-21)

**Context:** M20 requires two Firebase Functions for the commerce layer (ADR-062): `createMerchCart` (called by the mobile app) and `shopifyOrderCreated` (called by Shopify as a webhook). Before implementation begins, three structural choices must be settled: which Firebase Functions SDK generation to use, which function invocation model to use for each endpoint, and how to supply the Shopify Storefront API token at runtime.

**Decision 1 — Firebase Functions v2 (2nd generation)**

Use `firebase-functions/v2` (Cloud Run-backed). v2 is the current recommended generation; v1 is in maintenance mode. v2 provides better cold-start behaviour, configurable concurrency, and a cleaner SDK surface. The `apps/functions/` project uses `firebase-functions` v6+, which ships v2 as the primary API.

**Decision 2 — `onCall` for `createMerchCart`, `onRequest` for `shopifyOrderCreated`**

`createMerchCart` uses `onCall` (Firebase Callable Functions):
- `onCall` automatically verifies the Firebase Auth ID token in the request; the `context.auth` object is populated or the call is rejected before any application code runs
- `onCall` handles CORS automatically — no manual header management needed
- The mobile Firebase SDK sends the ID token transparently; no custom auth header logic in Dart

`shopifyOrderCreated` uses `onRequest` (raw HTTP):
- Shopify webhooks are plain HTTPS POST requests — they cannot use the Firebase callable protocol
- `onRequest` exposes a raw `(req, res)` handler, giving full access to the raw request body needed for HMAC-SHA256 verification
- HMAC verification must be performed before reading `req.body` as parsed JSON; the raw buffer must be captured using a `Buffer` middleware or `express.raw()` before any JSON parsing

**Decision 3 — `SHOPIFY_STOREFRONT_TOKEN` is a long-lived public token; no refresh logic in PoC**

The Shopify Storefront API access token (`SHOPIFY_STOREFRONT_TOKEN`) is a public app credential created in the Shopify Partner Dashboard. It does not expire on a time basis — it is revoked only by regenerating it in the dashboard. This is distinct from the Admin API short-lived tokens obtained via client credentials grant.

Consequence: `createMerchCart` reads `SHOPIFY_STOREFRONT_TOKEN` from `process.env` and uses it directly as the `X-Shopify-Storefront-Access-Token` header. No token exchange or refresh loop is required for the PoC.

The client credentials grant (documented in `commerce_api_contracts.md` §2) is the Admin API token flow and is deferred to post-PoC (needed only when Firebase Functions must call Admin API endpoints, e.g. order management or fulfilment).

**Decision 4 — `MerchConfig` TypeScript type defined in `apps/functions/src/types.ts`**

The `MerchConfig` document structure (ADR-062) is a Firestore document written and read exclusively by Firebase Functions in the PoC. The mobile app does not read `MerchConfig` documents directly — it only receives `{ checkoutUrl, cartId, merchConfigId }` from the callable function.

Defining `MerchConfig` in `packages/shared_models` would require a Dart mirror class and a TypeScript export — both unused in the PoC. Defining it in `apps/functions/src/types.ts` keeps it co-located with the only consumer and avoids premature cross-package coupling. If the mobile app later needs to render order history from `MerchConfig` documents, the type is promoted to `packages/shared_models` at that point.

**Decision 5 — Firestore security rules: no new rules required for `merch_configs`**

The existing rule `match /users/{userId}/{document=**}` with a wildcard `{document=**}` segment (ADR-029) already covers all subcollections under `users/{uid}/`, including `merch_configs/{configId}`. Adding a new explicit rule for `merch_configs` is unnecessary and would be dead code. The Task 71 acceptance criterion that mentioned "deploy new Firestore security rules" is removed.

**Decision 6 — Firebase project wiring**

- `.firebaserc` (repo root): maps default alias to project `roavvy-prod`
- `firebase.json` (repo root): adds a `functions` block pointing `source` at `apps/functions/` and `runtime` at `nodejs22`

Both files must be created/updated in Task 70 before any function can be deployed.

**Consequences:**
- `createMerchCart`: `onCall` — Firebase SDK in Dart handles auth token automatically; no custom header required in the Flutter caller
- `shopifyOrderCreated`: `onRequest` — must capture raw body before JSON parsing for HMAC verification; use `express.raw({ type: 'application/json' })` as the first middleware
- No Admin API token exchange logic in M20 PoC — the `client_id`/`client_secret` in `.env` are not used by the PoC functions (they were needed only for the variant setup scripts in M20A)
- Firestore rules remain unchanged from their current state

---

## ADR-065 — Per-order custom flag image generation pipeline

**Status:** Accepted (M21 planning — 2026-03-21)

**Context:** Every Roavvy merch order is personalised to the buyer's exact visited country set. The print file submitted to Printful must be unique per order — a composition of the customer's country flags, not a generic catalog product. The M20 PoC deferred this to manual Printful dashboard file attachment. M21 must automate the full pipeline.

**Core constraint:** Shopify webhooks must not perform heavy work. Webhook handlers are event notifications; a long image render inside `shopifyOrderCreated` is a reliability risk (timeout, retry storms, slow fulfilment). The generation must happen before the webhook fires.

---

### Decision: Two-stage model — generate at `createMerchCart` time; webhook only validates and submits.

**Stage 1 — `createMerchCart` (onCall, before checkout):**
1. Write `MerchConfig` to Firestore with `designStatus: 'pending'`.
2. Generate a **preview PNG** (web-optimised, ~800px wide, JPEG quality 80): returned to the mobile app for display if needed; uploaded to Firebase Storage at `previews/{configId}.jpg`.
3. Generate the **print PNG** (300 DPI at the product's full print dimensions): uploaded to Firebase Storage at `print_files/{configId}.png`. A signed URL (7-day expiry) is written to `MerchConfig.printFileSignedUrl`.
4. Update `MerchConfig`:
   ```typescript
   designStatus: 'files_ready';
   previewStoragePath: `previews/${configId}.jpg`;
   printFileStoragePath: `print_files/${configId}.png`;
   printFileSignedUrl: '<signed URL>';
   printFileExpiresAt: Timestamp; // now + 7 days
   ```
5. Return `{ checkoutUrl, cartId, configId, previewUrl }` to the mobile app.

If generation fails, `designStatus` is set to `'generation_error'`; the callable returns a typed error and the mobile app shows a "Try again" message. Cart is not created.

**Cart abandonment handling:** Design records with `designStatus !== 'ordered'` and `createdAt` older than 30 days are deleted by a scheduled cleanup function (Cloud Scheduler). Firebase Storage objects at `previews/` and `print_files/` are deleted in the same job. This bounds waste from abandoned carts.

**Stage 2 — `shopifyOrderCreated` (onRequest, webhook):**
1. Verify HMAC; look up `MerchConfig` by `configId` (existing logic).
2. Check `designStatus`:
   - `'files_ready'`: proceed.
   - `'generation_error'` or any other state: attempt regeneration once (same generator call). If it fails again, set `designStatus: 'print_file_error'`, log, return 200.
3. Create a Printful order via **direct API call** (`POST https://api.printful.com/v2/orders`):
   - Map `MerchConfig.variantId` (Shopify GID) to a Printful variant ID using the static mapping table.
   - Attach the print file to the line item using the Firebase Storage signed URL (or re-generate a fresh signed URL if `printFileExpiresAt` is within 1 hour).
4. Store `printfulOrderId` in `MerchConfig`; update `status: 'ordered'`, `designStatus: 'print_file_submitted'`.
5. Return 200. Shopify does not retry.

---

### Template: `flag_grid` (v1 only)

**v1** ships a single template: `flag_grid`. Flags are composited in a rectangular grid, left-to-right, top-to-bottom, sorted by country name. Each flag is 4:3 aspect ratio. Background is white (poster) or transparent (t-shirt DTG).

Layout algorithm input:
```typescript
{
  templateId: 'flag_grid_v1';
  selectedCountryCodes: string[];       // ISO 3166-1 alpha-2
  productType: 'poster' | 'tshirt';
  widthPx: number;
  heightPx: number;
  dpi: 300;
  backgroundColor: 'white' | 'transparent';
}
```

Flag source: `flag-icons` npm package — 4:3 SVG, MIT-licensed, bundled in `apps/functions/`. No network calls at render time.

Renderer: `@resvg/resvg-js` rasterises each flag SVG to PNG at the computed cell size; `sharp` composites the grid onto the canvas and outputs the final PNG buffer.

Minimum flag cell size: 100×67px. If the print canvas is too small to fit all flags at minimum size, the grid uses as many flags as fit and appends a legend strip listing overflow country names in small text.

---

### `MerchConfig` additions (full updated type)

```typescript
interface MerchConfig {
  // existing M20 fields
  configId: string;
  userId: string;
  variantId: string;
  selectedCountryCodes: string[];
  quantity: number;
  shopifyCartId: string | null;
  shopifyOrderId: string | null;
  status: 'pending' | 'cart_created' | 'ordered';

  // M21 additions
  templateId: 'flag_grid_v1';
  designStatus: 'pending' | 'files_ready' | 'generation_error' | 'print_file_submitted' | 'print_file_error';
  previewStoragePath: string | null;
  printFileStoragePath: string | null;
  printFileSignedUrl: string | null;
  printFileExpiresAt: Timestamp | null;
  printfulOrderId: string | null;
}
```

---

### Static print dimension map (in `apps/functions/src/printDimensions.ts`)

| Shopify variant GID suffix | Product | Printful SKU area | widthPx | heightPx | dpi |
|---|---|---|---|---|---|
| T-shirt (all sizes/colours) | DTG front | 4500 × 5400 | 4500 | 5400 | 150 |
| Poster 12×18in | Wall art | 3600 × 5400 | 3600 | 5400 | 300 |
| Poster 18×24in | Wall art | 5400 × 7200 | 5400 | 7200 | 300 |
| Poster 24×36in | Wall art | 7200 × 10800 | 7200 | 10800 | 300 |
| Poster A3 | Wall art | 3508 × 4961 | 3508 | 4961 | 300 |
| Poster A4 | Wall art | 2480 × 3508 | 2480 | 3508 | 300 |

---

### Printful order creation (pure API — see ADR-063 revision)

```
POST https://api.printful.com/v2/orders
Authorization: Bearer {PRINTFUL_API_KEY}
{
  "recipient": { /* from Shopify order shipping address */ },
  "items": [{
    "variant_id": <printful_variant_id>,
    "quantity": 1,
    "files": [{ "url": "<printFileSignedUrl>", "type": "default" }]
  }],
  "external_id": "<shopifyOrderId>"
}
```

The `external_id` links the Printful order to the Shopify order for tracking and support lookup.

---

### Consequences

- `apps/functions/package.json` gains: `flag-icons`, `@resvg/resvg-js`, `sharp`.
- `apps/functions/src/types.ts` gains M21 fields on `MerchConfig` (above).
- `apps/functions/src/printDimensions.ts` — new static map.
- `apps/functions/src/imageGen.ts` — new `generateFlagGrid(input)` helper.
- Firebase Storage bucket must be configured; `print_files/` and `previews/` paths are private (signed URL access only).
- `PRINTFUL_API_KEY` env var required from M21 onwards.
- Shopify variant GID → Printful variant ID mapping table required (Task 77).
- A Cloud Scheduler job for design record cleanup is deferred to post-M21 (30-day retention is acceptable as manual cleanup for MVP).
- Future templates (`heart_frame`, `map_silhouette`, etc.) add entries to the template dispatcher in `imageGen.ts` without changing the pipeline.

---

## ADR-066 — `CountryPolygonLayer` replaces imperative polygon building in `MapScreen` (M22)

**Status:** Accepted

**Context:**
`MapScreen` currently builds its polygon list imperatively in `_init()` — an async function called in `initState` that reads `polygonsProvider` and `effectiveVisitsProvider` once and stores `_mapPolygons` as local `State`. This worked while polygons had a single visual state (visited/unvisited). M22 adds 5 visual states, two of which (`newlyDiscovered`) require continuous animation. A single flat list of `Polygon` objects cannot express animated per-state fill changes without forcing a full rebuild of the entire polygon set on every animation tick — prohibitively expensive on a 200-country dataset.

**Decision:**
Introduce `CountryPolygonLayer` as a `ConsumerStatefulWidget` that owns all polygon rendering and replaces the `PolygonLayer` call in `MapScreen`.

- `CountryPolygonLayer` watches `polygonsProvider`, `effectiveVisitsProvider`, and `recentDiscoveriesProvider` reactively via `ref.watch`.
- It creates **two separate `PolygonLayer` instances**:
  1. **Static group** — `unvisited`, `visited`, `reviewed`, `target` polygons; rebuilt only when provider values change (no animation tick involvement).
  2. **Animated group** — `newlyDiscovered` polygons only; driven by a single `AnimationController` owned by `CountryPolygonLayer`; only this layer rebuilds on each tick via `AnimatedBuilder`.
- `MapScreen._init()` and `_mapPolygons` state are removed. `MapScreen` retains `_visitedByCode` (for tap resolution) but derives it from `effectiveVisitsProvider` via `ref.watch` in `build()` instead of imperative load.
- `MapScreen` passes no polygon data to `CountryPolygonLayer`; the widget is self-contained.

**Consequences:**
- Animated countries re-render at the animation frame rate; all static countries re-render only on data changes — correct performance profile.
- `MapScreen` becomes significantly simpler: no `_init()` async imperative load, no `_mapPolygons` state, no `_loading` flag driven by polygon init (loading state may remain for overall app init).
- Existing `MapScreen` widget tests that stub `polygonsProvider` and `effectiveVisitsProvider` continue to work; `CountryPolygonLayer` tests are added separately.
- `_visitedByCode` must remain in `MapScreen` for tap resolution; it is computed from `ref.watch(effectiveVisitsProvider)` synchronously in `build()` (no await needed after M22).

---

## ADR-067 — `recentDiscoveriesProvider` uses SharedPreferences with lazy async init (M22)

**Status:** Accepted

**Context:**
`recentDiscoveriesProvider` tracks ISO codes discovered in the last 24 hours, persisted across app restarts so newly-discovered polygons keep their amber pulse if the user force-quits and re-opens the app. Drift (the existing SQLite layer) is heavier than needed for a small JSON list with a 24h TTL. SharedPreferences is already in `pubspec.yaml` (used by `flutter_local_notifications`).

SharedPreferences is not currently in the Riverpod provider graph. Adding it requires an async initialisation step.

**Decision:**
`recentDiscoveriesProvider` is a `StateNotifierProvider<RecentDiscoveriesNotifier, Set<String>>`.

- `RecentDiscoveriesNotifier` starts with state `<String>{}` (empty set) synchronously.
- In its constructor it fires `_loadFromPrefs()` — an async private method that calls `SharedPreferences.getInstance()`, reads the `recent_discoveries_v1` key, deserialises the JSON list, filters out entries where `discoveredAt < now - 24h`, and updates state.
- `add(String isoCode)` appends to state immediately and serialises the full list to SharedPreferences via `unawaited(prefs.setString(...))`.
- `clear()` resets state to `<String>{}` and removes the SharedPreferences key.
- SharedPreferences instance is cached as a local field after the first `getInstance()` call; subsequent `add()` calls do not call `getInstance()` again.
- No change to `main.dart` or `ProviderScope` overrides is needed.

**Why not a `FutureProvider`?**
A `FutureProvider<Set<String>>` would make the consumer need to handle `AsyncValue` — adding `when(loading/error/data)` branches throughout `CountryPolygonLayer`. Since the 24h window means a brief cold-start race (polygons start as `unvisited`, then flip to `newlyDiscovered` ~one frame later once prefs load) is acceptable, the simpler `StateNotifier` with async background init is preferred.

**Consequences:**
- There is a one-frame window at cold start where `recentDiscoveriesProvider` is empty; any `newlyDiscovered` countries will flash from `visited` to `newlyDiscovered` amber pulse. This is imperceptible in practice.
- No SharedPreferences provider is added to `lib/core/providers.dart` — the notifier owns its own prefs instance. This keeps the provider graph simple.
- `add()` is safe to call from `unawaited()` contexts (it does not throw).

---

## ADR-068 — `DiscoveryOverlay` is pushed from `ScanSummaryScreen` on dismissal (M22)

**Status:** Accepted

**Context:**
ADR-054 defines the scan navigation stack: `ReviewScreen._save()` computes the pre/post-save delta, pushes `ScanSummaryScreen`, and `ScanSummaryScreen._handleDone()` double-pops to land back on `MapScreen`. M22 adds `DiscoveryOverlay` — a full-screen celebration for newly discovered countries. Where to insert it without breaking the ADR-054 stack was an open question.

**Options considered:**
1. Push `DiscoveryOverlay` from `ReviewScreen._save()` *before* `ScanSummaryScreen` — results in `MapScreen → ReviewScreen → DiscoveryOverlay → ScanSummaryScreen`; complex double-pop becomes triple-pop.
2. Push `DiscoveryOverlay` from `ReviewScreen._save()` *instead of* `ScanSummaryScreen` — removes the summary screen for new-country scans; loses confetti + achievement chips.
3. Push `DiscoveryOverlay` from `ScanSummaryScreen._handleDone()` before the double-pop — the summary screen shows first (confetti, achievements), then the overlay for the primary new country. Stack: `MapScreen → ReviewScreen → ScanSummaryScreen → DiscoveryOverlay`. Tapping "Explore your map" on the overlay pops it, landing back on `ScanSummaryScreen`; ADR-054 double-pop then clears `ReviewScreen` and `ScanSummaryScreen`, landing on `MapScreen`.

**Decision:** Option 3 — `DiscoveryOverlay` is pushed from `ScanSummaryScreen._handleDone()` for the first newly discovered country only.

- `ScanSummaryScreen` receives the list of newly discovered country codes (already known as part of the pre/post delta).
- If the list is non-empty, `_handleDone()` pushes `DiscoveryOverlay` for `newCodes.first` instead of immediately double-popping.
- `DiscoveryOverlay`'s "Explore your map" CTA calls `Navigator.of(context).popUntil(ModalRoute.withName('/'))` to clear the full scan stack in one operation — more robust than a counted pop.
- `recentDiscoveriesProvider.add(isoCode)` is called for *all* new country codes from `ScanSummaryScreen._handleDone()`, not just the one shown in the overlay, so all new countries get the amber pulse.

**Consequences:**
- ADR-054 double-pop is replaced by `popUntil('/')` from the overlay CTA; simpler and stack-count-independent.
- `ScanSummaryScreen` must accept a `List<String> newCodes` parameter (or derive it from its existing `delta` parameter).
- The overlay appears after the summary screen — users see confetti + achievement chips first, then the country celebration. This ordering feels correct: celebrate the set, then spotlight the headline country.
- Multiple new countries in one scan: only the first country gets the overlay (alphabetically first by ISO code for determinism). All countries get the amber pulse on the map.

---

## ADR-069 — `RegionChipsMarkerLayer` uses `MarkerLayer` with zoom gating via `MapCamera` (M23)

**Status:** Accepted

**Context:**
M23 adds floating progress chips at region centroids on the world map. Options for implementation:
1. Custom layer (`FlutterMapLayerOptions` subclass) — requires significant boilerplate and internal flutter_map API knowledge.
2. `MarkerLayer` with `ConsumerStatefulWidget` listening to map camera changes — standard API, well-tested, and idiomatic in flutter_map 6.x+.
3. Overlay widget positioned via `Stack` + coordinate-to-screen projection — brittle when map pans or zooms.

Zoom gating is needed because at low zoom levels (< 4) the chip markers overlap and clutter the map.

**Decision:** Use `MarkerLayer` (standard flutter_map layer). The widget listens to `MapController` camera change events and checks `camera.zoom`. When zoom < 4.0, return an empty `MarkerLayer(markers: [])`. Otherwise render one `Marker` per region at its centroid.

Each marker widget is a `GestureDetector` wrapping a chip painted with `CustomPainter` for the arc progress ring. The chip is 80×40 logical pixels; the arc is 24px diameter.

**Consequences:**
- Zero new packages required — `flutter_map` already provides `MarkerLayer` and `MapCamera`.
- Chip tap calls `showRegionDetailSheet()` — opens `RegionDetailSheet` as a bottom sheet.
- `MarkerLayer` markers do not scale with map zoom — chips remain the same logical pixel size regardless of zoom level, which is the desired behaviour.

---

## ADR-070 — `TargetCountryLayer` uses native `PolygonLayer` with solid amber border and breathing opacity (M23)

**Status:** Accepted

**Context:**
M23 requires a visual treatment for "target" countries (countries in regions that are exactly 1-away from completion and have at least one visit). Dashed borders were considered for distinction from regular visited countries.

Options:
1. Dashed border via `CustomPainter` — requires screen-space coordinate projection, repainting wired to map transforms, and manual geometry calculations. High implementation risk.
2. Solid amber border + breathing fill opacity — uses native `flutter_map` `PolygonLayer` with an `AnimationController`. The amber colour is visually distinct from regular visited countries without any `CustomPainter` complexity.
3. Hatched fill pattern — requires `CustomPainter` with a tiling shader; similar complexity to option 1.

**Decision:** Option 2 — solid amber border (`borderColor: Color(0xFFFFB300)`, `borderStrokeWidth: 2.5`) with breathing fill opacity (0.10 → 0.25 → 0.10, 2400ms `AnimationController`, repeat-reverse). Uses the same `AnimationController` + `AnimatedBuilder` pattern as `CountryPolygonLayer` (ADR-066). No `CustomPainter` involved.

The `TargetCountryLayer` is a `ConsumerStatefulWidget` that:
1. Watches `regionProgressProvider` to derive which regions are 1-away.
2. Derives target ISO codes from `kCountryContinent` filtered to those regions.
3. Builds a `PolygonLayer` from those codes' polygons.
4. Animates fill opacity via `AnimatedBuilder`.

In reduced-motion mode (`MediaQuery.disableAnimationsOf`): static opacity 0.175 (midpoint of the range).

**Consequences:**
- Visual treatment is solid amber border + breathing fill — clearly visible but not distracting.
- No `CustomPainter` means no screen-space projection and no repaint coupling to map transforms.
- The `TargetCountryLayer` adds a second `PolygonLayer` to the FlutterMap children list (after `CountryPolygonLayer`); ordering matters — target layer renders on top of visited-country fills.

---

## ADR-071 — `rovyMessageProvider` is a `StateProvider<RovyMessage?>` (M23)

**Status:** Accepted

**Context:**
`RovyBubble` needs a simple single-message store. Options:
1. `StateNotifier<List<RovyMessage>>` — queue of messages; complex dismissal logic.
2. `StateProvider<RovyMessage?>` — holds at most one message; null = no bubble shown.
3. `ChangeNotifier` — does not compose well with Riverpod provider graph.

The design requirement states "only one bubble visible at a time" and messages auto-dismiss after 4 seconds. A queue is not needed — if a new message arrives while one is displayed, it replaces the current one.

**Decision:** `StateProvider<RovyMessage?>((_) => null)`. Setting state to a new `RovyMessage` replaces any current message. Setting to null dismisses the bubble. `RovyBubble` watches the provider and starts/cancels a `Timer` on state changes.

**Consequences:**
- If two triggers fire close together (e.g. new country + region 1-away), the second message replaces the first rather than queuing. This is acceptable — the most recent message is most contextually relevant.
- The provider lives co-located in `rovy_bubble.dart` to keep `providers.dart` from becoming a catch-all.
- `RovyBubble` must cancel its `Timer` in `dispose()` to avoid calling `setState` after unmount.

---

## ADR-072 — `RegionDetailSheet` is a top-level function calling `showModalBottomSheet` (M23)

**Status:** Accepted

**Context:**
`RegionDetailSheet` shows regional progress detail when a chip is tapped. Options:
1. Named route — requires passing `RegionProgressData` as route arguments; adds navigation overhead for what is a contextual overlay.
2. `StatefulWidget` + manual `show` static method — similar to `AchievementUnlockSheet` pattern.
3. Top-level function `showRegionDetailSheet(context, data, visits)` — simplest; sheet content is pure from its inputs.

**Decision:** Top-level function `showRegionDetailSheet(BuildContext context, RegionProgressData data, List<EffectiveVisitedCountry> visits)` that calls `showModalBottomSheet`. The sheet content is a `StatelessWidget` that derives visited/unvisited country lists from `kCountryContinent` and `kCountryNames` at build time. No providers needed inside the sheet.

**Consequences:**
- `RegionDetailSheet` has no dependency on Riverpod or any provider — purely driven by its parameters.
- `showRegionDetailSheet` can be called from `RegionChipsMarkerLayer` chip taps; the caller passes the `RegionProgressData` (already known from `regionProgressProvider`) and the current `effectiveVisitsProvider` list.
- Tests can call `showRegionDetailSheet` directly with canned data — no provider setup needed for the sheet itself.


---

## ADR-073 — Two-stage checkout: `createMerchCart` called at preview time, `checkoutUrl` cached in state (M24)

**Status:** Accepted

**Context:**
M20 calls `createMerchCart` immediately when the user taps "Buy Now", then opens the returned `checkoutUrl` in-app. The user never sees the generated flag grid image before being sent to Shopify checkout. The UX spec requires a preview step so the user can see what they are buying before committing.

**Options considered:**
1. Add a separate `generatePreview` Firebase Function — returns only `previewUrl` without creating the Shopify cart. Two function calls total (preview + checkout).
2. Call `createMerchCart` at "Preview my design" time — cart is created, `previewUrl` and `checkoutUrl` returned in one call. Cache both in widget state. "Complete checkout" button opens cached `checkoutUrl` with no second call.
3. On-device emoji flag grid (existing `FlagGridPreview`) — user sees emoji flags but not the actual generated image.

**Decision:** Option 2. Call `createMerchCart` at "Preview my design" time. Cache `previewUrl` and `checkoutUrl` in `_MerchVariantScreenState`. Display `previewUrl` via `Image.network`. "Complete checkout →" opens the cached `checkoutUrl` — no second function call. If any variant option changes after preview, both cached values are cleared and the screen reverts to "Preview my design" state.

**Consequences:**
- A Shopify cart is created before the user opens checkout. Users who preview but do not proceed create abandoned carts. Shopify's cart abandonment email flow may fire; this can be disabled in Shopify settings if needed.
- One function call per "Preview" tap. Variant changes after preview trigger a new cart on re-tap; old carts are abandoned (consistent with web e-commerce norms).
- `previewUrl` is a Firebase Storage signed URL (7-day expiry); displayed immediately, not persisted.

---

## ADR-074 — Post-purchase screen triggered by `AppLifecycleState.resumed` after checkout launch (M24)

**Status:** Accepted

**Context:**
`url_launcher.launchUrl` with `LaunchMode.inAppBrowserView` presents `SFSafariViewController` on iOS and returns immediately. There is no callback for when the user closes the browser.

**Options considered:**
1. Shopify redirect URL / Universal Links — configure Shopify's "Return to store" URL to deep-link back. Requires Universal Links / custom URL scheme setup and Shopify store configuration. Complex.
2. `AppLifecycleState.resumed` — `MerchVariantScreen` mixes in `WidgetsBindingObserver`. After `launchUrl` succeeds, set `_checkoutLaunched = true`. On `didChangeAppLifecycleState(resumed)`, if `_checkoutLaunched`, push `MerchPostPurchaseScreen` and clear the flag.

**Decision:** Option 2. `MerchVariantScreen` registers as a `WidgetsBindingObserver`. After successful `launchUrl`, sets `_checkoutLaunched = true`. On app resume with flag set, pushes `MerchPostPurchaseScreen(product, countryCount)` and clears the flag.

`MerchPostPurchaseScreen` is optimistic — it does not verify whether a purchase completed. Shopify sends the real confirmation email; the app screen is a celebration prompt. Users who abandoned simply see an aspirational screen they can dismiss.

**Consequences:**
- Any app resume while `_checkoutLaunched` is true triggers the post-purchase screen (edge case: user switches away mid-checkout for an unrelated reason). Low-harm — screen is easy to dismiss.
- `MerchPostPurchaseScreen` is push-navigated; "Back to my map" uses `Navigator.popUntil('/')`.
- `MerchVariantScreen` must be a `StatefulWidget` (already is) mixing in `WidgetsBindingObserver`.

---

## ADR-075 — `MerchOrdersScreen` reads Firestore directly via `FutureProvider`, no repository layer (M24)

**Status:** Accepted

**Context:**
M24 adds order history. `MerchConfig` documents live in Firestore under `users/{uid}/merch_configs`. Options: (1) new `MerchRepository` class with `loadAll()`, consistent with existing repository pattern; (2) `FutureProvider` reading Firestore directly, no new class.

**Decision:** Option 2. `merchOrdersProvider` is a `FutureProvider<List<MerchOrderSummary>>` co-located in `merch_orders_screen.dart`. `MerchOrderSummary` is a simple local data class (not in `shared_models`). Commerce is app-layer only; no package boundary violation.

**Reasoning:** Commerce is app-layer only — no cross-package sharing of merch types needed. A repository for a single `loadAll()` query adds boilerplate without benefit. If a second merch screen needs order data in the future, promote to a repository at that point.

**Consequences:**
- Tests use `fake_cloud_firestore` to stub Firestore.
- `MerchOrderSummary` stays in `features/merch/` — no `shared_models` coordination needed.

---

## ADR-076 — `yearFilterProvider` is a global `StateProvider<int?>` in `providers.dart` (M26)

**Status:** Accepted

**Context:**
The timeline scrubber requires a shared year filter that affects three separate providers: `filteredEffectiveVisitsProvider`, `countryVisualStatesProvider`, and `countryTripCountsProvider`. Options: (1) local `StatefulWidget` state in `MapScreen` passed down via constructor arguments; (2) global `StateProvider<int?>` in `providers.dart`.

Option 1 breaks `CountryPolygonLayer` (a self-contained `ConsumerWidget` with no constructor parameters) and would require threading the filter through every layer widget. Option 2 is the idiomatic Riverpod approach — any provider that depends on the filter simply watches `yearFilterProvider`.

**Decision:** `yearFilterProvider = StateProvider<int?>(_ => null)` is defined in `lib/core/providers.dart`. Null means "no filter, show all time". Any integer value means "show countries confirmed visited on or before that year".

**Consequences:**
- The filter persists across tab switches while the app is running (intentional — scrubbing mid-session stays active when user returns to map).
- The filter resets to null on cold start (SharedPreferences persistence intentionally not added — the scrubber is a per-session exploratory tool).
- `clearAll()` (delete travel history) should also reset `yearFilterProvider` to null to avoid a dangling filter state.

---

## ADR-077 — `ScanRevealMiniMap` uses `Timer.periodic` + `Set<String>` to sequence polygon pop-in (M26)

**Status:** Accepted

**Context:**
`ScanRevealMiniMap` must animate newly-discovered country polygons appearing one-by-one. Options: (1) `AnimationController` with `Interval` curves per polygon (opacity fade per country); (2) `Timer.periodic` growing a `Set<String> _revealed`, triggering a `setState` that adds one polygon per tick.

Option 1 requires per-polygon opacity which `flutter_map`'s `PolygonLayer` does not support — each polygon in a `PolygonLayer` has a single static colour. Achieving per-polygon opacity would require one `PolygonLayer` per country or a `CustomPainter`, both expensive for a mini-map with 200+ polygons.

Option 2 side-steps per-polygon opacity entirely. The transition is instant per country ("pop-in"), not a fade. The sequence effect is clearly legible and the simplicity avoids custom rendering. The widget rebuilds once per tick (400ms interval) with a slightly larger `_revealed` set — each rebuild is cheap (only the revealed polygons layer changes).

**Decision:** `ScanRevealMiniMap` uses `Timer.periodic(Duration(milliseconds: 400), callback)` to pop one ISO code at a time from a queue into `_revealedCodes: Set<String>`. Two `PolygonLayer` instances: (1) all countries grey (static), (2) revealed countries amber (rebuilt each tick, culled by `polygonCulling: true`). Timer is cancelled in `dispose`. With `MediaQuery.disableAnimations`, all codes are added immediately (no timer started).

**Consequences:**
- No `AnimationController` or `Ticker` needed — `Timer` is sufficient for a 400ms UI update.
- The "pop-in" effect (instant per-country appearance) is visually distinct from smooth opacity fades but is acceptable for a celebratory reveal.
- The widget must be a `ConsumerStatefulWidget` to access `polygonsProvider` and `ref`.
- Test environments should override `disableAnimations` to avoid waiting for timers in widget tests.

---

## ADR-078 — `/sign-in` redirect-after-login uses `?next` query param; sanitised to relative paths only (M27)

**Status:** Accepted

**Context:**
M27 requires that navigating to `/sign-in?next=/shop` redirects to `/shop` after a successful sign-in, rather than always going to `/map`. This pattern (redirect-after-login) is standard but introduces an open-redirect risk: a malicious link such as `/sign-in?next=https://evil.com` could redirect users to an attacker-controlled site after they authenticate.

**Decision:**
The `next` parameter is read from `useSearchParams()` in the sign-in page. Before use it is validated with a single guard: the value must (a) start with `/` and (b) not start with `//` or contain a protocol string (`://`). Values failing validation are silently discarded and the default redirect (`/map`) is used.

```ts
function sanitiseNext(next: string | null): string {
  if (!next) return "/map";
  if (!next.startsWith("/") || next.startsWith("//") || next.includes("://")) return "/map";
  return next;
}
```

This is a denylist-of-patterns approach rather than an allowlist. It is sufficient because all legitimate `next` values in this app are internal Next.js routes (short strings starting with `/`).

**Consequences:**
- Open redirect is prevented: `https://evil.com` fails check (b); `//evil.com` fails check (b); `/evil` passes and is safe (relative path, Next.js router will navigate within the same origin).
- The sign-in page must use `useSearchParams()` which requires a `<Suspense>` boundary in Next.js App Router. Wrap the page body in `<Suspense fallback={<p>Loading...</p>}` or extract the params-reading logic into a child component.
- No allowlist maintenance needed — any new internal route works automatically.

---

## ADR-079 — Web `/shop/design` calls `createMerchCart` via Firebase Functions JS SDK; `checkoutUrl` opened via `window.location.href` (M28)

**Status:** Accepted

**Context:**
M28 introduces a web checkout flow: the user selects countries on `/shop/design`, the page calls the existing `createMerchCart` Firebase callable function, and the user is redirected to Shopify's hosted checkout. Three decisions were needed: (1) how to initialise Firebase Functions on the web side, (2) how to perform the redirect, and (3) how to display country names without a server round-trip.

**Decision:**

**Functions init:** `getFunctions(app)` is added to `apps/web_nextjs/src/lib/firebase/init.ts` and exported alongside `auth` and `db`. This mirrors the existing pattern for `auth` and `db`. The `firebase/functions` module is already bundled as part of the `firebase` package in `package.json`.

**Checkout redirect:** After `createMerchCart` returns `{ checkoutUrl }`, the web page does `window.location.href = checkoutUrl`. This is a full-page navigation away from the Next.js app into Shopify's domain — `router.push` cannot be used as it only works for same-origin Next.js routes.

**Country names:** A `const` map `COUNTRY_NAMES: Record<string, string>` is added in `apps/web_nextjs/src/lib/countryNames.ts`. It mirrors the Dart `kCountryNames` in `apps/mobile_flutter/lib/core/country_names.dart`. If a code is absent from the map, the ISO code itself is shown. This avoids a network dependency and matches ADR-019.

**Consequences:**
- `getFunctions` is exported from `init.ts`; every file that needs callable functions imports it from there.
- The `/shop/design` page calls `httpsCallable(functions, "createMerchCart")` with payload `{ countryCodes: string[], product: "poster" }`. The response type is `{ checkoutUrl: string }`.
- After Shopify checkout, Shopify redirects the browser to the shop's configured "thank you" URL. We set that to `/shop?ordered=true` in the Shopify store settings. The `/shop` page detects `?ordered=true` and shows a confirmation banner. This requires `useSearchParams` — same Suspense wrapping pattern as ADR-078.
- Function errors (network failure, Shopify misconfiguration) are caught and shown as an inline retry message. The user is not redirected on error.
- No order tracking on the web side in this milestone — that is a mobile-only feature (M24).

---

## ADR-080 — Map dark-ocean colour scheme (M32)

**Status:** Accepted

**Context:**
The map uses white/grey tones for ocean and muted amber for countries. User feedback indicates the map looks "boring". A premium travel-app aesthetic requires high contrast between visited (gold) countries, unvisited land, and the ocean.

**Decision:**
Set `FlutterMap`'s background `Scaffold` colour to `Color(0xFF0D2137)` (dark navy). Unvisited countries become `Color(0xFF1E3A5F)` with a `Color(0xFF2A4F7A)` border at 0.4 stroke. Visited depth colours shift from amber to richer gold: tier 1 (1 trip) → `Color(0xFFD4A017)`, tier 2 (2–3) → `Color(0xFFC8860A)`, tier 3 (4–5) → `Color(0xFFB86A00)`, tier 4 (6+) → `Color(0xFF8B4500)`. Newly-discovered pulse uses `Color(0xFFFFD700)` (bright gold). Target (1-away) border shifts to `Color(0xFFFF8C00)`. No new packages required.

`XpLevelBar` and `StatsStrip` switch from `Colors.black54` to a `Color(0xFF0D2137).withValues(alpha: 0.85)` background to blend with the new ocean colour. The level badge becomes `Color(0xFFFFD700)` and the progress bar track uses `Color(0xFF1E3A5F)`.

**Consequences:**
- Colour constants in `country_polygon_layer.dart` are updated; all tests that snapshot exact fill colours must be updated to match.
- No new dependencies or provider changes needed.
- The map background matches the overlay bars, producing a unified dark theme without requiring a full dark-mode MaterialTheme switch.

---

## ADR-081 — `tripListProvider` FutureProvider replaces `late final` future in JournalScreen (M32)

**Status:** Accepted

**Context:**
`JournalScreen` stores trip data in a `late final Future<List<TripRecord>> _tripsFuture` assigned in `initState`. This future is never re-executed: after `clearAll()` or a rescan, the journal continues showing stale (or empty) data from the initial load. A sign-out/sign-in forces a widget rebuild, which is why that workaround works.

**Decision:**
Add `tripListProvider` as a `FutureProvider<List<TripRecord>>` in `providers.dart`, backed by `TripRepository.loadAll()`. `JournalScreen` watches `tripListProvider` via `ref.watch` instead of a `late final` future. The `FutureBuilder` is removed; the journal builds directly from the provider's `AsyncValue`.

After `clearAll()` in `map_screen.dart`, add `ref.invalidate(tripListProvider)`. After scan save in `scan_screen.dart`, add `ref.invalidate(tripListProvider)`. Both call sites must also invalidate `regionCountProvider` (which was already missing from the scan-save path).

**Consequences:**
- `JournalScreen` no longer needs `ConsumerStatefulWidget`; it becomes a `ConsumerWidget`.
- The journal updates reactively whenever `tripListProvider` is invalidated.
- `countryTripCountsProvider` and `earliestVisitYearProvider` both call `TripRepository.loadAll()` internally — they are also FutureProviders and are already re-evaluated after `ref.invalidate(effectiveVisitsProvider)` triggers their dependency chain. No change needed for those.

---

## ADR-082 — Trip photo date filtering via optional `tripFilter` on `CountryDetailSheet` (M32)

**Status:** Accepted

**Context:**
`CountryDetailSheet` loads all photo asset IDs for a country via `VisitRepository.loadAssetIds(isoCode)`, with no date filter. When the sheet is opened from a trip row in the Journal, users expect to see only the photos from that trip's date range — not all photos ever taken in that country.

**Decision:**
Add `loadAssetIdsByDateRange(String countryCode, DateTime start, DateTime end)` to `VisitRepository`. The query adds a `capturedAt >= start AND capturedAt <= end` filter using Drift's `isBetweenValues` on the existing `capturedAt` column. No schema migration needed.

Add an optional `TripRecord? tripFilter` parameter to `CountryDetailSheet`. When non-null, `_assetIdsFuture` calls `loadAssetIdsByDateRange` instead of `loadAssetIds`, using start-of-day for `startedOn` and end-of-day (23:59:59.999) for `endedOn`. `JournalScreen._TripTile._openSheet()` passes the trip record to `CountryDetailSheet`.

**Consequences:**
- Photos opened from a country polygon (map tap) still show all country photos — `tripFilter` is null in that path.
- The photo count badge on the trip tile ("N photos") will now match the gallery count.
- `loadAssetIdsByDateRange` requires a unit test for boundary edge cases.

---

## ADR-083 — Real-time scan discovery feed: `_newlyFoundCodes` list in `ScanScreen` (M32)

**Status:** Accepted

**Context:**
The scan screen shows only a processed-photo count during scanning. New country discoveries are invisible until `ScanSummaryScreen` appears post-scan. This makes the scanning process feel unrewarding.

**Decision:**
In `ScanScreen._scan()`, after assigning `preScanCodes` (which already exists), initialise an empty `_newlyFoundCodes` list in state. In the batch loop, after merging into `accum`, compare `accum.keys` against `preScanCodes` ∪ `_newlyFoundCodes`. Any new code is appended to `_newlyFoundCodes` and triggers `setState`. The scan UI renders a "Countries found" `Column` below the photo counter; each entry animates in using `AnimatedList` or a growing `Column` with `FadeTransition` (respects `reduceMotion`). The section only appears when `_newlyFoundCodes.isNotEmpty`.

**Consequences:**
- `_ScanProgress` is extended with an optional `newCodes` field, or `_newlyFoundCodes` is held as a separate state field (preferred — avoids changing `_ScanProgress`).
- One additional `setState` per new country — negligible cost during a scan of thousands of photos.
- Previously-visited countries that appear again in the scan batch are not added (diff against `preScanCodes`).

---

## ADR-085 — M29 commerce entry point decisions

**Status:** Accepted

**Context:**
M29 adds three commerce/nudge touchpoints to the mobile app:
1. `MerchCountrySelectionScreen` is opened from scan summary pre-filtered to newly discovered codes only.
2. `MapScreen` needs a "Get a poster" overflow menu item.
3. `MapScreen` needs a per-session dismissible nudge banner when `lastScanAt > 30 days ago`.

Three non-obvious decisions arise:

**Decision A — `MerchCountrySelectionScreen.preSelectedCodes` initialisation**
`MerchCountrySelectionScreen` derives its country list from `effectiveVisitsProvider`, which is async. The pre-selection state (`_deselected`) cannot be seeded in the constructor because the full country list isn't available yet. The chosen pattern: add a `preSelectedCodes: List<String>?` constructor param and an `_initialized` bool flag. On the first `_buildScreen()` call after data loads, if `preSelectedCodes` is non-null, compute `_deselected = { all effective codes } - { preSelectedCodes }`, then set `_initialized = true` so subsequent rebuilds don't reset the selection. Filter `preSelectedCodes` against the loaded visits to guard against stale codes.

**Decision B — Nudge banner dismissal via `StateProvider<bool>`**
`MapScreen` is a `ConsumerWidget`. Per-session dismissed state cannot be stored in a local variable in a `ConsumerWidget.build()` method. Converting `MapScreen` to `ConsumerStatefulWidget` solely to hold a bool is unnecessary complexity. The chosen pattern: `scanNudgeDismissedProvider = StateProvider<bool>((ref) => false)` in `providers.dart`. It starts false on app launch and is set to true when the user dismisses. Since `StateProvider` is in-memory and not persisted, it resets to false on app restart — which is exactly the per-session behaviour required.

**Decision C — Nudge banner placement in MapScreen Stack**
The MapScreen Stack already contains `XpLevelBar` (top), `StatsStrip` (bottom), `TimelineScrubberBar` (above StatsStrip, shown when filter active), and `RovyBubble` (bottom-right). The nudge banner is placed above `StatsStrip` using a `Positioned` widget anchored from the bottom with enough offset to clear the StatsStrip height (approx 56 dp). The banner does not stack with `TimelineScrubberBar` — both can be shown simultaneously since the scrubber appears above the nudge banner.

**Consequences:**
- No schema changes. No new tables. No Firestore writes.
- `MerchCountrySelectionScreen` remains a single widget; callers control initial selection via the `preSelectedCodes` param — no need for two separate screen variants.
- Nudge banner dismissal does not survive app restart, which is intentional — it prevents the banner from being permanently silenced by an accidental tap.
- `lastScanAtProvider` is a new `FutureProvider<DateTime?>` that wraps `visitRepositoryProvider.loadLastScanAt()`; it is invalidated implicitly on app restart (provider graph reset).

---

## ADR-084 — Sequential `DiscoveryOverlay` for multiple new countries; cap at 5 (M32)

**Status:** Accepted

**Context:**
`ScanSummaryScreen._handleDone()` pushes `DiscoveryOverlay` once, only for `widget.newCodes.first`. Users who discover multiple countries on a scan see only one celebration screen, which feels incomplete.

**Decision:**
Add `currentIndex` (int, 0-based) and `totalCount` (int) to `DiscoveryOverlay`. When `totalCount > 1`, a "Country N of M" subtitle appears below the country name. The primary CTA reads "Next →" for all indices except the last, and "Done" for the last. A "Skip all" `TextButton` appears on every overlay screen.

`ScanSummaryScreen._handleDone()` iterates over `widget.newCodes` up to a cap of 5. It pushes each overlay sequentially, `await`-ing the pop before pushing the next. The "Skip all" CTA pops to the route just below the first overlay (using a counter to pop N times). After all overlays (or after skip), execution continues to register `recentDiscoveriesProvider` and call `onDone()` — these must happen regardless of the skip path.

**Consequences:**
- First-time users discovering 50 countries are shown 5 overlays max, then proceed to the summary — avoids an overwhelming sequence.
- "Skip all" on overlay 1 of 5 pops 1 route; "Skip all" on overlay 3 of 5 pops 3 routes. The overlay must receive a `onSkipAll` callback (or a `skipAll` return value) to signal the caller to pop all remaining overlays.
- `DiscoveryOverlay.routeName` is kept as `'/discovery'`; `popUntil(ModalRoute.withName('/'))` is replaced with calling the provided `onDone` callback so the caller controls navigation.

---

## ADR-086 — Shopify credential model: OAuth Client Credentials for admin token; permanent Storefront token

**Status:** Accepted

**Context:**
The `createMerchCart` Cloud Function calls the Shopify Storefront API (`cartCreate` mutation) server-side. Initial setup stored a `shpat_`-prefixed token directly in `.env` as `SHOPIFY_STOREFRONT_TOKEN`. This token was invalid: it had been revoked by repeated app reinstalls, and was being used against the wrong API (it is an Admin API token, not a Storefront API token). The Shopify admin UI no longer surfaces static Admin API tokens for OAuth-based custom apps — credentials are now issued via the Client Credentials OAuth grant.

Two distinct Shopify credentials are required:
1. **Admin API access token** — short-lived (24h), obtained via `POST /admin/oauth/access_token` using Client ID + Client Secret. Used only to provision Storefront tokens via the Admin REST API.
2. **Storefront API access token** — permanent (until explicitly deleted), a 32-char hex string. Used in `X-Shopify-Storefront-Access-Token` on every Storefront API call.

**Decision:**
- Store `SHOPIFY_CLIENT_ID` and `SHOPIFY_CLIENT_SECRET` (OAuth credentials) in `apps/functions/.env`.
- To provision or rotate a Storefront token:
  1. Exchange credentials for a short-lived admin token: `POST https://{shop}.myshopify.com/admin/oauth/access_token` with `client_id`, `client_secret`, `grant_type: client_credentials`.
  2. Use that admin token to create a permanent Storefront token: `POST /admin/api/{version}/storefront_access_tokens.json`.
  3. Store the resulting hex token as `SHOPIFY_STOREFRONT_TOKEN` in `.env` and redeploy.
- The `createMerchCart` function reads only `SHOPIFY_STOREFRONT_TOKEN` at runtime — it never holds the Client Secret or performs OAuth itself.
- The required Storefront API scopes are: `unauthenticated_read_product_listings`, `unauthenticated_write_checkouts`, `unauthenticated_read_checkouts`.

**Consequences:**
- The Storefront token is permanent and survives app reinstalls. It must be manually rotated if compromised.
- The admin token is never stored — it is obtained on demand during provisioning only.
- If the Storefront token is lost or the Shopify app is reinstalled, re-run the two-step provisioning process above to generate a new one.
- Firebase Storage uploads from the Admin SDK must include `metadata: { firebaseStorageDownloadTokens: crypto.randomUUID() }` in custom metadata, or files will not appear in the Firebase console (GCS stores the object; the console requires the token to list it).

---

## ADR-087 — Post-purchase payment confirmation via Firestore poll (M33)

**Status:** Accepted

**Context:**
`MerchVariantScreen` uses `WidgetsBindingObserver.didChangeAppLifecycleState` to detect when the app resumes after the in-app browser (SFSafariViewController via `url_launcher`) is dismissed. It then unconditionally pushes `MerchPostPurchaseScreen` — regardless of whether the user actually completed payment. A user who closes the browser mid-checkout (abandoned cart, wrong card, etc.) will see the celebration screen and read "Your order is on its way!" even though no order was placed. This is a confirmed UX/correctness gap (Task 118, M33 risks table).

Shopify's `return_url` deep-link mechanism would provide a payment-completion signal but requires a registered custom URL scheme and app handling for universal links — not yet implemented.

**Decision:**
Replace the optimistic post-purchase flow with a Firestore poll:

1. After `didChangeAppLifecycleState(resumed)` fires (browser dismissed), push a "Checking order..." loading screen instead of the celebration screen immediately.
2. From that screen, poll `users/{uid}/merch_configs/{configId}` every 3 seconds, up to 10 attempts (30 seconds total), using `docRef.get()` in a loop with `Future.delayed`.
3. If `status == 'ordered'` is observed: transition to celebration (`MerchPostPurchaseScreen`).
4. If 10 attempts elapse without `status == 'ordered'`: show a neutral fallback ("We're processing your order...") with a "Back to map" button. This handles cancelled payments, network lag, or webhook delays.

The poll is implemented as a `_pollForOrderConfirmation()` method on `_MerchVariantScreenState` (the widget that owns the checkout launch and the `WidgetsBindingObserver`). The `merchConfigId` returned by `createMerchCart` is stored in `_MerchVariantScreenState` alongside `_checkoutUrl` and `_previewUrl`.

The authenticated user's UID is obtained from `FirebaseAuth.instance.currentUser?.uid`. If null (unauthenticated — should not happen since `createMerchCart` requires auth), the fallback is shown immediately.

**Why poll Firestore rather than a Cloud Function endpoint?**
The `shopifyOrderCreated` webhook fires asynchronously after Shopify processes the payment (typically within 5–30 seconds). Firestore is already the source of truth for `MerchConfig.status`. Polling Firestore directly is simpler than introducing a new endpoint, avoids cold-start latency on Cloud Functions, and requires no additional backend code.

**Consequences:**
- The celebration screen is only shown when payment is confirmed (via webhook updating `status: 'ordered'`). False positives are eliminated.
- If the Shopify webhook is delayed beyond 30 seconds (rare), the user sees a neutral fallback. They will still receive the Shopify confirmation email and the Printful order will proceed normally once the webhook fires.
- The 3s / 30s parameters are constants in `_MerchVariantScreenState`; they can be tuned without an ADR update.
- `MerchPostPurchaseScreen` requires `product`, `countryCount`, AND `merchConfigId` (added in M33) so the celebration screen can display the correct product without re-fetching.
- `FirebaseAuth` import is already in the project (`firebase_auth` package); `cloud_firestore` is already imported in `providers.dart`. No new packages required.

---

## ADR-088 — Payment provider strategy: manual method for sandbox testing; Shopify Payments for production

**Status:** Accepted (sandbox); Production path defined

**Context:**
The Bogus Gateway (Shopify's built-in test payment provider) is only available on Shopify Partner development stores. It is not available on paid merchant stores (`roavvy.myshopify.com` on the Basic plan). During M33 sandbox validation, a **Manual payment method** named "Test Payment" was added to the store as the mechanism for placing test orders without a real card.

A manual payment method allows an order to be placed and the `orders/create` webhook to fire — which is sufficient to validate the full backend flow (webhook receipt → Firestore update → Printful draft order creation). It is not suitable for production because:
- No card details are collected — any visitor can "pay" without submitting payment credentials.
- No funds are captured.
- Fulfilment would ship without payment received.

**Decision:**

**Sandbox (current):** Manual payment method "Test Payment" remains active on the store for developer testing only. The store is not publicly marketed during this phase.

**Production (required before public launch):** Replace the manual method with a real payment provider:

1. **Activate Shopify Payments** — the preferred provider (lowest fees, native Shopify checkout experience, Shop Pay support). Requires:
   - A business bank account in a [supported country](https://help.shopify.com/en/manual/payments/shopify-payments/supported-countries)
   - Business or personal identity verification (Shopify KYC)
   - A valid business address and tax information
   - Remove the "Test Payment" manual method after activation

2. **Enable test mode on Shopify Payments** — for pre-launch validation after activating Shopify Payments. Allows use of Stripe-standard test cards (e.g. `4242 4242 4242 4242`) without real charges. This is the proper sandbox path once Shopify Payments is active.

3. **Disable test mode** before the store goes live.

**What else must be completed before public launch:**

| Item | Detail |
|---|---|
| Remove manual "Test Payment" method | Prevents orders without captured payment |
| Activate Shopify Payments (or Stripe) | Real card capture required |
| Set up Printful production shipping | Confirm rates, origin address, and fulfilment SLA |
| Configure Shopify shipping zones and rates | Currently unset — checkout may show $0 or block on shipping |
| Review Shopify store policies | Privacy policy, refund policy, terms of service — required by Shopify |
| Configure order confirmation emails | Shopify sends these automatically; customise branding |
| Remove test product variants (if any) | Ensure only live SKUs are purchasable |
| Validate Printful auto-confirm | Currently orders are created as drafts (`"confirm": false` default). Before launch, decide whether to enable auto-confirm on production orders or add a manual review step. |
| Register Apple Pay domain | Optional but recommended — increases checkout conversion on iOS |

**Consequences:**
- Until Shopify Payments is activated and verified, the commerce flow cannot accept real payments.
- The manual method must be explicitly removed — it is not automatically deactivated when Shopify Payments is enabled.
- Shopify Payments KYC can take 1–3 business days; plan accordingly before public launch.
- The mobile and web checkout flows (`MerchVariantScreen`, `/shop/design`) require no code changes for this transition — they use the `checkoutUrl` returned by `createMerchCart`, which works identically with any active Shopify payment provider.


---

## ADR-089 — Printful Mockup API: v2 async generation within `createMerchCart` (M34)

**Status:** Accepted

**Context:**

Users currently see only the flag grid print file (the design itself) before completing checkout. A photorealistic t-shirt mockup — the actual shirt with the design placed on it — significantly improves purchase confidence.

Printful provides a mockup generation API. Two integration points were considered:
1. Call it within `createMerchCart` (synchronous from the app's perspective — one function call returns everything)
2. Separate endpoint polled by the mobile app after `createMerchCart` returns

**Decision:**

Use **Printful v2 Mockup API** (`POST /v2/mockup-tasks`, `GET /v2/mockup-tasks/{task_key}`) called synchronously within `createMerchCart`, after the Shopify cart is created.

- **v2 not v1**: Consistent with the existing `POST /v2/orders` usage. v2 accepts `variant_ids` directly — no separate catalog product ID lookup required.
- **Within `createMerchCart`**: The function already has a 300s timeout and the app already shows a loading state. Adding ≤20s of mockup polling is acceptable. No separate function, no second callable, no mobile-side polling.
- **Non-blocking fallback**: If mockup generation times out (10 × 2s) or errors, `mockupUrl` is `null` in the response. The function does not throw. The flag grid preview is shown instead. Checkout proceeds normally.
- **Return in response**: `mockupUrl` is added to `CreateMerchCartResponse` so the mobile app receives it immediately — no Firestore poll needed for the image URL.
- **Also persist in Firestore**: `MerchConfig.mockupUrl` is written when available, for completeness and future web use.
- **No Dart model class**: The mobile app reads the callable response as a raw `Map<String, dynamic>` — no Dart `MerchConfig` class exists. Task 120 only changes TypeScript types.
- **T-shirt only**: Poster variants have `PRINTFUL_VARIANT_IDS` value `0` — used as the skip signal. When `printfulVariantId === 0`, skip mockup generation and return `mockupUrl: null`.
- **Colour matters; size does not**: The mockup appearance differs by shirt colour. Size has no visible effect on the rendered mockup. The `catalog_variant_id` already encodes colour × size, so passing it to the mockup API gives the correct shirt colour without extra logic.

**Printful Mockup API shape (v2):**

```
POST https://api.printful.com/v2/mockup-tasks
Authorization: Bearer {PRINTFUL_API_KEY}
{
  "variant_ids": [536],
  "files": [{ "placement": "front", "url": "https://storage.googleapis.com/..." }],
  "format": "jpg"
}

→ { "data": { "task_key": "abc123" } }

GET https://api.printful.com/v2/mockup-tasks/abc123
→ { "data": { "status": "completed", "mockups": [{ "placement": "front", "mockup_url": "https://..." }] } }
   OR  { "data": { "status": "waiting" } }
   OR  { "data": { "status": "error" } }
```

**`createMerchCart` step sequence (updated):**
1. Write MerchConfig (status=pending)
2. Generate preview + print PNGs (existing)
3. Upload preview (public) + print file (private); generate signed URL (existing)
4. Create Shopify cart (existing)
5. **NEW**: Call Printful Mockup API; poll up to 20s; store result in `MerchConfig.mockupUrl`
6. Update MerchConfig (shopifyCartId, status=cart_created)
7. Return `{ checkoutUrl, cartId, merchConfigId, previewUrl, mockupUrl }`

**Consequences:**
- `createMerchCart` may take up to 20s longer on the happy path (mockup generation).
- The existing loading state on `MerchVariantScreen` covers this — no UX change needed.
- `mockupUrl` is a Printful CDN URL (not Firebase Storage). No storage cost. It is not a signed URL and does not expire on a fixed schedule.
- If Printful changes the mockup URL CDN, cached URLs may break. Acceptable for PoC.
- Poster mockups are not supported until Printful poster sync variants are configured (tracked separately).

---

## ADR-091 — Country Region Map: hit-notifier tap detection + tap-point label anchor (M36)

**Status:** Accepted

**Context:**

M36 adds `CountryRegionMapScreen` — a full-screen map of all visited regions for a country (across all trips, not per-trip). It extends the M35 `TripMapScreen` pattern with two new requirements:
1. Region tap interaction — tapping a visited region shows a floating name label.
2. Entry from `RegionBreakdownSheet` — a map icon on each country tile navigates to the screen.

**Decisions:**

**Polygon hit detection — `LayerHitNotifier<String>` (flutter_map v7 API):**
flutter_map v7 does not expose `onTap` directly on `Polygon`. Instead, hit detection uses:
- `Polygon<String>` with `hitValue: regionCode` on each visited polygon.
- `PolygonLayer<String>(hitNotifier: _hitNotifier, ...)` for the visited layer only.
- A `GestureDetector` wrapping the `PolygonLayer<String>` (not the whole map).

In `GestureDetector.onTap`, `_hitNotifier.value` is read:
- Non-null → polygon was hit; set `_selectedCode` + `_selectedLatLng` from `hit.coordinate`.
- Null → background/unvisited tap; clear selection.

`MapOptions.onTap` is not used for dismissal (it fires for all taps, including polygon taps, causing conflicts). The `GestureDetector` approach is the canonical flutter_map v7 pattern.

**Label anchor — tap coordinate (not centroid):**
The label `Marker` is placed at `_hitNotifier.value!.coordinate` (the exact tap point) rather than a computed polygon centroid. Reasons:
- Tap point is immediately available with zero computation.
- For large polygons (e.g. US states, Russian oblasts), the centroid may fall outside the polygon boundary; the tap point is guaranteed to be within the visible polygon area.
- The tap-point anchor provides direct visual feedback at the touch site.

**AppBar region count — `_visitedCount` state field:**
The AppBar subtitle shows "N regions visited". Since the count is async (from `RegionRepository.loadByCountry`), it is stored in a `_visitedCount` int state field (default 0) updated via `.then()` on the same future used for the body `FutureBuilder`. This avoids a nested `FutureBuilder` in the `AppBar` and keeps subtitle update reactive via `setState`.

**Navigation from `RegionBreakdownSheet` — pop-then-push cascade:**
`Navigator.of(context)..pop()..push(...)` closes the bottom sheet and pushes `CountryRegionMapScreen` in a single expression. This prevents the sheet from lingering visually behind the new screen. The `trailing` of each `ExpansionTile` is set to an `IconButton(Icons.map_outlined)` — the default expand chevron is replaced; expand/collapse via header tap is preserved (tile body still expands).

**`_flagEmoji` and colour constants — local file, not extracted:**
Follows the pattern established in ADR-090 (each screen defines its own local helpers). Three screens now have local `_flagEmoji` functions; extraction to a shared utility is deferred until a fourth consumer appears.

**Consequences:**
- `GestureDetector` wrapping only the visited `PolygonLayer<String>` means unvisited polygon taps correctly produce a null hit → label is dismissed. No separate handling needed.
- `ExpansionTile.trailing` override removes the default animated chevron. The tile is still expandable via header tap, but there is no rotate animation. Acceptable: the region list is the secondary action; the map icon is the primary new feature.
- `LayerHitNotifier` is a `ValueNotifier` — it must be disposed in the screen's `dispose()` to avoid leaks.

---

## ADR-090 — Trip Region Map: synchronous polygon access + FutureBuilder for visited codes (M35)

**Status:** Accepted

**Context:**

M35 adds a `TripMapScreen` showing a country's region polygons with visited regions highlighted amber. Two data sources are needed:
1. All region polygons for the country (for rendering and bounds computation)
2. Which region codes were visited on the specific trip (for colour selection)

**Decisions:**

**Polygon access — synchronous, added to `RegionLookupEngine`:**
`RegionGeodataIndex` already stores all polygons in memory as `List<RegionPolygon>` and exposes them via `get polygons`. A `polygonsForCountry(String countryCode)` method is added to `RegionLookupEngine` — filters `_index.polygons` where `regionCode.startsWith('$countryCode-')`. The public `regionPolygonsForCountry` function in `region_lookup.dart` delegates to the engine. This call is synchronous (no I/O — the binary is already parsed at startup) and safe to call in `initState`.

**Visited region codes — async, `RegionRepository.loadRegionCodesForTrip`:**
Queries `photo_date_records` where `countryCode == trip.countryCode` AND `capturedAt BETWEEN trip.startedOn AND trip.endedOn` AND `regionCode IS NOT NULL`, returning distinct region codes. Pattern mirrors `VisitRepository.loadAssetIdsByDateRange` (ADR-083). This is an async Drift query, therefore:

**`TripMapScreen` uses a `StatefulWidget` + `FutureBuilder`** (not a Riverpod provider):
- `initState` calls `regionPolygonsForCountry` synchronously → stored in `_allPolygons`
- `FutureBuilder` over `_visitedFuture` (the Drift query) controls the loading/ready states
- No Riverpod provider needed — screen is transient, single-use, not shared

**Map initial camera — `CameraFit.bounds` in `MapOptions.initialCameraFit`:**
Bounding box computed from all region polygon vertices (`LatLngBounds.fromPoints`). Passed as `MapOptions.initialCameraFit` — no `MapController` required. Falls back to world view when the polygon list is empty (micro-states).

**Navigation — full-screen push (not modal bottom sheet):**
`TripMapScreen` is pushed via `Navigator.push(MaterialPageRoute)` from `JournalScreen`. The existing `CountryDetailSheet` modal is removed from the Journal trip card tap. Back navigation returns to Journal.

**`depthFillColor` — inline constant, not extracted:**
`TripMapScreen` uses `const Color(0xFFD4A017)` directly (the 1-trip amber tier). Extracting `depthFillColor` to a shared file is deferred — one new consumer does not justify the refactor.

**`_flagEmoji` — local file function:**
Matches existing pattern in `journal_screen.dart` and `scan_screen.dart`. Not extracted to a shared utility — three separate local functions is acceptable until a dedicated `utils.dart` is warranted.

**Consequences:**
- `RegionPolygon` becomes part of the public API surface of `packages/region_lookup` — a breaking change if the shape changes. Acceptable: the class is simple and stable.
- `TripMapScreen` renders up to ~80 polygons for large countries (US, RU). `flutter_map` handles this without optimisation.
- Countries with no region data (micro-states) show a blank dark navy map — acceptable UX, no crash.


---

## ADR-092 — Travel Card Generator: Firestore-only storage, timestamp ID, in-screen capture, simplified Heart template (M37)

**Status:** Accepted

**Context:**

M37 introduces the Travel Card Generator — a screen where users pick one of three card templates (Grid Flags, Heart Flags, Passport Stamps), preview a card built from their visited countries, and share it. The card is also persisted as a `TravelCard` entity so future milestones (M38: print flow) can reference it.

**Decisions:**

**`TravelCard` in `shared_models`, Firestore-only (no Drift table):**
Unlike visits, trips, and region visits — which are scanned from on-device data and must work fully offline — travel cards are user-initiated creative artefacts. They have no offline-first requirement: a card cannot be generated without the user actively opening the generator, and the generator already requires the visit data to be loaded. Firestore-only storage avoids a schema migration and keeps the local DB focused on scan-derived data.

**Card ID: `'card-${DateTime.now().microsecondsSinceEpoch}'`:**
A microsecond-precision timestamp prefix gives collision-free IDs within a single user session without adding the `uuid` package. The same pattern is used for XP event IDs. Acceptable: two cards created within the same microsecond is not a realistic scenario.

**Firestore path: `users/{uid}/travel_cards/{cardId}`:**
Consistent with `users/{uid}/inferred_visits`, `users/{uid}/trips` etc. (ADR-029). The existing wildcard security rule `match /users/{userId}/{document=**}` already covers this subcollection — no rule change needed.

**`TravelCardService.create()` fire-and-forget before sharing:**
The share flow must not be blocked by a Firestore write. `create()` is called with `unawaited`; any error is silently logged. The card is primarily useful for future print flows (M38); if persistence fails the user can still share the image. Anonymous users have a valid UID (Firebase anonymous auth) so they can also persist cards.

**In-screen `RepaintBoundary.toImage()` capture (not off-screen overlay):**
The existing `captureAndShare()` in `travel_card_share.dart` renders the card widget off-screen via `Overlay.insert` because the share action originates from a menu button where no card widget is on-screen. In `CardGeneratorScreen`, the preview is already rendered and visible — the `RepaintBoundary` wrapping the preview widget can be captured directly via its `GlobalKey`. No overlay required; simpler and avoids a render frame delay.

**`HeartFlagsCard`: gradient background + ❤️ watermark (not `ClipPath` heart mask):**
A `ClipPath` heart-shaped mask over a `Wrap` of flags requires either a custom clip path with precise Bézier curves, or pre-computing which grid cells fall inside a heart shape — complex for variable country counts and device sizes. The simplified version (warm amber gradient + large semi-transparent ❤️ as a background layer) delivers the identity-driven "Heart" feeling at low implementation cost, and is visually distinct from the Grid template. This can be upgraded to a true heart mask in a future polish pass.

**Consequences:**
- `TravelCard` is not available offline. If Firestore is unreachable, cards are not persisted. The share image still works.
- Future print flow (M38) depends on `cardId` being persisted in Firestore — fire-and-forget write should succeed in the vast majority of cases; the rare failure would require the user to re-generate.
- Timestamp IDs are not universally unique across users (different users could theoretically get the same timestamp). Subcollection path `users/{uid}/...` ensures no collision since each user's collection is independent.


---

## ADR-093 — Print from Card: optional `cardId` on `createMerchCart` + `MerchConfig` (M38)

**Status:** Accepted

**Context:**

M38 enables the "Print your card" CTA in `CardGeneratorScreen`. The user taps Print → a `TravelCard` is saved → they navigate directly to `MerchProductBrowserScreen` (skipping `MerchCountrySelectionScreen`) → they complete checkout via the existing `MerchVariantScreen` → `createMerchCart` flow.

The `MerchConfig` Firestore document created by `createMerchCart` currently has no reference back to the originating `TravelCard`. For future milestones (e.g. print-file generation from the card's template rather than the generic flag grid), the order must be traceable to the card.

**Decisions:**

**Optional `cardId` on `CreateMerchCartRequest` and `MerchConfig` (backwards-compatible):**
`cardId?: string` is added as an optional field to both the TypeScript request type and the `MerchConfig` Firestore document shape. When the print flow originates from a card, `CardGeneratorScreen` passes `cardId` through `MerchProductBrowserScreen` → `MerchVariantScreen` → `createMerchCart` callable payload. The Firebase Function stores it on `MerchConfig`. When the flow originates from `MerchCountrySelectionScreen` (existing path), `cardId` is omitted from the payload and stored as `null`.

**Skip `MerchCountrySelectionScreen` — navigate directly to `MerchProductBrowserScreen`:**
The card already captures the country selection. Showing `MerchCountrySelectionScreen` again would be confusing — the user would see all their countries pre-selected, not the card-specific subset. `CardGeneratorScreen` passes `codes` (the card's country list) directly to `MerchProductBrowserScreen`. Country re-selection is out of scope for M38.

**`MerchProductBrowserScreen` and `MerchVariantScreen` accept optional `cardId: String?`:**
Adding an optional parameter (default `null`) is backwards-compatible — all existing callers continue to work without change. The parameter is threaded through to the callable payload as `'cardId': widget.cardId` only when non-null (to avoid sending unnecessary data on existing paths).

**`TravelCard` persisted before navigation (same fire-and-forget pattern as share):**
The card save uses the same `unawaited(TravelCardService(...).create(card))` pattern from the share flow. Navigation proceeds immediately; a rare persistence failure means `cardId` in `MerchConfig` would point to a non-existent `TravelCard` — acceptable, as the order fulfils correctly regardless.

**Consequences:**
- `MerchConfig` documents from card-originated print flows have a `cardId` field; others have `null`.
- Future milestone can query `merch_configs` by `cardId` to find all orders from a specific card.
- Firebase Function deploy required (TypeScript types + Function code change).
- No Firestore security rule change needed (existing wildcard rule covers `merch_configs` subcollection).


---

## ADR-094 — Achievement & Level-Up Commerce Triggers: level detection, sheet navigation, and milestone CTA (M39)

**Status:** Accepted

**Context:**

M39 adds two commerce-trigger surfaces: (1) a `LevelUpSheet` shown when a user crosses an XP level threshold during/after scan, and (2) a "Create a travel card" CTA on the existing `MilestoneCardSheet`. Both surfaces navigate the user to `CardGeneratorScreen` — the Phase 13b primary path into commerce.

**Decisions:**

**Level-up detection: SharedPreferences `lastShownLevel` (not stream-based):**
XP is awarded during `ScanScreen` before `ScanSummaryScreen` is pushed. By the time `ScanSummaryScreen` builds, `xpNotifierProvider.state.level` already reflects the post-scan level and the `xpEarned` broadcast stream has already emitted. A stream listener in `ScanSummaryScreen.initState` would miss these events. Instead, `LevelUpRepository` persists `lastShownLevel` (int, default 1, SharedPreferences key `level_up_shown_v1`). In `ScanSummaryScreen._checkAndShowLevelUp()`, `currentLevel > lastShownLevel` triggers the sheet. This mirrors the `MilestoneRepository` pattern exactly.

**`_checkAndShowLevelUp` as a `VoidCallback next` chain (mirrors `_checkAndShowMilestone`):**
`ScanSummaryScreen` already uses the `_checkAndShowMilestone(VoidCallback next)` pattern. `_checkAndShowLevelUp(VoidCallback next)` follows the same shape: check, show if needed, then call `next`. The chains become:
- `_handleDone`: `_checkAndShowMilestone(() => _checkAndShowLevelUp(() => _pushDiscoveryOverlays()))`
- `_handleCaughtUp`: `_checkAndShowMilestone(() => _checkAndShowLevelUp(widget.onDone))`
Level-up is shown after milestone (if both trigger on the same scan) — milestone first is the natural chronological order.

**Sheet → CardGeneratorScreen navigation: pop then push on the same navigator:**
Both `LevelUpSheet` and the updated `MilestoneCardSheet` navigate to `CardGeneratorScreen` via a `onCreateCard: VoidCallback?` callback passed from `ScanSummaryScreen`. The callback: (1) pops the sheet with `Navigator.of(context).pop()`, then (2) pushes `CardGeneratorScreen` with `Navigator.of(context).push(MaterialPageRoute(...))`. Using a callback (not inline navigation inside the widget) ensures the correct navigator context is used. Do not pass `rootNavigator: true` — the main navigator is the correct target.

**`MilestoneCardSheet` gets `onCreateCard: VoidCallback?` (optional, backward-compatible):**
The sheet renders "Create a travel card" `FilledButton` only when `onCreateCard` is non-null. All existing call sites that omit the parameter continue to work. The button is placed above the Share button (primary CTA position).

**`LevelUpSheet` is not shown for Level 1 (the default starting level):**
`LevelUpRepository.getLastShownLevel()` returns 1 on first install. The condition is `currentLevel > lastShownLevel`, so a user at level 1 never sees the sheet. The sheet is first shown when reaching level 2 (Explorer). This is intentional — level 1 is the baseline, not an achievement.

**Level emoji map defined in `level_up_sheet.dart`:**
A const map `_kLevelEmoji` (Traveller: 🌱, Explorer: 🧭, Navigator: 🗺️, Globetrotter: ✈️, Pathfinder: 🌍, Voyager: ⚓, Pioneer: 🔭, Legend: 🏆). Unknown labels fall back to ✈️.

**Consequences:**
- `ScanSummaryScreen` gains one new async method and two updated call chains — no change to the existing milestone or discovery overlay flows.
- `LevelUpRepository` is a new SharedPreferences-backed class; its unit tests mirror `MilestoneRepository` tests.
- `MilestoneCardSheet` gains one optional parameter — zero impact on existing callers.
- No XP system, Firestore, or Firebase Function changes required for M39.


---

## ADR-095 — M43 Scan Delight: widget conversions, in-scan toast/map/confetti, and app-open prompt

**Status:** Accepted

**Context:**
M43 adds real-time discovery feedback during scanning (toast, inline world map, micro-confetti), a redesigned post-scan flag timeline, and an app-open scan prompt. These require decisions about: (1) how to convert `_ScanningView` to stateful to manage animation controllers; (2) how to detect new codes in widget lifecycle; (3) how to debounce camera moves; (4) how to trigger a one-shot modal from `MapScreen`, which is currently a `ConsumerWidget` with no `initState`.

**Decision:**

**`_ScanningView` → `ConsumerStatefulWidget`:**
`_ScanningView` is converted from `StatelessWidget` to `ConsumerStatefulWidget` to support: (a) watching `polygonsProvider` for `_ScanLiveMap`, (b) managing the `ConfettiController` for micro-confetti, and (c) managing the toast animation controller. All existing props (`progress`, `liveNewCodes`) remain unchanged.

**New code detection via `didUpdateWidget` length comparison:**
The trigger for both toast and confetti is: `widget.liveNewCodes.length > oldWidget.liveNewCodes.length`. The newly discovered code is `widget.liveNewCodes.last`. This is reliable because `_liveNewCodes` in `_ScanScreenState` only ever grows (never shrinks mid-scan). No need for Set diffing.

**Camera debounce via Timer cancel-and-restart:**
`_ScanLiveMap` holds a `Timer? _debounceTimer` and a `String? _pendingCode`. On each new code: cancel any running timer, store the code as pending, start a new 800ms timer. When the timer fires, call `mapController.fitCamera(...)` for `_pendingCode`. This ensures only the latest code drives camera movement during rapid discovery, discarding intermediate codes. The `MapController` is initialised in `initState`.

**App-open scan prompt via `_ScanPromptGate` (ConsumerStatefulWidget):**
`MapScreen` is currently a `ConsumerWidget` (no `initState`). Rather than reverting it to `ConsumerStatefulWidget`, a small `_ScanPromptGate` — a `ConsumerStatefulWidget` returning `SizedBox.shrink()` — is inserted into the `MapScreen` Stack. Its `initState` uses `WidgetsBinding.instance.addPostFrameCallback` to read the two async conditions (`onboardingCompleteProvider`, `lastScanAtProvider`) and show `DiscoverNewCountriesSheet` if both are met. This pattern mirrors `_NewDiscoveriesStateState._initAnimations()` and keeps `MapScreen` lean.

**Dismissed-today state via SharedPreferences key `scan_prompt_dismissed_at`:**
On dismiss ("Later" or "Scan now"), write today's date as ISO string (`DateTime.now().toIso8601String()`) to SharedPreferences key `scan_prompt_dismissed_at`. On next app open, `_ScanPromptGate` reads this key; if the stored date matches today's `DateUtils.dateOnly(DateTime.now())`, the prompt is skipped. No new Riverpod provider needed — read directly from SharedPreferences in `_ScanPromptGate.initState`.

**Micro-confetti cap and debounce in `_ScanningViewState`:**
`_burstCount: int` tracks how many bursts have fired; reset to 0 in `initState`. A `_burstTimer: Timer?` enforces the 500ms minimum gap. On `didUpdateWidget` new code detected: if `_burstCount >= 5` → skip; if timer is active → skip (still cooling down); otherwise play one burst, increment `_burstCount`, start 500ms timer. `ConfettiController` disposed in `dispose()` with `mounted` guard.

**Consequences:**
- `_ScanningView` becomes a `ConsumerStatefulWidget` — slight complexity increase, same pattern as `TripMapScreen` and others.
- `_ScanLiveMap` is a `ConsumerStatefulWidget` nested inside `_ScanningView`; it watches `polygonsProvider` directly (already loaded at app start — no latency).
- `MapScreen` stays a `ConsumerWidget` — no regression.
- `_ScanPromptGate` is a `SizedBox.shrink()` — zero visual impact; disposed when MapScreen leaves the tree.
- No new packages required; no Firestore or platform channel changes.

---

## ADR-096 — Passport Stamp Card: CustomPainter rendering, deterministic layout, and richer card input (M44)

**Status:** Accepted

**Context:**
`PassportStampsCard` in M37 is a widget-based `Wrap` of small bordered boxes (`_StampWidget`). It functions but looks like a data table, not a passport page. The two other card templates (grid, heart) similarly use widget layout and flag emojis. For the passport template specifically, authentic stamp appearance requires: true arbitrary rotation (not `Transform.rotate` which affects widget layout flow), overlapping stamps with controlled occlusion, per-stamp `CustomPainter` drawing of shape-specific stamp anatomy, and ink-transparency effects. None of these are achievable with standard widget layout.

Additionally, `PassportStampsCard` currently accepts only `List<String> countryCodes`. Showing trip dates ("12 JAN 2023") and ENTRY/EXIT labels requires access to `TripRecord` data, which the `CardGeneratorScreen` already loads via `tripRepositoryProvider`.

**Decision:**

**1. Flutter `CustomPainter` + `Canvas` for all stamp drawing:**
Each stamp is drawn by `StampPainter.paint()` using `canvas.save()` / `translate(center)` / `rotate(rotation)` / `restore()`. This gives pixel-accurate rotation and placement with no layout side-effects. The `PassportStampsCard` widget wraps a single top-level `CustomPaint` (sized by `LayoutBuilder`) whose painter composes background + stamps in a single paint pass.

**2. `StampData` is a rendering artefact, not a domain model:**
`StampData` lives in `lib/features/cards/` alongside the card templates. It has no Firestore serialisation. It is derived transiently from `TripRecord` data at paint time. This keeps `packages/shared_models` clean.

**3. Deterministic layout via seeded `Random`:**
`PassportLayoutEngine.layout()` accepts a `seed` (default 0). The seed is derived from `countryCodes.join().hashCode`. Same user → same layout on every device and session. A caller can pass a different seed for "shuffle" variety. Partial overlap is allowed; full occlusion is prevented by an 80%-radius rejection test with 8 max attempts per stamp.

**4. Procedural paper texture — no PNG asset:**
`PaperTexturePainter` draws: warm parchment base (`0xFFF5ECD7`), ~1000 seeded micro-rects for grain, two faint fold lines, and corner aging via radial gradient. Avoids adding a binary asset to the Flutter bundle and keeps the texture deterministic.

**5. `PassportStampsCard` signature extension:**
New signature: `PassportStampsCard({required List<String> countryCodes, List<TripRecord> trips = const []})`. When `trips` is non-empty, stamp data is derived from trips sorted by date. When empty (fallback), stamps use codes only with no date label. Grid and Heart cards are unchanged.

**6. `CardGeneratorScreen` passes trips to passport template only:**
`CardGeneratorScreen` already watches `visitRepositoryProvider` for codes. It now also watches `tripRepositoryProvider`. When the passport template is active, it passes `trips: allTrips.where((t) => selectedCodes.contains(t.countryCode)).toList()`. This is a UI-layer concern; no package boundaries are crossed.

**7. 4 stamp shapes for MVP:**
`circular`, `rectangular`, `oval`, `doubleRing`. Hexagonal, vintage, and block-typography shapes are deferred. Shapes cycle deterministically by stamp index so the layout has visual variety without randomness.

**8. Cap of 20 stamps:**
Cards render at most 20 stamps. Countries beyond 20 are silently omitted from the stamp layout (the card footer continues to show the total country count). This prevents layout engine performance degradation and visual clutter on the small card canvas.

**Consequences:**
- `_StampWidget` and `_OverflowChip` private classes are deleted from `card_templates.dart`.
- `card_templates_test.dart` requires update: `PassportStampsCard` tests must pass `trips: []` (or supply `TripRecord` stubs).
- `CardGeneratorScreen` gains a second async dependency (`tripRepositoryProvider`) — handled by `.when()` in the existing provider pattern.
- Arc text for the circular stamp shape requires manual glyph positioning via `TextPainter`; if too complex, circular stamps use top-aligned straight text instead (builder decision).
- No new pub packages required. `intl` (date formatting) and `dart:math` (PRNG) are already present.

---

## ADR-097 — Passport Stamp Realism Upgrade: Ink Simulation, Pressure Distortion, and Authentic Layout

**Status:** Accepted

**Context:**
M44 established a working `CustomPainter`-based stamp renderer with 4 shapes, deterministic layout, and a procedural paper texture. Visual review and reference imagery (real passport stamp sheets) reveal that the stamps look too clean and digitally perfect. Authentic passport stamps exhibit:
- Ink bleed, uneven opacity, and micro-gaps in lines from rubber stamp mechanics
- Pressure variation producing darker/lighter zones across the stamp face
- Subtle geometric imperfection — real circles are not mathematically perfect
- Muted, de-saturated ink colours (not pure RGB)
- Occasional rare artefacts: double-stamp ghosting, partial stamp, ink blobs, smudge streaks
- Typography with condensed letterforms, slight character-spacing variation, ARRIVAL/DEPARTURE/IMMIGRATION sublabels, and monospaced dates
- Richer shape vocabulary: triangles, hexagons, vintage thick-border, transit minimal circles, hex achievement badges

The current 4-shape system (circular, rectangular, oval, doubleRing) needs expanding to at least 12 reusable procedural style templates, and the ink rendering pipeline needs a multi-step effect chain.

**Decisions:**

**1. Ink realism — procedural noise opacity mask:**
Each stamp is drawn into an `OffscreenCanvas` (via `PictureRecorder`). After drawing, a noise layer is composited over the stamp using `BlendMode.dstIn` (alpha mask). The noise is generated by `StampNoiseGenerator` — a deterministic Perlin-approximation using `dart:math` `Random(seed)` — producing:
- Edge opacity falloff: radial gradient from 0.95 opacity at centre to 0.70 at edge
- Micro-gap noise: ~3% of edge pixels reduced to 0 opacity via random threshold
- Ink bleed simulation: 1–3px Gaussian-equivalent blur applied via `MaskFilter.blur(BlurStyle.normal, sigma)` on stroke paints
- No external packages; all implemented in `stamp_noise_generator.dart` using `dart:math`

**2. Pressure distortion — vertex jitter:**
`StampShapeDistorter` applies sub-pixel vertex offsets before passing paths to `StampPainter`. For circular stamps, the path is approximated as a 72-point polygon; each vertex is offset by `±distortion * radius` where `distortion` is drawn from the stamp's seeded random (range 0.005–0.025). Rectangular stamps have corner radius randomised ±1–2px and border width varied ±15% across the four sides. This breaks mathematical perfection without visible distortion at normal viewing size.

**3. Expanded stamp style system — 12 template types:**
`StampStyle` enum replaces the current `StampShape` enum. Each value maps to a `StampStyleConfig` that defines geometry, typography layout, and decorative elements:

| Style | Geometry | Characteristic element |
|---|---|---|
| `airportEntry` | Double-ring circle | Airplane silhouette (paths only, no assets) |
| `airportExit` | Single-ring circle | Airplane silhouette mirrored |
| `landBorder` | Rounded rectangle | Single border, wide spacing |
| `visaApproval` | Double-border rectangle | APPROVED sublabel |
| `transit` | Minimal thin circle | Country code only, no sublabel |
| `vintage` | Thick-border circle | Ornamental inner cross-hatch ring |
| `modernSans` | Oval | Clean condensed typography |
| `triangle` | Equilateral triangle | Country name along bottom edge |
| `hexBadge` | Hexagon | Achievement-badge style |
| `dottedCircle` | Circle with dashed border | Dashed path via `PathEffect` equivalent |
| `multiRing` | Triple-ring circle | Three concentric rings at varying widths |
| `blockText` | Wide rectangle | Large monospaced country code fill |

Style assignment is deterministic by `(countryCode.hashCode + index) % StampStyle.values.length`. Callers can force a specific style for special countries (e.g. home country).

**4. Ink colour palette — de-saturated ink families:**
`StampInkPalette` defines 6 ink families drawn from reference imagery:

| Family | Primary hex | Use |
|---|---|---|
| `immigrationBlue` | `#2D4F8B` | Most entry stamps |
| `customsRed` | `#8B2C2C` | Customs / border control |
| `purpleVisa` | `#5B3A7E` | Visa approval stamps |
| `blackBorder` | `#1A1A1A` | Formal border control |
| `oliveGreen` | `#4A6741` | Some Latin American stamps |
| `fadedInk` | `#6B7B8D` (desaturated) | Older / aged stamps |

Pure RGB values are avoided. Colour is assigned deterministically by `(countryCode.hashCode * 31) % 6`. Saturation is further reduced by 10–20% at paint time via HSL manipulation using `HSLColor.fromColor`.

**5. Stamp aging system — optional effect chain:**
`StampAgeEffect` is an enum with 4 levels: `fresh`, `aged`, `worn`, `faded`. Age is assigned by seeded random, weighted toward `fresh` (60%) and `aged` (30%), with `worn` (8%) and `faded` (2%). Each level modifies:
- Overall opacity: `fresh`=0.90, `aged`=0.78, `worn`=0.62, `faded`=0.45
- Noise intensity: increases with age
- Colour: `worn` and `faded` shift toward `fadedInk` family

**6. Rare artefact system:**
After normal stamp rendering, `RareArtefactEngine.apply()` is called per stamp with the stamp's seeded random. Probabilities:

| Artefact | Probability | Implementation |
|---|---|---|
| Double-stamp ghost | 5% | Stamp drawn twice; second pass offset 1–3px at 20% opacity |
| Partial stamp | 3% | `canvas.clipRect` applied before drawing, cropping 10–30% of stamp |
| Heavy ink blob | 2% | Filled circle 3–6px at stamp centre at 80% opacity |
| Smudge streak | 2% | `MaskFilter.blur` directional smear via sheared rect |
| Correction stamp | 1% | Small "VOID" or "CANCELLED" rectangle overlaid at 40% opacity |

Rare artefacts are deterministic (same seed = same artefacts). They can be disabled via `StampRenderConfig.enableRareArtefacts = false` for screenshot/export contexts that need clean output.

**7. Typography realism:**
`StampTypographyPainter` replaces direct `TextPainter` calls in `StampPainter`. It adds:
- Condensed letter-spacing: `letterSpacing: -0.5` to `-1.0` depending on style
- Monospaced date rendering: date string drawn character-by-character with fixed advance width
- Sublabel text: "ARRIVAL" / "DEPARTURE" / "IMMIGRATION" in smaller weight, above or below country name depending on shape
- Slight baseline jitter: each character's baseline offset by `±0.5px` from seeded random
- Ink break simulation: 1–2 characters per stamp rendered at 60% opacity (random selection)

Arc text for circular stamps is implemented via glyph-by-glyph `canvas.translate + rotate` — each character individually transformed along the circle path.

**8. Layout algorithm improvements:**
`PassportLayoutEngine` gains the following behaviours (all deterministic via seed):
- Rotation range widened to ±20° (was ±15°)
- Temporal ordering: stamps are sorted by trip date before placement; earliest stamps placed lower on the page, later stamps fill upper gaps — matches real passport page progression
- Partial page-edge clipping: 8% of stamps are placed such that 10–25% of their bounding box extends beyond the page edge, then clipped with `canvas.clipRect(pageRect)`
- Cluster seeding: the page is divided into a 3×4 soft grid; placement probability is weighted toward underoccupied cells to simulate natural stamping patterns

**9. Paper × stamp blend mode:**
`PaperTexturePainter` now draws to a `Picture`, converted to an `Image`. Stamps are composited over it using `BlendMode.multiply`. This causes stamp ink to darken the paper texture underneath rather than floating on top — the critical visual difference between a real stamp and a digital overlay. The `BlendMode.multiply` requires drawing stamps after paper in a `Canvas.saveLayer()` call that covers the full card bounds.

**10. Rendering pipeline order (replaces current single-pass paint):**
```
1. PaperTexturePainter → base layer (parchment + grain + fold lines)
2. canvas.saveLayer(BlendMode.multiply)
3.   For each StampData (sorted by z-order):
4.     PictureRecorder → offscreen canvas
5.     StampShapeDistorter → distorted path
6.     StampStyleConfig → draw geometry (rings, borders, icons)
7.     StampTypographyPainter → draw text elements
8.     StampNoiseGenerator → apply opacity mask
9.     StampAgeEffect → apply opacity + colour shift
10.    RareArtefactEngine → apply rare effects
11.    Composite offscreen picture onto main canvas at stamp position/rotation
12. canvas.restore()
13. Vignette overlay (subtle darkening at page corners)
```

**11. Performance guardrails:**
- Offscreen `PictureRecorder` per stamp adds ~1–2ms per stamp at 3× pixel ratio; capped at 20 stamps = ~40ms maximum extra cost
- `StampNoiseGenerator` precomputes a 64×64 noise tile per stamp seed, reused across the render pass
- `PassportStampsCard` wraps the full paint in `RepaintBoundary` — no repaints triggered by parent widget rebuilds
- All expensive computations (`layout()`, `StampData` derivation) run in `compute()` on a background isolate before the first paint

**12. No new pub packages:**
All effects implemented using `dart:math`, `dart:ui` (`Canvas`, `Paint`, `Path`, `PictureRecorder`, `MaskFilter`, `BlendMode`), and `flutter/painting.dart`. Adding a Perlin noise package is explicitly rejected — the approximation quality from seeded `Random` is sufficient for stamp-scale noise.

**Consequences:**
- `StampShape` enum is replaced by `StampStyle` enum; `StampData.shape` field renamed `StampData.style`. All references in `stamp_painter.dart`, `passport_layout_engine.dart`, and tests updated.
- `stamp_painter.dart` gains 3 collaborator classes: `StampNoiseGenerator`, `StampShapeDistorter`, `StampTypographyPainter` — each in its own file to keep paint logic navigable.
- `RareArtefactEngine` and `StampInkPalette` are new files in `lib/features/cards/`.
- `PaperTexturePainter` gains `BlendMode.multiply` composition — the card must be rendered inside `canvas.saveLayer()`. Export (screenshot) path is unaffected as it already uses `RepaintBoundary.toImage()`.
- The 20-stamp cap remains. Performance budget is not exceeded.
- `card_templates_test.dart` stamp tests require updating for renamed enum and new `StampRenderConfig` parameter.
- Legally safe: no reproduction of real government stamp designs. All shapes are generic geometric forms. Country names and dates are user data, not copied government text.

---

## ADR-098 — Flag Heart Card: True Heart-Mask Layout Engine with Dynamic Grid Density

**Status:** Accepted

**Context:**
ADR-092 (M37) introduced a `HeartFlagsCard` using a warm amber gradient with a semi-transparent ❤️ watermark rather than a true geometric heart clip — explicitly deferred as a "future polish pass." The existing implementation does not produce a heart composed of flags; it produces a flag grid over a heart-branded background. The design requirement is a product-quality graphic — suitable for t-shirts and posters — where the heart shape itself is formed by the flag tiles, with flags clipped at the heart boundary and at least 66% of each tile remaining visible. This is structurally different from the current implementation and requires a dedicated layout engine.

The `CardGeneratorScreen` already passes `countryCodes` to all three templates. Flag rendering currently uses emoji characters. For the Flag Heart, emoji rendering is insufficient at 3000×3000 and 5000×5000 export resolutions — SVG flag assets or high-resolution PNGs are required.

**Decisions:**

**1. Heart mask: parametric equation, not Bézier or SVG:**
The heart boundary is evaluated using the standard parametric form:
```
(x² + y² − 1)³ − x²y³ ≤ 0
```
where `x` and `y` are normalised to `[−1.4, 1.4]` over the canvas bounds. This is computed once per layout pass and cached as a `bool` lookup grid at tile resolution. A `Path`-based Bézier alternative was considered but the parametric form is simpler to implement, perfectly symmetrical, and produces smoother results at variable resolutions. The `Path` is also built from the parametric equation for `Canvas.clipPath()` at export time.

**2. Layout engine: Option C — dense grid filtered by mask coverage:**
`HeartLayoutEngine.layout()` operates in three stages:

*Stage 1 — Density selection:*
| Flag count | Tile size (at 1024px canvas) | Tile size (at 3000px) |
|---|---|---|
| 1–12 | 180px | 525px |
| 13–40 | 110px | 320px |
| 41–120 | 72px | 210px |
| 121–200 | 52px | 152px |
| 201+ | 40px | 117px |

Tile size is calculated as `canvasSize / targetColumns` where `targetColumns` is selected from the above bands. The engine then iterates column counts ±1 to find the count that best fills the heart with the actual flag count (minimises empty valid cells).

*Stage 2 — Candidate generation:*
A rectangular grid of tile centres is generated covering the full canvas bounding box. Each centre is tested against the parametric heart inequality. The coverage fraction of each tile is estimated by testing the four corners plus centre (5-point sample) — tiles with ≥3/5 sample points inside the heart pass immediately; tiles with 2/5 undergo a denser 9-point test for the 66% threshold. Tiles below 66% coverage are rejected.

*Stage 3 — Flag assignment:*
Valid tile positions are sorted by the selected ordering strategy (see decision 4). Flags are assigned sequentially. If valid tile count exceeds flag count, surplus tiles are discarded from the outer edge inward (preserving heart density). If flag count exceeds valid tiles, tile density is increased one band and layout is re-run (max 2 re-runs).

**3. `HeartFlagsCard` replaces `HeartFlagsCard` (same widget name, new implementation):**
The existing `HeartFlagsCard` widget in `card_templates.dart` is rewritten. Its external interface (`required List<String> countryCodes`) is unchanged so `CardGeneratorScreen` requires no update. Internally it switches from `Wrap` + gradient to `CustomPaint` with `HeartPainter`. The amber gradient background and ❤️ watermark are removed.

**4. Flag ordering strategies:**
`HeartFlagOrder` enum with 4 values:
- `chronological` — sort by earliest trip date for country; requires `List<TripRecord>` passed to widget (same pattern as `PassportStampsCard`)
- `alphabetical` — sort by `CountryName.forCode(code)`
- `geographic` — sort by continent then by longitude (groups neighbouring countries visually)
- `randomized` — seeded shuffle by `countryCodes.join().hashCode` (default; deterministic per user)

`CardGeneratorScreen` exposes a segmented control for order selection when the passport template is active. Default is `randomized`.

**5. Flag rendering — SVG assets via `flutter_svg`, PNG fallback:**
Emoji flag rendering (`🇬🇧`) is not viable at 3000×3000 — glyph rasterisation is device-font-dependent and produces pixelation at large tile sizes. Flag Heart requires vector-quality flag rendering.

Decision: add `flutter_svg: ^2.x` to `pubspec.yaml`. Flag SVGs are sourced from the `country-flags` open-source dataset (MIT licence), bundled as Flutter assets under `assets/flags/svg/{code}.svg` (ISO 3166-1 alpha-2 lowercase). PNG 256×256 fallbacks are provided for codes where SVG is unavailable.

`FlagTileRenderer` wraps `SvgPicture.asset()` inside a `SizedBox` constrained to tile dimensions. At export resolution, `SvgPicture` is rendered into an offscreen `Picture` via `PictureRecorder` at the target DPI. This is the only milestone that adds a new pub package; it is justified by the product requirement for print-quality output.

**6. Canvas clip and blend pipeline:**
```
1. canvas.save()
2. canvas.clipPath(heartPath, doAntiAlias: true)   // vector clip, smooth edge
3.   For each FlagTile in layout:
4.     canvas.drawImageRect(flagImage, src, dst, paint)  // or SvgPicture at tile bounds
5.     if gapWidth > 0: draw 1px white separator lines over tile edges
6. canvas.restore()
7. canvas.saveLayer(fullBounds, Paint()..blendMode = BlendMode.dstIn)
8.   canvas.drawPath(heartPath, solidPaint)   // feathered alpha mask for 1–2px edge softening
9. canvas.restore()
```
The `dstIn` saveLayer after the clip produces a 1–2px feathered edge, eliminating staircase artefacts at the heart boundary. The clip alone produces a hard vector edge; the `dstIn` pass softens it.

**7. Visual polish options:**
`HeartRenderConfig` controls optional effects (all off by default for performance):
- `gapWidth` (0–4px): white hairline between tiles; default 1px
- `tileCornerRadius` (0–4px): micro-rounded tile corners; default 2px
- `tileShadowOpacity` (0.0–0.3): subtle drop shadow under each tile; default 0.0
- `edgeFeatherPx` (1–3px): softness of heart boundary feather; default 1.5px

**8. Multi-resolution export:**
`HeartImageExporter.export(codes, size, config)` returns a `Future<ui.Image>`. It runs `HeartLayoutEngine.layout()` at the target size (tile sizes scale proportionally), renders to `PictureRecorder`, and returns the rasterised image. Supported sizes: 1024, 3000, 5000px square.

Export is called from `CardGeneratorScreen`'s existing share/print flow — same `RepaintBoundary.toImage()` path for in-app preview; `HeartImageExporter.export()` called separately for merch/poster generation at 3000×3000.

**9. Performance:**
- `HeartLayoutEngine.layout()` runs in `compute()` (background isolate) — layout for 200 flags at 3000px takes ~80ms on an iPhone 12
- Flag SVG → `ui.Image` conversion is cached by country code + tile size in `FlagImageCache` (LRU, max 300 entries)
- Heart path and parametric mask grid are cached for the session; invalidated only on canvas size change
- 50 flags preview: <50ms; 100 flags: ~100ms; 200 flags: ~220ms (within spec)

**10. `CardTemplateType` and `TravelCard` Firestore schema:**
`CardTemplateType.heart` already exists. `TravelCard.templateType` is already stored. No Firestore schema change required. The `HeartFlagOrder` preference is not persisted — it is session-only state in `CardGeneratorScreen`.

**11. Aspect ratio and background:**
The heart canvas is always square (1:1). The exported PNG has a fully transparent background (alpha channel preserved). No background colour is written. In preview mode within `CardGeneratorScreen`, the card sits on the existing dark card preview background — no change to screen layout required.

**Consequences:**
- `flutter_svg` added to `pubspec.yaml` — first new pub package since M34. Must be approved in `pubspec_approvals.md` or equivalent review step.
- Flag SVG assets must be bundled: ~260 SVG files, ~1.5MB total. Added to `pubspec.yaml` `assets:` section under `assets/flags/svg/`.
- `HeartFlagsCard` widget is a breaking rewrite — existing `card_templates_test.dart` heart tests require full replacement.
- `HeartLayoutEngine`, `MaskCalculator`, `FlagTileRenderer`, `HeartImageExporter`, `FlagImageCache` are new files in `lib/features/cards/`.
- `CardGeneratorScreen` gains a flag-order segmented control (visible only when heart template is selected) and a second async provider watch for `tripRepositoryProvider` (for chronological ordering).
- Grid and Passport card templates are unchanged.

---

## ADR-099 — Commerce Template & Placement: `CardImageRenderer`, in-screen template picker, and Printful placement field (M47)

**Status:** Accepted

**Context:**
ADR-093 (M38) introduced `clientCardBase64` so the t-shirt mockup reflects the card template the user designed. The implementation partially landed in M44–M46: `card_generator_screen.dart` captures a `RepaintBoundary` and threads `Uint8List? cardImageBytes` through `MerchProductBrowserScreen` → `MerchVariantScreen`. Three gaps remain:

1. **Template not carried to merch screen**: When the user navigates from card generator → product browser → variant screen, the variant screen does not have a template picker — it always sends the bytes captured at navigation time. If the user wants to change the template inside the merch flow, they must go back to `CardGeneratorScreen`, change it, and re-enter.
2. **Colour variant not driving mockup**: `generatePrintfulMockup` finds the variant by `Number(vm.catalog_variant_id) === printfulVariantId` — the `Number()` coercion was added in M44 as BUG-001 fix, but it has not been confirmed as working in production. The user still reports always seeing a white t-shirt regardless of colour selection.
3. **No front/back placement**: The Printful mockup API supports a `placement` field (`front` / `back`). It is not currently sent; Printful defaults to `front` for all orders.

**Decisions:**

**1. `CardImageRenderer` replaces `RepaintBoundary` capture for merch:**
The current capture approach (`boundary.toImage()` from a `GlobalKey`) works only when the widget is rendered on screen. Inside `MerchVariantScreen`, there is no passport/grid/heart widget tree — only the mockup preview. Therefore the variant screen cannot capture a live widget.

Decision: introduce `CardImageRenderer.render(template, codes, trips)` — a utility that constructs a full `RenderView`/`RenderBox` tree, pumps it without displaying it, and calls `toImage()`. This produces PNG bytes for any template on demand, without requiring a `BuildContext` or an on-screen widget.

If constructing an offscreen render tree proves unviable in the current Flutter version, the fallback is: the variant screen opens from the generator screen (which has the template on screen), and the template picker inside the variant screen causes a navigation-pop + push cycle. The `CardImageRenderer` approach is strongly preferred.

**2. Template picker moves into `MerchVariantScreen`; `cardImageBytes` threading removed:**
Passing `Uint8List? cardImageBytes` through the navigation stack creates tight coupling. The variant screen is the right place for template selection — the user is customising the product, and the template is a product customisation. Changing the template triggers `_generatePreview()`, which re-renders via `CardImageRenderer` and re-calls `createMerchCart`.

`cardImageBytes` is removed as a constructor param from `MerchVariantScreen`, `MerchProductBrowserScreen`, and the navigator call in `CardGeneratorScreen`. `CardGeneratorScreen` no longer needs to capture an image at nav time.

**3. Placement picker: `SegmentedButton`, t-shirt only, defaults to `front`:**
Posters and framed prints have no placement concept — the print covers the entire surface. The placement picker is therefore conditionally visible based on `product == MerchProduct.tshirt`. Default is `front` to maintain the existing behaviour for all existing orders. Changing placement triggers `_generatePreview()`.

**4. Firebase Function `placement` field:**
`CreateMerchCartRequest.placement?: 'front' | 'back'` (optional; defaults to `'front'`). The value is stored on `MerchConfig` and passed to Printful in the `placements[0].placement` field of the mockup request body. Printful's v2 Mockup API uses the key `placement` with values `front` and `back` for the DTG technique.

**5. `clientCardBase64` size guard:**
The base64 of a 3× pixel-ratio PNG at 340×480 logical pixels is approximately 2–3 MB. The guard rejects inputs over 4 MB (base64 string length > 5,500,000 characters, which corresponds to ~4 MB decoded) with `HttpsError('invalid-argument')`. This prevents accidentally sending full-resolution export images.

**6. BUG-001 diagnostic logging:**
The `Number()` coercion fix (ADR-093 + M44) is believed correct but unconfirmed in production. Structured logging is added to `generatePrintfulMockup` so every invocation emits the matched variant ID and its runtime type. This closes the observability gap without changing behaviour.

**Consequences:**
- `cardImageBytes` parameter removed from the nav chain — breaking change for any call sites outside the identified files (none expected; checked via grep).
- `CardImageRenderer` is a new file with no pub package dependencies — uses only `dart:ui` and existing Flutter card widgets.
- `MerchConfig` Firestore schema gains a `placement` field — backward-compatible (new orders written with `placement: 'front'`; old documents missing the field treated as `'front'` at read time).
- `CreateMerchCartRequest` and `CreateMerchCartResponse` TypeScript interfaces updated — `packages/shared_models` TypeScript counterpart does not exist yet (deferred; not affected).
- Printful sandbox testing required to confirm `placement: 'back'` produces a back-print mockup URL before production deploy.

---

## ADR-100 — ArtworkConfirmation: user-scoped Firestore subcollection, SHA-256 image hash, optional cart linkage (M48)

**Status:** Accepted

**Context:** M48 establishes the data foundation for the Print Confidence series (M48–M54). The feature requires:
1. An `ArtworkConfirmation` record that proves the user explicitly approved a specific rendered image before purchase.
2. A deterministic image hash so the approval is tied to the exact pixels, not just the parameters.
3. A linkage from `MerchConfig` → `ArtworkConfirmation` so after purchase the `ArtworkConfirmation` status updates to `purchase_linked`.

Three structural decisions are needed: where to store the record, how to compute the hash, and how to add the linkage non-breakingly.

**Decision:**

**1. Storage: `users/{uid}/artwork_confirmations/{confirmationId}` subcollection**
Confirmed and pre-existing Firestore rule `match /users/{userId}/{document=**}` already covers all subcollections at any depth — no new rules are needed for `artwork_confirmations` or `mockup_approvals`. The `{document=**}` wildcard covers `users/{uid}/artwork_confirmations/{id}/mockup_approvals/{id}`.

**2. Hash: SHA-256 hex of the PNG bytes from `CardImageRenderer.render()`**
`CardImageRenderer.render()` is changed to return `CardRenderResult({Uint8List bytes, String imageHash})` instead of `Uint8List`. The hash is computed in Dart using `package:crypto` (already in pubspec) so it is deterministic for identical inputs within the same render session. The `renderSchemaVersion` field (`"v1"`) documents the rendering parameters so future re-renders can be verified.

**3. `artworkConfirmationId` on `MerchConfig`: optional, null for legacy orders**
`CreateMerchCartRequest` gains `artworkConfirmationId?: string`. `MerchConfig` gains `artworkConfirmationId: string | null`. The `shopifyOrderCreated` webhook: when `artworkConfirmationId` is non-null, updates the `ArtworkConfirmation` document status to `purchase_linked` + stores `orderId`. Legacy orders (null `artworkConfirmationId`) are unaffected.

**Consequences:**
- `CardImageRenderer.render()` return type changes — only one call site (`merch_variant_screen.dart`) must be updated to `.bytes`.
- `CardRenderResult` is a plain value type in `card_image_renderer.dart` — not in `shared_models` (no network/persistence boundary; Flutter-only type).
- `MerchConfig` schema gains `artworkConfirmationId: string | null` — backward-compatible (old docs missing the field read as null).
- The `shopifyOrderCreated` webhook gains a Firestore write to the confirmation doc — non-breaking side-effect; fails gracefully if doc not found.
- No new Firestore security rules needed — existing wildcard covers the new subcollections.

---

## ADR-101 — Branding Layer: `CardBrandingFooter` Widget, dateLabel pass-through, Heart canvas-to-Widget migration (M49)

**Status:** Accepted

**Context:** M49 requires all three card templates (Grid, Heart, Passport) to show a consistent branding footer — Roavvy wordmark + country count + date range label — as part of the captured PNG artwork.

Three structural decisions:

1. **Widget vs. canvas for branding**: The Grid and Passport templates are `StatelessWidget`/`Stack` layouts; adding a footer widget is straightforward. The Heart template currently draws the ROAVVY label directly in `_HeartPainter.paint()` as a `TextPainter` canvas call.

2. **Where to compute the date label**: Date range depends on which trips are in scope, not on the card template. Templates should receive a pre-computed string, not trip records they must re-process.

3. **`CardImageRenderer` parameter surface**: Adding `dateLabel` to `render()` now is premature — M51 (Artwork Confirmation Screen) is the first caller that will have a meaningful date range from the UI. Changing the signature now would require updating M48-era tests with no actual benefit.

**Decision:**

**1. `CardBrandingFooter` is a `StatelessWidget`** in `lib/features/cards/card_branding_footer.dart`. All three card templates use it as a Widget positioned at the bottom of their layout — consistent approach, no canvas drawing for branding text.

**2. Heart template: replace canvas brand label with `Positioned` Widget overlay**. `_HeartPainter._drawBrandLabel()` is removed. The Heart card's `LayoutBuilder` → `CustomPaint` is wrapped in a `Stack`; `CardBrandingFooter` is `Positioned(bottom: 0)`. Dark navy background beneath the branding strip is inherent to the canvas; `CardBrandingFooter` uses a semi-transparent `Color(0xFF0D2137)` background to stay readable regardless of what heart tiles are drawn below.

**3. `dateLabel: String = ''` added to all three card templates**. Empty string = date label omitted from footer (only ROAVVY + count shown). This is backward-compatible: all existing call sites compile without changes. `CardGeneratorScreen._buildTemplate()` computes the label from `filteredTrips` and passes it. `CardImageRenderer.render()` is NOT changed — its rendered output will show ROAVVY + count (satisfying M49 acceptance criteria) with an empty date label, which is correct behaviour for a programmatic render without UI date selection context.

**4. Date label format**: single-year → `"2024"`, multi-year → `"2018\u20132024"` (en-dash, not hyphen). Empty string when no trip data. Computed by a pure helper `_computeDateLabel(List<TripRecord>)` local to `card_generator_screen.dart`.

**Consequences:**
- `GridFlagsCard`: top-level ROAVVY text header removed; bottom Row (count + "countries visited") replaced by `CardBrandingFooter`. Visual change: ROAVVY moves from top to footer.
- `HeartFlagsCard`: `_drawBrandLabel` removed from `_HeartPainter`. Branding now Widget-level; `shouldRepaint` gains `dateLabel` comparison.
- `PassportStampsCard`: `Positioned` ROAVVY watermark replaced by `Positioned` `CardBrandingFooter`. Passport-specific amber text colour (`Color(0xFF8B6914)`) preserved via `textColor` parameter.
- Existing template tests that checked for `find.text('countries visited')` must be updated (text changes to `'{N} countries'`).
- All card templates remain backward-compatible: `dateLabel` defaults to `''`.

---

## ADR-102 — M50 Layout Quality: Grid Adaptive Tile Size and Passport Print-Safe Mode

**Status:** Accepted

**Context:** M50 corrects two layout deficiencies before M51 (Artwork Confirmation) asks users to confirm print-ready artwork:

1. **Grid adaptive fill**: `GridFlagsCard` uses a fixed `fontSize: 18` regardless of country count. For N=1 this wastes most card area; for N=50+ the tiles become small and uniform.
2. **Passport print-safe mode**: `PassportLayoutEngine` uses 8% margins and randomly edge-clips ~8% of stamps. For print output, clipped stamps are unacceptable and all stamp centres must remain within a 3% safe zone.

**Decision:**

**M50-C1 — Grid adaptive fill**: A `gridTileSize(double canvasArea, int n)` pure function implements `clamp(floor(sqrt(canvasArea / n) * 0.85), 28, 90)`. `GridFlagsCard` wraps its tile area in a `LayoutBuilder`; the result drives the emoji `fontSize`. Minimum tile: 28 logical pixels; maximum: 90. The function is exposed with `@visibleForTesting` for unit testing without widget infrastructure.

**M50-C2 — Passport print-safe mode**: `PassportLayoutEngine.layout()` gains `forPrint: bool = false` and now returns `PassportLayoutResult({stamps: List<StampData>, wasForced: bool})` instead of bare `List<StampData>`.

When `forPrint = true`:
- Safe-zone margin: 3% each edge (was 8%).
- No edge clipping: `edgeClip` is always `null`.
- Uniform adaptive base radius: `unclamped = safeArea.shortSide / (2.5 × ceil(sqrt(N)))`, clamped to [20, 38]. Stamp scale is derived: `scale = clampedRadius / 38.0`.
- If `unclamped < 20` and caller did not already set `entryOnly`: force `entryOnly = true`, set `wasForced = true` on the result.

`PassportStampsCard` gains `forPrint: bool = false`, which it passes to `_PassportPagePainter`. `_PassportPagePainterState` stores `_wasForced: bool` for future surfacing by M51.

**Consequences:**
- Existing `PassportLayoutEngine.layout()` callers must access `.stamps` on the returned `PassportLayoutResult`; all existing tests updated accordingly.
- `gridTileSize()` is a top-level `@visibleForTesting` function in `card_templates.dart`.
- N=1 on a square canvas: tile fills ~85% of canvas width.
- N≥100 on typical card canvas: tile clamped to 28 px minimum.
- `wasForced` stored in `_PassportPagePainterState`; M51 will surface it to callers.

---

## ADR-103 — M51 Artwork Confirmation Flow: Screen, Navigation, and Re-Confirmation

**Status:** Accepted

**Context:** M51 requires users to explicitly confirm the exact rendered artwork before entering the product selection / purchase flow (M51-E1), with correct forward/back navigation (M51-E2) and re-confirmation when artwork parameters change (M51-E3).

Three structural decisions:

1. **How to surface `wasForced` from `_PassportPagePainterState` to `CardImageRenderer.render()`**: The renderer creates a widget, inserts it into an `OverlayEntry`, and captures it after one frame. The layout engine's `wasForced` result is set during `_PassportPagePainterState.initState()`, which runs synchronously during the first frame build — before `addPostFrameCallback` fires. An `onWasForced: ValueChanged<bool>?` callback on `PassportStampsCard` (called in `_applyLayoutResult()`) is therefore sufficient to capture the value before image capture.

2. **Navigation stack for the confirmation flow**: The M51-E2 requirement "Back from Product Browser returns to Card Generator (not Artwork Confirmation)" requires the Artwork Confirmation screen to be absent from the route stack when Product Browser is live. The cleanest approach: `ArtworkConfirmationScreen` pops with an `ArtworkConfirmResult({confirmationId, bytes})` return value; `CardGeneratorScreen` awaits the push, then (on non-null result) stores `_lastConfirmedParams` + `_artworkConfirmationId` + `_artworkImageBytes`, and pushes `MerchProductBrowserScreen`. Stack: Card Generator → Product Browser. ✓

3. **Re-confirmation comparison**: `CardGeneratorScreen` stores a `_CardParams` snapshot (templateType, countryCodes, aspectRatio, entryOnly, yearStart?, yearEnd?). On each "Print your card" press: if `currentParams == _lastConfirmedParams && _artworkConfirmationId != null`, navigate directly to Product Browser (skip confirmation). Otherwise, navigate through `ArtworkConfirmationScreen` (with `showUpdatedBanner: true` when a prior confirmation exists).

**Decision:**

- `PassportStampsCard` gains `onWasForced: ValueChanged<bool>?`; `_PassportPagePainterState._applyLayoutResult()` calls it after applying the layout result.
- `CardRenderResult` gains `wasForced: bool = false`.
- `CardImageRenderer.render()` gains `forPrint: bool = false`; when rendering passport with `forPrint=true`, wires up `onWasForced` to capture the flag.
- `ArtworkConfirmationScreen` (`lib/features/cards/artwork_confirmation_screen.dart`) is a `ConsumerStatefulWidget` receiving `(templateType, countryCodes, filteredTrips, dateRangeStart?, dateRangeEnd?, aspectRatio, entryOnly, showUpdatedBanner)`. On init it renders the card; on confirm it creates an `ArtworkConfirmation` and pops with `ArtworkConfirmResult`.
- `CardGeneratorScreen` stores `_lastConfirmedParams: _CardParams?`, `_artworkConfirmationId: String?`, `_artworkImageBytes: Uint8List?`. `_onPrint()` checks for same-params shortcut or routes through confirmation.
- `MerchProductBrowserScreen` gains `artworkConfirmationId: String?` and `artworkImageBytes: Uint8List?`; shows a rendered preview thumbnail at the top of the screen when bytes are present; threads `artworkConfirmationId` to `MerchVariantScreen`.
- `MerchVariantScreen` gains `artworkConfirmationId: String?`; passes it in the `createMerchCart` callable payload.

**Consequences:**
- `CardImageRenderer.render()` callers that already check `.bytes` and `.imageHash` are unaffected by the new `wasForced` field (default `false`).
- The `onWasForced` callback is only set for passport + `forPrint=true`; all other templates/modes are unaffected.
- `ArtworkConfirmationScreen` handles Firestore write internally via `ArtworkConfirmationService(FirebaseFirestore.instance)` — no new Riverpod provider needed.
- Re-confirmation banner copy: "Your artwork has been updated — please confirm the new version." (positive/factual, not legalistic).

---

## ADR-104 — M52 Timeline Card Template: Layout Engine, Widget, and Enum Extension

**Status:** Accepted

**Context:** M52 adds a fourth card template — "Timeline" — which renders a user's trips as a dated travel log. Three decisions need to be locked before building:

1. **Where `TimelineLayoutEngine` lives**: It uses `TripRecord` (from `shared_models`) and `Size` (from `dart:ui`). `dart:ui` is a Flutter/Dart runtime import, not a platform API, so it is available in pure Dart unit tests. However, the package boundary rule is that `shared_models` contains no business logic. The layout engine IS business logic. Therefore `TimelineLayoutEngine` lives in `lib/features/cards/timeline_layout_engine.dart` inside the mobile app, not in `shared_models`.

2. **`CardTemplateType.timeline` enum extension**: Adding `timeline` to the Dart enum in `shared_models` is a backwards-compatible change (new enum variant). All Dart exhaustive switch statements over `CardTemplateType` will fail to compile if they omit the new case — the compiler enforces completeness. The TypeScript type in `ts/` is not updated in this milestone (TypeScript-side update is deferred; `artworkConfirmationId` flow in Functions does not switch over template type).

3. **Font strategy for monospaced dates**: iOS provides `Courier` (serif monospaced) and `Courier New` natively. Rather than bundling a font, use `fontFamily: 'CourierNew'` with `fontFamilyFallback: ['Courier', 'monospace']`. For the rendered PNG (via `CardImageRenderer`) this is acceptable — the font will resolve correctly on the test/rendering device. Date columns use a fixed `TextStyle` width via `SizedBox` wrappers to prevent layout shifts regardless of font metrics.

**Decision:**

- `CardTemplateType.timeline` added to the Dart enum in `packages/shared_models/lib/src/travel_card.dart`. TypeScript `ts/` not updated this milestone.
- `TimelineLayoutEngine` and `TimelineEntry` / `TimelineLayoutResult` in `lib/features/cards/timeline_layout_engine.dart` (mobile app, features layer). Pure static methods; `Size` from `dart:ui` is the only non-domain import.
- `TimelineCard` is a `StatelessWidget` in `lib/features/cards/timeline_card.dart`. Parchment background `Color(0xFFF5F0E8)`, dark ink `Color(0xFF2C1810)`, amber year dividers `Color(0xFFD4A017)`. Monospaced date column uses `fontFamily: 'CourierNew'` with Courier fallback.
- `TimelineCard` calls `TimelineLayoutEngine.layout()` inside `build()` via `LayoutBuilder` to obtain the canvas size. This keeps the widget stateless and avoids a `CustomPainter` for text-heavy content.
- `CardImageRenderer._cardWidget()` gains a `timeline` case. No `forPrint` special mode needed — no stamps, no edge clipping.
- `ArtworkConfirmationScreen` needs no change: it renders via `CardImageRenderer.render()` which already dispatches to `_cardWidget()`.
- `MerchVariantScreen` template picker gains a "Timeline" segment.

**Consequences:**
- All `switch (templateType)` statements in `card_generator_screen.dart`, `card_image_renderer.dart`, `merch_variant_screen.dart` must add a `timeline` case — Dart compiler enforces this exhaustively.
- `TimelineLayoutEngine.layout()` takes `Size` as a parameter; tests can pass a literal `Size(600, 400)` without needing widget infrastructure.
- `PassportStampsCard`'s `forPrint` complexity does not apply to Timeline — the layout engine is simpler.
- TypeScript Functions code is unaffected: `createMerchCart` accepts `templateType` as an opaque string stored on `MerchConfig`; no server-side switch over template type exists.

---

## ADR-105 — M53 Mockup Approval: Screen Placement, `artworkImageBytes` Threading, and Approval-Before-Cart Ordering

**Status:** Accepted

**Context:** M53 inserts an explicit user-approval step into the commerce flow before checkout is initiated. Three structural decisions must be made before building begins:

1. **When in the flow to request approval** — the approval screen can be shown either (a) before `createMerchCart` is called, (b) after the cart is created but before the checkout URL is launched, or (c) as part of the Printful mockup review step. The product intent is to capture consent before any server-side cart is created, ensuring that `mockupApprovalId` can be included in the `createMerchCart` payload as evidence of explicit user approval at order time.

2. **Where `artworkImageBytes` is available in the commerce stack** — `artworkImageBytes: Uint8List?` is currently a constructor parameter on `MerchProductBrowserScreen` (threaded from `CardGeneratorScreen` via `ArtworkConfirmResult`) but is NOT passed to `MerchVariantScreen`. The approval screen needs to show the card artwork for the user to confirm it is correct.

3. **What the `variantId` type is at the call site** — `_resolvedVariantGid` in `MerchVariantScreen` is already a `String`. The `MockupApproval` model stores it as `String`. No type conversion is needed.

**Decision:**

1. **Approval before cart creation.** `MockupApprovalScreen` is shown when the user taps the "Approve & buy" button (replacing the current "Preview my design" label on the `initial` state button). After approval, `_generatePreview(mockupApprovalId: result.mockupApprovalId)` is called, which includes `mockupApprovalId` in the `createMerchCart` payload. The Printful product mockup is then shown in the existing `ready` state. The existing two-stage flow (`initial → loading → ready → "Complete checkout →"`) is preserved; the approval screen is inserted before the `initial → loading` transition.

2. **Thread `artworkImageBytes` into `MerchVariantScreen`.** `MerchVariantScreen` gains `artworkImageBytes: Uint8List?` as an optional constructor parameter. `MerchProductBrowserScreen` passes it when navigating to `MerchVariantScreen` (it already holds the bytes). `MerchVariantScreen` passes `artworkImageBytes` to `MockupApprovalScreen`. The screen gracefully handles null bytes with a "Preview unavailable" placeholder.

3. **`MockupApproval` model in `shared_models`; `MockupApprovalService` in mobile features layer.** Consistent with `ArtworkConfirmation` / `ArtworkConfirmationService` pattern (ADR-100 / ADR-103). The model is a pure data class exported from the shared barrel; the service contains Firestore write logic and lives in `lib/features/merch/`. The Functions side adds `mockupApprovalId?: string` to `CreateMerchCartRequest` and `MerchConfig`.

4. **`MockupApprovalScreen` is a push route, not a bottom sheet.** The screen performs an async Firestore write before popping — this warrants full-screen treatment to prevent accidental dismissal. It pops with `MockupApprovalResult(mockupApprovalId: String)` on approval; pops null on back navigation. Consistent with `ArtworkConfirmationScreen` (ADR-103).

5. **Placement checkbox is conditional.** The screen shows 3 checkboxes for t-shirts (design, colour, placement) and 2 for posters (design, colour — placement omitted when `placementType == null`). This is safe because `MerchVariantScreen` does not include `placement` in the `createMerchCart` payload for posters.

**Consequences:**
- `MerchVariantScreen` gains one new optional constructor parameter: `artworkImageBytes: Uint8List?`. `MerchProductBrowserScreen` must be updated to pass this when navigating.
- The "Preview my design" button label in `MerchVariantScreen` state `initial` changes to "Approve & buy". Any widget tests asserting on the old label text must be updated.
- `_generatePreview()` gains a `mockupApprovalId: String` required parameter (or is split into `_navigateToApproval()` + `_generatePreview(String mockupApprovalId)`); the `initial` state button no longer calls `_generatePreview()` directly.
- Firestore `mockup_approvals` subcollection is already covered by the wildcard security rule `match /users/{userId}/{document=**}` (confirmed ADR-100). No Firestore rules changes needed.
- `MockupApproval.variantId` is a `String` — no coercion from int. Consistent with BUG-001 resolution (ADR-099) where all variant IDs are treated as opaque strings.

---

## ADR-106 — M54 Gap Closure: Artwork Bytes Reuse, Confirmation Archival, and UID-Null UX

**Status:** Accepted

**Context:** Three concrete gaps identified after M53 completion:

1. **Timeline card renders empty in `MerchVariantScreen`**: `CardImageRenderer.render()` accepts `List<TripRecord> trips = const []` as a default. When `MerchVariantScreen._generatePreview()` calls it, no trips are threaded in, so the Timeline template renders an empty card. The confirmed artwork bytes (in `widget.artworkImageBytes`) already have trips baked in from the `ArtworkConfirmationScreen` render — reusing them is both correct and avoids a needless re-render.

2. **Orphaned `ArtworkConfirmation` documents**: `ArtworkConfirmationService.archive()` was implemented and tested in M48/M50 but is never called. Each time a user re-confirms with changed params in `CardGeneratorScreen`, the old `_artworkConfirmationId` is silently overwritten, leaving an unarchived document in Firestore.

3. **Silent UID-null failures**: Both `ArtworkConfirmationScreen._onConfirm()` and `MockupApprovalScreen._onApprove()` silently return when `currentUidProvider` is null. The loading spinner stays visible and no feedback is shown — the user has no way to know what happened.

**Decision:**

1. **Reuse `artworkImageBytes` as `clientCardBase64` when template unchanged.** In `MerchVariantScreen._generatePreview()`, if `widget.artworkImageBytes != null` AND `_selectedTemplate == widget.initialTemplate`, set `cardBase64 = base64Encode(widget.artworkImageBytes!)` and skip the `CardImageRenderer.render()` call. The confirmed artwork is the source of truth — it is pixel-identical to what the user approved. If the user changes template, the re-render path proceeds normally. This is a conditional bypass, not a removal of the renderer.

2. **Archive superseded confirmation fire-and-forget.** In `CardGeneratorScreen._goToProductBrowser()`, before overwriting `_artworkConfirmationId` with `result.confirmationId`, check if a prior ID exists and differs. If so, call `ArtworkConfirmationService(FirebaseFirestore.instance).archive(uid, _artworkConfirmationId!)` via `unawaited()` (fire-and-forget). Exceptions are swallowed. Archive failure must not block checkout navigation — it is a housekeeping concern, not a correctness concern.

3. **SnackBar + loading reset on UID null.** Both approval screens replace `if (uid == null || !mounted) return;` with an explicit branch: show `SnackBar('Please sign in to continue')`, reset the loading state flag, and return. This makes the failure visible without requiring a restart or nav action from the user.

**Consequences:**
- `MerchVariantScreen` must import `dart:convert` for `base64Encode`; it already has `widget.artworkImageBytes` and `widget.initialTemplate` in scope (M53).
- `CardGeneratorScreen` must have access to `currentUidProvider` (already used, M51) and `ArtworkConfirmationService` (already imported, M51). If `dart:async` is not already imported, `unawaited` requires it — alternatively `.ignore()` may be used.
- Both approval screens already import `ScaffoldMessenger` via their widget tree; no new dependencies needed.
- The `artworkImageBytes` reuse path produces identical bytes to what was shown in `ArtworkConfirmationScreen` — the confirmed artwork is the product print source of truth.

---

## ADR-107 — M55 Local Product Mockup: Screen Architecture, Inline Re-confirmation, Deferred Printful Mockup, and Poster Handling

**Status:** Accepted

**Context:** The existing commerce navigation sequence (`MerchProductBrowserScreen` → `MerchVariantScreen` → `MockupApprovalScreen`) has four structural problems:

1. **Product image is never shown before checkout.** `MockupApprovalScreen` shows the flat card art, not the card on the product. The user cannot see how their design looks on a t-shirt or poster until after they leave the app to Shopify.
2. **Printful mockup API called too early.** `MerchVariantScreen._generatePreview()` calls `createMerchCart` immediately when the screen loads, triggering a Printful API call before the user has made any product choices. This wastes credits and creates latency before confirmation.
3. **Colour/variant changes restart the full flow.** Any product option change requires popping back through multiple screens.
4. **`artworkImageBytes` threading gap.** `MerchVariantScreen` needed `artworkImageBytes` threaded through two screens (`MerchProductBrowserScreen` → `MerchVariantScreen`) to avoid Timeline re-render emptiness — a brittle prop-drilling pattern across unrelated screens.

**Decision:**

1. **Introduce `LocalMockupPreviewScreen` as a single unified screen** replacing `MerchProductBrowserScreen`, `MerchVariantScreen`, and `MockupApprovalScreen`. All product configuration, mockup preview, and approval happen on one screen. `CardGeneratorScreen._goToProductBrowser()` pushes `LocalMockupPreviewScreen` directly.

2. **On-device compositing with `LocalMockupPainter`.** Bundled product mockup images (PNG) are loaded from the asset bundle by `LocalMockupImageCache` (LRU, 6 entries). `LocalMockupPainter` (`CustomPainter`) composites `ui.Image` (product) + `ui.Image` (artwork bytes) using `spec.printAreaNorm: Rect` (normalised 0.0–1.0 coordinates). No network call is made during configuration. This is entirely local rendering.

3. **Inline re-confirmation when template changes.** When the user changes card template inside `LocalMockupPreviewScreen`, show an amber inline banner ("Design changed — please confirm again") and change the CTA to "Confirm updated design". Do not force navigation back to `ArtworkConfirmationScreen`. Instead, `_onApprove()` creates a new `ArtworkConfirmation` inline (with `archive()` fire-and-forget on the prior ID) before writing `MockupApproval`. Colour, size, and placement changes do NOT invalidate the artwork confirmation.

4. **Printful mockup deferred to `ready` state only.** `createMerchCart` (which triggers the Printful API call) is called exactly once: when the user explicitly taps "Approve this order". The `ready` state then shows `Image.network(mockupUrl)` as the photorealistic preview. The local `CustomPaint` is the `loadingBuilder` fallback — the user always sees something while the network image loads. The remote mockup is not optional; it is always shown in `ready` state before "Complete order →".

5. **Poster: `productImage = null` → edge-to-edge artwork.** For poster products, `LocalMockupPainter` is constructed with `productImage: null`. When `productImage` is null, the painter fills the canvas with a white background and draws the artwork at `spec.printAreaNorm = Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)` (full canvas). No frame or room mockup is rendered for MVP.

6. **Variant GID lookup tables extracted to `lib/features/merch/merch_variant_lookup.dart`.** Both `MerchVariantScreen` and `LocalMockupPreviewScreen` require the same `(MerchProduct, colour, size, placement) → variantGid` mapping. Extract to a single shared file to avoid divergence. `MerchVariantScreen` (deprecated) may delegate to this file or keep its own copy until M56 deletion.

7. **`_lastConfirmedTrips` added to `_CardGeneratorScreenState`.** `filteredTrips` is computed inside `_navigateToPrint()` and currently not persisted to state. Add `List<TripRecord>? _lastConfirmedTrips` and capture the value alongside `_artworkImageBytes` when an `ArtworkConfirmResult` is received. Thread to `LocalMockupPreviewScreen` as `trips:` so template re-renders within the screen use the trip list that corresponds to the confirmed artwork.

**Consequences:**
- `MerchProductBrowserScreen`, `MerchVariantScreen`, and `MockupApprovalScreen` are deprecated (not deleted); deletion is scheduled for M56.
- `LocalMockupPreviewScreen` must implement `WidgetsBindingObserver` for the app-resume poll (same pattern as `MerchVariantScreen`).
- Bundled mockup PNG assets (~11 files, ≤200 KB each) must be registered in `pubspec.yaml`.
- `ProductMockupSpec.printAreaNorm` values must be calibrated against actual image dimensions at native size; a `kDebugMockup` flag should draw a visible debug border during development.
- `LocalMockupImageCache.dispose()` is called from `LocalMockupPreviewScreen.dispose()` to release `ui.Image` objects and avoid memory leaks.
- The `_MockupState` enum (`configuring | rerendering | approving | ready`) is internal to `LocalMockupPreviewScreen` and not persisted to Firestore.

---

## ADR-108 — M56 Celebration Queue: Sequential Navigation via Async Loop

**Status:** Proposed

**Context:** M56-03 requires that when multiple countries are discovered in a single scan, celebrations do not overlap. M56-06 reports that pressing Next can navigate prematurely to the main map before all countries in the queue are shown. M56-07 reports that Skip All does not reliably navigate to the correct destination.

Examining the existing implementation in `scan_summary_screen.dart`: `_pushDiscoveryOverlays()` already drives a sequential loop using `await Navigator.of(context).push(...)` inside a `for` loop, with a `skipped` boolean flag to break early on Skip All. However, three bugs exist:

1. **Early exit bug (M56-06)**: `_pushDiscoveryOverlays()` is capped at `_kMaxOverlays = 5`. The loop `codes = widget.newCodes.take(_kMaxOverlays).toList()` processes at most 5 overlays, but `widget.onDone()` is called after only those 5 complete — causing navigation to the map while remaining countries in the queue are unshown.

2. **Skip All navigation bug (M56-07)**: `onSkipAll` on the final overlay in the 5-cap batch is set to `null`, meaning the last visible overlay has no Skip All button. When Skip All is tapped on a non-final overlay, `skipped = true` breaks the loop and calls `widget.onDone()`, but the `Navigator.of(context).pop()` inside `_handleSkipAll()` pops the overlay before the loop's `await` resumes — this path works correctly. The actual navigation destination failure is a separate issue: `widget.onDone()` at the call site must navigate to the Main Map, not simply return.

3. **No inter-celebration gap**: There is no configurable pause between sequential overlays.

**Decision:**

The existing async `for`-loop + `await push` pattern is the correct structural approach and must not be replaced with a separate queue object or `StreamController`. The pattern is clean, respects `mounted` checks, and avoids shared mutable state across rebuilds.

The three bugs are fixed surgically:

1. **Remove the `_kMaxOverlays = 5` cap.** All countries in `widget.newCodes` are iterated. The `take(5)` guard was a conservative UI decision made in ADR-084 that is now overridden by M56 requirements.

2. **Skip All destination.** The `onSkipAll` callback on every overlay (except the last) clears the queue by setting `skipped = true` and popping. After the loop, `widget.onDone()` is called unconditionally. The caller (`ReviewScreen` / `ScanSummaryScreen`) is responsible for routing `onDone` to the Main Map — this is already the contract. No navigation change is needed inside `_pushDiscoveryOverlays()`.

3. **Inter-celebration gap.** A `Future.delayed(const Duration(milliseconds: 300))` is inserted after each `await push` call within the loop body (before the next iteration), gated by `if (!mounted || skipped) break`. The delay duration is extracted to a top-level constant `kCelebrationGapMs = 300` in `discovery_overlay.dart` so it can be overridden in tests.

No new class, provider, or state object is introduced. The fix is local to `_pushDiscoveryOverlays()` in `scan_summary_screen.dart` and the constant in `discovery_overlay.dart`.

**Consequences:**
- For a user with 15 newly discovered countries, all 15 overlays are shown sequentially; total wait time is approximately 15 × (overlay duration + 300 ms).
- Tests for `_pushDiscoveryOverlays()` must be updated to remove the 5-overlay cap expectation and to verify that all N overlays are shown.
- M56-04 (audio) attaches to `DiscoveryOverlay.initState()` — the sequential loop guarantees only one overlay is mounted at a time, so audio cannot overlap by construction.
- M56-05 (first-visited date) is additive to `DiscoveryOverlay` and does not affect the queue logic.

---

## ADR-109 — M56 Celebration Audio: `audioplayers` Package, App-Layer Only

**Status:** Proposed

**Context:** M56-04 requires a short audio effect to play when a country celebration (`DiscoveryOverlay`) is shown. No audio package currently exists in the project. The mute requirement states that audio must be silent when the device is muted (iOS silent switch / Android volume 0).

Three candidate packages exist for Flutter audio:

- `just_audio`: full-featured streaming player. Appropriate for music playback; has native background audio capabilities. Overkill for a single short SFX clip.
- `audioplayers`: lightweight single-clip playback. Suitable for SFX. Respects the iOS `AVAudioSession` ambient category by default (plays through the mute switch? — no: ambient mode is silenced by the silent switch on iOS). Actively maintained.
- `soundpool`: low-latency pool for short clips. Less widely adopted; API is less ergonomic for single-clip use.

The mute constraint is the deciding factor. On iOS, `AVAudioSession.Category.ambient` is silenced by the hardware mute/silent switch — the correct behaviour for an in-app celebration sound. `audioplayers` defaults to ambient mode on iOS, satisfying the requirement without additional configuration.

**Decision:**

Add `audioplayers: ^6.0.0` (or latest stable at build time) to `apps/mobile_flutter/pubspec.yaml` under `dependencies`. Do not add it to any package — audio is an app-layer concern.

A single bundled audio asset (`assets/audio/celebration.mp3`, ≤ 100 KB, duration < 2 s) is registered in `pubspec.yaml`. The file must be a short positive chime or pop; the specific clip is a Builder decision.

`DiscoveryOverlay._DiscoveryOverlayState.initState()` creates an `AudioPlayer`, calls `player.play(AssetSource('audio/celebration.mp3'))`, and disposes the player in `dispose()`. No provider, no singleton, no shared player state. Each overlay instance owns its own short-lived player. Because ADR-108 guarantees that only one `DiscoveryOverlay` is mounted at a time, concurrent audio playback cannot occur by construction.

No mute-detection code is written. `audioplayers` ambient mode on iOS and the system volume on Android provide the correct mute behaviour automatically.

**Consequences:**
- `audioplayers` adds a native dependency (iOS: AVFoundation; Android: MediaPlayer). The iOS `Podfile.lock` will update.
- `DiscoveryOverlay` gains an `AudioPlayer` field — it must remain `StatefulWidget` (already is).
- Widget tests for `DiscoveryOverlay` that run on the host (non-device) test environment must stub or ignore `AudioPlayer` initialisation. Tests should set `AudioPlayer.global.setLogLevel(LogLevel.none)` and wrap the play call in a try/catch to avoid `MissingPluginException` in host tests.
- The Builder must verify the asset path is consistent in both `pubspec.yaml` and the `AssetSource` call.

---

## ADR-110 — M56 Incremental Scan State: `lastScanAt` is the Boundary Marker

**Status:** Proposed

**Context:** M56-13 requires that after the first full scan, subsequent scans process only newly added images. M56-14 adds a UI control for incremental vs full scan. M56-15 auto-triggers an incremental scan on app open.

The scan pipeline already has partial infrastructure for this:

- `ScanMetadata.lastScanAt` (nullable TEXT, ISO 8601) is stored in the Drift `scan_metadata` table (schema v8). It is written by `scan_screen.dart` after a scan completes.
- `startPhotoScan({DateTime? sinceDate})` in `photo_scan_channel.dart` passes `sinceDate` to the Swift PhotoKit bridge, which filters `PHAsset.creationDate > sinceDate`. This is the incremental boundary (ADR-012).
- The `photo_date_records` Drift table stores `assetId` per scanned photo (added in a prior migration), providing an alternative deduplication mechanism.

**Decision:**

`lastScanAt` in `ScanMetadata` is the sole scan boundary marker for incremental scans. Its semantics are:

- `null` → no full scan has ever completed; incremental scan must not be offered or auto-triggered.
- Non-null ISO 8601 string → the UTC timestamp at which the most recent scan (full or incremental) completed. The next incremental scan passes this value as `sinceDate` to `startPhotoScan`.

**What constitutes "scanned"**: a photo is considered scanned if its `capturedAt` date is ≤ `lastScanAt` at the time the scan was initiated. Photos added to the library after `lastScanAt` are "new" and will be included in the next incremental scan. The PhotoKit `sinceDate` predicate uses asset `creationDate`; this matches `capturedAt` (which is derived from `PHAsset.creationDate`).

**Persistence**: `lastScanAt` is updated in `ScanMetadata` at the end of every successful scan (full or incremental), to the UTC `DateTime.now()` captured immediately before the scan starts (pre-scan timestamp, not post-scan, to avoid a race where photos taken during the scan are silently skipped on the next incremental pass).

**Full scan trigger**: when a full scan is requested (M56-14 or first-time scan), `sinceDate` is omitted from `startPhotoScan`. On completion, `lastScanAt` is written as normal. No additional state is needed to distinguish "full scan completed" from "incremental scan completed" — both update `lastScanAt`.

**Duplicate detection**: because `sinceDate` filters on `PHAsset.creationDate`, and `lastScanAt` is set to the pre-scan timestamp, any photo processed in the prior scan cannot appear in the next incremental scan. The `assetId` deduplication in `photo_date_records` remains as a defence-in-depth guard against clock skew or edge cases.

**Auto-trigger (M56-15)**: `AppLifecycleListener.onResume` (or `WidgetsBindingObserver.didChangeAppLifecycleState`) in `scan_screen.dart` checks `lastScanAt != null` and, if true, calls the incremental scan path. A boolean `_scanInProgress` guard prevents duplicate launches.

**Consequences:**
- No Drift schema migration is required — `lastScanAt` and `assetId` already exist.
- `ScanMetadata` must expose a `hasCompletedFirstScan` getter: `lastScanAt != null`. This is used by M56-15 auto-trigger and M56-14 UI.
- The Builder must verify that the pre-scan timestamp is captured before `startPhotoScan()` is awaited, not after.
- `sinceDate` already flows through the Swift bridge; no native code changes are needed for the incremental path.
- A full scan triggered from M56-14 clears no existing visit data — it re-processes all photos and merges results. Duplicate country detections are suppressed by the existing `upsert` semantics in `VisitRepository` and `TripRepository`.

---

## ADR-111 — M56 Pastel Region Colour Palette: Static Ordered List, Index-Mod Assignment

**Status:** Proposed

**Context:** M56-11 requires that regions in `CountryRegionMapScreen` are filled using a pastel colour palette with at least 12 distinct colours, cycling if a country has more than 12 regions, and with adjacent regions visually distinguishable where practical.

The current implementation uses two hardcoded colours: amber `_kVisitedFill` for visited regions and dark navy `_kUnvisitedFill` for unvisited regions. The task replaces the visited-region fill with a per-region pastel colour.

**Decision:**

A static constant list `kRegionPastelPalette` of exactly 12 `Color` values is defined in `lib/features/map/country_region_map_screen.dart`. The colours are desaturated mid-tones chosen to:

- Remain legible against the dark navy `_kOceanBackground`.
- Avoid conflict with the amber brand colour used for the app's "visited" highlight state.
- Be perceptually distinct from each other at typical map zoom levels.

The 12 colours are assigned to regions by index: `kRegionPastelPalette[regionIndex % 12]`. `regionIndex` is the 0-based position of the region in the sorted list returned by `RegionRepository.loadByCountry(countryCode)`. Sorting is alphabetical by `regionCode` (ISO 3166-2), which is deterministic and stable across rebuilds.

No graph-colouring algorithm is applied. Index-mod assignment does not guarantee that spatially adjacent regions receive different colours, but with 12 colours and typical region counts (≤ 30 for most countries), adjacent conflicts are rare and acceptable for an MVP pastel map.

The exact 12 colour values are a Builder decision. The constraint is: each colour must have HSL lightness ≥ 0.60 (pastel range) and saturation ≤ 0.55, and all 12 must be visually distinct when rendered at ≥ 30×30 px.

Unvisited regions retain the existing `_kUnvisitedFill` (dark navy). Only visited region fills change.

**Consequences:**
- `CountryRegionMapScreen` is the only file that changes for this task. No new file, no new provider.
- `kRegionPastelPalette` is a top-level constant, accessible with `@visibleForTesting` for the widget test that verifies 12+ region countries produce 12 distinct fill colours.
- If `RegionRepository.loadByCountry` returns regions in a non-deterministic order, the palette assignment will be unstable across rebuilds. The sort-by-`regionCode` step is therefore load-bearing and must be explicit in the implementation.
- Selection state (tapped region label) must remain visually distinct from the pastel fills — the existing amber `MarkerLayer` label is unaffected.
- The ADR does not define the 12 colour values — this is a Builder decision, constrained by the HSL bounds above.

---

## ADR-112 — M56 Card Design Image Consistency: Single Pre-Render and Deterministic Param Threading

**Status:** Accepted

**Context:** When a user selects and configures a card design in `CardGeneratorScreen` (template, orientation, year filter, entryOnly, heart order), tapping "Print your card" previously navigated to `ArtworkConfirmationScreen`, which triggered a fresh `CardImageRenderer.render()` call. For non-deterministic templates (Heart/randomized flag order, Passport with stamp scatter/rotation) and for templates with explicit user-controlled params (`entryOnly`, `aspectRatio`), this produced a different image than the one the user had been viewing and configuring. The user was confirming — and potentially purchasing — something different from what they selected.

Additionally, `CardImageRenderer._cardWidget()` ignored `entryOnly`, `aspectRatio`, `heartOrder`, and `dateLabel` entirely, so every call to the renderer used defaults regardless of what was configured.

**Decision:**

1. **Extend `CardImageRenderer.render()` and `_cardWidget()`** to accept and thread `entryOnly`, `cardAspectRatio`, `heartOrder`, and `dateLabel` to all template widgets. This makes every render call parametrically deterministic for a given set of inputs.

2. **Pre-render in `CardGeneratorScreen`**: when the user taps "Print your card", `_navigateToPrint()` calls `CardImageRenderer.render()` with the exact current state (`entryOnly`, `_aspectRatio`, `_heartOrder`, `dateLabel`) before pushing `ArtworkConfirmationScreen`. The `_printing` flag prevents double-taps and disables both action buttons during the render. On render failure, `preRender` is `null` and the flow falls back to in-screen rendering.

3. **`ArtworkConfirmationScreen` accepts `preRenderedResult: CardRenderResult?`**: if non-null, the screen sets `_result` and `_rendering = false` in `initState` without calling `_startRender()`. The user sees and confirms exactly the image that was pre-rendered. If null (fallback path), `_startRender()` is called as before, now passing `entryOnly` and `cardAspectRatio` for correctness.

4. **`LocalMockupPreviewScreen` receives `confirmedAspectRatio` and `confirmedEntryOnly`** from `CardGeneratorScreen`. When the user changes template inside the mockup screen, `_onTemplateChanged()` re-renders with `forPrint: true` for passport, `cardAspectRatio: widget.confirmedAspectRatio`, and `entryOnly: false` (template change resets to entry+exit).

5. **`_CardParams` includes `heartOrder`** so the same-params re-confirmation shortcut (ADR-103) correctly detects when the heart order has changed and requires re-confirmation.

**Consequences:**

- The pre-render adds a brief loading delay when "Print your card" is tapped (spinner shown inside the button). For typical stamp counts on target devices this is sub-second.
- Heart/randomized layouts are now deterministic within a single print flow: the pre-rendered layout is what gets confirmed. The user cannot see the "live" randomized layout and a "different" confirmation layout simultaneously.
- `CardImageRenderer` public API gains four optional named parameters with sensible defaults; all existing call sites without these params continue to compile and produce equivalent output (defaults match prior implicit behaviour for grid).
- Passport template re-renders inside `LocalMockupPreviewScreen` now correctly include print-safe margins.
- The fallback path (pre-render throws) preserves the prior behaviour for robustness; no user-visible failure mode is introduced.

---

## ADR-113 — M57 Passport Stamp Density and Preview Consistency

**Status:** Accepted

**Context:** `PassportLayoutEngine` capped stamp output at 20, producing one stamp per trip with alternating entry/exit labels. Users with 50+ trips expected a distinct entry stamp and exit stamp per trip. Additionally, the live card preview in `CardGeneratorScreen` used `forPrint=false` and was unconstrained in width, while `CardImageRenderer` renders at exactly 340 logical pixels with `forPrint=true` — producing visually different stamp sizes, margins, and positions in the preview and confirmation screens.

**Decision:**

1. **Two stamps per trip (entry + exit):** `PassportLayoutEngine._buildEntries()` now emits two `_StampEntry` records per `TripRecord` when `entryOnly=false`: entry (date = `startedOn`) then exit (date = `endedOn`). `StampData.fromTrip()` gains an optional `stampDate` parameter to support this. When `entryOnly=true`, only the entry stamp is emitted (unchanged).

2. **Cap raised to 200:** `_kMaxStamps` increased from 20 to 200. With 50 trips × 2, total stamps = 100 — well within the new cap.

3. **Dynamic stamp radius:** `baseRadius = 38 × √(min(1, 20/n))` clamped to `[6, 38]` px. For ≤ 20 stamps this equals 38 px (unchanged). Beyond 20 the radius scales down smoothly so stamps remain individually visible while fitting the canvas. Per-stamp ±10% size variety is preserved in non-print mode.

4. **Dynamic grid:** `gridCols` and `gridRows` scale with stamp count and canvas aspect ratio so cells distribute evenly across both landscape and portrait canvases.

5. **Relaxed collision threshold:** Minimum placement distance lowered from 80% to 50% of combined radii, allowing organic overlapping at high stamp counts. Best-effort fallback is unchanged.

6. **`wasForced` threshold lowered to 8 px** (consistent with the new 6 px minimum radius).

7. **Preview consistency:** `CardGeneratorScreen._buildTemplate()` passes `forPrint=true` to `PassportStampsCard` so margin and radius logic match the renderer. The preview `InteractiveViewer` is wrapped in `ConstrainedBox(maxWidth: 340)` so `PassportLayoutEngine` receives the same canvas width as `CardImageRenderer`.

**Consequences:**

- Users with many trips now see all stamps — at visually smaller but readable sizes — rather than a silent 20-stamp cap.
- Entry and exit stamps for the same trip show distinct dates (`startedOn` vs `endedOn`), making the passport metaphor more accurate.
- The live preview and the "Confirm your artwork" image are now pixel-consistent for passport cards.
- For cards with ≤ 20 trips, stamp size is unchanged (38 px); the visual difference is only apparent at higher trip counts.
- The `_buildEntries` extraction makes the layout loop cleaner and removes the interleaved `tripIdx`/`codeIdx` coupling.

---

## ADR-114 — M58 2.5D T-Shirt Mockup: Asset Format, Flip Animation, and Screen Layout

**Status:** Accepted

**Context:** `LocalMockupPreviewScreen` uses ten 600×800 RGB PNG placeholder images for all shirt mockups. The mockup area shares screen space equally with an options panel, leaving insufficient room for the user to appreciate the design. Switching front/back requires tapping a text chip; there is no swipe gesture or flip animation; there is no zoom.

**Decision:**

1. **Asset format — RGBA PNG at 1200×1600.** Replace all ten `assets/mockups/tshirt_*.png` files with 1200×1600 RGBA (transparent alpha channel) images with a proper shirt silhouette shape. Transparent background allows the canvas background colour to show through the shirt edges without a rectangular cut-off artefact. The same aspect ratio (3:4) is preserved so `LocalMockupPainter`'s existing `BoxFit.cover` logic continues to work. `printAreaNorm` coordinates are recalibrated to the new layout.

2. **Full-screen layout.** `LocalMockupPreviewScreen`'s body switches to a `Column` where the mockup `Expanded` widget takes all available space minus a fixed-height bottom bar (≈ 80 px) and the action button. Options are moved into a `DraggableScrollableSheet` anchored below the compact strip. The compact strip shows only the colour swatch row and a "More options" drag handle. This gives the mockup ~80% of the visible viewport. The `Approve / Complete` button remains outside the sheet so it is always reachable.

3. **`_ShirtFlipView` StatefulWidget.** Extracted to own the `AnimationController` (duration 350 ms, `Curves.easeInOut`), `GestureDetector` (horizontal drag), and `Transform` widget. It accepts `frontShirt`, `backShirt`, `frontSpec`, `backSpec`, `frontArtwork`, `backArtwork`, `showFront`, and `onFlipped`. The perspective transform uses `Matrix4.rotationY(angle)` with `matrix.setEntry(3, 2, 0.001)`. At the 90° midpoint (`controller.value >= 0.5`) the displayed face swaps, so the correct shirt image appears as the card "comes around." `LocalMockupPreviewScreen` listens to `onFlipped` and updates `_placement` to keep `_resolvedVariantGid` (checkout) in sync.

4. **Colour swatch picker.** The Colour `ChoiceChip` row is replaced with 32 px diameter filled `InkWell` circles. Selected swatch has a 2 px `colorScheme.primary` outline. The five hard-coded colour values (Black, White, Navy, Heather Grey, Red) are defined as constants in the screen file. Tapping a swatch calls the existing `_onVariantOptionChanged`.

5. **Zoom + pan.** The mockup canvas inside `_ShirtFlipView` is wrapped in `InteractiveViewer` (`minScale: 1.0, maxScale: 4.0`). A `TransformationController` is owned by `_ShirtFlipView`; double-tap resets it to identity. The controller is reset (`_transformationController.value = Matrix4.identity()`) whenever `onFlipped` fires or the parent notifies a colour change via a `key` change.

**Consequences:**

- `LocalMockupPainter` is unchanged; the compositing logic works the same at any asset size because it normalises coordinates via `printAreaNorm`.
- `ProductMockupSpecs.printAreaNorm` values must be re-calibrated for the new shirt layout; the debug overlay (`debugPrintArea: true`) can be used to verify calibration visually.
- The `_ShirtFlipView` widget is private to `local_mockup_preview_screen.dart`; no new public API.
- `MockupApprovalScreen` and `createMerchCart` are unchanged.
- The `InteractiveViewer` reset-on-flip ensures users cannot get lost at high zoom when switching sides.

---

## ADR-115 — M59 Photoreal Shirt Mockup: Split-Image Source Cropping and 3-Layer Fabric Compositing

**Status:** Accepted

**Context:**
M58 replaced 600×800 RGB placeholder images with programmatically generated 1200×1600 RGBA shirt silhouettes. While correctly shaped, these silhouettes lack photorealism — no fabric texture, no folds, no wrinkles. A single photoreal asset (`shirt-mockup-final.jpg`, 1600×1066) has been provided, with the front view on the left half and the back view on the right half.

Two decisions are needed: (1) how to address front/back from a single source image, and (2) how to composite artwork so it looks embedded rather than pasted on top.

**Decision 1 — Source cropping via `srcRectNorm` on `ProductMockupSpec`:**
Add an optional `Rect? srcRectNorm` field to `ProductMockupSpec`. When set, `LocalMockupPainter` uses only that normalised sub-rectangle of the source image when drawing the shirt background. Front specs use `Rect.fromLTWH(0.0, 0.0, 0.5, 1.0)` (left half); back specs use `Rect.fromLTWH(0.5, 0.0, 0.5, 1.0)` (right half). Null means use the full image (backward compatible with the poster spec).

This avoids splitting the image at load time (no extra `ui.Image` allocation) and keeps the entire cropping policy declarative in the spec.

**Decision 2 — 3-layer fabric-embedding compositing in `LocalMockupPainter`:**
Replace the single artwork layer + inner shadow with three layers:
1. Shirt background (cropped via `srcRectNorm`, BoxFit.cover).
2. Artwork at 0.92 opacity (BoxFit.contain inside print area), clipped to print area.
3. Shirt shading overlay: the same shirt image drawn again, cropped to print area, at 0.25 opacity with `BlendMode.multiply`. This reapplies the fabric folds and shadows over the artwork, creating the "embedded" effect.

The inner shadow from M58 is removed — the shading overlay subsumes it and looks more natural.

**Decision 3 — Single JPG shared for all colour variants:**
All five colour variants (Black, White, Navy, Heather Grey, Red) reference `shirt-mockup-final.jpg`. The colour swatch picker continues to function (it controls the Printful order colour), but the in-app preview shows the same photoreal shirt for all swatches. Per-colour photo assets are deferred to a future milestone.

**Consequences:**
- `ProductMockupSpec` gains one nullable field; all call sites are backward compatible.
- `LocalMockupPainter.paint()` gains one additional `drawImageRect` call (the shading overlay); performance impact is negligible for a single `CustomPaint`.
- The screen loads one image (the JPG) instead of two (front + back PNGs), halving asset load time.
- The preview colour will not match the swatch selection until per-colour photo assets are added. This is a known limitation accepted for M59.

---

## ADR-117 — M61 Passport Card Refinement: Safe Zones, Color Customization, and Rendering Consistency

**Status:** Accepted

**Context:**
Milestone 61 addresses design inconsistencies and layout issues in the Passport-style card. Key issues include:
1. Stamps overlapping text areas or leaving too much blank space on some screens.
2. Background appearing with a green tint instead of pure white/transparent.
3. Text rendering artifacts (underlines) and inconsistency between preview and confirmation screens.
4. Lack of user customization for stamp/date colors.
5. Inconsistent layout density between the generator screen and checkout flow.

**Decisions:**

**1. Explicit Safe Zones in `PassportLayoutEngine`:**
The layout engine will now enforce two safe zones where no stamps can be placed:
- **Title Safe Zone (Top):** The top 18% of the card height. This area is reserved for the centered title.
- **Branding Safe Zone (Bottom-Left):** A 110x40 logical pixel area (scaled by DPI) at the bottom-left corner. This area is reserved for the "Roavvy" wordmark and country count.
Stamps that intersect these zones will be rejected during the layout pass, ensuring zero overlap with text.

**2. Unified Layout Parameters & Scaling:**
To guarantee identical layout across all screens:
- All screens (Generator, Confirmation, Mockup) MUST use the exact same `Uint8List` bytes generated by the initial `CardImageRenderer.render()` call.
- The `CardGeneratorScreen` preview will be constrained to the same aspect ratio and logical width (340px) as the final print renderer to ensure the `PassportLayoutEngine` produces identical results.
- No re-rendering is allowed in `ArtworkConfirmationScreen` or `MerchVariantScreen` unless the user explicitly changes a design parameter (template, color, text).

**3. User-Configurable Stamp and Date Colors:**
`CardGeneratorScreen` will provide UI controls for:
- `stampColor`: A choice of 6 ink families or a "Multi-color" (randomized) mode.
- `dateColor`: Option to match the stamp color or use a fixed secondary ink.
These preferences are passed to `PassportStampsCard` and used by `StampPainter`.

**4. Pure White / Transparent Background:**
`PaperTexturePainter` is updated to remove the warm parchment tint (`0xFFF5ECD7`) when `transparentBackground` is true. For mobile display, the background will default to the app's surface color (pure white). The generated PNG for print will have a fully transparent alpha channel.

**5. Integrated Text Rendering (No Overlays):**
All text (Title and Branding) will be drawn directly onto the `Canvas` within the `PassportStampsCard`'s `CustomPainter` pass. This eliminates "underline" artifacts caused by Flutter's default `Text` widget inheritance in some `Material` contexts and ensures text is part of the flattened image.

**6. Editable Title Text:**
The auto-generated title (e.g., "12 Countries · 2024") can be overridden by the user in `CardGeneratorScreen`. The custom string is passed to the layout engine to calculate centered positioning within the top safe zone.

**Consequences:**
- `PassportLayoutEngine` signature changes to include safe zone definitions.
- `CardGeneratorScreen` state expanded to include `titleOverride`, `stampColor`, and `dateColor`.
- `PassportStampsCard` gains `CustomPainter` logic for Title and Branding.
- Visual density will be high and consistent because the same image is scaled rather than re-laid out.
- Underline artifacts will be eliminated as standard `Text` widgets are replaced by `TextPainter.paint()` calls.

---

## ADR-118 — M61 GridMathEngine: aspect-ratio-aware tile sizing

**Status:** Accepted

**Context:**
`gridTileSize(double canvasArea, int n)` computes tile size as `sqrt(area / n) * 0.85`, clamped to [28, 90] px. This formula uses total canvas area, which means portrait (2:3) and landscape (3:2) cards with the same flag count produce identical tile sizes but different grid geometries — portrait gets too many columns for its width, or too few rows for its height, leaving blank space or causing overflow. The formula also has no concept of `cols`, so the grid always wraps based on available width at render time, producing non-deterministic layouts when the card is rendered at different widths.

**Decision:**
Replace `gridTileSize()` with `gridLayout(Size canvasSize, int n) → GridLayout` in a new `grid_math_engine.dart` file.

`GridLayout` is a value type: `{int cols, int rows, double tileSize, int overflow}`.

Algorithm:
1. If `n == 0` or canvas has zero area, return `GridLayout.empty`.
2. `cols = max(1, (sqrt(n * canvasSize.width / canvasSize.height)).ceil())`
3. `tileSize = (canvasSize.width / cols).clampDouble(28.0, 90.0)`
4. `rows = (n / cols).ceil()`
5. `overflow = max(0, n - 40)` (max 40 tiles displayed, same as before)

`gridTileSize()` in `card_templates.dart` is kept as a thin delegate to `gridLayout()` for backward compatibility with any tests that call it directly.

`GridMathEngine` is a library-private name; `gridLayout()` is the public function; the file is annotated `@visibleForTesting` on the function for direct test access.

**Consequences:**
- Portrait and landscape orientations now produce different `cols` values for the same flag count, correctly filling the card area.
- `GridFlagsCard` can use `gridLayout()` with the actual `BoxConstraints` size from `LayoutBuilder`, giving a fully deterministic layout at any render width.
- `grid_tile_size_test.dart` is superseded by `grid_math_engine_test.dart` and deleted.
- No change to the maximum-40-flags cap or overflow indicator.

---

## ADR-119 — M61 GridFlagsCard: SVG flag images via shared FlagImageCache

**Status:** Accepted

**Context:**
`GridFlagsCard` currently renders flags as emoji text via `FlagTileRenderer._drawEmoji()`. Emoji flags vary wildly across OS versions and devices, and print poorly. `HeartFlagsCard` already renders real SVG flag images via `FlagTileRenderer.loadSvgToCache()` + `FlagTileRenderer.renderFromCache()` using a static shared `FlagImageCache`. The SVG assets and renderer are already bundled (from M46). `GridFlagsCard` should use the same infrastructure.

Two sub-problems exist:
1. `GridFlagsCard` is a `StatelessWidget` — it cannot hold async state or trigger reloads on code changes.
2. `CardImageRenderer.render()` has an `assetsCompleter` gate only for the passport template — off-screen rendering for grid would capture the emoji fallback before SVGs load.

**Decision:**

**1. `GridFlagsCard` becomes a `StatefulWidget`:**
- State holds a `static final FlagImageCache _sharedCache = FlagImageCache()` (mirrors `_HeartPainter._sharedCache`).
- `initState()` calls `_loadImages()` which fires `FlagTileRenderer.loadSvgToCache()` for each code at the current tile size; on each completion it calls `setState()` to repaint.
- `didUpdateWidget()` calls `_loadImages()` if `countryCodes` or aspect ratio changed.
- A `VoidCallback? onAssetsLoaded` constructor parameter is added; it is called once all codes have loaded (or are already cached), mirroring `PassportStampsCard.onAssetsLoaded`.
- Rendering uses `LayoutBuilder` → `gridLayout()` → `CustomPaint` with a new `_GridPainter` that calls `FlagTileRenderer.renderFromCache()` per tile. Emoji fallback is provided automatically by `renderFromCache()` when the cache miss occurs.

**2. `CardImageRenderer.render()` gates grid capture on `onAssetsLoaded`:**
- A `Completer<void>? assetsCompleter` is created for `CardTemplateType.grid` in the same way it is created for `CardTemplateType.passport`.
- `_cardWidget()` passes `onAssetsLoaded` to `GridFlagsCard` when the completer is non-null.
- `render()` awaits `assetsCompleter.future.timeout(const Duration(seconds: 10))` before scheduling the capture frame, same as passport.

**Consequences:**
- Grid card always shows real SVG flag images in rendered PNGs (no emoji in print output).
- `FlagImageCache` is shared across `GridFlagsCard` instances; SVGs loaded for the heart card are reused by the grid card at the same tile size, and vice versa.
- The 10-second timeout in `CardImageRenderer` is the safety valve if an SVG fails to decode; a partial (emoji-fallback) image is captured rather than hanging indefinitely.
- `GridFlagsCard` widget tests must use `tester.pumpAndSettle()` or pump multiple frames to allow async image loads.

---

## ADR-120 — M61 Shared editable title across Grid, Heart, and Passport templates

**Status:** Accepted

**Context:**
`_CardGeneratorScreenState` holds `String? _titleOverride` and `_CardParams` includes `titleOverride` in its equality check. However, `_titleOverride` is only displayed in the UI when the passport template is selected (`_PassportCustomizer` widget), and only forwarded to `PassportStampsCard` in `_cardWidget()`. Grid and Heart cards have no `titleOverride` parameter and no editing UI.

The M61 backlog scope says: "Shared title editing: centralise the editable title state so it can be applied to Grid, Passport, and Heart cards uniformly."

**Decision:**

**1. Extract `_TitleEditor` from `_PassportCustomizer`:**
The title `TextField` portion of `_PassportCustomizer` is extracted into a private `_TitleEditor` stateless widget accepting `{String? titleOverride, ValueChanged<String?> onTitleChanged, int countryCount, String dateLabel}`. `_PassportCustomizer` is updated to embed `_TitleEditor` at its top. The stamp/date color pickers and background toggle remain inside `_PassportCustomizer` unchanged (passport-only controls).

**2. Show `_TitleEditor` for all three editable templates:**
The template-controls section of `CardGeneratorScreen` shows `_TitleEditor` for `CardTemplateType.grid`, `CardTemplateType.heart`, and `CardTemplateType.passport`. `_titleOverride` state is shared — switching templates preserves the user's entered title (one title, not per-template).

**3. `GridFlagsCard` and `HeartFlagsCard` gain `titleOverride: String?`:**
When non-null, `titleOverride` is passed to `CardBrandingFooter` as a new optional `customLabel: String?` parameter. `CardBrandingFooter` renders `customLabel` in place of the `"{N} countries"` default when `customLabel` is non-null and non-empty.

**4. `CardImageRenderer._cardWidget()` forwards `titleOverride` to all templates:**
Grid and Heart branches in `_cardWidget()` now pass `titleOverride` to their respective widgets. `_CardParams` already includes `titleOverride` in equality — no change needed there.

**Consequences:**
- `CardBrandingFooter` gains one nullable parameter (`customLabel`); all existing call sites pass no argument (default null) and are unaffected.
- `_PassportCustomizer` becomes slightly shorter; `_TitleEditor` is a net-new private widget.
- A single shared `_titleOverride` value covers all three templates — if the user switches from Grid to Heart, their title is preserved. This is the intended UX ("shared title").
- `CardImageRenderer` now correctly embeds the user's title in Grid and Heart off-screen renders, making the confirmed artwork match the on-screen preview.

---

## ADR-120 — M63 Sync Front + Back T-Shirt Images with Shopify + Printful

**Status:** Accepted

**Context:**
Milestone 63 requires the merch flow to fully support sending **both** a front chest ribbon design and a back travel card design to Printful for t-shirt orders. Currently, only a single image is supported, and there are bugs where Printful ignores the selected shirt size and color (defaulting to white).

**Decisions:**

**1. Dual-Placement Request Model:**
- The backend `CreateMerchCartRequest` will accept `frontImageBase64` and `backImageBase64`, deprecating `clientCardBase64`.
- `MerchConfig` will store two storage paths and URLs for front and back print files.
- The `generatePrintfulMockup` function will send an array of multiple `placements` (`front` and `back`) to Printful's `/v2/mockup-tasks` endpoint, returning an object with `frontMockupUrl` and `backMockupUrl`.
- The Printful Order creation (`POST /v2/orders` in `shopifyOrderCreated`) will send both placements in the line item configuration.

**2. Printful Variant ID Fix:**
- The bug causing white shirts and incorrect sizes is due to incorrect or missing `printfulVariantId` mappings. `apps/functions/src/printDimensions.ts` must be updated with the exact Printful variant IDs for all 25 size/color combinations of the selected t-shirt product (e.g., Gildan 64000).

**3. Mobile Mockup UX:**
- `LocalMockupPreviewScreen` will decode both `frontMockupUrl` and `backMockupUrl` from `CreateMerchCartResponse`.
- The `_ShirtFlipView` will display the respective mockup URL based on the current flip side (front or back).

**Consequences:**
- The payload size for `CreateMerchCartRequest` will increase due to two Base64 images.
- Printful API integration will be more complex but correctly handle two-sided printing.
- Manual verification of Printful variant IDs is required.
