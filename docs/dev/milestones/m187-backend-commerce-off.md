# M187 — Commerce off end to end (no network, server refuses)

**Phase:** Free Launch (M184–M189)
**Depends on:** M184
**Status:** In progress (code done, dev deployed; prod deploy awaits owner approval)
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
- [x] Functions test suite green (72, including 6 new gate tests).

## 4. As built (2026-11-20)

- **T1 client audit.**
  - Every commerce network call (`createMerchCart`, `getMerchPrices`, `merch_configs`
    reads and writes, Printful mockups, post-purchase polling) lives inside commerce screens,
    which M186 made unreachable.
  - The only startup listener was the cart badge (`merchCartProvider`). It is gated in the
    shell (M185) and now also in the provider itself, as is `shopifyPricingProvider`.
  - The architecture test fails if either callable appears outside commerce code.
  - Silhouette downloads stay: free card templates (grid clip shapes) use them.
  - The daily-challenge callables are free features.
- **T2.**
  - `apps/functions/src/commerceGate.ts` defines `COMMERCE_ENABLED` (`defineBoolean`, default
    false). `assertCommerceEnabled()` runs first in both callables.
  - Per-project values are set in the committed `.env.roavvy-prod` (false) and
    `.env.roavvy-dev` (true). Secrets stay in the gitignored `.env`.
- **T3.** With the screens unreachable and the cart provider gated, nothing writes `merch_configs`
  or carts in a commerce-off session. Firestore rules are unchanged.
- **T4.**
  - Dev: deployed 2026-11-20. `getMerchPrices` passes the gate and reaches Shopify. The dev
    store returns "incomplete price data", which is a dev store data issue that predates this
    milestone.
  - Prod: **not deployed yet; waiting for owner approval.** Once deployed, every current prod
    build loses pricing and checkout.
- Still open: the device network capture (M189 QA) and the prod `failed-precondition` check
  after deploy.
