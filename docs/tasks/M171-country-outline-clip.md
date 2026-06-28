# M171 — Country Outline Clip

**Status:** `backlog`
**Created:** 2026-06-28
**Depends on:** M170 (clip shape infrastructure in `GridFlagsCard`)

---

## Product Rationale

The single most distinctive design a traveller can wear is a shirt where the flags of the countries they have visited are arranged inside the shape of a country they love. An Australian user sees their flags clipped to the continent outline of Australia. A Japan fan sees flags cropped to the iconic islands. A Europe traveller sees flags within the outline of France.

This turns a generic "flag grid" into a personalised piece of geography. No other merch app offers this. It is the premium "wow" feature of the grid template.

---

## Scope

### What is delivered

- Country outline path data for all 195 UN-recognised states, bundled as app assets
- `CountryPathService` that loads, scales, and caches a Flutter `Path` for any country code
- Integration into the `GridClipShape.countryOutline` variant introduced in M170
- UX to select *which* country's outline to use when multiple countries are in the design
- Graceful fallback (circle) if a path cannot be loaded

### What is explicitly out of scope

- Sub-national shapes (US states, Australian states, etc.) — future milestone
- Custom drawn shapes — future milestone
- SVG rendering of the country name alongside the outline — future milestone
- Animated path drawing / reveal — future milestone

---

## UX Design

### Single-country selection

If the user has one country selected, "Country outline" automatically uses that country's shape. No further input needed.

### Multi-country selection

When 2+ countries are selected, a secondary picker appears below the clip shape row:

```
┌──────────────────────────────────────────┐
│  Clip to which country?                  │
│                                          │
│  [🇦🇺 Australia ▾]                       │
│                                          │
│  (shows a scrollable list of all         │
│   countries in the user's selection,     │
│   sorted alphabetically)                 │
└──────────────────────────────────────────┘
```

Default selection: the country with the most visits in the user's selection, as a proxy for "most loved". Ties broken alphabetically.

### Preview

The clip shape picker tile for "Country outline" updates its schematic thumbnail live as the user picks a country, showing a tiny version of that outline filled with flag tiles.

### Fallback

If a country's outline cannot be loaded within 500 ms (cold-start first frame), the render falls back to circle clip and shows a non-blocking toast: "Shape unavailable — using circle". This is expected only in edge cases (corrupted bundle, unusual country codes).

---

## Architecture

### Country path data pipeline

**Source:** Natural Earth 10m cultural vectors (public domain, ne_10m_admin_0_countries)

**Pipeline (run offline, output committed):**

```
scripts/build_country_paths.py
  Input:  ne_10m_admin_0_countries.geojson
  Steps:
    1. For each feature, extract the dominant polygon (largest by area)
       to avoid scattered island chains producing a poor clip
    2. Simplify with Ramer-Douglas-Peucker (ε = 0.15°) to reduce point count
    3. Normalise to a 1000×1000 unit space (origin at bounding box centre)
    4. Serialize as JSON: {"w": 1000, "h": 800, "pts": [[x,y], ...]}
       (separate arrays for each sub-polygon of multi-part countries)
  Output: assets/country_paths/{iso2_lowercase}.json
```

**Bundle size:** ~200 files × ~3 KB average = ~600 KB uncompressed. After gzip compression in the IPA this is ~150 KB. Acceptable.

**Multi-polygon handling (islands, exclaves):**

Some countries have meaningful multi-part shapes (Greece + islands, Indonesia, Philippines). Strategy:
- If largest polygon ≥ 80% of total area → use only largest polygon
- Otherwise → use union of all polygons (may produce disconnected clip regions, which is visually interesting)
- User can switch between "mainland only" and "all territories" via a toggle (default: mainland only)

### `CountryPathService`

```dart
class CountryPathService {
  static final _cache = <String, ui.Path>{};

  /// Loads and scales the outline path for [code] to fill [targetSize].
  /// Returns null if the asset does not exist.
  static Future<ui.Path?> pathFor(String code, Size targetSize) async { ... }

  /// Preloads paths for all codes in [codes] into the cache.
  static Future<void> preload(List<String> codes) async { ... }
}
```

Paths are stored in normalised 1000-unit space and scaled on load via a `Matrix4` fit-inside transform. Cached by `"${code}_${targetSize.width.round()}x${targetSize.height.round()}"` key to handle different card aspect ratios.

### Integration with M170 clip infrastructure

`GridClipShape.countryOutline` in `GridFlagsPainter._clipPathFor()` calls:

```dart
final path = await CountryPathService.pathFor(clipCountryCode, size);
return path ?? _circlePath(size); // fallback
```

Because loading is async and `paint()` is synchronous, the path must be pre-loaded before the paint cycle. `GridFlagsCard` preloads in `initState` (or `didUpdateWidget`) and stores the loaded `ui.Path` in state, triggering a repaint when ready.

### New state in `LocalMockupPreviewScreen`

```dart
String? _clipCountryCode; // null = auto (most-visited in selection)
```

When `_clipShape == GridClipShape.countryOutline`, the artwork renderer receives `clipCountryCode: _clipCountryCode ?? _autoClipCountry()`.

### New params in `CardImageRenderer.render()`

```dart
String? clipCountryCode,   // only used when clipShape == countryOutline
```

---

## Asset pipeline

### Offline script

