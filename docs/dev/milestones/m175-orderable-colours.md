# M175 — Only offer shirts that can be made

**Phase:** T-Shirt Experience (M175–M183)
**Promise it makes true:** Rule 10 — never offer what can't be made
**Depends on:** —  (blocked on Printful)
**Status:** Queued
**Primary target:** `apps/mobile_flutter` · `packages/design_studio`

Definition: [`docs/product/tshirt-experience-definition.md`](../../product/tshirt-experience-definition.md)
Plan and wave sequencing: `next_tasks.md`

---

## 1. Why this exists

The palette offers eight garment colours; the store carries five variants, and two of those
are mislabelled. Orange and Royal have no variant at all — today they are blocked by name at
add-to-cart, which is a catch, not a fix. Dark Heather and Sport Grey both resolve to the
store's single heather, so one of them ships a visibly different shirt from the one chosen.

Until this lands, the studio can show a customer a shirt it cannot make.

## 2. Tasks

- T1 · Enable Orange and Royal in **Printful first**, let them sync to Shopify. Shopify-only
  variants would pass checkout and fail at fulfilment, which is worse than failing at checkout.
- T2 · Wire the new variant GIDs into `merch_variant_lookup.dart` and `PRINTFUL_VARIANT_IDS`
  (`apps/functions/src/printDimensions.ts`).
- T3 · Split Dark Heather from Sport Grey, or drop one from the palette until a variant exists.
- T4 · Replace the silent `tshirtGids[(colour, size)] ?? tshirtGids.values.first` fallback with
  a loud failure — that line is how a customer pays for one colour and is shipped another.
- T5 · Stop rendering swatches for unstocked colours, rather than blocking a screen later.
- T6 · Extend `studio_v2_cart_adapter_test.dart`: every palette colour maps to a real variant.

## 3. Acceptance criteria

- Every colour in `StudioController.garments` resolves to a real Shopify variant.
- A colour with no variant cannot appear on the swatch row at all.
- No code path silently substitutes one garment colour for another.
- Two greys, if both offered, map to two different variants.

## 4. Out of scope

Anything not named above. This milestone closes one named gap between what ships and what the
definition promises — it is not a redesign of the screen it touches.

## 5. Constraints

- `features/studio_v2` must not import `features/merch` (guarded by `v1_isolation_test.dart`);
  shared code goes in `features/shared/`.
- Never delete image assets.
- No new failures in the mobile, `design_studio`, `design_forge_render` or Lab suites.
