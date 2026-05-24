# M119 — UNESCO World Heritage Site Detection & Achievements

**Status:** Not started

## Goal

When Roavvy scans photo locations, detect whether any photo was taken at or near a UNESCO World Heritage Site. Show visited sites as map markers, record visits offline, and unlock a new tier of heritage achievements.

The feature is entirely offline and privacy-first: the UNESCO dataset is preprocessed into a bundled app asset; no external API is called during scanning.

---

## Architecture Overview

The feature follows existing Roavvy patterns exactly:

- **Preprocessing tool** (run once by a developer, not at runtime): downloads/reads the UNESCO GeoJSON, strips to required fields, writes `whs_sites.json` into `assets/geodata/`.
- **`WorldHeritageLookupService`**: loaded at app startup from the bundled JSON, indexed as `Map<String, List<WorldHeritageSite>>` by ISO country code for O(1) candidate filtering.
- **Scan integration**: after each batch is resolved to country codes, WHS lookup runs in the main scan loop using raw photo GPS coordinates (not bucketed). Country-first filtering limits candidates to ~5–30 sites per lookup.
- **`HeritageRepository`**: Drift table `VisitedHeritageSites`, keyed on `siteId`, upserted on each scan.
- **`WorldHeritageMarkerLayer`**: new `MarkerLayer` added to `MapScreen` for visited sites only.
- **9 new achievements** in `kAchievements`; `AchievementEngine.evaluate()` extended with heritage site counts.

---

## Data Model

### Bundled Asset: `whs_sites.json`

One record per site. Approximately 1,200 records, ~150 KB total.

```json
{
  "siteId": "211",
  "name": "Minaret and Archaeological Remains of Jam",
  "countryCode": "AF",
  "latitude": 34.396,
  "longitude": 64.516,
  "category": "cultural",
  "region": "Asia and the Pacific",
  "inscriptionYear": 2002
}
```

Fields map directly from `whc001`: `id_no` → `siteId`, `name_en` → `name`, `iso_codes` → `countryCode` (first code for transboundary sites), `category` lowercased, `region`, `date_inscribed` → `inscriptionYear`.

Transboundary sites (spanning multiple countries): indexed once per country code so they are discoverable from any member country.

### `WorldHeritageSite` (shared_models)

```dart
class WorldHeritageSite {
  final String siteId;
  final String name;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String category; // "cultural" | "natural" | "mixed"
  final String region;
  final int inscriptionYear;
}
```

### `WhsMatch` (internal, not persisted)

Returned by `WorldHeritageLookupService.findNearby()`:

```dart
class WhsMatch {
  final WorldHeritageSite site;
  final double distanceKm;
  final String confidence; // "strong" (≤2 km) | "nearby" (≤10 km)
}
```

### `VisitedHeritageSite` (shared_models + Drift)

```dart
class VisitedHeritageSite {
  final String siteId;
  final String name;
  final String countryCode;
  final String category;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int photoCount;
  final String confidence; // strongest confidence ever seen
  final double nearestDistanceKm; // closest photo ever matched
}
```

---

## Matching Strategy

**Thresholds (ADR-163):**
- `strong`: ≤ 2 km — photo is clearly within or at the site
- `nearby`: ≤ 10 km — photo is in the vicinity
- Ignored: > 10 km

**Algorithm (per photo GPS record):**
1. Use the already-resolved `countryCode` from the batch result to fetch candidate sites (O(1) map lookup).
2. Run haversine distance for each candidate (typically 5–30 per country).
3. Accept the nearest match ≤ 10 km. If multiple sites qualify, take the closest.
4. Transboundary sites: discoverable regardless of which member country's code was resolved.

**Why raw GPS, not bucketed (ADR-163):** The 0.5° bucket (≈55 km) used for country/region lookup is far too coarse for WHS matching. WHS lookup uses raw `lat`/`lng` from `PhotoGpsRecord`. Country-first filtering keeps the candidate set small enough that no additional bucketing is needed.