`scripts/build_country_paths.py` — not bundled in the app, run by developers when source data updates. Output JSON files committed to `assets/country_paths/`.

### `pubspec.yaml` asset registration

```yaml
assets:
  - assets/country_paths/
```

### Data quality

Known problem countries (review manually during pipeline run):
- `ru` — very large; only western polygon to avoid huge bounds
- `us` — Alaska + Hawaii need conscious choice
- `fr` — mainland only (exclude DOM/TOM)
- `cl` — extremely narrow; may need aspect ratio padding
- `no` — fjord-heavy coastline; increase simplification ε to 0.3°

A QA review step in the pipeline flags any polygon with > 800 points after simplification for manual inspection.

---

## Tasks

### T1 — Offline path pipeline

**Files:** `scripts/build_country_paths.py`, `assets/country_paths/*.json`

- Write Python script using `shapely` + `fiona` to read Natural Earth GeoJSON
- Implement dominant-polygon selection (area-based)
- Implement Ramer-Douglas-Peucker simplification (ε = 0.15°)
- Normalise to 1000×1000 unit space
- Serialize to JSON format and write `assets/country_paths/{code}.json`
- Manual QA pass on problem countries listed above
- Commit all 195 country JSON files

### T2 — `CountryPathService`

**Files:** `lib/features/cards/country_path_service.dart`

- Implement async loader from bundle asset
- Parse JSON → `List<List<Offset>>` (sub-polygons)
- Build `ui.Path` combining all sub-polygons via `Path.combine` or sequential `moveTo/lineTo`
- Scale path to target `Size` using bounding box fit-inside transform
- LRU cache by `"${code}_${w}x${h}"` key
- `preload(List<String> codes)` for preloading before paint cycle
- Unit tests: parse known country file, verify path is non-empty, bounding box within target

### T3 — `GridFlagsCard` async path loading

**Files:** `card_templates.dart`

- Add `clipCountryCode: String?` param to `GridFlagsCard` constructor
- In state `initState` / `didUpdateWidget`: call `CountryPathService.preload([clipCountryCode])` when clip mode is `countryOutline`
- Store loaded `ui.Path?` in state; trigger `setState` on load
- Pass path to painter; painter uses it in `_clipPathFor()`

### T4 — Country picker UI in customisation sheet

**Files:** `merch_customisation_sheet.dart` (or `local_mockup_preview_screen.dart`)

- `_CountryOutlinePicker` widget: visible only when `_clipShape == countryOutline`
- Scrollable dropdown / modal sheet listing countries from `widget.selectedCodes`, sorted alphabetically, with flag emoji + name
- Default selection: `_autoClipCountry()` = country with most trip records in selection
- On change: update `_clipCountryCode` state → triggers artwork re-render (debounced 400 ms)
- "Mainland only" toggle if selected country has multi-polygon outline (stored as metadata in JSON)

### T5 — Clip shape picker: enable country outline tile

**Files:** `merch_customisation_sheet.dart`

- Remove "Coming soon" disabled state from country outline tile (M170 T4 added it)
- Tile thumbnail now shows a live schematic of the selected country's outline

### T6 — Integration, fallback, and Printful payload

**Files:** `merch_option_list_widgets.dart`, `local_mockup_preview_screen.dart`

- Thread `clipCountryCode` through carousel → `LocalMockupPreviewScreen`
- Include `clipCountryCode` in Printful `createMerchCart` metadata for traceability
- Fallback: if `CountryPathService.pathFor()` returns null, use circle + show toast
- Log path load failures to Crashlytics

### T7 — `flutter analyze` clean + manual test matrix

- Analyze: no new issues
- Manual tests:
  - Single-country selection → correct country auto-selected
  - Multi-country → default auto pick is most-visited
  - Switching countries updates preview within 400 ms
  - Multi-polygon country (Greece) renders both mainland + islands
  - "Mainland only" toggle for multi-polygon country
  - Fallback to circle on path load failure (test by temporarily removing one asset)
  - Printful photorealistic mockup generated correctly with country clip

---

## Definition of Done

- [ ] All 195 country JSON path files committed to `assets/country_paths/`
- [ ] `CountryPathService` loads, scales, and caches paths with < 16 ms on warm cache
- [ ] Country outline clip renders in carousel preview and `LocalMockupPreviewScreen`
- [ ] Single-country: auto-selects that country; multi-country: picker defaults to most-visited
- [ ] "Mainland only" toggle functional for island/exclave countries
- [ ] Fallback to circle + non-blocking toast when path unavailable
- [ ] Country outline tile in clip shape picker no longer shows "Coming soon"
- [ ] `clipCountryCode` included in Printful cart metadata
- [ ] `flutter analyze` no new issues
- [ ] IPA size increase ≤ 200 KB (compressed country path assets)

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Country outlines look ugly at shirt print scale (too complex / too simple) | Medium | High | QA test on physical print mockup before release; adjust ε per-country |
| Asset bundle size exceeds target | Low | Medium | gzip all files; exclude dependencies-only countries (e.g. VAT, SJM) |
| `CountryPathService` blocks first paint | Low | Medium | Always preload before navigating to card; show spinner if not ready |
| Narrow/elongated countries (Chile, Norway) fill poorly | Medium | Medium | Pad bounding box to minimum aspect ratio before normalisation |
| Natural Earth data accuracy disputes | Low | Low | Use only for decorative clip, not authoritative borders; add disclaimer |
