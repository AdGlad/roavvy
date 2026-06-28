# M170 — Flag Grid: Density Repeats & Clip Shapes

**Status:** `backlog`
**Created:** 2026-06-28
**Depends on:** M169 (carousel entry flow)

---

## Product Rationale

The flag grid is the most versatile merch template, but it currently has two UX gaps:

1. **Single-country buyers are under-served.** A user who has only visited Japan gets a shirt with one small flag floating in whitespace. They need the ability to repeat that flag to fill the canvas.

2. **The design feels flat.** Every flag grid looks the same — a rectangular block of flags. Adding a clip shape (heart, circle) gives each design a distinctive silhouette that makes it more personal and more share-worthy.

These two controls together transform the flag grid from a utility template into a creative canvas.

---

## Scope

### Feature 1 — Flag repeat count

Allow the user to set how many times each country flag is repeated in the grid (1–9). A user with 3 countries at repeat ×3 gets 9 tiles. A user with 1 country at repeat ×6 gets a full shirt of that flag.

**Key decisions:**
- Repeat applies to every flag equally (not per-country — that is future scope)
- Range: 1–9. Above 9, layouts become very small and lose visual impact
- Smart default: solo/small density class → default ×4; medium → ×2; large/massive → ×1
- Repeat is applied before the layout engine runs, so all three `FlagGridLayoutMode` algorithms benefit automatically

### Feature 2 — Clip shape

Apply a clip mask to the entire rendered flag grid. The clip is applied after the flag tiles are drawn, before the title/branding zone.

**Shapes available in M170:**

| Shape | Implementation | Notes |
|---|---|---|
| `none` | No clip (default, existing behaviour) | Rectangular grid |
| `heart` | Reuse `MaskCalculator.heartPath()` from `heart_layout_engine.dart` | Parametric heart, same curve as `HeartFlagsCard` |
| `circle` | `Path()..addOval(Rect.fromCircle(...))` | Centred, diameter = min(width, height) × 0.92 |
| `countryOutline` | Deferred to M171 | Shown as disabled in picker with "Coming soon" label |

**Note on `HeartFlagsCard`:** The existing heart template remains unchanged. The new heart clip in the grid template is a different design expression — it fills the heart with the user's flag grid rather than the bespoke heart-tile layout. Both are valid; neither is deprecated.

---

## UX Design

### Where the controls live

Both controls slot into the existing customisation sheet in `LocalMockupPreviewScreen`, below the current layout mode picker (packedRow / normalizedGrid / treemap). This keeps configuration progressive: casual users skip it, power users scroll down.

### Repeat count UI

```
┌─────────────────────────────────────┐
│  Flag repeats                       │
│  How many times each flag appears   │
│                                     │
│        [−]   ×3   [+]               │
│                                     │
│  ○ ○ ●  1  2  3  4  5  6  7  8  9  │
└─────────────────────────────────────┘
```

- Minus/plus taps increment by 1; long-press jumps to min/max
- Dot row below gives quick tap targets for common values
- Live preview updates immediately (no "apply" button)

### Clip shape UI

```
┌──────────────────────────────────────────────────────┐
│  Shape                                               │
│                                                      │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐            │
│  │      │  │  ♥   │  │  ●   │  │  ?   │            │
│  │ None │  │Heart │  │Circle│  │Country│ (disabled) │
│  └──────┘  └──────┘  └──────┘  └──────┘            │
└──────────────────────────────────────────────────────┘
```

- 4 icon tiles in a row, tappable
- Selected tile gets a gold border
- "Country outline" tile shows lock/coming-soon overlay (enabled in M171)
- Each tile shows a small schematic (tiny flag grid in that shape), not just text

### Interaction model

Both controls update the live preview immediately via `setState`. No debounce needed — layout computation is synchronous and fast (< 5 ms for most cases). The re-render of artwork bytes for the mockup is debounced by 400 ms to avoid thrashing during rapid tapping.

---

## Architecture

### New parameter: `flagRepeatCount`

Added to:
- `CardImageRenderer.render()` — forwarded to `GridFlagsCard`
- `GridFlagsCard` constructor
- `FlagGridLayoutEngine.layout()` — expands `codes` list before layout: `codes = codes.expand((c) => List.filled(repeatCount, c)).toList()`
- `LocalMockupPreviewScreen` state: `int _flagRepeatCount = 1`
- `PulseMerchOption` — no change needed (default will be computed from density)

### New enum and parameter: `GridClipShape`

```dart
enum GridClipShape { none, heart, circle, countryOutline }
```

Added to:
- `CardImageRenderer.render()` — forwarded to `GridFlagsCard`
- `GridFlagsCard` constructor and painter
- `LocalMockupPreviewScreen` state: `GridClipShape _clipShape = GridClipShape.none`

### Clip path rendering

Applied inside `GridFlagsPainter.paint()` after drawing all tiles, before the branding zone:

```
canvas.save();
canvas.clipPath(_shapePathFor(size, clipShape), doAntiAlias: true);
// draw all flag tiles
canvas.restore();
// draw branding zone (not clipped)
```

