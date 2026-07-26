# M187 — Shop Configurator: Single-Screen Live Configuration

**Status:** `todo`
**Created:** 2026-07-26
**Updated:** 2026-07-26
**Depends on:** none (foundation for M188, M189)
**Program:** Rich Shop Configurator (M187–M189)

---

## Product Rationale

Configuring a flag t-shirt today is a **two-screen dead-end**. The user picks a
clip shape ("clipping") and a row count on `FlagShapeCustomiseScreen`, then is
pushed forward into `LocalMockupPreviewScreen` for colour / size / front-back
placement. To change the clip shape or row count they must navigate **back out
and in again**, losing their place. Clip shape and row count are baked in as
immutable constructor args — they are literally not editable on the config
screen.

This is the single biggest friction in the shop. The fix: **one configurator
screen** with a large live mockup and a single scrolling stack of options.
Every option — clip shape, rows, colour, size, front/back placement,
orientation — lives together, and **each change refreshes the mockup in place**.

Good news from the audit: `LocalMockupPreviewScreen` **already** renders a large
mockup behind a `DraggableScrollableSheet` whose body (`_buildCompactConfigContent`)
is a scrolling row of option controls (colour, size, placement, orientation,
shuffle). The pattern the user is asking for already exists — we just need to
(a) make clip shape + rows *mutable state* that re-renders, (b) surface them in
that sheet, and (c) delete the intermediate screen.

---

## Scope

### Delivered
- **Clip shape is live-editable** on the configurator: a horizontally scrolling
  row of clip-shape chips/thumbnails (Grid, Heart, Circle, Country Outline,
  Continent Outline, Animal, Plant, Landmark — same set `FlagShapeCustomiseScreen`
  builds today, including async silhouette options for single-country sets).
  Selecting one re-renders the mockup.
- **Row count is live-editable** on the configurator: the existing debounced
  slider from `FlagShapeCustomiseScreen`, moved into the options sheet.
- **`FlagShapeCustomiseScreen` is removed from the flow.** The grid branch in
  `merch_option_list_widgets.dart` pushes straight to `LocalMockupPreviewScreen`
  with sensible defaults; users refine everything on the one screen.
- **Live mockup refresh** on every option change (already the mechanism for
  colour/orientation/shuffle via `_generateFromPreset`; extend to clip/rows).
- **Grouped, scannable option layout** — a simple primary strip (the most-used
  controls) with an expandable "More options" section for detailed config, so
  the screen is *simple by default, deep on demand* (product requirement).

### Out of scope
- The montage layout option (**M188**) and image-size option (**M189**) — this
  milestone only builds the single-screen frame they slot into.
- Persisting clip/rows/layout into `MerchCartItem` for later re-editing from the
  cart (future; today they bake into the rendered artwork bytes).
- Redesign of non-grid template paths beyond removing the extra hop.

---

## UX Design

**Layout (portrait phone):**
- Top ~55–60%: **large live mockup** (existing `LocalMockupPainter` CustomPaint),
  garment + composited artwork, front/back toggle overlaid.
- Bottom: **draggable options sheet** (existing `DraggableScrollableSheet`),
  reorganised into a clear vertical rhythm:

```
┌─────────────────────────────┐
│      LARGE LIVE MOCKUP       │  ← refreshes on every change
│         [Front | Back]       │
├─────────────────────────────┤
│  ▓▓ Style ▓▓ (clip shapes)   │  ← horizontal chip strip, thumbnails
│  [Grid][Heart][Circle][Map…] │
│                              │
│  Colour  ● ● ● ● ●           │
│  Size    S — M — L — XL      │  (garment size)
│  Layout rows  ──●────  (3)   │  (grid row slider; hidden for silhouettes)
│                              │
│  ▾ More options              │  ← expandable
│    Orientation  [P | L]      │
│    Placement    front/back   │
│    Shuffle flags  ⟳          │
└─────────────────────────────┘
```

- **Progressive disclosure:** clip Style, Colour, Size stay always-visible
  (the 80% case). Orientation, per-face placement, shuffle live under a
  collapsible "More options" header so the default view is calm.
- **Every tap re-renders** the mockup; while re-rendering show the existing
  subtle `rerendering` state (no full-screen spinner, no layout jump).
