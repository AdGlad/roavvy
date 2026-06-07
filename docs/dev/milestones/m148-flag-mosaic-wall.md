# M148 — Flag Mosaic Wall

**Branch:** `milestone/m148-flag-mosaic-wall`
**Phase:** 22 — Stats Depth
**Depends on:** M147 (stats visual upgrade)
**Status:** Backlog

---

## Goal

Users can see every country's flag in a scrollable grid — visited flags in full colour, unvisited ones dimmed — giving an immediate, visceral sense of how much of the world they've covered.

---

## Screen Layout

```
FlagMosaicScreen (launched from Countries stat card)
  1. Header — "Your Flags  ·  X / 195"
  2. Search / filter bar — filter by continent chip
  3. Grid — 6-column flag grid, visited=full colour, unvisited=greyscale+0.25 opacity
  4. Tap visited flag — bottom sheet: country name, first/last visit date, trip count
  5. Share button — exports grid as PNG (visited flags only)
```

---

## Scope

### In
- `lib/features/stats/flag_mosaic_screen.dart` — new full-screen widget
- `lib/features/stats/widgets/flag_mosaic_grid.dart` — `GridView` with flag emoji + greyscale shader
- Bottom sheet on tap: country name, first seen, last seen, trip count
- Continent filter chips (All / Africa / Asia / Europe / North America / South America / Oceania)
- Entry point: tap Countries card in `StatsGrid`
- Share CTA: renders visited-only grid to PNG via `RenderRepaintBoundary`

### Out
- Bucket list / "want to visit" marking (deferred M160+)
- Flag image assets — use Unicode flag emoji (zero dependency)
- Web version

---

## Acceptance Criteria

- [ ] Given the user has visited N countries, when they open Flag Mosaic, they see exactly N coloured flags and 195-N dimmed flags.
- [ ] Given a continent filter is selected, only flags from that continent are shown.
- [ ] Given the user taps a visited flag, a bottom sheet shows country name, first visit date, last visit date, and trip count.
- [ ] Given the user taps Share, a PNG of visited flags only is exported to the share sheet.
- [ ] Unvisited flags are greyscale with 0.25 opacity — still identifiable but clearly locked.

---

## Technical Notes

- Flag emoji rendered as `Text` in a fixed-size `SizedBox` — no image assets needed.
- Greyscale: wrap unvisited flag `Text` in `ColorFiltered(colorFilter: ColorFilter.matrix([greyscale matrix]))`.
- `kCountryContinent` from `shared_models` drives the continent filter.
- Country order: alphabetical by country name within each continent group.
- Share PNG: `RepaintBoundary` key on the grid widget + `toImage()` + `Share.shareXFiles`.

---

## Dependencies

- Depends on: M147
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Widget test: given 3 visited countries, grid renders 3 coloured and 192 dimmed tiles.
- [ ] `current_state.md` updated.
