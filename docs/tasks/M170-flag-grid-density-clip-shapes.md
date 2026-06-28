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

### New screen: `FlagShapeCustomiseScreen`

When the user taps "Design This Shirt" on a flag grid option in the main design carousel, they land on a new intermediate screen before `LocalMockupPreviewScreen`. This screen has two jobs: choose a clip shape by swiping, and set the flag count with a slider.

This screen only appears for `CardTemplateType.grid`. All other templates navigate directly to `LocalMockupPreviewScreen` as before.

```
┌──────────────────────────────────────┐
│  ←   Choose your style              │
│                                      │
│  ┌────────────────────────────────┐  │
│  │                                │  │
│  │   [full shirt mockup with      │  │
│  │    current clip shape applied] │  │
│  │                                │  │
│  │                                │  │
│  │                                │  │
│  └────────────────────────────────┘  │
│         ○  ●  ○                      │  ← page dots
│     ←  swipe for shapes  →          │
│                                      │
│  Flag count   ×4                     │
│  1 ────────●──────────── 9          │  ← slider
│                                      │
│  ┌────────────────────────────────┐  │
│  │      Design This Shirt  →      │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### Clip shape carousel

A `PageView` where each page is a full shirt mockup rendered with one clip shape applied. Swiping to a page IS the selection — no separate picker widget, no tap-to-select.

**Pages in M170 (3 pages):**

| Page | Shape | Label below dots |
|---|---|---|
| 0 | `none` | Grid |
| 1 | `heart` | Heart |
| 2 | `circle` | Circle |

M171 appends additional pages:
- Page 3: `countryOutline` — shown only for single-country designs
- Page 4: `continentOutline` — shown only for continent-scoped collections

Each page is a `_ClipVariantCard` widget (analogous to `_DesignCard` from M169). It renders the artwork with its assigned clip shape and composites it onto a shirt mockup. Rendering is lazy: a page starts rendering when the `PageController` comes within one page of it (using the `pageSnapping` listener). Already-rendered pages are cached by clip shape so slider changes only re-render when `flagRepeatCount` actually changes.

### Flag count slider

Below the carousel, a `Slider` widget:

```
Flag count   ×4
1 ─────────●────────── 9
```

- Integer steps (use `divisions: 8` on Flutter `Slider`)
- Label shows current value as `×N`
- On change: update `_flagRepeatCount` state; all carousel pages re-render with 400 ms debounce
- Smart default on screen open: `merchDefaultRepeatCount(codes.length, currentShape)`

### Interaction model

- Swiping between pages triggers lazy render of the new page if not yet rendered
- Moving the slider debounces 400 ms then re-renders all cached pages
- The CTA "Design This Shirt →" is always enabled; it passes the currently visible page's clip shape and the current slider value to `LocalMockupPreviewScreen`

### Fill behaviour

The layout engine generates tiles across the full bounding rectangle of the card. The clip is applied as a canvas layer clip, so edge tiles are partially visible. This guarantees zero empty space inside the shape. No gap-filling logic needed in the layout engine.

### Title placement

Titles and branding are rendered after `canvas.restore()` removes the clip. They appear below the silhouette, never inside it. In `FlagShapeCustomiseScreen` the title is not shown at all (it is pre-generated later inside `LocalMockupPreviewScreen` as today).

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
- Implement non-adjacency interleave spread algorithm (pre-expansion step, before layout)
- Add `flagRepeatCount` and `clipShape` params to `GridFlagsCard` and `CardImageRenderer.render()`
- All new params backward-compatible (`repeatCount = 1`, `clipShape = GridClipShape.none`)

### T2 — Fill rendering + clip path in `GridFlagsPainter`

**Files:** `card_templates.dart`, `heart_layout_engine.dart`

- Implement `_clipPathFor(size, shape)` — circle fallback for M171 shapes, never throws
- Apply clip: `canvas.save()` → `clipPath` → draw tiles → `canvas.restore()`
- Extract feathered edge pass from `HeartFlagsCard` into `MaskCalculator.applyFeatheredEdge(canvas, size, path)` in `heart_layout_engine.dart`
- Apply feathered edge for heart and circle; skip for none
- Title/branding drawn after `restore()` — verified outside clip in all code paths

### T3 — Deprecate `HeartFlagsCard`

**Files:** `card_templates.dart`, `card_image_renderer.dart`, `merch_template_ranker.dart`, `merch_option_list_widgets.dart`, `pulse_merch_option.dart`

- Mark `CardTemplateType.heart` `@Deprecated`
- `CardImageRenderer`: redirect `heart` case to `GridFlagsCard(clipShape: GridClipShape.heart, ...)`
- Remove `heart` from `MerchTemplateRanker` ranked list
- Remove `HeartFlagsCard` from carousel options
- Retain `templateLabel` mapping for in-flight order compatibility

### T4 — `FlagShapeCustomiseScreen`

**Files:** `lib/features/merch/flag_shape_customise_screen.dart` (new)

This is the new intermediate screen between the design carousel and `LocalMockupPreviewScreen` for the grid template.

Constructor params:
```dart
FlagShapeCustomiseScreen({
  required List<String> codes,
  required List<String> allCodes,
  required List<TripRecord> trips,
  required String? continentKey,   // non-null for continent collections
})
```

Screen layout:
- `AppBar` title: "Choose your style"
- Body:
  - `PageView.builder` (3 pages in M170: none, heart, circle)
  - Page indicator dots (same `AnimatedContainer` pattern as M169 carousel)
  - Shape label below dots (e.g. "Heart", "Circle", "Grid")
  - `Slider` with `divisions: 8`, range 1.0–9.0, integer display `×N`
  - "Design This Shirt →" `FilledButton` at bottom
- `SafeArea` wraps bottom controls

On "Design This Shirt →": push `LocalMockupPreviewScreen` with the currently selected clip shape and flag repeat count.

### T5 — `_ClipVariantCard` widget

**Files:** `lib/features/merch/flag_shape_customise_screen.dart`

One page in the `FlagShapeCustomiseScreen` carousel. Analogous to `_DesignCard` from M169.

State:
- `_MerchGenState _state` (loading / ready / error)
- `Uint8List? _artworkBytes`
- `ui.Image? _artImage`, `ui.Image? _shirtImage`
- `int _renderedRepeatCount` — the count used for the current render (used to decide whether re-render is needed)

`_generate(int repeatCount)`:
- Calls `CardImageRenderer.render()` with `clipShape`, `flagRepeatCount: repeatCount`
- Composites onto back shirt mockup (same pattern as `_DesignCard`)
- On slider change: if `repeatCount != _renderedRepeatCount`, re-render after 400 ms debounce

Lazy trigger: `_ClipVariantCard` starts `_generate()` in `initState`. Pages are built lazily by `PageView.builder` so off-screen pages render only when the user swipes near them (Flutter builds ±1 page by default).

### T6 — Carousel entry point routing

**Files:** `merch_option_list_widgets.dart`

- `_DesignCard._navigate()`: for `CardTemplateType.grid`, push `FlagShapeCustomiseScreen` instead of `LocalMockupPreviewScreen`
- For all other templates: behaviour unchanged
- Same routing change applied to `_AlternativeThumb._navigate()` and `MerchOptionFeaturedCard._navigate()`

### T7 — `LocalMockupPreviewScreen` param additions

**Files:** `local_mockup_preview_screen.dart`

- Add `flagRepeatCount: int` constructor param (default 1)
- Add `clipShape: GridClipShape` constructor param (default `GridClipShape.none`)
- Pass both into `CardImageRenderer.render()` calls inside the screen
- No customisation sheet changes needed for these controls — they are pre-configured in `FlagShapeCustomiseScreen`

### T8 — Helpers and smart defaults

**Files:** `merch_option_list_widgets.dart`

- Add `merchDefaultRepeatCount(int codeCount, GridClipShape shape)` helper
- Apply in `_DesignCard._generate()` so the carousel previews use sensible defaults
- Apply in `FlagShapeCustomiseScreen` as the initial slider value

### T9 — Unit tests for layout engine

**Files:** `test/features/cards/flag_grid_layout_engine_test.dart`

- `repeatCount: 9` with 1 country → 9 tiles, all within canvas bounds
- `repeatCount: 3` with 2 countries → 6 tiles, no two identical codes adjacent
- Minimum tile size guard triggers and clamps correctly
- Non-adjacency holds across all three `FlagGridLayoutMode` values

### T10 — `flutter analyze` clean + manual test matrix

- Analyze: no new issues
- Swipe through all 3 pages; each renders the correct clip shape
- Slider at ×1, ×5, ×9: all pages re-render; min-tile guard clamps at low count + high repeat
- Title rendered below shape on all pages
- Feathered edge on heart and circle, absent on none
- Tapping "Design This Shirt →" carries correct clip shape and repeat count to `LocalMockupPreviewScreen`
- `HeartFlagsCard` route redirects cleanly, no visual regression

---

## Definition of Done

- [ ] `FlagShapeCustomiseScreen` opens when tapping "Design This Shirt" on a grid template option
- [ ] Swiping left/right shows none → heart → circle, each as a full rendered shirt mockup
- [ ] Page indicator dots update correctly during swipe
- [ ] Slider (×1–×9) re-renders all visible pages with 400 ms debounce
- [ ] Min-tile-size guard clamps slider and shows toast when tiles would be too small
- [ ] Smart default repeat count applied on screen open (accounts for clip shape area)
- [ ] Flags are randomly ordered; same-country flags not adjacent in any page
- [ ] Title and branding never visible inside the clip shape
- [ ] Heart clip reuses `MaskCalculator.heartPath()`; feathered edge extracted as shared utility
- [ ] `HeartFlagsCard` removed from carousel; `CardTemplateType.heart` redirects to grid + heart clip
- [ ] All other templates (passport, timeline, etc.) skip `FlagShapeCustomiseScreen` entirely
- [ ] M171 pages (country/continent outline) can be appended to the carousel without restructuring
- [ ] `flutter analyze` no new issues

---

## Risks

- **Tile overflow at clip boundary:** Tiles near the edge are partially visible (intentional fill behaviour). Verify that partial tiles look clean and don't produce harsh cuts, particularly at the heart's two lobes and the top of the circle.
- **Feathered edge extraction:** `HeartFlagsCard` uses a custom `dstIn` softening pass. Extracting it to a shared utility requires careful testing against the existing heart template's appearance (though the template is being deprecated, the same path is now used in two places).
- **Non-adjacency with high density:** With 30+ countries × 1 repeat, the interleave algorithm has no repeated codes so it is trivially satisfied. Verify no off-by-one in stride calculation for small repeat counts.
