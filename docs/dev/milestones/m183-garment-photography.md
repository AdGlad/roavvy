# M183 — Garment photography

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** Quality — the shirt is the hero
**Depends on:** —
**Status:** Partial — T2–T4 delivered; T1 (reshoot) blocked on asset work
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

The bundled garment shots are 513×640 — sized for the merch preview they were taken for, and
soft as a full-height Studio hero. Asset work, not code.

The **grey** shirt matters most: it is the tint base every recoloured garment is derived from
(see `GarmentTint`), so its resolution and its clean edge against the sweep set the ceiling for
all eight colours.

## 2. Tasks

- T1 · Reshoot or source at 2–3× the current resolution.
- T2 · Keep the framing — garment bounding boxes currently agree within 0.006 normalised across
  the set, and the print-area geometry depends on that.
- T3 · Keep a clean, separable edge against the backdrop; a white garment on a white sweep is
  what forced the tint base to grey in the first place.
- T4 · Register paths in `garment_mockup_spec.dart` — no other code changes.

## 3. Acceptance criteria

- Garment photography is crisp at full studio-hero size.
- Print areas still land correctly (bounding boxes within tolerance).
- The tint pipeline still cuts the garment out cleanly on both faces.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
