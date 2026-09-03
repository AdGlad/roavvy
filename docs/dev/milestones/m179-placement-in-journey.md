# M179 — Placement inside the journey

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** S12 — Placement
**Depends on:** M178
**Status:** Done
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

The M174 mockup canvas — drag, pinch, twist, with the fabric's folds across the ink — lives on
the V1 merch screen the Studio hands off to. The definition places it as a step in the flow.

This milestone also resolves the orphaned `printArea` wiring in `studio_v2_screen.dart`
(currently in `stash@{1}`), which is what makes the front print render where it will actually
land rather than centred.

## 2. Tasks

- T1 · Bring the canvas into the V2 journey between Review and Size, or make the hand-off
  continuous enough to read as one flow.
- T2 · Carry the arranged transform through to the print file — `MerchImageProcessor` already
  accepts it.
- T3 · Land the `printArea` wiring so left/right chest and full front preview correctly.

## 3. Acceptance criteria

- Placement is a step in the journey, not a screen the flow escapes into.
- Where the design is left is where it prints.
- Front placement previews on the correct side of the garment.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
