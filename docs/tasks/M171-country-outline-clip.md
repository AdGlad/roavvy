# M171 — Country & Continent Outline Clip

**Status:** `complete`
**Created:** 2026-06-28
**Updated:** 2026-06-29
**Depends on:** M170 (clip shape infrastructure in `GridFlagsCard`)

---

## Product Rationale

Two premium clip shapes that tie the design directly to geography:

**Country outline** — for single-country designs. The flags fill the exact shape of that country. A Japan shirt is clipped to the islands of Japan. An Australia shirt fills the continent. This is only offered when one country is selected, where it is unambiguous and visually powerful.

**Continent outline** — for continent-scoped collection designs (e.g. "Europe", "Asia"). The flags of all visited countries in that continent fill the silhouette of the continent. This is only offered when the design originates from a continent-scoped collection.

In both cases the flags must fully fill the interior of the outline — no empty space — and the title sits outside the shape below it.

No other merch product offers either of these. They are the defining "wow" features of the platform.

---

## Scope

### What is delivered

- Country outline paths for all 195 UN-recognised states, bundled as app assets
- Continent outline paths for 6 continents (Africa, Asia, Europe, North America, Oceania, South America)
- `CountryPathService` loading, scaling, and caching Flutter `Path` objects
- `CountryOutlineClipper` integrating with M170's `GridClipShape.countryOutline` and `GridClipShape.continentOutline`
- Country outline: automatically applied when `selectedCodes.length == 1`; no picker needed
- Continent outline: automatically applied from the collection's continent label; no picker needed
- Graceful fallback (circle) if a path fails to load

### What is explicitly out of scope

- Sub-national shapes (US states, Australian states) — future
- Custom drawn shapes — future
- Per-country selection when multiple countries are selected — not supported; outline is always unambiguous
- Animated path reveal — future

---

## UX Design

### Integration with M170's swipe carousel

M171 appends new pages to the `FlagShapeCustomiseScreen` `PageView` introduced in M170. No new screen or picker is introduced — the user simply swipes further right to reach the outline shapes.

**Full page order after M171:**

| Page | Shape | Label | Condition |
|---|---|---|---|
| 0 | `none` | Grid | Always |
| 1 | `heart` | Heart | Always |
| 2 | `circle` | Circle | Always |
| 3 | `countryOutline` | e.g. "Japan" | `codes.length == 1` only |
| 4 | `continentOutline` | e.g. "Europe" | Continent collection only |

Pages 3 and 4 are conditionally included in the page list at build time.

### Country outline page

Only present when `codes.length == 1`. The page label shows the country name. No picker — there is only one country and it is used automatically.

The `_ClipVariantCard` for this page shows a loading spinner until `CountryPathService` delivers the path, then renders the full mockup. The preload is started in `_DesignCard._navigate()` before pushing `FlagShapeCustomiseScreen`, so in practice the path is ready by first paint.

### Continent outline page

Only present when the design originates from a continent-scoped collection (`continentKey != null`). The page label shows the continent name. The continent path is preloaded alongside the country path.

### Fill guarantee

Flags tile across the full bounding rectangle; the clip path discards out-of-bounds pixels at the GPU layer. No empty space inside the outline at any zoom level.

### Title placement

Title and branding are rendered after `canvas.restore()` removes the clip. They appear below the shape silhouette, never inside the outline.

### Fallback

If a path fails to load (timeout or bundle error), the `_ClipVariantCard` renders with circle clip and shows a non-blocking inline message below the mockup: "Shape unavailable — showing circle instead". Logs to Crashlytics.

---

## Architecture

### Country path data

**Source:** Natural Earth 50m cultural vectors (`ne_50m_admin_0_countries`) — public domain.

50m resolution (one point per ~3.75 km) is sufficient for shirt print quality and produces significantly smaller, cleaner files than 10m. Use 10m only for countries with feature-defining fine detail (Japan, Greece, Indonesia) — specified per-country in the pipeline config.

**Pipeline (offline script, output committed):**

```
scripts/build_country_paths.py
  Input:  ne_50m_admin_0_countries.geojson  (+ ne_10m overrides for specific codes)
  Steps:
    1. For each feature, select polygons:
         - If largest polygon area ≥ 80% of total → use only largest polygon (mainland)
         - Otherwise → use all polygons (recognisable island chains: JP, GR, ID, PH, NZ, FJ)
    2. Simplify with Ramer-Douglas-Peucker (ε = 0.08 for 10m overrides, ε = 0.05 for 50m)
       Flag polygon if > 600 points post-simplification for manual review
    3. Normalise: fit to 1000 × N unit space preserving aspect ratio
       (width always 1000; height computed from bounding box)
       Minimum height: 400 (prevents extremely narrow countries like Chile from producing
       a thin sliver; pad with transparent space)
    4. Serialize: {"w": 1000, "h": <height>, "polys": [[[x,y], ...], ...]}
       Each inner array is one polygon/island ring
  Output: assets/country_paths/{iso2_lowercase}.json

  Build metadata: assets/country_paths/_meta.json
    {"source": "ne_50m_admin_0_countries", "built": "2026-06-28", "count": 195}
```