**Why JSON, not binary (ADR-164):** The dataset is ~1,200 records. JSON parsing at startup takes < 50 ms and produces a small in-memory index. The custom binary format used for country/region polygons (100k+ vertices) is unnecessary here.

---

## Scope In

- `tools/preprocess_whs/` — Dart CLI preprocessing script
- `assets/geodata/whs_sites.json` — bundled offline dataset (~1,200 sites)
- `packages/shared_models/lib/src/world_heritage_site.dart` — `WorldHeritageSite`, `WhsMatch`, `VisitedHeritageSite`
- `lib/features/heritage/world_heritage_lookup_service.dart` — load + index + haversine lookup
- `lib/main.dart` — initialize `WorldHeritageLookupService` at startup
- `lib/data/db/roavvy_database.dart` — `VisitedHeritageSites` Drift table
- `lib/data/heritage_repository.dart` — CRUD: `upsertAll()`, `loadAll()`, `loadByCountry()`
- `lib/features/scan/scan_screen.dart` — WHS lookup wired into post-batch loop; new discovery accumulation; post-scan upsert; batched discovery toast
- `lib/features/map/world_heritage_marker_layer.dart` — `MarkerLayer` for visited WHS pins on `MapScreen`
- `lib/features/map/map_screen.dart` — add `WorldHeritageMarkerLayer`
- `lib/features/heritage/heritage_detail_sheet.dart` — tap sheet: name, country, category, inscription year, first visit date, photo count
- `packages/shared_models/lib/src/achievement.dart` — 9 new WHS achievements in `kAchievements`
- `packages/shared_models/lib/src/achievement_engine.dart` — evaluate WHS achievements; `evaluate()` signature extended
- `lib/features/scan/scan_screen.dart` — pass heritage site counts into `AchievementEngine.evaluate()`
- `pubspec.yaml` — register `assets/geodata/whs_sites.json`

## Scope Out

- Polygon/boundary matching (point + radius only for MVP)
- City-level or admin1-level heritage filtering
- Memory Pulse integration for heritage sites
- Country detail screen WHS summary (future polish)
- Trip detail screen WHS callout (future polish)
- Web app WHS features
- Firestore sync for visited heritage sites (local-only for MVP)

---

## Tasks (build order)

### Part 1 — Data & Preprocessing

**Task 1: Preprocessing script**

Create `tools/preprocess_whs/main.dart` — a Dart CLI script:
- Reads a locally downloaded `whc001.geojson` file (passed as arg or hardcoded path)
- Extracts: `id_no`, `name_en`, `iso_codes` (split on `,` → multiple entries for transboundary), `coordinates` (lat/lng), `category` (lowercase), `region`, `date_inscribed`
- Normalises `category`: maps `"Cultural"` → `"cultural"`, `"Natural"` → `"natural"`, `"Mixed"` → `"mixed"`
- For transboundary sites, emits one record per country code (same siteId)
- Skips records with null coordinates or null iso_codes
- Writes `apps/mobile_flutter/assets/geodata/whs_sites.json` as a JSON array

**Task 2: Generate asset and register**

- Run the preprocessing script against the downloaded UNESCO GeoJSON
- Verify output (~1,200+ records, all fields populated)
- Add `assets/geodata/whs_sites.json` to the `flutter` → `assets` section of `pubspec.yaml`

---

### Part 2 — Models

**Task 3: Shared models**

In `packages/shared_models/lib/src/world_heritage_site.dart`:
- `WorldHeritageSite` (immutable, `==`/`hashCode` on `siteId`)
- `WhsMatch` (site + distanceKm + confidence string)
- `VisitedHeritageSite` (full persisted record)
- `parseWhsSitesJson(String json)` → `List<WorldHeritageSite>` (top-level helper)

Export from `shared_models` barrel.

---

### Part 3 — Storage

**Task 4: Drift table**

