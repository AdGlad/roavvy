# M170 — Flag Grid: Density Repeats & Clip Shapes

**Status:** `backlog`
**Created:** 2026-06-28
**Updated:** 2026-06-28 (revised after design review)
**Depends on:** M169 (carousel entry flow)

---

## Product Rationale

The flag grid is the most versatile merch template, but it currently has two UX gaps:

1. **Single-country buyers are under-served.** A user who has only visited Japan gets a shirt with one small flag floating in whitespace. Repeating the flag fills the canvas.

2. **Every flag grid looks the same.** A rectangular block of flags is flat. A heart or circle silhouette makes the design personal and share-worthy.

These two controls transform the flag grid from a utility template into a creative canvas.

---

## Scope

### Feature 1 — Flag repeat count

Allow the user to set how many times each country flag appears in the grid (1–9).

**Key decisions:**

- Repeat applies uniformly to every country in the selection
- Range: 1–9. At 10+ the tiles become too small to read
- Smart default derived from country count (see Architecture section)
- Repeat is applied before layout, so all three `FlagGridLayoutMode` algorithms benefit automatically
- **Flag order is random.** The expanded codes list is shuffled before the layout engine runs. Same-country flags must not be adjacent where avoidable (see non-adjacency algorithm below)

### Feature 2 — Clip shape

Apply a clip mask to the flag tile area. The clip is applied to the tiles only. **Titles and branding are always rendered outside and below the clip area, never inside it.**

**Shapes available in M170:**

| Shape | Applies to | Notes |
|---|---|---|
| `none` | Any selection | Rectangular grid — default |
| `heart` | Any selection | Replaces the old `HeartFlagsCard` template |
| `circle` | Any selection | Centred, diameter = min(width, height) × 0.92 |
| `countryOutline` | **Single-country only** | Deferred to M171, shown disabled |
| `continentOutline` | **Continent collections only** | Deferred to M171, shown disabled |

### Deprecation: `HeartFlagsCard`

`HeartFlagsCard` is removed from the carousel and deprecated as a named template type. Its heart path (`MaskCalculator.heartPath`) is preserved and reused by `GridFlagsCard` + `clipShape: heart`. The grid + heart clip is a strictly superior version: users can now combine heart shape with any repeat count and layout mode.

Existing persisted data or deep links referencing `CardTemplateType.heart` are remapped to `CardTemplateType.grid` with `clipShape: heart` at read time.

---

## UX Design

### Where the controls live

Both controls slot into the existing customisation sheet in `LocalMockupPreviewScreen`, below the layout mode picker. Casual users skip them; power users scroll down.

### Repeat count UI

```
  Flag repeats
  ─────────────────────────────
       [−]   ×3   [+]
   1   2   3   4   5   6   7   8   9
       ●
```

- Minus/plus taps increment by 1
- Dot row gives quick tap targets
- Live preview re-renders with 400 ms debounce (layout is fast, but Printful mockup generation is not triggered until the user taps "Approve")

### Clip shape UI

```
  Shape
  ──────────────────────────────────────────────
  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
  │ Grid │  │  ♥   │  │  ●   │  │  ?   │
  │ None │  │Heart │  │Circle│  │Country│ (*)
  └──────┘  └──────┘  └──────┘  └──────┘

  (*) Visible only for single-country designs.
      Shown as "Coming soon" in M170.
```

- 4 icon tiles; selected gets gold border
- "Country outline" tile is only visible when `selectedCodes.length == 1`. Hidden otherwise.
- "Continent outline" is shown only when the design originated from a continent-scoped collection. Hidden otherwise.
- Tapping a disabled tile shows a bottom sheet: "Coming soon — tap to be notified when ready."
- Clip shape picker thumbnails are **static pre-rendered assets** (PNG), not live canvas renders. One set of 4 tiles at 2× covers all uses.

### Fill behaviour

The layout engine generates tiles across the full bounding rectangle of the card. The clip shape is applied as a canvas clip, causing tiles near the boundary to be partially visible. This naturally produces a fully-filled interior — no empty space inside the shape. The over-draw is intentional: tiles outside the clip are discarded by the GPU, not rendered to the final image.

### Title placement

The card's title and branding zone are drawn **after** `canvas.restore()` removes the clip. They appear below the shape, not inside it. For heart and circle clips this means the title sits beneath the silhouette; for `none` it sits beneath the rectangular grid as today.

---

## Architecture

### Non-adjacency algorithm for repeated flags

