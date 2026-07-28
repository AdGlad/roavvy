# M195 — Currency Follows the Buyer (not hardcoded £/GBP)

**Status:** `done`
**Created:** 2026-07-28
**Program:** Purchase-Flow Fixes (M194–M196)

## Bug
The app shows **£/GBP** (should be AU$ for an Australian buyer). Two causes:
1. **Shopify checkout page currency.** `apps/functions/src/index.ts` `CART_CREATE_MUTATION` (140-153) has **no `buyerIdentity.countryCode` / `@inContext`**, so the generated `checkoutUrl` uses the store default (GBP). The `selectedCountryCodes` threaded in are the *design's* travel countries, not the buyer's.
2. **Displayed price defaults to £.** Hardcoded fallbacks: `merch_variant_lookup.dart:19,25` (`£29.99`/`£24.99`), `shopify_pricing_repository.dart:17-20`. Buyer country defaults to `'GB'` when locale has no region (`shopify_pricing_repository.dart:59-69`; `index.ts:194-196`). The dynamic `currencyCode → symbol` path already works (`shopify_pricing_repository.dart:35-56`, `AUD → AU$`).

## Fix
- **Backend (function):** add a `buyerCountry` to `CreateMerchCartRequest` (types.ts:121) and set `buyerIdentity: { countryCode: $country }` (with `$country: CountryCode!` + `@inContext(country:)`) on `cartCreate`, so the checkout page presents the buyer's currency. Default to `'AU'` (not GB) when absent. Thread `buyerCountry` from the client `createMerchCart` call (local_mockup_preview_screen.dart ~1774).
- **Client:** derive buyer country from the device locale / user profile (default `'AU'`, not `'GB'`) in `shopify_pricing_repository.dart:59-69` and pass it to `createMerchCart`. Change the hardcoded £ fallbacks to AU$ (or show a spinner instead of a stale symbol). Keep the dynamic `currencyCode`-driven formatting.

## Tasks
- T1 — (backend, parallel-safe) `index.ts` + `types.ts`: `buyerIdentity.countryCode` on cartCreate, `buyerCountry` request field, default `AU`.
- T2 — (client) pass `buyerCountry` into `createMerchCart`; default country `AU`.
- T3 — Fallback price strings → AU$ (or spinner); keep dynamic symbol from Shopify response.
- T4 — Tests for the function (country threaded into mutation) + pricing repo symbol/default.
- T5 — `flutter analyze` clean; function builds.

## Definition of Done
- [ ] Shopify checkout page + in-app price show the buyer's currency (AU$ for AU).
- [ ] No hardcoded £ leaks into the flow.