**Bundle size estimate:** ~195 files × ~1.5 KB average (50m) = ~300 KB uncompressed, ~70 KB compressed in IPA.

### Continent path data

Continent outlines are **not** derived from unioning country paths at runtime — too slow and produces ugly shared borders. Instead they are pre-computed by the same pipeline from a separate Natural Earth dataset (`ne_50m_admin_0_map_subunits` dissolved by continent).

```
Output: assets/continent_paths/{continent_key}.json
  Keys: africa, asia, europe, north_america, oceania, south_america
```

The 6 continent paths are ~3 KB each uncompressed.

### `CountryPathService`

```dart
class CountryPathService {
  static const int _maxCacheEntries = 40;
  static final LinkedHashMap<String, ui.Path> _cache = LinkedHashMap();

  /// Returns a Flutter Path for [code] scaled to [targetSize].
  /// [code] is an ISO 3166-1 alpha-2 code (country) or a continent key.
  /// Returns null on load failure.
  static Future<ui.Path?> pathFor(String code, Size targetSize) async { ... }

  /// Preloads and caches paths for [codes] before they are needed.
  /// Call from _DesignCard._navigate() before pushing LocalMockupPreviewScreen.
  static Future<void> preload(List<String> codes, Size targetSize) async { ... }
}
```

**Cache key:** `"${code}_${targetSize.width.round()}x${targetSize.height.round()}"`
**Eviction:** LRU; when size exceeds 40, remove the oldest entry.
**Path construction:** each `polys` array becomes a separate moveTo/lineTo sequence on the same `ui.Path`. Do NOT use `Path.combine` — add contours directly to one path.

```dart
final path = ui.Path();
for (final poly in data['polys'] as List) {
  final pts = poly as List;
  path.moveTo((pts[0][0] as num).toDouble() * scaleX, ...);
  for (int i = 1; i < pts.length; i++) {
    path.lineTo(...);
  }
  path.close();
}
```

### Integration in `GridFlagsPainter`

`GridClipShape.countryOutline` and `GridClipShape.continentOutline` cases in `_clipPathFor()` use the pre-loaded path from state (not loaded inside `paint()`):

```dart
// In GridFlagsCard state:
ui.Path? _outlinePath;  // set by preload in initState/didUpdateWidget

// In _clipPathFor():
GridClipShape.countryOutline ||
GridClipShape.continentOutline => _outlinePath ?? _circlePath(size),
```

### Context propagation for continent detection

`ShopCollectionOptionScreen` already has the collection label (e.g. "Europe"). This label is passed through to `LocalMockupPreviewScreen` via the `PulseMerchOption` `contextLabel` field, which is already threaded through the carousel. At the customisation sheet level, the continent key is derived: `kLabelToContinent['Europe'] = 'europe'`.

---

## Problem countries — manual QA list

| Code | Issue | Resolution |
|---|---|---|
| `ru` | Extreme east-west span; Siberia dwarfs European Russia | Use mainland polygon only (largest by area) |
| `us` | Alaska + Hawaii disconnected from contiguous US | All three as separate polys; visually interesting |
| `fr` | GeoJSON includes French Guiana as same feature | Filter out non-European polygons by bounding box (lon < 10°) |
| `cl` | 4,300 km long, ~170 km wide | Minimum height pad of 400 units prevents total sliver |
| `no` | Fjord coastline very complex | Use 50m dataset; ε = 0.08 to preserve recognisable shape |
| `ca` | Many islands in north; Hudson Bay interior | Use all polys; Hudson Bay will appear as a void (correct) |
| `gb` | Great Britain + Northern Ireland separate | Both as polys |

---

## Tasks

### T1 — Pipeline environment setup

**Files:** `scripts/requirements.txt`, `scripts/README.md`

- `requirements.txt`: `fiona>=1.9`, `shapely>=2.0`, `pyproj>=3.5`
- `README.md`: setup instructions for macOS (conda recommended), Docker one-liner
- Download and verify Natural Earth 50m source data
- No Dart/Flutter changes in this task

### T2 — Offline path pipeline

**Files:** `scripts/build_country_paths.py`, `assets/country_paths/*.json`, `assets/continent_paths/*.json`

- Implement all pipeline steps (select polygons, simplify, normalise, serialize)
- Per-country override config (10m sources, ε overrides) in `scripts/country_overrides.json`
- QA flag for any polygon with > 600 points post-simplification
- Manual review of all flagged polygons
- Build continent paths from dissolved continent dataset
- Write `_meta.json` with source version and build date
- Commit all output files

### T3 — `CountryPathService`

**Files:** `lib/features/cards/country_path_service.dart`

