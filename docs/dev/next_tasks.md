# M67 — Grid Card Upgrade

**Goal:** Make GridFlagsCard and HeartFlagsCard display real SVG flag images (not emoji), wire HeartFlagsCard title rendering, and pass titleOverride through CardImageRenderer for all non-passport templates.

**Milestone number:** M67 (backlog entry labelled M61 "Grid Card Upgrade"; renumbered to avoid conflict with the completed M61 Passport Card Refinement in current_state.md)

---

## Context (from Architect review)

After rebasing to main, the codebase already contains work from M62:
- `GridFlagsCard` has `titleOverride` param and uses `_GridPainter` with `GridMathEngine` — title is rendered in the card header ✅
- `HeartFlagsCard` has `titleOverride` param (accepted but **not rendered**) ❌
- `CardEditorScreen` passes `titleOverride` to both Grid and Heart cards ✅
- `CardEditorScreen` shows title editing for Grid and Heart templates ✅

Critical gap: Neither card calls `FlagTileRenderer.loadSvgToCache()`. The `_sharedCache` in each painter is always empty. Both cards always render emoji flags. (ADR-123)

---

## Scope

**Included:**
- SVG async preloading for `GridFlagsCard` (StatefulWidget + ChangeNotifier repaint)
- SVG async preloading for `HeartFlagsCard` (StatefulWidget + ChangeNotifier repaint)
- Wire `titleOverride` through `HeartFlagsCard` → `_HeartPainter` → canvas text
- Fix `CardImageRenderer._cardWidget()` to pass `titleOverride` to Grid and Heart templates

**Excluded:**
- Web card generator changes
- Changes to PassportStampsCard, TimelineCard, FrontRibbonCard
- New SVG assets

---

## Tasks

### Task 1 — SVG preloading for GridFlagsCard (ADR-123)

**Deliverable:** `GridFlagsCard` displays real SVG flag images after async loading.

**Acceptance criteria:**
- `GridFlagsCard` converted to `StatefulWidget`
- `_GridFlagsCardState` owns `ChangeNotifier _repaintNotifier`; disposed in `dispose()`
- `LayoutBuilder` in `build()` computes layout via `GridMathEngine.calculate()` and calls `_preloadSvgs(tileWidth)` on the state
- `_preloadSvgs(double tileSize)` iterates visible codes; for each: skips if `_GridPainter._sharedCache.get(code, tileSize) != null`; calls `FlagTileRenderer.loadSvgToCache(code, tileSize, _GridPainter._sharedCache).then((img) { if (mounted && img != null) _repaintNotifier.notifyListeners(); })`
- `_preloadSvgs` is idempotent — calling it again when cache is warm is a no-op
- `_GridPainter` constructor updated to accept `ChangeNotifier repaintNotifier`; passes it as `super(repaint: repaintNotifier)`
- `_GridPainter._sharedCache` made accessible (keep as static field but remove `_` prefix so state can reference it, or use a top-level private variable)
- Initial render shows emoji fallback; after SVGs load, repaints with SVG images
- `flutter analyze` clean

### Task 2 — SVG preloading for HeartFlagsCard (ADR-123)

**Deliverable:** `HeartFlagsCard` displays real SVG flag images after async loading.

**Acceptance criteria:**
- `HeartFlagsCard` converted to `StatefulWidget`
- `_HeartFlagsCardState` owns `ChangeNotifier _repaintNotifier`; disposed in `dispose()`
- `LayoutBuilder` in `build()` calls `_preloadSvgsForSize(Size canvasSize)`
- `_preloadSvgsForSize` runs `HeartLayoutEngine.layout(codes, size, ...)` to get tile rects, then for each tile: checks cache, schedules `loadSvgToCache(tile.countryCode, tile.rect.width, ...)`, notifies on completion
- `_HeartPainter` constructor accepts `ChangeNotifier repaintNotifier`; passes as `repaint:`
- `_HeartPainter._sharedCache` accessible from state (same approach as Task 1)
- `flutter analyze` clean

### Task 3 — Wire titleOverride to HeartFlagsCard rendering

**Deliverable:** `HeartFlagsCard` renders `titleOverride` text at the top of the card.

**Acceptance criteria:**
- `titleOverride: String?` passed from `HeartFlagsCard` to `_HeartPainter` via constructor
- `_HeartPainter.paint()` draws title text **before** applying the heart clip path so it is not clipped
  - White text, `fontSize: 14`, centred, top padding 8px
  - Uses `TextPainter` with `TextDecoration.none` (same pattern as PassportStampsCard `_drawTitle`)
  - Only drawn when `titleOverride != null && titleOverride!.isNotEmpty`
- When null/empty, card renders identically to current output
- `flutter analyze` clean

### Task 4 — Pass titleOverride in CardImageRenderer

**Deliverable:** Off-screen rendering captures the user's title on Grid and Heart cards.

**Acceptance criteria:**
- `CardImageRenderer._cardWidget()` passes `titleOverride: titleOverride` to `GridFlagsCard` (line ~219)
- `CardImageRenderer._cardWidget()` passes `titleOverride: titleOverride` to `HeartFlagsCard` (line ~225)
- `CardImageRenderer.render()` already accepts `titleOverride` param — no signature change needed
- `flutter analyze` clean

### Task 5 — Tests

**Deliverable:** Tests cover SVG preloading trigger and title rendering.

**Acceptance criteria:**
- Widget test: `GridFlagsCard` with codes → after `pump()`, `_repaintNotifier` is set (test structural correctness, not async SVG loading which requires real assets)
- Widget test: `GridFlagsCard` with `titleOverride: 'My Travels'` → title `Text` widget appears in tree
- Widget test: `GridFlagsCard` with `titleOverride: null` → title string still shows default (country count)
- Widget test: `HeartFlagsCard` builds without error
- Existing `grid_tile_size_test.dart` still passes (the `gridTileSize` function may have been removed — verify)
- `flutter analyze` clean; all existing tests pass

---

## Dependencies

- `FlagTileRenderer.loadSvgToCache()` exists — no changes needed
- `HeartLayoutEngine.layout()` is pure synchronous — safe to call in build/state
- `GridMathEngine.calculate()` is pure synchronous — safe to call in build/state

## Risks

1. **ChangeNotifier called after dispose:** Guard all `.notifyListeners()` calls with `if (mounted)` at the StatefulWidget level.
2. **Tile size mismatch for Heart card:** HeartLayoutEngine tile sizes depend on canvas size; if the canvas size changes (orientation switch), the preloaded SVGs may have wrong sizes and cache misses will occur until re-loaded. Acceptable on first render; subsequent renders will use correct sizes.
3. **grid_tile_size_test.dart may fail:** The `gridTileSize` top-level function was removed in M62 (replaced by `GridMathEngine`). Verify test file state before claiming it passes.
