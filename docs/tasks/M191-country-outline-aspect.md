# M191 — Country Outline Clip: Preserve True Aspect Ratio

**Status:** `done`
**Created:** 2026-07-27
**Depends on:** none (coordinates with M190 on the preview screen)
**Program:** Purchase-Flow Tuning (M190–M193)

## Problem
The flag grid clipped to a country outline (`GridClipShape.countryOutline`, also
continent/animal/plant/landmark) looks **skewed/stretched to the available
width** instead of keeping the country's natural proportions.

Root cause (per audit): the clip path math is already uniform min-scale, but the
card **aspect ratio is snapped to a coarse binary** `kPortraitCardAspectRatio =
2/3` or `kLandscapeCardAspectRatio = 3/2` (`grid_clip_shape_orientation.dart`).
A near-square or oddly-proportioned country is forced into 2:3 or 3:2, then the
outline is letterboxed into that mismatched card — reading as distortion.

## Fix
- Add a function that returns the **continuous** aspect ratio of a clip shape's
  outline (`bounds.width / bounds.height`) rather than a binary portrait flag,
  in `grid_clip_shape_orientation.dart`.
- Thread that continuous ratio into the card aspect used for outline/silhouette
  clips: `local_mockup_preview_screen.dart` (`_currentAspectRatio` /
  `_initGridOrientationAndRender`, ~line 1345) and
  `merch_option_list_widgets.dart` (~1652-1656).
- Keep `isPortraitForClipShape` for callers that still need the boolean, but
  prefer the continuous ratio where the card aspect is chosen.
- Confirm the outline path fit stays uniform (`_clipPathFor` in
  `card_templates.dart` ~805 already uses min-scale) so the shape isn't squished.

## Tasks
- T1 — `aspectRatioForClipShape(shape, clipCode)` (continuous, async, reuses the
  bounds probe) in `grid_clip_shape_orientation.dart`.
- T2 — Use it for the card aspect on outline/silhouette clips in the preview
  screen and the option carousel; clamp to a sane range (e.g. 0.5–2.0) so
  extreme countries don't produce unusable cards.
- T3 — Verify the clipped grid preserves the country's proportions (no
  horizontal stretch) on a near-square country and a tall one.
- T4 — Update `grid_clip_shape_orientation_test.dart`.
- T5 — `flutter analyze` clean; tests pass.

## Definition of Done
- [ ] Country/continent/silhouette outline clips render at their true aspect
      ratio — no width stretching.
- [ ] Card aspect follows the outline's real proportions (clamped sanely).
- [ ] `flutter analyze` clean; tests pass.
