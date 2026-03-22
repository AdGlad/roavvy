# M24 — Phase 10 Commerce Polish: Preview, Post-Purchase & Order History

**Planner:** 2026-03-22
**Branch:** `milestone/m24-commerce-polish`

**Goal:** A user can see a generated preview of their personalised product before paying, receives a celebration screen when they return from Shopify checkout, and can view their order history in-app.

---

## Scope

**Included:**
- Two-stage checkout UX in `MerchVariantScreen`: "Preview my design" → show generated flag grid image → "Complete checkout" → Shopify
- `MerchPostPurchaseScreen`: celebration screen shown after SFSafariViewController dismisses
- `MerchOrdersScreen`: list of past merch orders read from Firestore `merch_configs`
- Entry point for order history from `PrivacyAccountScreen`

**Excluded:**
- Web commerce (no website work in this milestone)
- Live mockup API integration (Printful mockup API) — flag grid preview from Firebase Function is sufficient
- Additional design styles (World Map, Passport Stamps) — flag grid (Flags style) only
- "Add another product" multi-cart flow — deferred
- Cart review screen (Screen 4 from UX spec) — simplified into post-preview "Complete checkout" CTA

---

## Tasks

### Task 91 — Preview-first checkout in `MerchVariantScreen`

**Deliverable:** Refactor `MerchVariantScreen` so that tapping the primary CTA first calls `createMerchCart`, displays the returned `previewUrl` image in the product slot (replacing the placeholder icon), then reveals a "Complete checkout →" button that opens the `checkoutUrl`. No second function call on checkout open.

**Acceptance criteria:**
- [ ] Button label is "Preview my design" on initial screen load (not "Buy Now")
- [ ] Tapping "Preview my design" calls `createMerchCart` and shows a `CircularProgressIndicator` in the product image slot during the call
- [ ] On success, the product image slot shows the generated flag grid image (loaded from `previewUrl` via `Image.network` with shimmer loading builder)
- [ ] Below the image, a "Complete checkout →" filled button appears; "Preview my design" button is gone
- [ ] Tapping "Complete checkout →" opens `checkoutUrl` in `LaunchMode.inAppBrowserView`; no second function call
- [ ] If the function call fails, error message is shown and "Preview my design" button is re-enabled
- [ ] Changing any variant option after preview resets to pre-preview state (clears `_previewUrl` and `_checkoutUrl`, re-enables "Preview my design")
- [ ] Loading state disables the CTA button

**Files to modify:**
- `apps/mobile_flutter/lib/features/merch/merch_variant_screen.dart`

---

### Task 92 — Post-purchase celebration screen

**Deliverable:** A new `MerchPostPurchaseScreen` shown after the SFSafariViewController dismisses. Pushed immediately after `launchUrl` returns in `MerchVariantScreen._completeCheckout()`. Optimistic — assumes purchase completed (user receives Shopify email as ground truth).

**Acceptance criteria:**
- [ ] `MerchPostPurchaseScreen` is a `StatelessWidget` accepting `product` (`MerchProduct`) and `countryCount` (`int`)
- [ ] Shows: large 🎉 icon/emoji, "Your order is on its way!" heading, body "You'll receive a confirmation email shortly. Your [product.name] is being made with your [N] countries."
- [ ] "Back to my map" filled button pops to root via `Navigator.popUntil`
- [ ] "Share" outline button shares pre-composed message: `"Just ordered a [product name] with all [N] countries I've visited — made with Roavvy 🌍"` via `share_plus`
- [ ] Confetti animation plays on entry (respects `MediaQuery.disableAnimationsOf`)
- [ ] No back navigation (no back button in AppBar; block swipe-back)
- [ ] Pushed from `MerchVariantScreen` after `launchUrl` returns
- [ ] Unit test: widget renders correct product name and country count

**New files:**
- `apps/mobile_flutter/lib/features/merch/merch_post_purchase_screen.dart`

**Modified files:**
- `apps/mobile_flutter/lib/features/merch/merch_variant_screen.dart`

---

### Task 93 — Merch order history

**Deliverable:** `MerchOrdersScreen` reads `users/{uid}/merch_configs` from Firestore and displays past orders with status. Entry point from `PrivacyAccountScreen`.

**Acceptance criteria:**
- [ ] `MerchOrdersScreen` is a `ConsumerWidget`; uses `merchOrdersProvider` (`FutureProvider<List<MerchOrderSummary>>`)
- [ ] `MerchOrderSummary` data class: `configId`, `productName`, `countryCount`, `createdAt`, `status`
- [ ] Reads `users/{uid}/merch_configs` ordered by `createdAt` descending, limit 20
- [ ] Unauthenticated: shows "Sign in to view your orders"
- [ ] Empty: shows "No orders yet. Head to the Shop to order your first personalised item."
- [ ] Each order row: product name, country count, date, status badge
- [ ] Status badge: `pending`/`cart_created` → grey "In progress"; `ordered`/`print_file_submitted` → amber "Processing"; `*_error` → red "Error"
- [ ] `PrivacyAccountScreen` has a "My orders" `ListTile` navigating to `MerchOrdersScreen`
- [ ] Loading state shows `CircularProgressIndicator`
- [ ] Unit test: provider maps Firestore documents to `MerchOrderSummary` correctly; status badge colour test

**New files:**
- `apps/mobile_flutter/lib/features/merch/merch_orders_screen.dart`

**Modified files:**
- `apps/mobile_flutter/lib/features/settings/privacy_account_screen.dart`

---

## Dependencies

- Task 91: no dependencies (standalone refactor)
- Task 92: depends on Task 91 (pushed from variant screen)
- Task 93: independent; build after Task 92

Build order: Task 91 → Task 92 → Task 93

---

## Risks / Open Questions

1. **`launchUrl` return timing**: On iOS, `launchUrl` with `inAppBrowserView` returns when SFSafariViewController is dismissed. Verify this is `await`-able before Task 92.
2. **Preview image shimmer**: `Image.network` `loadingBuilder` provides a frame-by-frame callback — use a simple grey container shimmer for loading, not a third-party package.
3. **Variant change reset**: After variant change, `_previewUrl` and `_checkoutUrl` must both be cleared to avoid stale preview / wrong cart.
4. **Firestore anonymous orders**: Anonymous users can technically create orders (Firebase auth required for `createMerchCart`). `MerchOrdersScreen` should show orders for any Firebase user (anonymous or signed in).
