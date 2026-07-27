# M193 — Review & Improve the "Tour Dates" Option

**Status:** `done`
**Depends on:** none (mostly isolated to timeline files — parallel-safe)
**Created:** 2026-07-27
**Program:** Purchase-Flow Tuning (M190–M193)

## What it is
"Tour Dates" = `CardTemplateType.timeline` — a concert-tour-poster style listing
of trips (country + date range) rendered by `lib/features/cards/timeline_card.dart`
via `TimelineLayoutEngine` and `_TimelinePainter`.

## Weaknesses to fix
- **Contrast bug (highest priority):** palette is hardcoded (`_kInk`,
  `_kInkMuted`, `_kAmber`, `_kParchment` at timeline_card.dart:9-12). Only
  `textColor` is overridable. On a **black shirt** the dark ink / parchment is
  invisible (a known TODO noted at `merch_option_list_widgets.dart:136`). Make
  the palette adapt to the shirt colour / transparent background so it's legible
  on dark garments (light ink on dark).
- **Ordering:** default is chronological (`newestFirst=false`). For a "tour"
  poster, latest-first usually reads better — review and pick the better default
  (or make it deliberate).
- **Aspect:** fixed 3:2; a long trip list wastes space or truncates at 25. Review
  whether a taller aspect or better fitting helps (coordinate loosely with the
  aspect work in M191 — but keep changes inside the timeline files).
- **Flag emoji:** `_flag()` silently returns `''` for non-2-char codes — make it
  robust.

## Tasks
- T1 — Adaptive palette: derive ink/muted/accent/background from the shirt
  colour (or `transparentBackground`) so Tour Dates is legible on black, white,
  and coloured shirts. Reuse the existing `textColor` plumbing where possible.
- T2 — Review ordering default; set the better one (document the choice).
- T3 — Harden `_flag()` and any silent-empty paths.
- T4 — Aspect/fit review: ensure a realistic trip list fills the poster nicely
  without premature truncation.
- T5 — Widget/layout test for legibility on a dark shirt + ordering.
- T6 — `flutter analyze` clean; tests pass.

## Definition of Done
- [ ] Tour Dates is legible on dark and light shirts.
- [ ] Ordering default reviewed and set deliberately.
- [ ] `_flag()` robust; no silent empties.
- [ ] `flutter analyze` clean; tests pass.