When `repeatCount > 1` and `codes.length > 1`, naively shuffling produces occasional same-country neighbours. The required algorithm:

```
1. Compute the expanded list: codes.expand((c) => List.filled(repeat, c))
2. Sort by code to group identical flags together
3. Apply an "interleave spread": distribute groups evenly across positions
   by iterating slots in stride order: position = (i * stride) % totalTiles
   where stride is the smallest integer > totalTiles / codes.length
   that is coprime with totalTiles
4. Final shuffle within same-code runs of ≤ 1 (i.e. no two adjacent same-code)
```

For the common case of 2 countries × 3 repeats = 6 tiles, stride=3 gives:
`[AU, NZ, AU, NZ, AU, NZ]` — perfectly interleaved.

For a single country (codes.length == 1), all tiles are identical and the constraint is trivially satisfied.

### `GridClipShape` enum

```dart
enum GridClipShape { none, heart, circle, countryOutline, continentOutline }
```

`countryOutline` and `continentOutline` are added here but remain unimplemented until M171.

### `_clipPathFor(Size size, GridClipShape shape)`

```dart
Path _clipPathFor(Size size, GridClipShape shape) => switch (shape) {
  GridClipShape.none => Path()..addRect(Offset.zero & size),
  GridClipShape.heart => MaskCalculator.heartPath(size),
  GridClipShape.circle => Path()..addOval(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: math.min(size.width, size.height) * 0.46,
      ),
    ),
  // M171: both fall back to circle until implemented
  GridClipShape.countryOutline ||
  GridClipShape.continentOutline => Path()..addOval(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: math.min(size.width, size.height) * 0.46,
      ),
    ),
};
```

No `UnimplementedError` — unimplemented shapes fall back to circle silently.

### Paint order in `GridFlagsPainter.paint()`

```
1. canvas.save()
2. canvas.clipPath(_clipPathFor(size, clipShape))
3. Draw all flag tiles                            ← tiles are clipped
4. canvas.restore()                               ← clip removed
5. Draw feathered edge pass (dstIn, shared with HeartFlagsCard)
6. Draw title + branding zone                     ← not clipped
```

The feathered edge softens the clip boundary for heart and circle. For `none` the feather pass is skipped.

### Smart defaults

```dart
// Repeat count
int merchDefaultRepeatCount(int codeCount, GridClipShape shape) {
  final base = switch (codeCount) {
    1 => 9,
    2 => 6,
    <= 4 => 4,
    <= 8 => 2,
    _ => 1,
  };
  // Heart/circle clip ~35% smaller effective area — increase to compensate
  final clipBoost = (shape != GridClipShape.none && shape != GridClipShape.countryOutline)
      ? 1 : 0;
  return math.min(9, base + clipBoost);
}

// Clip shape: no default shape; always starts as 'none'
// Country outline only offered when codes.length == 1
// Continent outline only offered when collection is continent-scoped
```

### Minimum tile size guard

If `(clipArea / totalTileCount) < 48×36 logical px`, clamp `repeatCount` down and show a toast: "Reduced repeats to keep flags readable."

### `HeartFlagsCard` migration

- `CardTemplateType.heart` enum value retained but marked `@Deprecated`
- `CardImageRenderer._cardWidget()`: `heart` case redirects to `GridFlagsCard(clipShape: GridClipShape.heart, ...)`
- `MerchTemplateRanker`: remove `heart` from ranked options
- Carousel: `HeartFlagsCard` no longer offered as a separate option
- `PulseMerchOption.templateLabel`: `heart` maps to `'Heart'` (kept for any in-flight orders)

---

## Tasks

### T1 — `GridClipShape` enum + `flagRepeatCount` parameter (data model)

**Files:** `flag_grid_layout_engine.dart`, `card_image_renderer.dart`, `card_templates.dart`

- Add `GridClipShape` enum (all 5 values)
- Add `flagRepeatCount: int` param to `FlagGridLayoutEngine.layout()`
- Implement non-adjacency interleave spread algorithm inside layout engine (pre-expansion step)
- Add `flagRepeatCount` and `clipShape` params to `GridFlagsCard` and `CardImageRenderer.render()`
- All new params backward-compatible (`repeatCount = 1`, `clipShape = GridClipShape.none`)

### T2 — Fill rendering + clip path in `GridFlagsPainter`

**Files:** `card_templates.dart`, `heart_layout_engine.dart`

