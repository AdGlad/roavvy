# M120 — Merch Cart, Saved Mockups & Order History

**Status:** In Progress
**Branch:** `milestone/m120-merch-cart-order-history`
**Started:** 2026-05-24

## Goal

Wrap the existing Printful v2 / Shopify purchase workflow with a persistent
client-side cart layer, enabling users to save designs, return later, and view
past orders with a "Buy Again" action.

## Scope

- `MerchCartItem` Firestore model + `MerchCartRepository`
- Modify `_onApprove()` in `LocalMockupPreviewScreen` to create a cart item before
  calling the Firebase Function, and update it when mockup is ready
- `MerchCartScreen` — browse saved/in-progress designs with delete + continue checkout
- `MerchOrdersScreen` enhanced with mockup thumbnails + "Buy Again" action
- Cart entry points: profile screen tile + floating badge on merch screens
- Milestone doc + ADR-167

## Tasks

- [x] T1 — `MerchCartItem` model + `MerchCartRepository`
- [x] T2 — Cart item creation in `_onApprove()`
- [x] T3 — `MerchCartScreen` (view/delete/continue)
- [x] T4 — "Buy Again" in `MerchOrdersScreen`
- [x] T5 — Entry points (profile + merch badge)
- [x] T6 — Docs + ADR-167

## Acceptance Criteria

- "Approve & Preview" creates a Firestore cart item under `users/{uid}/cartItems/{id}`
- Cart item status progresses: `mockupGenerating` → `mockupReady` (or `failed`)
- Cart screen shows active designs with Printful mockup thumbnail when ready
- User can delete a cart item
- User can tap a `mockupReady` cart item to continue to checkout
- Order history ("My orders") shows "Buy Again" CTA for completed orders
- Existing Printful + Shopify checkout flow unchanged
- `flutter analyze` — 0 new errors

## Risks

- `local_mockup_preview_screen.dart` is large; changes must be surgical
- Cart items may accumulate if user never completes purchase — no auto-expiry in PoC
- Artwork bytes not re-storable from cart item alone (mockup URL is the preview)

## ADR-167

**Cart persistence layer for merch purchase flow (M120)**

Decision: Store cart items in Firestore `users/{uid}/cartItems/{id}` (client-side
created) separately from `users/{uid}/merch_configs` (server-side created by the
Firebase Function). Cart items are the pre-purchase record; merch_configs are the
post-payment record. This avoids coupling the checkout server logic to the client
cart lifecycle.

Status: Accepted
