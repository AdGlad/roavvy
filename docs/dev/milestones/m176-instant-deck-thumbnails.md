# M176 — Swipe through shirts, not names

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** S1 — Ready to wear
**Depends on:** M175 (none technically)
**Status:** Queued
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

The Instant deck shows each pick's name and position in the set. The promise of the screen is
swiping through ready-made shirts, so the deck should show shirts.

Deliberately deferred when Instant was built: the hero above already renders the current design,
and two previews of the same design disagreeing with each other is worse than no thumbnail.

## 2. Tasks

- T1 · Render eight garment thumbnails through the existing `RenderService` cache, at a
  thumbnail size tier so they do not compete with the hero's full-size render.
- T2 · Render lazily around the current index; never block first paint.
- T3 · Keep the design name as a caption beneath each.
- T4 · Hold the line on the startup guard — `startup_idle_test.dart` is the tripwire that
  caught the last first-paint regression.

## 3. Acceptance criteria

- The deck shows eight shirt thumbnails, each the design it selects.
- The shell still settles on open; idle rebuilds mint no new render work.
- Swiping remains free of undo history and preference learning.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
