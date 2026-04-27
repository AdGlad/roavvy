# M85 — Order Confirmation Screen (Pre-Checkout)
Branch: milestone/m85-order-confirmation-screen

## Goal
After the Printful mockup is returned, the user must explicitly review size, colour, design, and
print positions and tick a confirmation checkbox before the "Proceed to Checkout" button enables.

## Scope
In:
  - NEW `apps/mobile_flutter/lib/features/merch/merch_order_confirmation_screen.dart`
  - `apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart` — trigger change only
  - NEW `apps/mobile_flutter/test/features/merch/merch_order_confirmation_screen_test.dart`
Out: Printful API; Firestore schema; Cloud Functions; card editor; scan; map; web; poster flow.

## Tasks

- [ ] T1 — Create `MerchOrderConfirmationScreen`
  Files: `lib/features/merch/merch_order_confirmation_screen.dart`
  Deliverable: Full-screen StatefulWidget with:
    - Constructor params (all immutable): frontMockupUrl, backMockupUrl, frontArtworkBytes,
      artworkBytes, size, colour, frontPosition, backPosition, templateType, checkoutUrl, isTshirt
    - PageView showing front mockup (NetworkImage) + back mockup (if backMockupUrl present);
      falls back to Image.memory(frontArtworkBytes ?? artworkBytes) when URL is null
    - Order summary card: colour swatch (filled circle matching _kSwatchColours palette),
      size chip, front/back position labels, design template label
    - Warning box: amber border, warning icon, no-refund copy
    - Checkbox row: "I confirm..." — drives _confirmed bool via setState
    - Action row: TextButton "Go Back" (Navigator.pop) + FilledButton "Proceed to Checkout"
      (disabled when !_confirmed; on tap calls _launchCheckout)
    - _launchCheckout: launchUrl(uri, mode: LaunchMode.inAppBrowserView), SnackBar on failure
  AC: Button disabled when checkbox unchecked; enabled when checked; Go Back pops.

- [ ] T2 — Wire trigger in `LocalMockupPreviewScreen`
  Files: `lib/features/merch/local_mockup_preview_screen.dart`
  Deliverable:
    - In `_buildBottomBar()`, replace direct `_completeCheckout` call (ready state button) with
      Navigator.push to MerchOrderConfirmationScreen, passing frozen state values.
    - Change button label from "Complete order →" to "Review & Checkout".
    - Keep `_completeCheckout` removed; checkout is now launched from inside confirmation screen.
    - `_checkoutLaunched` flag: set in confirmation screen's _launchCheckout instead.
  AC: Tapping "Review & Checkout" in ready state pushes confirmation screen. Direct checkout
      no longer reachable without ticking checkbox.

- [ ] T3 — Widget tests
  Files: `test/features/merch/merch_order_confirmation_screen_test.dart`
  Deliverable:
    - Test: button disabled initially (checkbox unchecked)
    - Test: button enabled after ticking checkbox
    - Test: Go Back pops navigator (use NavigatorObserver)
    - Test: shows Image.memory fallback when frontMockupUrl is null
    - Test: shows two-item PageView tab indicator when both mockup URLs are provided
  AC: All tests compilable and logically correct.

- [ ] T4 — Analyze clean
  Deliverable: `flutter analyze 2>/tmp/m85_analyze.txt; tail -5 /tmp/m85_analyze.txt`
  AC: No errors reported.

## Status: In Progress (2026-04-27)