In `lib/data/db/roavvy_database.dart`, add table `VisitedHeritageSites`:

| Column | Type | Notes |
|---|---|---|
| `siteId` | TEXT PRIMARY KEY | UNESCO `id_no` as string |
| `name` | TEXT | |
| `countryCode` | TEXT | |
| `category` | TEXT | "cultural" / "natural" / "mixed" |
| `firstSeen` | DATETIME | |
| `lastSeen` | DATETIME | |
| `photoCount` | INTEGER | |
| `confidence` | TEXT | "strong" / "nearby" |
| `nearestDistanceKm` | REAL | |

Regenerate Drift generated code.

**Task 5: HeritageRepository**

`lib/data/heritage_repository.dart`:
- `upsertAll(List<VisitedHeritageSite> sites)` — for each site: insert new or merge with existing (take min `firstSeen`, max `lastSeen`, sum `photoCount`, take strongest `confidence`, take min `nearestDistanceKm`)
- `loadAll()` → `List<VisitedHeritageSite>`
- `loadByCountry(String countryCode)` → `List<VisitedHeritageSite>`
- `loadVisitedCount()` → `int`
- `loadVisitedCountByCategory()` → `Map<String, int>` (keyed by category)

---

### Part 4 — Lookup Service

**Task 6: WorldHeritageLookupService**

`lib/features/heritage/world_heritage_lookup_service.dart`:

```dart
class WorldHeritageLookupService {
  // Singleton; call init() once at startup
  static void init(String jsonString);

  // Find matching WHS for a single GPS point
  // Returns null if no site within 10 km
  static WhsMatch? findNearest(double lat, double lng, String countryCode);

  // Bulk lookup for a batch of GPS records; returns one match per photo (or null)
  static List<WhsMatch?> findBatch(List<PhotoGpsRecord> records);
}
```

Internals:
- Parse JSON → `Map<String, List<WorldHeritageSite>>` (country code → sites list)
- Haversine distance function (pure Dart, no external package)
- `findBatch`: iterate records, get candidates by `countryCode`, check haversine for each candidate, return nearest ≤ 10 km or null
- Transboundary sites appear under multiple country keys; dedup in `findBatch` by `siteId`

**Task 7: Startup initialization**

In `lib/main.dart`, after existing geodata init:
- `final whsJson = await rootBundle.loadString('assets/geodata/whs_sites.json');`
- `WorldHeritageLookupService.init(whsJson);`

No provider override needed (service is a static singleton, same pattern as `initCountryLookup`).

---

### Part 5 — Scan Integration

**Task 8: Wire WHS lookup into scan pipeline**

In `lib/features/scan/scan_screen.dart`, inside `_scan()`, in the per-batch loop after `_resolveBatch()` returns a `BatchResult`:

```dart
// WHS lookup (main isolate — fast in-memory, no isolate needed)
final whsMatches = WorldHeritageLookupService.findBatch(batchResult.photoGps);
_accumulateWhsMatches(whsMatches, _whsAccum);
```

`_whsAccum` is `Map<String, VisitedHeritageSite>` (keyed by siteId), accumulated across all batches.

`_accumulateWhsMatches`: for each non-null match, merge into `_whsAccum`:
- If new siteId: create `VisitedHeritageSite` from match
- If existing: merge (min firstSeen from photoGps timestamp, sum photoCount, take strongest confidence, take min distanceKm)

Post-scan (before navigation):
- `await heritageRepo.upsertAll(_whsAccum.values.toList())`
- Compute newly discovered site IDs (sites in `_whsAccum` that were not in pre-scan `loadAll()` set)
- Store newly discovered list for discovery toast + achievement eval

**Task 9: Discovery toast**

After scan completes, before pushing `ScanSummaryScreen`, if `_newlyDiscoveredSites.isNotEmpty`:
- Show a lightweight `SnackBar` or bottom sheet:
  > "World Heritage Site found — [Name]" (if 1 site)
  > "[N] World Heritage Sites found" (if multiple)