- Async loader from bundle assets (`rootBundle.loadString`)
- JSON parse → multi-polygon `ui.Path` via direct moveTo/lineTo (not `Path.combine`)
- Scale via fit-inside Matrix4 transform (preserve aspect ratio, centre in targetSize)
- LRU cache (max 40 entries, keyed by code + size)
- `preload(List<String> codes, Size targetSize)` for pre-navigation loading
- Unit tests:
  - Parse a known country JSON, verify path is non-empty
  - Verify bounding box of scaled path fits within targetSize
  - Verify cache eviction at 41st unique entry
  - Verify multi-polygon country produces a single `ui.Path` with multiple contours

### T4 — `GridFlagsCard` outline path loading

**Files:** `card_templates.dart`

- Add `clipCode: String?` param to `GridFlagsCard` (used when `clipShape` is `countryOutline` or `continentOutline`)
- `initState` and `didUpdateWidget`: call `CountryPathService.preload([clipCode], cardSize)` when clip mode requires it
- Store `ui.Path?` in state; `setState` on load to trigger repaint
- Pass stored path to painter; painter uses it in `_clipPathFor()`

### T5 — Conditional carousel pages in `FlagShapeCustomiseScreen`

**Files:** `lib/features/merch/flag_shape_customise_screen.dart`

- Build page list dynamically at screen construction:
  ```dart
  final pages = [
    GridClipShape.none,
    GridClipShape.heart,
    GridClipShape.circle,
    if (codes.length == 1) GridClipShape.countryOutline,
    if (continentKey != null) GridClipShape.continentOutline,
  ];
  ```
- Pass `clipCode` (ISO2 country code or continent key) to `_ClipVariantCard` for outline pages
- Page label for country outline: `kCountryNames[codes.first]` (e.g. "Japan")
- Page label for continent outline: continent display name derived from `continentKey`
- `_ClipVariantCard` for outline pages: shows loading spinner until `CountryPathService` delivers the path, then renders full mockup
- Preload started in `_DesignCard._navigate()` before pushing `FlagShapeCustomiseScreen` so path is ready by first paint

### T6 — Pre-navigation preload

**Files:** `merch_option_list_widgets.dart`

- In `_DesignCard._navigate()`: before `Navigator.push`, call `CountryPathService.preload(...)` with the card size (approximated from screen size)
- Await preload with a max timeout of 800 ms; proceed regardless (fallback is circle)
- Apply same preload in `_AlternativeThumb._navigate()` and `MerchOptionFeaturedCard._navigate()`

### T7 — Continent context propagation

**Files:** `pulse_merch_option.dart`, `shop_collection_option_screen.dart`, `merch_option_list_widgets.dart`

- Add `continentKey: String?` to `PulseMerchOption`
- `ShopCollectionOptionScreen` sets `continentKey` from the collection label when it maps to a continent
- `_DesignCard._navigate()` passes `continentKey` to `LocalMockupPreviewScreen`
- `LocalMockupPreviewScreen` derives `_collectionContinent` from this value

### T8 — `flutter analyze` clean + manual test matrix

- Analyze: no new issues
- Country outline: Japan (multi-polygon), Australia (single polygon), France (DOM/TOM filtered), Chile (narrow padded)
- Continent outline: Europe, Asia, Oceania
- Title always below the shape, never inside
- Interior fully filled — no gaps — at all tested country/continent shapes
- Fallback to circle when path asset removed
- Printful photorealistic mockup generates correctly with both outline types
- IPA size delta measured and within target (≤ 200 KB compressed)

---

## Definition of Done

- [ ] All 195 country JSON files committed to `assets/country_paths/`
- [ ] All 6 continent JSON files committed to `assets/continent_paths/`
- [ ] `_meta.json` committed with source version and build date
- [ ] `CountryPathService` warm cache < 16 ms; cold load < 100 ms
- [ ] Country outline carousel page appears only for single-country designs; page label is the country name
- [ ] Continent outline carousel page appears only for continent-scoped collections; page label is the continent name
- [ ] Path preloaded before navigation; no flash or spinner on first paint
- [ ] Flags fully fill interior; title always below shape
- [ ] Multi-polygon countries render all polys as a single `ui.Path` (not `Path.combine`)
- [ ] Fallback to circle + Crashlytics log on path load failure
- [ ] `clipCode` included in Printful cart metadata
- [ ] IPA size increase ≤ 200 KB compressed
- [ ] `flutter analyze` no new issues

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Country outlines too complex / too simple at print scale | Medium | High | Physical mockup QA before release; per-country ε override in pipeline config |
| France / Russia / US polygon selection wrong | Medium | High | Explicit manual QA pass on problem country list; visual review step in pipeline |
| Narrow countries (Chile, Norway) fill poorly | Medium | Medium | Minimum height padding (400 units) + manual QA |
| Bundle size exceeds 200 KB compressed | Low | Medium | Use 50m as default; exclude micro-territories (VAT, SMR, MCO, etc.) below 100 km² |
| Pre-navigation preload times out on slow device | Low | Low | 800 ms timeout; circle fallback; path cached for next open |
| Continent path looks wrong (shared borders between countries visible) | Low | Medium | Use dissolved dataset, not union of country paths |
| Natural Earth political boundaries disputed | Low | Low | Decorative use only; add `_meta.json` disclaimer; do not display borders as authoritative |
