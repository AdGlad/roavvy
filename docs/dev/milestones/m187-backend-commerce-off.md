# M187 — Commerce off end to end (no network, server refuses)

**Phase:** Free Launch (M184–M189)
**Depends on:** M184
**Status:** Todo
**Primary target:** `apps/mobile_flutter` startup · `apps/functions/src/index.ts`

---

## 1. Why this exists

Hiding the UI is not enough:

- A free build should make **no** calls to Shopify or Printful.
- Our callable functions should refuse cart creation even if an old or dev build, or a crafted
  request, calls them.
- App Store privacy labels should not have to declare purchase data.

## 2. Tasks

- **T1 Client, no commerce traffic.** Audit startup and background work for commerce calls:
  - `ShopifyPricingRepository` / `getMerchPrices` prefetch;
  - mockup cache warm-up;
  - Firestore cart/order listeners;
  - silhouette/merch asset downloads used only by merch;
  - post-purchase polling.
  Gate each one on `commerceEnabledProvider`. Verify on device that the network log has no
  Shopify, Printful or merch-function calls during a full session with commerce off.
- **T2 Server kill switch.** `createMerchCart` and `getMerchPrices` check a `COMMERCE_ENABLED`
  parameter (Firebase `defineBoolean` param, default **false** in prod). When it is off they
  throw `failed-precondition`. Webhooks (`shopifyOrderCreated`, `printfulMockupWebhook`) stay
  deployed (they do nothing without orders).
  - Add a functions unit test for each of the two states.
- **T3 Data.** Confirm that a commerce-off session writes no `carts`/`orders`/merch documents.
  Firestore rules are unchanged.
- **T4** Deploy functions to **dev**, verify, then prod. Prod deploy needs explicit owner
  approval.

## 3. Acceptance

- [ ] Device network capture with commerce off shows no commerce endpoints.
- [ ] Calling `createMerchCart` directly against prod returns `failed-precondition`.
- [ ] Functions test suite green.
