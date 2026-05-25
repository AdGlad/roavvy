# M129 — Heritage Pulse on Main Map

**Status:** Complete (2026-05-25)
**Phase:** Map UX
**Depends on:** M119 ✅, M126 ✅

---

## Goal

Show UNESCO World Heritage Site locations as ambient pulsing amber dots on the main map globe (outside of scan), so users can see which heritage sites they've visited and discover nearby ones at a glance.

---

## Background

M126 scoped this out explicitly:
> "Heritage pulse on main map screen (non-scan) — deferred from M126"

The scan globe already renders heritage dots with amber pulse via `GlobePainter`. This milestone extends that capability to the always-visible main map screen.

---

## Scope In

### Two Heritage Dot Modes
The main map should show two layers:
1. **Visited** (bright amber, strong pulse) — sites the user has visited (matched against `VisitRepository`)
2. **Unvisited** (dim amber/grey, no pulse or very slow pulse) — all other sites, so the user can see what's possible

Toggle: a toggle chip on the map screen "Show heritage sites" — off by default, persisted in `SharedPreferences`.

### Globe Rendering
Extend `GlobePainter` (or the main map's equivalent painter) to accept:
- `visitedHeritageSiteCoords: List<(double lat, double lng)>`
- `unvisitedHeritageSiteCoords: List<(double lat, double lng)>` (optional, only when toggle is on)
- `heritagePulseValue: double` — driven by an `AnimationController` in the map widget

Visited site dots: amber, 1400 ms pulse (same as scan globe).
Unvisited site dots: `Colors.amber[200]` at 40% opacity, static (no pulse).

### Performance
Unvisited list is large (~1,150 sites). Cull to only render sites in the current visible hemisphere (same back-face culling already in `GlobePainter.project()`).

### Heritage Site Count in Map Stats
If the heritage toggle is on, show `"N / 1,157 heritage sites"` in the map stats footer.

---

## Scope Out

- Heritage site tooltip on map tap (consistent with M128 scan globe — can follow the same pattern later)
- Colour coding by cultural/natural on main map (deferred, lower priority here)
- Heritage sites on the 2D map view (flat map only)
- Web map

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/map/globe_painter.dart` | Add `visitedHeritageSiteCoords` + `unvisitedHeritageSiteCoords` params |
| `lib/features/map/map_screen.dart` | Heritage toggle chip; animation controller; load visited/all site coords |
| `lib/data/visit_repository.dart` | Query to return set of visited heritage site IDs |

---

## Data Source

`WorldHeritageLookupService` already holds all 1,157 sites in memory (loaded in `main()`).
`VisitRepository` already stores visits. Cross-reference on-screen by matching visit GPS coords against WHS bounding boxes — same logic used in scan detection.

Alternatively, persist a `visitedWhsIds: Set<int>` in a new `WhsVisitRepository` or as a column on `visits` table. Choose the simpler approach.

---

## Acceptance Criteria

- [x] "Show heritage sites" toggle visible on map screen
- [x] When toggle is on, visited sites show as bright amber pulsing dots
- [x] When toggle is on, all unvisited sites show as dim amber static dots
- [x] Toggle state persists across app restarts
- [x] Heritage site count shown in map stats when toggle is on
- [x] No perceptible frame-rate drop when rendering heritage dots
- [x] No `flutter analyze` warnings introduced
