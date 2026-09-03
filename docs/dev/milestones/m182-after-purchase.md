# M182 — After the purchase

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** S14 — Checkout and after
**Depends on:** —
**Status:** Done
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

Order status through to delivery, and sharing the design. The shirt is a travel brag, not just a
transaction, and the moment after buying is when someone most wants to show it.

V1 already has confirmation and share screens to reuse rather than rebuild.

## 2. Tasks

- T1 · Order status, from confirmation through to delivery.
- T2 · Share the design from the confirmation.
- T3 · The purchased design stays in the library (see M181).

## 3. Acceptance criteria

- A buyer can see where their order is.
- A buyer can share what they made.
- Nothing in the flow ends on a dead confirmation screen.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
