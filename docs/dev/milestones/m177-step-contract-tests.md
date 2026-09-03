# M177 — The step contract, enforced

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** Rule 4 — a control appears only where it applies
**Depends on:** —
**Status:** Queued
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

The definition's "appears when" column is a contract with nothing enforcing it. A control that
leaks into the wrong context is precisely the failure that makes depth feel like clutter, and it
will regress silently — no test fails when a passport control appears on a flag design.

Pure test milestone. It cannot break the app, and it can start immediately.

## 2. Tasks

- T1 · Table-driven tests over the disclosure predicates: Travels only with trip history ·
  Detail only for Flags · chest side only when Fit = Chest · ribbon coverage only when
  Art = Ribbon.
- T2 · Fine Tune categories present exactly per the definition's table — Layout for Flags,
  Graphic for clipped-or-Passport, Text for Words, the rest always.
- T3 · Structure it so adding a category means adding a row, not writing a test.

## 3. Acceptance criteria

- Every predicate in the definition's table has a test.
- Adding a category to the menu without a rule fails the suite.
- No production behaviour changes.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