`_shapePathFor(size, shape)` returns:
- `none` → full canvas rect (no-op clip)
- `heart` → `MaskCalculator.heartPath(size)` (existing)
- `circle` → `Path()..addOval(Rect.fromCircle(center: size.center, radius: min(w, h) * 0.46))`
- `countryOutline` → M171

### Smart defaults for repeat count

Applied in `merch_option_list_widgets.dart` helper:

```dart
int merchDefaultRepeatCount(int codeCount) => switch (codeCount) {
  1 => 9,
  2 => 6,
  <= 4 => 4,
  <= 8 => 2,
  _ => 1,
};
```

This means a 1-country Oceania design gets a dense grid by default.

### Propagation through the carousel

`_DesignCard._navigate()` passes `flagRepeatCount` and `clipShape` to `LocalMockupPreviewScreen` as new constructor params. The carousel preview (`_DesignCard._generate()`) also uses these defaults so the user sees the intended design before tapping.

---

## Tasks

### T1 — `GridClipShape` enum + `flagRepeatCount` parameter (data model)

**Files:** `flag_grid_layout_engine.dart`, `card_image_renderer.dart`, `card_templates.dart`

- Add `GridClipShape` enum
- Add `flagRepeatCount: int` param to `FlagGridLayoutEngine.layout()` with pre-expansion logic
- Add `flagRepeatCount` and `clipShape` params to `GridFlagsCard` and `CardImageRenderer.render()`
- All new params are optional with backward-compatible defaults (`repeatCount = 1`, `clipShape = GridClipShape.none`)

### T2 — Clip path rendering in `GridFlagsPainter`

**Files:** `card_templates.dart`

- Implement `_clipPathFor(Size size, GridClipShape shape)` private method
- Apply clip in `paint()` with `canvas.save()` / `canvas.restore()` sandwich
- Heart: call `MaskCalculator.heartPath(size)`
- Circle: construct `Path` from `Rect.fromCircle`
- `none`: return full-rect path (no visual change)
- `countryOutline`: throw `UnimplementedError` with clear message (M171)

### T3 — `LocalMockupPreviewScreen` state & customisation sheet

**Files:** `local_mockup_preview_screen.dart`, `merch_customisation_sheet.dart`

- Add `_flagRepeatCount` and `_clipShape` state fields
- Smart default for `_flagRepeatCount` on init: `merchDefaultRepeatCount(widget.selectedCodes.length)`
- Rebuild preview on change (same debounce pattern as existing template switch)
- Pass new params into `CardImageRenderer.render()` calls and into Printful `createMerchCart` payload as metadata

### T4 — Repeat count stepper + clip shape picker widgets

**Files:** `merch_customisation_sheet.dart` (or inline in config panel)

- `_FlagRepeatStepper` widget: minus/plus buttons + dot row indicator
- `_ClipShapePicker` widget: 4 tiles (icon + label), gold border on selected, disabled state for `countryOutline`
- Both widgets are only shown when `_template == CardTemplateType.grid` or `CardTemplateType.heart` (heart shape defaults pre-selected for heart template)

### T5 — Carousel & preview integration

**Files:** `merch_option_list_widgets.dart`

- Add `merchDefaultRepeatCount()` helper
- `_DesignCard._generate()` uses smart default repeat count per density
- `_DesignCard._navigate()` passes `flagRepeatCount` and `clipShape` through
- Same applied to `_AlternativeThumb` and `MerchOptionFeaturedCard`
- `GridClipShape.none` used as default in carousel (shape is a user choice, not a pre-set)

### T6 — `flutter analyze` clean + manual test

- Analyze: no new issues
- Manual test matrix:
  - Repeat ×1 / ×3 / ×9 at each density class (solo, small, medium, large)
  - Clip: none / heart / circle across 1, 6, 30+ country selections
  - Printful mockup still generates correctly with new clip shapes

---

## Definition of Done

- [ ] Flag repeat stepper (1–9) in customisation sheet, live preview updates
- [ ] Clip shape picker: none, heart, circle selectable; country outline disabled with "Coming soon"
- [ ] Heart clip produces identical curve to `HeartFlagsCard` (same `MaskCalculator.heartPath`)
- [ ] Circle clip centred, matches 92% of min dimension
- [ ] Smart repeat defaults: 1-country → ×9, 2 → ×6, 3–4 → ×4, 5–8 → ×2, 9+ → ×1
- [ ] Carousel preview uses smart defaults (not always ×1)
- [ ] Existing `HeartFlagsCard` template unaffected
- [ ] `flutter analyze` reports no new issues
- [ ] `flagRepeatCount` and `clipShape` threaded to Printful payload for traceability

---

## Risks

- **Layout engine with repeats + heart/circle clip:** At high repeat counts on dense collections, tiles become very small. Minimum tile size guard needed (clip area ÷ total tile count ≥ 8×6 px) — add assertion to `FlagGridLayoutEngine` and clamp repeat count in UI before applying.
- **Feathering on heart clip:** `HeartFlagsCard` applies a second `dstIn` pass for a feathered edge. The grid version should do the same for visual consistency. Extract as a shared utility in `heart_layout_engine.dart`.
