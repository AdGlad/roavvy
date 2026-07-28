# M194 — Checkout Success Must Be Verified (no false "Order placed")

**Status:** `todo`
**Created:** 2026-07-28
**Program:** Purchase-Flow Fixes (M194–M196)

## Bugs
1. **False success.** `_CheckoutProcessingScreen._openBrowser` (merch_order_confirmation_screen.dart:542-547) does `launchUrl(..., inAppBrowserView)`, which returns the moment the browser is *presented* — not when payment completes. The `_CheckoutState.returned` UI (573-601) then unconditionally renders **"Order placed!"**. So cancelling the Shopify page still shows success. There is NO payment check on this path; the correct Firestore poll (`status == 'ordered'`, local_mockup_preview_screen.dart:983-1038; cart path polls `purchased`, merch_cart_screen.dart:203) is bypassed.
2. **Stuck cart + greyed checkout.** An abandoned checkout leaves the item permanently at `checkoutStarted` (markCheckoutStarted, merch_cart_repository.dart:77-81; never reverted). Re-checkout opens `CartItemCheckoutScreen` where "Proceed to Checkout" is disabled because `_confirmed` starts false (merch_cart_screen.dart:122, checkbox 410-417, button 434-438) and is never restored; also `_launchCheckout` silently no-ops if `checkoutUrl == null` (152-154).

## Fix
- **Neutral post-browser state.** Replace the unconditional "Order placed!" with a non-committal state: "Did you complete your purchase?" with actions [I paid / Not yet]. Only show real success once the Firestore status flips to `ordered`/`purchased` (webhook-driven). Reuse the existing poll logic — on return from the browser, poll the config/cart doc; show "processing/verifying" until confirmed, and a "we couldn't confirm payment — you can retry from your cart" fallback on timeout. Never claim success from `launchUrl` returning.
- **Cart re-checkout usable.** For a returning `checkoutStarted` item: pre-tick/skip `_confirmed` (they already confirmed), and if `checkoutUrl == null` disable with a clear message + a way to regenerate. Add a `markCheckoutAbandoned` (→ `mockupReady`) transition and/or revert `checkoutStarted` when the user returns without paying, so items don't stick.

## Tasks
- T1 — `_CheckoutProcessingScreen`: neutral "verifying" state; success only on Firestore `ordered`/`purchased`; honest timeout fallback.
- T2 — Cart: enable Proceed for returning items (pre-confirm), handle null `checkoutUrl`.
- T3 — Repo: `markCheckoutAbandoned` / revert-on-return so items don't stay stuck.
- T4 — Tests: cancelled checkout does NOT show "Order placed"; poll gates success; cart proceed enabled for checkoutStarted.
- T5 — `flutter analyze` clean.

## Definition of Done
- [ ] Cancelling Shopify checkout never shows "Order placed".
- [ ] Success shown only after a real paid/ordered status.
- [ ] Cart re-checkout works (not greyed); stuck items recover.
