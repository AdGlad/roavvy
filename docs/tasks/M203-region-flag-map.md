# Region Flag Map (per-country fill) — M203–M205

**Created:** 2026-07-29
**Goal:** Region/continent designs (e.g. Europe) should draw ALL country
borders, fill each **visited** country with **its own** flag, leave unvisited
countries outlined-but-empty, and stroke the region's outer boundary bolder.
Replaces the current "grid/montage of all flags clipped to the region outline"
(which put the UK flag inside France, etc.).

Only `GridClipShape.continentOutline` changes. Country/heart/circle/grid/montage
unchanged. Purchase flow unchanged.

## M203 — Data + loader
- Extend `tools/gen_continent_paths.py` to also emit
  `assets/continent_paths/{key}_countries.json` =
  `{"w":1000,"h":H,"countries":{"FR":[[[x,y]…]…], …}}` — every country's
  polygons in the SAME shared Mercator/window frame as the merged outline
  (so they tessellate). Keep the merged outline file for the bold outer border.
- pubspec asset entry. Loader: `RegionMapService.mapFor(key, targetSize)` →
  `{iso: ui.Path}` fitted to targetSize with the SAME fit as the merged outline
  (reuse the `_buildPath` fit; all countries share one transform).

## M204 — Renderer
New paint path used when `clipShape == continentOutline` (ignore grid/montage
layout for this mode):
1. Fit the region frame into the grid zone (one transform for all).
2. For each country in the region map: if its ISO is in `countryCodes`
   (visited) → clip to the country path, draw its flag (FlagTileRenderer);
   else skip fill. Then stroke the country border (thin, muted).
3. Stroke the merged region outline **bolder** on top.
- No flag = graceful (border only). Deterministic.

## M205 — Integrate + verify
- Route continent designs through the new renderer in `GridFlagsCard` /
  `_GridPainter` (or a dedicated painter); leave the other clip shapes intact.
- Ensure the merch preview + design engine continent path uses it (initialPreset
  already carries clipShape/clipCode).
- Tests: map loads per-country paths; visited filled + unvisited outline-only;
  outer border bolder. `flutter analyze` clean. Device QA on Europe.

## DoD
- [ ] Europe shows country borders; visited filled with own flag; unvisited
      outlined-only; region border bolder.
- [ ] Other clip shapes + purchase flow unchanged; analyze clean; tests pass.
