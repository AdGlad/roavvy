# M178 — Buy from anywhere

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** Rule 3 — buying is reachable from everywhere
**Depends on:** M175
**Status:** Queued
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

Buying is reachable from Instant and Review only. The definition says a confident person can
leave at any point — a fast path to purchase is a stated principle, not a convenience.

**Gated on M175 deliberately.** Widening the path to checkout while two of eight colours cannot
be fulfilled only widens a broken promise.

## 2. Tasks

- T1 · A persistent buy affordance in the frame, present on every step.
- T2 · One shared path — `buildGarmentCartRequest` already exists; no second copy.
  A hand-rolled duplicate is how a quick path starts ordering something the careful path doesn't.
- T3 · Never a dead end: an unstocked colour states the reason in place.

## 3. Acceptance criteria

- Buy is reachable from every step of the flow.
- All routes to the cart build byte-identical payloads.
- Buying an unbuyable configuration is impossible, and says why.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