- Implement `_clipPathFor(size, shape)` — no `UnimplementedError`, use circle fallback for M171 shapes
- Apply clip: `canvas.save()` → `clipPath` → draw tiles → `canvas.restore()`
- Extract feathered edge pass from `HeartFlagsCard` into `heart_layout_engine.dart` as `MaskCalculator.applyFeatheredEdge(canvas, size, path)`
- Apply feathered edge for heart and circle; skip for none
- Draw title/branding zone after `restore()` — confirm it is outside clip in all code paths

### T3 — Deprecate `HeartFlagsCard`

**Files:** `card_templates.dart`, `card_image_renderer.dart`, `merch_template_ranker.dart`, `merch_option_list_widgets.dart`, `pulse_merch_option.dart`

- Mark `CardTemplateType.heart` `@Deprecated`
- `CardImageRenderer`: redirect `heart` to `GridFlagsCard` with `clipShape: heart`
- Remove `heart` from `MerchTemplateRanker` ranked list
- Remove `HeartFlagsCard` from carousel options
- Retain `templateLabel` mapping for in-flight order compatibility

### T4 — `LocalMockupPreviewScreen` state + customisation controls

**Files:** `local_mockup_preview_screen.dart`, `merch_customisation_sheet.dart`

- Add `_flagRepeatCount` (smart default) and `_clipShape` (default: `none`) state fields
- Add `_FlagRepeatStepper` widget with min-tile-size guard
- Add `_ClipShapePicker` widget; show/hide `countryOutline` tile based on `codes.length == 1`; show/hide `continentOutline` based on collection origin
- Tapping disabled tile → "Coming soon" bottom sheet with notification opt-in
- Static PNG picker thumbnails: 4 tiles × 2× resolution, prepared as design assets

### T5 — Carousel & preview integration

**Files:** `merch_option_list_widgets.dart`

- Add `merchDefaultRepeatCount(int codeCount, GridClipShape shape)` helper
- Apply in `_DesignCard._generate()` and `_AlternativeThumb._generate()`
- Pass `flagRepeatCount` and `clipShape` through all `_navigate()` → `LocalMockupPreviewScreen` calls

### T6 — Unit tests for layout engine

**Files:** `test/features/cards/flag_grid_layout_engine_test.dart`

- `repeatCount: 9` with 1 country → 9 tiles, all within canvas bounds
- `repeatCount: 3` with 2 countries → 6 tiles, no two identical codes adjacent
- Minimum tile size guard triggers at correct threshold
- Non-adjacency holds across all three `FlagGridLayoutMode` values

### T7 — `flutter analyze` clean + manual test matrix

- Analyze: no new issues
- Repeat ×1 / ×3 / ×9 at solo, small, medium, large density
- Clip: none / heart / circle across 1, 6, 30+ country selections
- Title rendered below shape in all clip modes
- Feathered edge visible on heart and circle, absent on none
- `HeartFlagsCard` route redirects cleanly, no visual regression on existing orders

---

## Definition of Done

- [ ] Flag repeat stepper (1–9) with live preview and min-tile-size guard
- [ ] Clip shape picker: none, heart, circle selectable
- [ ] Country outline tile visible only for single-country designs, shown disabled
- [ ] Continent outline tile visible only for continent-scoped collections, shown disabled
- [ ] Heart clip reuses `MaskCalculator.heartPath()`, feathered edge extracted as shared utility
- [ ] Flags are randomly ordered; same-country flags not adjacent
- [ ] Title and branding zone always outside/below the clip area
- [ ] `HeartFlagsCard` removed from carousel; `heart` template type redirects to grid + heart clip
- [ ] Smart repeat defaults account for clip shape (boosted for heart/circle)
- [ ] All new params backward-compatible; no crash on `countryOutline` / `continentOutline`
- [ ] `flutter analyze` no new issues

---

## Risks

- **Tile overflow at clip boundary:** Tiles near the edge are partially visible (intentional fill behaviour). Verify that partial tiles look clean and don't produce harsh cuts, particularly at the heart's two lobes and the top of the circle.
- **Feathered edge extraction:** `HeartFlagsCard` uses a custom `dstIn` softening pass. Extracting it to a shared utility requires careful testing against the existing heart template's appearance (though the template is being deprecated, the same path is now used in two places).
- **Non-adjacency with high density:** With 30+ countries × 1 repeat, the interleave algorithm has no repeated codes so it is trivially satisfied. Verify no off-by-one in stride calculation for small repeat counts.
