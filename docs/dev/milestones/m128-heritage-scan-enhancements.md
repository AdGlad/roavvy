# M128 — Heritage Scan Enhancements

**Status:** Complete (2026-05-25)
**Phase:** Scan UX
**Depends on:** M123 ✅, M126 ✅

---

## Goal

Improve the heritage site experience during and after scan with three focused enhancements:
1. A persistent heritage progress bar in the scan stats bar
2. Tappable heritage dots on the scan globe with a site name tooltip
3. Colour-coded heritage dots (cultural = amber, natural = green)

---

## Background

M123 scoped out the heritage progress widget:
> "Heritage progress widget (persistent '7/25 sites' bar) — deferred"

M126 scoped out tooltip and colour coding:
> "Heritage site label/tooltip on tap in globe — deferred"
> "Colour-coding heritage dots by category (cultural/natural) — deferred"

---

## Scope In

### 1. Heritage Progress Bar
In `_ScanStatsBar`, add a thin linear progress indicator below the text stats row:
- Shows `discoveredHeritage / 1157` as a horizontal bar (amber fill, grey track)
- Only visible once at least one heritage site has been found this scan
- Animates smoothly as new sites are discovered
- Label: `"$discovered / 1,157 heritage sites"` (small caption text)

### 2. Tappable Heritage Dots on Scan Globe
- `GlobePainter` already renders heritage dots; make them hittable via `GestureDetector` on `_ScanGlobeWidget`
- On tap, calculate nearest visible heritage dot within a 24 px radius
- Show a compact tooltip overlay with the site name (max 2 lines) and UNESCO category
- Tooltip auto-dismisses after 3 seconds or on next tap

### 3. Colour-Coded Heritage Dots
Split `heritageSiteCoords` into two lists by UNESCO category:
- `culturalSiteCoords: List<(double lat, double lng)>` — amber/gold dots (existing colour)
- `naturalSiteCoords: List<(double lat, double lng)>` — green dots (`Colors.green[400]`)
- Mixed/both categories: amber (dominant type)

`GlobePainter` renders each list with its respective colour. Pulse animation applies to both.

---

## Scope Out

- Heritage pulse on main map screen outside of scan (→ M129)
- Heritage category legend/key on the globe
- Filtering heritage dots by category

---

## Data Model Changes

`_liveHeritageSiteCoords` in `scan_screen.dart` currently stores `List<(double lat, double lng)>`.

Change to store `List<(double lat, double lng, String category)>` where `category` is `'Cultural'`, `'Natural'`, or `'Mixed'` from `WhsSite.category`.

Thread the split lists down: `_ScanningView` → `_ScanGlobeWidget` → `GlobePainter`.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/scan/scan_screen.dart` | Heritage progress bar; split coords by category; tap handler for tooltip |
| `lib/features/map/globe_painter.dart` | Two coord lists with separate colours; `shouldRepaint` update |

---

## Acceptance Criteria

- [ ] Heritage progress bar appears in scan stats after first heritage site found
- [ ] Progress bar animates as more sites are discovered during scan
- [ ] Cultural sites render as amber dots; natural sites as green dots
- [ ] Tapping a heritage dot shows a tooltip with the site name
- [ ] Tooltip auto-dismisses after 3 seconds
- [ ] No `flutter analyze` warnings introduced
