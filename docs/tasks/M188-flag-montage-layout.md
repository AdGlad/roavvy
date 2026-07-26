# M188 — Shop Configurator: Randomised Flag Montage Layout

**Status:** `done`
**Created:** 2026-07-26
**Updated:** 2026-07-26
**Depends on:** M187 for final UI wiring; engine work is independent
**Program:** Rich Shop Configurator (M187–M189)

---

## Product Rationale

Every flag design today is a **uniform grid** — tidy, but samey. The user wants
an expressive alternative: a **randomised montage of overlapping flags**, like a
scattered collage of travel stickers rather than a spreadsheet. This gives the
product a second distinct personality and a reason to keep tapping options to
find a layout they love.

The engine is already built for this: `FlagGridLayoutEngine.compute` dispatches
on a `FlagGridLayoutMode` enum, and each mode returns `List<FlagGridTile>` where
a tile is just `{code, rect}` — **rects may overlap**. Adding a montage is a new
enum value + a new layout function; the render pipeline downstream needs no
structural change.

---

## Scope

### Delivered
- **New `FlagGridLayoutMode.montage`** — flags placed at randomised positions,
  scales, and (optionally) small rotations, deliberately overlapping to form a
  collage that fills the canvas.
- **Deterministic from a seed** — the montage is a pure function of
  (codes, canvas, seed), so the existing **Shuffle** button reuses `_shuffleSeed`
  to regenerate a fresh arrangement, and a given design renders identically every
  time (required for order fidelity — the mockup must equal the printed artwork).
- **Coverage + legibility guarantees:** every selected country appears at least
  once; overlap is bounded so no flag is fully hidden; z-order and a subtle edge/
  shadow keep overlapping flags readable.
- **Exposed as a layout choice** in the M187 configurator (Grid ↔ Montage
  toggle) with live mockup refresh.

### Out of scope
- Rotation support in `FlagGridTile` **if** it proves invasive to the painter —
  fall back to position+scale montage only (documented decision in T2).
- Clip-shape interaction beyond `none` (montage is a fill style; when combined
  with a silhouette clip it fills the silhouette — verify, don't redesign).
- New persistence of layout mode in `MerchCartItem` (tracked with M187's
  persistence follow-up).

---

## UX Design

- **Toggle** in the configurator's Style area: `Grid` | `Montage` (segmented).
  Selecting Montage re-renders immediately.
- **Shuffle** (existing ⟳ control) regenerates the montage arrangement; in grid
  mode it keeps its current meaning. Shuffle is the "roll again" delight loop.
- Montage aesthetic: flags at ~50–90% of a nominal cell, random offsets, gentle
  overlap (~15–30%), optional ≤ ~12° rotation, thin light stroke or soft drop
  shadow so edges read against neighbours. Denser toward centre, airier at edges
  reads better than uniform scatter — tune in design QA.
- **Reduce-motion:** no animated re-shuffle transition; the new arrangement
  simply replaces the old (single render swap).

## Architecture

- **Engine (`lib/features/cards/flag_grid_layout_engine.dart`):**
  - Add `montage` to `FlagGridLayoutMode` (enum ~47-63) with a doc comment.
  - Add `static List<FlagGridTile> _montage(List<String> codes, Size canvas,
    {required int seed, ...})` and a `case FlagGridLayoutMode.montage` branch in
    the `switch` (~174-197). Use a seeded `math.Random(seed)` for reproducibility.
  - Reuse `_expandAndSpread` / existing helpers for code expansion where useful;
    guarantee each code appears ≥ once before random fill.
  - If `FlagGridTile` gains rotation, add an optional `double rotation` (default
    0) so existing modes are unaffected; otherwise omit.
- **Painter (`local_mockup_painter.dart` / `CardImageRenderer`):** confirm the
  tile-drawing loop honours arbitrary/overlapping rects and draw order; add
  rotation + edge stroke/shadow only if `FlagGridTile.rotation` is introduced.
  Overlap ⇒ **draw order matters**: later tiles paint on top.
- **Seed source:** reuse `_shuffleSeed` from `_LocalMockupPreviewScreenState`
  so Shuffle already perturbs the montage; thread `gridLayoutMode` (already a
  field) so `montage` reaches `CardImageRenderer.render`.
- **UI wiring (depends on M187):** add the Grid/Montage segmented control to the
  configurator Style area; on change set `_gridLayoutMode` and `_generateFromPreset`.

## Tasks
- T1 — Add `FlagGridLayoutMode.montage` enum value + doc.
- T2 — Implement seeded `_montage` layout (coverage guarantee, bounded overlap,
  optional rotation); decide rotation support and document it.
- T3 — Unit tests: every code present ≥1×; deterministic for a fixed seed;
  different seeds differ; all tiles within canvas bounds; no full occlusion of
  any single code (bounded-overlap invariant).
- T4 — Painter: verify overlapping draw order; add stroke/shadow (+ rotation if
  chosen) for legibility. Painter test for draw-order/overlap.
- T5 — (M187-dependent) Grid/Montage toggle in the configurator; Shuffle
  regenerates montage; live refresh.
- T6 — `flutter analyze` clean; device QA for legibility + render time on large
  country sets.

## Definition of Done
- [ ] Montage is selectable and renders an overlapping flag collage.
- [ ] Same design + seed renders identically every time (order fidelity).
- [ ] Shuffle produces a fresh montage arrangement.
- [ ] Every selected country is visible; no flag fully hidden.
- [ ] `flutter analyze` no new issues; engine + painter tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Overlap hides flags / looks messy | Medium | High | Coverage invariant + bounded overlap; edge stroke; design QA |
| Non-determinism breaks print == preview | Low | High | Pure seeded function; unit test determinism |
| Rotation invasive to painter | Medium | Medium | Ship position+scale first; rotation optional/flagged |
| Render time on 50+ flags | Low | Medium | Cap tile count / reuse decoded flag images cache |