- Non-blocking; auto-dismisses after 4 seconds
- Does not interrupt large scan progress

---

### Part 6 — Map

**Task 10: WorldHeritageMarkerLayer**

`lib/features/map/world_heritage_marker_layer.dart` (ConsumerWidget):
- Watches a new `visitedHeritageProvider` (FutureProvider from `HeritageRepository.loadAll()`)
- Renders `MarkerLayer` with one `Marker` per visited site
- Marker widget: small filled circle with a monument/heritage icon (use `Icons.account_balance` or a custom SVG if available), white icon on gold background, 28×28 dp
- Visible at all zoom levels (markers are small enough)
- `onTap`: call `showHeritageDetailSheet(context, site)`

**Task 11: Wire into MapScreen**

In `lib/features/map/map_screen.dart`, add `WorldHeritageMarkerLayer()` as the top-most layer in the `FlutterMap` children stack (renders above country polygons, below any future overlays).

Does NOT add to `GlobeMapWidget` (globe mode deferred).

**Task 12: HeritageDetailSheet**

`lib/features/heritage/heritage_detail_sheet.dart` — `showHeritageDetailSheet(context, VisitedHeritageSite site)`:

Bottom sheet content:
- Site name (headline)
- Category pill (Natural / Cultural / Mixed) with colour coding: Natural = green, Cultural = amber, Mixed = teal
- Country name + flag
- Inscription year: "UNESCO Listed [year]"
- First visited: formatted date
- Photo count: "[N] photos"
- Achievement status if applicable (e.g. "Unlocked: Natural Wonder")

---

### Part 7 — Achievements

**Task 13: 9 new achievements in kAchievements**

Add to `packages/shared_models/lib/src/achievement.dart` under a new `AchievementCategory.heritageSites`:

Count-based (6):
| ID | Title | Target |
|---|---|---|
| `whs_1` | First Heritage Site | 1 |
| `whs_5` | Heritage Explorer | 5 |
| `whs_10` | Heritage Hunter | 10 |
| `whs_25` | Heritage Enthusiast | 25 |
| `whs_50` | Heritage Scholar | 50 |
| `whs_100` | World Heritage Legend | 100 |

Category-based (3) — target: 1 site of each type:
| ID | Title | Filter |
|---|---|---|
| `whs_natural_1` | Natural Wonder | 1+ natural site |
| `whs_cultural_1` | Cultural Explorer | 1+ cultural site |
| `whs_mixed_1` | Mixed Heritage | 1+ mixed site |

**Task 14: Extend AchievementEngine.evaluate()**

Current signature:
```dart
Set<String> evaluate(List<EffectiveVisitedCountry> visits, {int tripCount, int thisYearCountryCount})
```

Extended signature (ADR-166):
```dart
Set<String> evaluate(
  List<EffectiveVisitedCountry> visits, {
  int tripCount,
  int thisYearCountryCount,
  int heritageCount = 0,
  Map<String, int> heritageByCategory = const {},
})
```

Logic:
- Count-based: unlock `whs_N` achievements where `heritageCount >= N`
- Category-based: unlock `whs_natural_1` if `heritageByCategory['natural'] >= 1`, etc.

**Task 15: Wire heritage counts into post-scan achievement eval**

In `lib/features/scan/scan_screen.dart`, post-scan:
```dart
final heritageCount = await heritageRepo.loadVisitedCount();
final heritageByCategory = await heritageRepo.loadVisitedCountByCategory();
final unlocked = AchievementEngine.evaluate(
  visits,
  tripCount: trips.length,
  thisYearCountryCount: thisYear,
  heritageCount: heritageCount,
  heritageByCategory: heritageByCategory,
);
```

---

### Part 8 — QA & Edge Cases

**Task 16: Edge cases**

