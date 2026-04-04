# M60 — Globe Map View — Task List

**Milestone:** 60
**Phase:** Map Experience / Visual Quality
**Branch:** milestone/m60-globe-map
**Status:** 🔄 In Progress

---

## Goal

Replace the flat Mercator `FlutterMap` with an interactive 3D globe. Drag to spin, pinch to zoom. All country visit states, depth colours, and tap-to-detail flows carry over unchanged. A toggle button lets users switch between globe and flat modes; preference is persisted.

---

## Task M60-01 — `GlobeProjection` utility (pure Dart)

**Deliverable:** `lib/features/map/globe_projection.dart`

**Acceptance criteria:**
- `GlobeProjection` is an immutable value class with fields `rotLat` (double, radians, clamped −π/2..π/2), `rotLng` (double, radians), and `scale` (double, 0.8–8.0).
- `Offset? project(double lat, double lng, Size canvasSize)` converts lat/lng (degrees) to a screen `Offset` using orthographic projection centred on the canvas. Returns `null` when the point is on the back of the globe (dot product < 0 after rotation).
- `(double lat, double lng)? inverseProject(Offset screenPoint, Size canvasSize)` reverses the projection. Returns `null` when `screenPoint` is outside the globe circle.
- `bool isVisible(double lat, double lng)` — true when dot product of rotated unit vector with view axis is ≥ 0.
- `List<List<(double, double)>> splitAtAntimeridian(List<(double, double)> ring)` splits a polygon ring at the antimeridian (±180° lng), returning one or two sub-rings. If no crossing, returns the original ring in a single-element list.
- `GlobeProjection copyWith({double? rotLat, double? rotLng, double? scale})` returns updated instance.
- No Flutter imports; pure `dart:math` only.

---

## Task M60-02 — `GlobePainter` CustomPainter

**Deliverable:** `lib/features/map/globe_painter.dart`

**Acceptance criteria:**
- `GlobePainter` extends `CustomPainter` with: `polygons: List<CountryPolygon>`, `visualStates: Map<String, CountryVisualState>`, `tripCounts: Map<String, int>`, `projection: GlobeProjection`.
- `paint()` draws:
  1. Filled ocean circle (`Color(0xFF0D2137)`) centred on canvas, radius = `min(w,h)/2 * scale`.
  2. For each polygon: `splitAtAntimeridian` each ring, project vertices, skip rings where all points null, build `Path`, fill + stroke with per-state colour.
  3. Atmosphere rim: circle stroke at globe radius, `Color(0xFF2A4F7A)`, strokeWidth 1.5.
- Colour logic: `newlyDiscovered` → `Color(0xFFFFD700)` / white stroke; `reviewed` → `Color(0xFFC8860A)` / gold; `visited` → `depthFillColor(tripCounts[code] ?? 0)` / gold; `unvisited` → `Color(0xFF1E3A5F)` / `Color(0xFF2A4F7A)`. Stroke width 0.3.
- `'AQ'` polygons skipped.
- `shouldRepaint` returns true when `projection`, `visualStates`, or `tripCounts` differ by identity.
- Private `depthFillColor(int n)` mirrors existing logic in `country_polygon_layer.dart`.

---

## Task M60-03 — `GlobeMapWidget` StatefulWidget

**Deliverable:** `lib/features/map/globe_map_widget.dart`

**Acceptance criteria:**
- `GlobeMapWidget` is a `ConsumerStatefulWidget` accepting `onCountryTap: void Function(String isoCode)`.
- State owns `GlobeProjection _projection` (initial: `rotLat: 0.35`, `rotLng: 0.0`, `scale: 1.0`).
- `GestureDetector` handles:
  - `onPanUpdate`: `rotLng += delta.dx/150`, `rotLat = (rotLat - delta.dy/150).clamp(-π/2, π/2)`, `setState`.
  - `onScaleUpdate`: when `pointerCount >= 2`, `scale = (scale * d.scale).clamp(0.8, 8.0)`, `setState`. Reset a `_baseScale` at `onScaleStart`.
  - `onTapUp`: inverse-project `d.localPosition`; if non-null, call `resolveCountry(lat, lng)` and if non-null call `onCountryTap`.
- Wrapped in `LayoutBuilder` to pass canvas size to projection.
- `CustomPaint` with `GlobePainter` reads `polygonsProvider`, `countryVisualStatesProvider`, `countryTripCountsProvider.valueOrNull ?? {}`.

---

## Task M60-04 — Globe/flat toggle in `MapScreen`

**Deliverable:** `lib/features/map/map_screen.dart` updated; `lib/core/providers.dart` gains `globeModeProvider`.

**Acceptance criteria:**
- `globeModeProvider = StateProvider<bool>((ref) => false)` in `lib/core/providers.dart`.
- `MapScreen.build()` watches `globeModeProvider`. When true, `FlutterMap(...)` replaced by `GlobeMapWidget(onCountryTap: ...)`.
- Private `_onGlobeTap(context, ref, isoCode, visitedByCode)` shows `CountryDetailSheet` (same logic as current `_onMapTap`).
- Toggle `Positioned` button: top-left below safe-area, `Icons.public` in flat mode / `Icons.language` in globe mode, `Colors.black45` background, borderRadius 20.
- `RegionChipsMarkerLayer` and `TargetCountryLayer` included only in flat mode.
- All other overlays remain in the `Stack` above both modes.

---

## Task M60-05 — ADR-116 and tests

**Deliverable:** ADR-116 appended to `docs/architecture/decisions.md`; two test files.

**Acceptance criteria:**
- ADR-116 documents: orthographic projection, antimeridian split, scale bounds, toggle via `StateProvider`.
- `test/features/map/globe_projection_test.dart`:
  - `project(0, 0, ...)` with identity rotation → canvas centre.
  - `isVisible(0, 180)` with identity rotation → false.
  - `splitAtAntimeridian` on a ring with no crossing → single-element list.
  - `splitAtAntimeridian` on a ring crossing ±180° → two sub-rings.
  - `inverseProject` outside globe circle → null.
- `flutter analyze --no-pub` passes with no issues.

---

## Dependencies

- M60-01 before M60-02 and M60-03.
- M60-02 and M60-03 can proceed in parallel after M60-01.
- M60-04 depends on M60-03.
- M60-05 alongside all tasks.

## Risks

1. **Performance**: cull entire polygons by centroid visibility before iterating all vertices.
2. **Antimeridian polygons**: `splitAtAntimeridian` in M60-01 prevents horizontal-line artefacts.
3. **Pan vs scale conflict**: distinguish by `pointerCount`; update rotation only on single-finger drag.
