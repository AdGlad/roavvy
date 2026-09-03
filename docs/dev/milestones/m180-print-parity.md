# M180 — What you see is what prints

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** Rule 8 — the preview is a promise
**Depends on:** M179
**Status:** Done
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

Preview and print file are produced by different paths. That they agree on placement, colour and
scale is currently an assumption, and it is the assumption the whole product rests on: the
preview is a promise about a physical object someone paid for.

## 2. Tasks

- T1 · Assert parity for a given recipe: the print file's placement, garment colour and artwork
  scale match the preview.
- T2 · Cover both faces and every print position.
- T3 · Cover the transformed case, not just the default — a design the customer moved.

## 3. Acceptance criteria

- Preview and print file agree for every face and placement.
- A parity break fails a test rather than reaching a customer.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
