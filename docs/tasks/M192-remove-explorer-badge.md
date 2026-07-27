# M192 — Remove the "Explorer Badge" Style Option

**Status:** `done`
**Created:** 2026-07-27
**Depends on:** none (fully isolated — safe to run in parallel)
**Program:** Purchase-Flow Tuning (M190–M193)

## Problem
The "Explorer Badge" design (`CardTemplateType.badge`) is offered as a
user-selectable t-shirt style. The user wants it removed from the shop.

## Constraint
**Keep the `CardTemplateType.badge` enum value and `BadgeCard` widget** —
multiple exhaustive `switch`es (no `default`) case on it
(`card_image_renderer.dart:380`, label switches in
`merch_option_list_widgets.dart`, `pulse_merch_option.dart`, `merch_story.dart`,
editor/picker). Removing the enum breaks compilation. Only stop **offering** it.

## Fix (edit sites)
- `lib/features/merch/merch_template_ranker.dart` — flip every active
  `_rank(CardTemplateType.badge, N)` to `_excluded(CardTemplateType.badge)`:
  lines ~108 (solo), ~119 (small), ~134 (medium), ~168 (continent explorer),
  ~186 (region). (Large/massive already `_excluded`.) This removes it from every
  ranked, user-visible option list (feeds `MerchContext.buildOptions`).
- `lib/features/merch/merch_drop.dart` — remove the
  `explorer_badge_collection` `MerchDrop` entry (~48-54) so it isn't surfaced as
  a curated collection either. (Do not touch the unrelated `MerchDrop.badge`
  string field.)

## Tasks
- T1 — Exclude badge in all 5 ranker sites.
- T2 — Remove the `explorer_badge_collection` MerchDrop.
- T3 — Grep the shop/design surfaces to confirm badge no longer appears as a
  selectable option anywhere; keep enum + BadgeCard intact.
- T4 — Update `merch_template_ranker_test.dart` if it asserts badge ranking
  (note: this file has a pre-existing unrelated failing test — do not try to
  fix that one).
- T5 — `flutter analyze` clean; tests pass.

## Definition of Done
- [ ] "Explorer Badge" is not offered anywhere in the shop.
- [ ] Enum value + `BadgeCard` remain; no exhaustive-switch breakage.
- [ ] `flutter analyze` clean.
