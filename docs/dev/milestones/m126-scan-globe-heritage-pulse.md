# M126 — Scan: Globe Heritage Pulse

**Status:** Complete (2026-05-25)
**Branch:** `milestone/m123-scan-live-heritage-stats-totals`
**Phase:** 25 — Scan UX Transformation

---

## Goal

When a new UNESCO World Heritage Site is discovered during a scan, show a gold pulse dot
at the exact GPS coordinates of that site on the spinning globe — giving the heritage
discovery a distinct visual signal on the map in addition to the `_HeritageToastBanner`.

---

## What Exists Today (post-M125)

| Element | Current state |
|---|---|
| `GlobePainter` | Renders country halo pulse (white, country centroid) via `pulseValue` + `highlightedCode` |
| `_ScanGlobeWidget` | Receives `liveNewCodes` + `existingCodes`; no heritage coords |
| `WorldHeritageSite` | Has `latitude`, `longitude` fields |
| `whsAccum` | `Map<String, VisitedHeritageSite>` — site GPS available via `site.latitude/longitude` |
| `_liveHeritageCount` | State field on `_ScanScreenState` tracking count |

---

## Scope In

### T1 — Thread heritage GPS coords to `_ScanGlobeWidget`

Add state field to `_ScanScreenState`:

```dart
List<(double lat, double lng)> _liveHeritageSiteCoords = const [];
```

Reset to `const []` at scan start.

After each batch, inside `setState`:
```dart
_liveHeritageSiteCoords = whsAccum.values
    .map((s) => (s.latitude, s.longitude))
    .toList();
```

Pass to `_ScanningView` as new prop:
```dart
final List<(double lat, double lng)> liveHeritageSiteCoords;
```

`_ScanningView` passes to `_ScanGlobeWidget`.

**Files:** `scan_screen.dart` — `_ScanScreenState`, `_ScanningView`, `_ScanGlobeWidget`

---

### T2 — Heritage pulse animation in `_ScanGlobeWidgetState`

Add a second pulse controller dedicated to heritage dots:

```dart
late final AnimationController _heritagePulseCtrl;
```

In `initState`:
```dart
_heritagePulseCtrl = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1400),
)..repeat(reverse: true);
```

In `dispose`, add `_heritagePulseCtrl.dispose()`.

Pass `heritagePulseValue` to `GlobePainter`:
```dart
final heritagePulseValue = reduceMotion ? 0.0 : _heritagePulseCtrl.value;
```

Include `_heritagePulseCtrl` in `Listenable.merge(...)`.

**Files:** `scan_screen.dart` — `_ScanGlobeWidgetState`

---

### T3 — Extend `GlobePainter` with heritage pulse dots

Add two new parameters to `GlobePainter`:

```dart
final List<(double lat, double lng)> heritageSiteCoords;
final double heritagePulseValue;
```

Defaults: `heritageSiteCoords = const []`, `heritagePulseValue = 0.0`

In `paint()`, after the country halo section (step 4), add step 5:

```dart
// 5. Heritage site gold pulse dots.
if (heritagePulseValue > 0.0) {
  for (final coord in heritageSiteCoords) {
    final pt = projection.project(coord.$1, coord.$2, size);
    if (pt == null) continue;
    // Outer glow ring.
    canvas.drawCircle(
      pt,
      r * 0.04 * (1.0 + heritagePulseValue * 0.6),
      Paint()
        ..color = Colors.amber[400]!.withValues(
            alpha: heritagePulseValue * 0.30),
    );
    // Inner solid dot.
    canvas.drawCircle(
      pt,
      r * 0.018,
      Paint()..color = Colors.amber[300]!.withValues(alpha: 0.90),
    );
  }
}
```

Update `shouldRepaint`:
```dart
!identical(heritageSiteCoords, old.heritageSiteCoords) ||
heritagePulseValue != old.heritagePulseValue ||
```

**Files:** `apps/mobile_flutter/lib/features/map/globe_painter.dart`

---

### T4 — Wire everything up

Update `GlobePainter(...)` call in `_ScanGlobeWidgetState.build()`:

```dart
painter: GlobePainter(
  polygons: polygons,
  visualStates: visualStates,
  tripCounts: const {},
  projection: displayProjection,
  highlightedCode: _highlightedCode,
  pulseValue: pulseValue,
  heritageSiteCoords: widget.heritageSiteCoords,
  heritagePulseValue: heritagePulseValue,
),
```

Update `_ScanGlobeWidget` constructor:
```dart
const _ScanGlobeWidget({
  required this.liveNewCodes,
  this.existingCodes = const [],
  this.heritageSiteCoords = const [],
});
final List<(double lat, double lng)> heritageSiteCoords;
```

Update `_ScanningView` to accept and pass `liveHeritageSiteCoords`.

**Files:** `scan_screen.dart` — `_ScanGlobeWidget`, `_ScanningView`, `_ScanningViewState.build()`

---

### T5 — Docs & validation

- Update milestone status to Complete
- Update `current_task.md` and `backlog_active.md`
- Run `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`
- Run `python3 scripts/index_docs.py`

---

## Scope Out

| Feature | Reason |
|---|---|
| Heritage pulse on main map screen (non-scan) | Separate feature; map screen has no live scan data |
| Site label / tooltip on tap | Interaction complexity — separate milestone |
| Animated "travel-to" for heritage site | Globe already travels to country; site is within that country |
| Colour-coding by heritage category (cultural/natural) | Can be done in a future polish pass |

---

## Acceptance Criteria

- [ ] Gold pulse dots appear on the globe at heritage site GPS coordinates when
      `liveHeritageSiteCoords` is non-empty.
- [ ] Heritage dots pulse independently from the country halo (separate `AnimationController`).
- [ ] Heritage dots are gold/amber, distinct from the white country halo.
- [ ] Multiple heritage site dots all render (one per discovered site).
- [ ] Dots only render for sites on the visible hemisphere (back-face culled via
      `projection.project()` returning null).
- [ ] Reduce-motion: `heritagePulseValue = 0.0` (inner dot still renders at full alpha,
      glow ring hidden).
- [ ] `GlobePainter.shouldRepaint()` correctly fires when coords or pulse value changes.
- [ ] `flutter analyze` — 0 new errors or warnings.
- [ ] All M121–M125 acceptance criteria still met.

---

## ADR-172

**Scan screen: globe heritage pulse dots (M126)**

Decision: Render animated amber pulse dots at heritage site GPS coordinates in
`GlobePainter` using a new `heritageSiteCoords` parameter. Use a separate
`_heritagePulseCtrl` (1400 ms) so the heritage rhythm is distinct from the country
halo (900 ms).

Rationale: The gold dot is the visual "anchor" that makes the heritage discovery feel
anchored to a real place on earth, not just an abstract count. It reinforces the
`_HeritageToastBanner` without duplicating it. Using the exact site GPS (not country
centroid) gives accuracy that validates the "offline UNESCO lookup" architecture.

Status: Accepted