- **Row slider visibility is contextual:** shown for grid/heart/circle/outline
  fills where repeat count is meaningful; hidden for single-silhouette clips
  where it does nothing.
- **Reduce-motion:** mockup swaps without crossfade; no animated chip motion.

---

## Architecture

- **Promote immutable → mutable state** in `_LocalMockupPreviewScreenState`
  (`local_mockup_preview_screen.dart`): `clipShape`, `clipCode`,
  `flagRepeatCount`, `rowCount` are currently read from `widget.*` straight into
  `CardImageRenderer.render`. Introduce `_clipShape`, `_clipCode`,
  `_flagRepeatCount`, `_rowCount` state fields seeded from the widget values;
  every render path (`_generateFromPreset` ~691-710, and the two other call
  sites ~1140-1143, ~1295-1298) reads the state fields.
- **Clip-shape option builder:** lift the page-building logic from
  `FlagShapeCustomiseScreen._buildPages` (171-225) — including the async
  `AnimalSilhouetteService.optionsFor` load for single-country sets — into a
  reusable helper (e.g. `flag_clip_options.dart`) so both the (to-be-removed)
  screen and the configurator sheet share one source of truth. Render as a
  horizontal chip/thumbnail strip in `_buildCompactConfigContent`.
- **Row slider:** move the debounced slider (`_onSliderChanged`, 400 ms debounce)
  into the sheet; on settle, update `_rowCount`/`_flagRepeatCount` and call
  `_generateFromPreset`.
- **Selecting a clip shape** must also update orientation defaults the way the
  old screen did (via `isPortraitForClipShape` in `grid_clip_shape_orientation.dart`)
  and recompute the default repeat count (`merchDefaultRepeatCount`).
- **Navigation change:** in `merch_option_list_widgets.dart` (branch at 372-390,
  plus the duplicated pushes at 853/873, 1340/1360, 1699/1719) push
  `LocalMockupPreviewScreen` directly for the grid template, passing the same
  default `clipShape`/`rowCount` the customise screen would have started with.
  Delete `FlagShapeCustomiseScreen` and its now-dead test once nothing pushes it.
- **Re-render throttling:** clip/rows changes go through the same
  `_MockupState.rerendering` path as orientation; debounce rapid slider changes
  so we don't thrash `CardImageRenderer`.

## Tasks
- T1 — Add mutable `_clipShape/_clipCode/_flagRepeatCount/_rowCount` state; route
  all render call sites through them.
- T2 — Extract shared clip-shape option builder (`flag_clip_options.dart`) from
  `FlagShapeCustomiseScreen._buildPages`, incl. async silhouette options.
- T3 — Clip-shape chip strip in the options sheet; tap → update state, recompute
  orientation + default repeat, `_generateFromPreset`.
- T4 — Move debounced row slider into the sheet; contextual visibility.
- T5 — Reorganise `_buildCompactConfigContent` into primary strip + collapsible
  "More options" (progressive disclosure).
- T6 — Repoint grid-template navigation to `LocalMockupPreviewScreen` directly;
  remove `FlagShapeCustomiseScreen` + its test; update any callers.
- T7 — Widget tests: changing clip shape re-renders and updates orientation;
  changing rows re-renders; row slider hidden for single-silhouette clips;
  navigation no longer visits the customise screen.
- T8 — `flutter analyze` clean; device QA on single-country and multi-country
  flag sets.

## Definition of Done
- [ ] Clip shape and row count are changeable on the configurator with a live
      mockup refresh — no back-navigation required.
- [ ] All previously-available clip shapes/rows are reachable on one screen.
- [ ] `FlagShapeCustomiseScreen` is removed; grid flow lands directly on the
      configurator.
- [ ] Default view is simple (primary options); detailed options are one tap away.
- [ ] `flutter analyze` no new issues; widget tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Making clip/rows mutable triggers heavy re-renders / jank | Medium | High | Reuse `rerendering` state; debounce slider; cache decoded assets |
| Async silhouette option load stalls the strip | Medium | Medium | Show grid/heart/circle immediately; append silhouette chips when loaded |
| Removing the screen breaks other entry points | Medium | High | Grep all 4 push sites; keep defaults identical to old screen; test |
| Sheet becomes cluttered | Medium | Medium | Progressive disclosure; design QA against mobile-design-system.md |
