# Program — Rich Shop Configurator (M187–M189)

**Created:** 2026-07-26
**Goal:** Make the merch shopping experience intuitive and feature-rich. Replace
the two-screen flag t-shirt flow with **one live configurator** where every
option is available and the mockup refreshes on each change, and add two new
expressive options.

## Problem
Configuring a flag t-shirt splits across two screens: `FlagShapeCustomiseScreen`
(clip shape + rows) → `LocalMockupPreviewScreen` (colour/size/placement). Changing
the clip shape or row count means navigating back out and in again. The
configurator is missing options and is hard to navigate.

## The three milestones
| # | Milestone | Core files | Parallelisable core |
|---|---|---|---|
| **M187** | Single-screen live configurator (foundation) | `local_mockup_preview_screen.dart`, `merch_option_list_widgets.dart`, `flag_shape_customise_screen.dart` (removed) | UI refactor — the frame everything slots into |
| **M188** | Randomised overlapping flag **montage** layout | `flag_grid_layout_engine.dart`, `local_mockup_painter.dart` | **Engine, independent** |
| **M189** | **Image size** S/M/L print scale | `product_mockup_specs.dart`, `merch_cart_item.dart`, `printful_placement_mapper.dart` | **Pipeline, independent** |

## Parallelisation strategy (sub-agents)
The three milestones touch **mostly disjoint files**, so their cores run in
parallel isolated git worktrees:

- **Branch A — M188 engine:** add `FlagGridLayoutMode.montage` + seeded `_montage`
  + unit tests. Touches `flag_grid_layout_engine.dart` (+painter). No UI.
- **Branch B — M189 pipeline:** add `ImageSize` enum + centre-scaled print area +
  `MerchCartItem.imageSize` persistence + tests. Touches `product_mockup_specs.dart`,
  `merch_cart_item.dart`, `printful_placement_mapper.dart`. No UI.
- **Branch C — M187 foundation:** the big UI merge in `local_mockup_preview_screen.dart`
  (promote clip/rows to live state, move options into the sheet, delete the
  intermediate screen).

**Integration (serial, after A+B+C land):** wire the montage toggle (M188 T5) and
the Image-size control (M189 T5) into the M187 configurator sheet. These are the
only points where the branches meet, and they touch the M187 file — so they are
done last, on top of the merged foundation.

## Definition of done (program)
- [ ] One configurator screen; no back-out to change clip shape or rows.
- [ ] Grid ↔ Montage layout selectable, live.
- [ ] Image size S/M/L selectable, live, persisted to order.
- [ ] All options refresh the large mockup on change.
- [ ] `flutter analyze` clean; tests pass across all three.
