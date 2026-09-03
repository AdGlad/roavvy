# M181 — Saved designs

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** S14 / Rule 9 — every design is reproducible
**Depends on:** —
**Status:** Done
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

`PersistentDesignLibrary` saves garments; nothing browses them. A reproducible design nobody can
reopen is a promise with no payoff — the whole point of deterministic recipes is that a shirt can
come back exactly as it was.

## 2. Tasks

- T1 · Browse saved designs.
- T2 · Reopen one into the Studio exactly as saved, both faces and garment colour.
- T3 · Re-order a saved design without rebuilding it.

## 3. Acceptance criteria

- A saved design reopens byte-identical (same `recipeId`).
- Saved designs survive an app restart.
- Re-ordering a saved design needs no re-design.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
