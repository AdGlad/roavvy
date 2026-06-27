# M168 — Merch Checkout UX Improvements

**Status:** `done`
**Created:** 2026-06-24

---

## Overview

Four focused UX improvements to the merch purchase flow, reducing friction
between design selection and completed checkout.

---

## Tasks

### 1. Horizontal scroll for design options (replace hidden "See all styles")

**Files:** `achievement_merch_option_screen.dart`, `pulse_merch_option_screen.dart`

The current layout shows a featured card + a small alternatives strip, with
the full list hidden behind a "See all styles ›" tap. Most users never discover
the full option set.

**Change:** Replace the featured card + alternatives strip + toggle with a
single horizontally-scrollable card carousel showing all options upfront.

- Each card shows a thumbnail preview + label
- First card is the recommended/featured option (visually highlighted)
- No toggle needed — all options visible on first load
- Existing `MerchOptionFeaturedCard` / `MerchOptionCard` widgets adapted for
  fixed-height horizontal list items

---

### 2. In-app browser for Shopify checkout (SFSafariViewController)

**Files:** `merch_order_confirmation_screen.dart`, `merch_cart_screen.dart`

Currently checkout launches full Safari, breaking the in-app experience at the
most critical conversion moment.

**Change:** Replace `launchUrl(Uri.parse(checkoutUrl))` with
`launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.inAppBrowserView)`.

This uses `SFSafariViewController` on iOS — the Shopify checkout page opens
inside the app with a native Done button, keeping the user in context.

- Verify `url_launcher` version supports `LaunchMode.inAppBrowserView` (>=6.1.0)
- Apply consistently everywhere `checkoutUrl` is launched:
  `MerchOrderConfirmationScreen._launchCheckout`,
  `_CheckoutProcessingScreen`, `MerchCartScreen._launchCheckout`

---

### 3. Swipe-to-confirm gesture (replace checkbox)

**File:** `merch_order_confirmation_screen.dart`

The checkbox on `MerchOrderConfirmationScreen` adds a bureaucratic step before
checkout. The original double-order problem it guarded against is now solved by
the `PopScope` processing screen guard.

**Change:** Replace the `Checkbox` + label with a swipe-to-confirm slider widget.

- Horizontal drag: user swipes a pill button left-to-right to confirm
- Triggers `_launchCheckout()` at 85% of slider width
- Haptic feedback (`HapticFeedback.heavyImpact`) on completion
- Communicates intent more naturally than a checkbox while still requiring a
  deliberate gesture

---

### 4. Show price on the confirmation screen

**File:** `merch_order_confirmation_screen.dart`

The user completes the entire design flow — achievement unlock, style selection,
mockup preview — without seeing the price. It only appears once Safari opens
Shopify checkout. This causes surprise abandonment at the last step.

**Change:** Display the product price prominently on `MerchOrderConfirmationScreen`
before the swipe-to-confirm gesture.

- Read price from `shopifyPricingRepository` (already used in
  `local_mockup_preview_screen.dart` via `ShopifyPricingRepository`)
- Show as "£29.99" (t-shirt) or "From £24.99" (poster) near the size/colour
  summary row
- If price fetch fails, show the static fallback from `MerchProduct.fromPrice`
  in `merch_variant_lookup.dart`

---

## Definition of Done

- [x] Design options shown as horizontal scroll on both
      `AchievementMerchOptionScreen` and `PulseMerchOptionScreen`; no "See all
      styles" toggle needed
- [x] Shopify checkout opens via `LaunchMode.inAppBrowserView` across all
      launch sites
- [x] Swipe-to-confirm replaces checkbox on `MerchOrderConfirmationScreen`
- [x] Price shown on confirmation screen; falls back to static price if fetch fails
- [x] `flutter analyze` reports no new issues
- [ ] Manual end-to-end test: achievement unlock -> design selection -> mockup
      -> swipe confirm -> in-app Shopify -> order confirmed
