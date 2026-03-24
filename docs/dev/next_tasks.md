# M35 — Trip Region Map

**Milestone:** 35
**Phase:** Mobile Experience Depth
**Status:** Not started

**Goal:** Tapping a trip in the Journal opens a full-screen country map — styled identically to the main map — with the regions visited on that trip highlighted in amber. Unvisited regions of that country are shown in the dark navy style.

---

## Scope

**Included:**
- `packages/region_lookup`: expose `regionPolygonsForCountry(countryCode)` public API returning all `RegionPolygon`s for a country; export `RegionPolygon` from the package barrel
- `RegionRepository`: add `loadRegionCodesForTrip(TripRecord)` — queries `photo_date_records` by `countryCode` + `capturedAt` date range → distinct `regionCode` values
- `TripMapScreen`: full-screen `FlutterMap` showing the country with region polygons; visited regions amber (matching main map depth-colour style); unvisited regions dark navy; map auto-fits to the country bounding box; app bar with country flag emoji + country name + trip date range
- `JournalScreen`: trip card tap navigates to `TripMapScreen` (replaces current `CountryDetailSheet` modal)

**Excluded:**
- Tapping a region polygon for drill-down detail
- Editing the trip from `TripMapScreen`
- World-level map or multi-country view
- Web version
- CountryDetailSheet changes (the sheet is still accessible from the map screen if needed in future)

---

## Tasks

### Task 123 — Expose region polygon API in `packages/region_lookup`

**Deliverable:**
- `RegionPolygon` class exported from `region_lookup.dart` (currently internal to `src/binary_format.dart`)
- New public function `regionPolygonsForCountry(String countryCode)` added to `region_lookup.dart`
- Returns all `RegionPolygon`s where `regionCode.startsWith('$countryCode-')` (e.g. `'GB'` returns all `'GB-*'` polygons)
- `initRegionLookup` must have been called first (same guard as `resolveRegion`)

**Acceptance criteria:**
- `regionPolygonsForCountry('GB')` returns a non-empty list of `RegionPolygon`s
- `regionPolygonsForCountry('XX')` returns an empty list (unknown country)
- `RegionPolygon` is importable from `package:region_lookup/region_lookup.dart`
- `flutter analyze` zero issues on the package
- Existing `resolveRegion` tests still pass

---

### Task 124 — Add `RegionRepository.loadRegionCodesForTrip`

**Deliverable:**
- New method `Future<List<String>> loadRegionCodesForTrip(TripRecord trip)` on `RegionRepository`
- Queries `photo_date_records` where `countryCode == trip.countryCode` and `capturedAt BETWEEN trip.startedOn AND trip.endedOn`
- Returns distinct non-null `regionCode` values

**Acceptance criteria:**
- Returns only region codes whose photos fall within the trip date range for the correct country
- Returns empty list when no region-tagged photos exist for the trip
- Unit test: insert photo records with known dates; verify correct region codes returned for a trip spanning those dates

**Notes:**
- Pattern mirrors `VisitRepository.loadAssetIdsByDateRange` (Task 108, ADR-083) — same Drift query approach with `isBetweenValues` on `capturedAt`
- `photo_date_records` already has `regionCode` column (schema v7)

---

### Task 125 — `TripMapScreen`

**Deliverable:**
- New screen `lib/features/map/trip_map_screen.dart`
- Full-screen `FlutterMap` (same `MapOptions` as `MapScreen`: dark navy `Color(0xFF0D2137)` background, `interactionOptions` with pan/zoom enabled)
- Two `PolygonLayer`s:
  - Visited regions: amber fill using `depthFillColor(1)` (single-visit tier `Color(0xFFD4A017)`) + no border
  - Unvisited regions: fill `Color(0xFF1E3A5F)` (main map unvisited style) + no border
- Map auto-fits to the country bounding box on init (derived from min/max of all region polygon vertices for the country)
- `AppBar` shows `'${flagEmoji(trip.countryCode)}  ${countryName(trip.countryCode)}'` as title; subtitle shows trip date range formatted as "Mar 2023 – Apr 2023"
- Loading state: `CircularProgressIndicator` while region polygons and visited codes are being fetched

**Acceptance criteria:**
- Screen renders without error for any `TripRecord`
- Visited region polygons are amber; unvisited are dark navy
- Map is centred on the country when the screen opens (no manual pan required)
- Countries with zero detected regions show only a blank dark navy map area (no crash)
- `flutter analyze` zero issues

**Notes:**
- `depthFillColor` is already defined in `CountryPolygonLayer` — extract to a shared location or duplicate for now (extract preferred)
- `flagEmoji` and `countryName` helpers already exist in the app; locate and reuse
- Bounding box: `LatLngBounds.fromPoints(allVertices)` → `mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(24)))`

---

### Task 126 — Wire `TripMapScreen` from `JournalScreen`

**Deliverable:**
- `JournalScreen` trip card `onTap` pushes `TripMapScreen` as a full-screen route (replaces the `showModalBottomSheet` call to `CountryDetailSheet`)

**Acceptance criteria:**
- Tapping a trip card in the Journal navigates to `TripMapScreen` for that trip
- Back button returns to the Journal
- `flutter analyze` zero issues; existing Journal tests pass

---

## Dependencies

```
Task 123 (region_lookup polygon API)
    └─ Task 125 (TripMapScreen — needs polygon data)

Task 124 (loadRegionCodesForTrip)
    └─ Task 125 (TripMapScreen — needs visited region codes)

Tasks 123 + 124 + 125 complete
    └─ Task 126 (wire navigation)
```

---

## Risks / Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| `RegionPolygon.vertices` is `List<(double, double)>` — `flutter_map` `Polygon` expects `List<LatLng>` | Certain | Convert in `TripMapScreen`: `vertices.map((v) => LatLng(v.$1, v.$2)).toList()` |
| Some countries have many regions (US: 50, RU: 80+) — polygon count may be high | Medium | `flutter_map` handles 50–100 polygons efficiently; no optimisation needed for PoC |
| Countries with no region data (micro-states) show blank map | Accepted | Empty list from `regionPolygonsForCountry` → empty layers; no crash, acceptable UX |
| `depthFillColor` is currently private in `CountryPolygonLayer` | Low | Move to a shared `map_colors.dart` file in the same feature directory |
| Trip date range spans midnight boundaries — photo `capturedAt` is UTC | Low | Same issue as Task 108 (trip photo filtering); consistent with existing approach |
