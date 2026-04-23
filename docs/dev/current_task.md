# Active Task: M76 — Named Printful Placement for Left Chest Designs
Branch: milestone/m76-printful-front-placement

## Goal
Use Printful's named `left_chest` placement for left-chest t-shirt designs so the
Printful photorealistic mockup accurately shows a small chest badge instead of a
full-front canvas with content in the corner.

## Scope
In: `apps/functions/src/index.ts`, `apps/functions/src/types.ts` — mockup generation,
    print file generation, Orders API call, MerchConfig type.
Out: `right_chest` (keeps pre-composite; not a standard DTG named placement), mobile app,
     local mockup painter, card editor, web, Shopify, packages.

## Tasks
- [x] T1 — Add `frontPosition` to `MerchConfig` type and persist in `createMerchCart`
- [x] T2 — Update left_chest print file generation: small chest PNG, not composited canvas
- [x] T3 — Update `generatePrintfulMockup` to use `placement: 'left_chest'` for left_chest
- [x] T4 — Update `shopifyOrderCreated` Orders API call to use `placement: 'left_chest'`
- [x] T5 — Compile JS output and update docs

## ✅ Complete (2026-04-23)

## Risks
| Risk | Mitigation |
|---|---|
| Printful rejects `left_chest` DTG for product 12 | Manual verification prerequisite (T0); mockup returns null on reject (non-blocking) |
| Collage style 24458 doesn't render left_chest correctly | Fallback: first available mockup item |
| Orders API `placement` field format differs from mockup API | Use `type: 'left_chest'` as fallback; note in code |
| right_chest kept as pre-composite | Accepted; document clearly in code |

## Production prerequisite
Before deploying: call `GET /v2/catalog/products/12/placements` with PRINTFUL_API_KEY
and confirm `left_chest` appears with `technique: 'dtg'`. If absent, revert T2–T4.