Verify handling of:
- Sites with null or zero coordinates in source data → skipped by preprocessor
- Photos near coastal WHS (point may be offshore) → 10 km threshold handles reasonable proximity
- Transboundary sites (e.g. Pyrenees-Mont Perdu, ES+FR): indexed under both `ES` and `FR`; `siteId` dedup in `findBatch` ensures one `WhsMatch` per site per photo, not one per country
- Multiple nearby sites (e.g. Rome historic centre near several WHS clusters): return nearest only
- Sites with `iso_codes` containing multiple values (e.g. `"DE, FR"`): preprocessor splits and emits one record per code with the same `siteId`; dedup in `HeritageRepository.upsertAll()` by `siteId` (one row per site, not per country)
- Incremental scan rediscovering already-visited sites: `upsertAll` merges cleanly; `lastSeen` and `photoCount` updated, `firstSeen` preserved
- Full scan: pre-scan snapshot of `loadAll()` taken before scan starts for new-discovery diffing
- Photos with no GPS (`lat == null`) already excluded from `PhotoGpsRecord` list; WHS lookup never receives them

**Task 17: Performance validation**

- Scan 10,000 photo library; confirm WHS lookup adds < 200 ms total to scan duration
- Verify `WorldHeritageLookupService.init()` completes < 100 ms on cold start
- Verify `HeritageRepository.upsertAll()` for 50 sites completes < 50 ms

---

## Acceptance Criteria

- [ ] `tools/preprocess_whs/main.dart` runs cleanly and produces `whs_sites.json` with ~1,200+ records
- [ ] `whs_sites.json` bundled as app asset; loads at startup with no errors
- [ ] `WorldHeritageLookupService.findNearest()` returns correct match for known WHS coordinates
- [ ] `WorldHeritageLookupService.findNearest()` returns null for coordinates > 10 km from any WHS
- [ ] Scanning photos taken at a known WHS records a `VisitedHeritageSite` row
- [ ] Incremental scan updates `lastSeen`/`photoCount` without duplicating rows
- [ ] Full scan re-evaluates all WHS but does not reset `firstSeen`
- [ ] Global map shows monument icons for all visited WHS
- [ ] Tapping a WHS marker opens `HeritageDetailSheet` with correct data
- [ ] `whs_1` achievement unlocks after first WHS detected
- [ ] Count achievements unlock at correct thresholds (5, 10, 25, 50, 100)
- [ ] Category achievements unlock when first natural/cultural/mixed site is visited
- [ ] Transboundary sites are discoverable from any member country
- [ ] No network calls during scanning or map rendering
- [ ] `flutter analyze` passes with no new errors
- [ ] Scan of 10,000-photo library adds < 200 ms overhead

---

## ADR

**ADR-163:** WHS lookup uses raw photo GPS coordinates (from `PhotoGpsRecord`), not 0.5° bucketed values. The bucket size (~55 km) is orders of magnitude too coarse for WHS matching; sites can be < 1 km across. Country-first candidate filtering (O(1) map lookup) limits the haversine candidate set to ~5–30 sites, making raw-coordinate lookup performant without bucketing.

**ADR-164:** WHS dataset bundled as plain JSON (`whs_sites.json`) rather than a custom binary format. The ~1,200-record dataset is approximately 150 KB; JSON parse time is < 50 ms. The binary format used for country/region polygon data (100k+ vertices) is unnecessary for a small point dataset.

**ADR-165:** WHS match confidence (`strong` ≤ 2 km, `nearby` ≤ 10 km) is stored per visited site. On subsequent scans, only the strongest observed confidence is kept (e.g. if a user later gets a photo closer to the centroid, confidence upgrades from `nearby` to `strong`). This allows future UI differentiation without requiring a rescan.

**ADR-166:** `AchievementEngine.evaluate()` accepts two new optional parameters (`heritageCount`, `heritageByCategory`) with default values of `0` / `const {}`. This preserves backward compatibility with all existing call sites. Heritage achievement evaluation is additive — it does not modify the logic for any existing achievement category.
