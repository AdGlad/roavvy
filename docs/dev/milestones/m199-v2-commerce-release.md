# M199 — v2 release: commerce on, print-validated signature T-shirts

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M192–M198
**Status:** Todo
**Primary target:** release build · functions · Shopify/Printful · App Store
**Size:** M + owner

---

## 1. Why this exists

Turning purchasing on means a reviewed build with `ROAVVY_COMMERCE=true` and the server param on (ADR-180). Before that, every signature recipe has to be proven on a real shirt, and the store listing has to describe what is now sold.

## 2. Tasks

- **T1 Print validation.** For each of the 6 recipes, generate the print file for 2 countries (one hard case from its QA sheet) and order physical samples on a light and a dark garment (12 shirts). Owner checks colour, edge quality, distress texture and text size. Fixes go back to the recipe's pack (re-approve, version++).
- **T2 Print pipeline check.** Confirm `production_render` output is 3600×4500 at 300 dpi, sRGB, transparent background, `backFull` placement, and that the order payload carries `packId`, `version` and `recipeId` so any order can be re-rendered exactly.
- **T3 Remove the old front door.** Retire the Instant workspace entry; V1 merch entry points stay off (ADR-180 seam), v2 Signature feed is the only T-shirt path.
- **T4 Release guard update.** `scripts/build_ios_release.sh` gets a `--commerce` mode that requires `ROAVVY_COMMERCE=true`, checks every bundled pack is `approved` and passes `SignatureCatalog.verify`, and still refuses `STUDIO_V2`/trace defines.
- **T5 Backend.** Prod `COMMERCE_ENABLED=true` param deploy (owner), Remote Config `commerce_enabled` true, price check of `getMerchPrices` for the 6 garment colours.
- **T6 Store + legal (owner sign-off).** App Store "What's New", screenshots/preview showing the feed, In-App Purchase not involved (physical goods via Shopify checkout; confirm guideline 3.1.3(e)), Terms returns/refunds section, Privacy policy for order data; marketing site update deployed from `apps/web_marketing` only.
- **T7 Device QA + ship.** Physical iPhone walk: feed → detail → customise → cart → Shopify checkout → order confirmation; account deletion still wipes local designs; TestFlight ≥ 3 days, then submit.

## 3. Acceptance

- [ ] 12 sample shirts approved by the owner.
- [ ] Release script passes in commerce mode and refuses a draft pack.
- [ ] A real order placed from TestFlight reaches the print provider with a correct file.
- [ ] Submitted to App Review as v2.0.
