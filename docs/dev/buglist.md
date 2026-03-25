# Bug List

Tracked bugs found during development or testing. Add new bugs at the top.

---

## BUG-003 — Card preview in CardGeneratorScreen is not visually impressive

**Status:** Open
**Milestone:** M37 (Travel Card Generator) / polish pass
**Severity:** Low — functional but underwhelming; the card is the hero moment

**Description:**
The card preview in `CardGeneratorScreen` is rendered inside an `Expanded` widget with `24px` horizontal padding. On typical iPhone screen sizes the card ends up relatively small, which undersells the identity-driven "Travel Card" concept. The card should fill as much of the screen as possible to feel like a premium, shareable artefact — not a thumbnail.

**Expected:** Card preview fills the available width edge-to-edge (or with minimal padding); the 3:2 aspect ratio is respected so the card appears large and impressive before the user shares or prints.
**Actual:** Card is padded 24px each side and centred in an `Expanded` column area, making it smaller than necessary.

**Fix suggestion:**
Remove the `Expanded` wrapper and instead size the preview to the full screen width minus a small margin (e.g. `16px` each side or none at all). Use `AspectRatio(aspectRatio: 3/2)` directly constrained by screen width. This is the same approach used by card-sharing apps where the card is the focal point of the screen.

**Files to investigate:**
- `apps/mobile_flutter/lib/features/cards/card_generator_screen.dart` — preview layout in `_CardGeneratorScreenState.build()`

---

## BUG-002 — Print flow fails silently when offline

**Status:** Open
**Milestone:** M38 (Print from Card)
**Severity:** Medium — user taps "Print your card", nothing happens or an unhandled error is shown

**Description:**
The "Print your card" button navigates to `MerchProductBrowserScreen` and eventually calls the `createMerchCart` Firebase Function via `MerchVariantScreen._generatePreview()`. If the device has no internet connection, the callable will throw a `FirebaseFunctionsException`. The current error handling in `_generatePreview()` catches `FirebaseFunctionsException` and sets `_error`, but the error message shown to the user is a raw exception string — it does not tell them that an internet connection is required.

**Steps to reproduce:**
1. Disable Wi-Fi and mobile data.
2. Open `CardGeneratorScreen`, tap "Print your card".
3. On `MerchVariantScreen`, select a variant and tap "Preview my design".
4. Observe: a generic error message appears (or the spinner hangs).

**Expected:** A clear message: "An internet connection is required to create your order."
**Actual:** Raw Firebase error string or timeout with no user guidance.

**Fix suggestion:**
In `MerchVariantScreen._generatePreview()`, catch network-unavailable errors (check for `FirebaseFunctionsException` with code `unavailable` or a general `SocketException`) and show a user-friendly message. Alternatively, check connectivity before calling the Function and show an inline banner: "You need an internet connection to complete your purchase."

**Files to investigate:**
- `apps/mobile_flutter/lib/features/merch/merch_variant_screen.dart` — `_generatePreview()` error handling

---

## BUG-001 — T-shirt mockup always renders white regardless of selected colour

**Status:** Open
**Milestone:** M34 (Printful mockup preview)
**Severity:** High — directly misleads the user before purchase

**Description:**
When the user selects a black or navy t-shirt colour variant in the merch flow, the Printful mockup preview always shows a white t-shirt. The colour selection is not being passed correctly to the mockup generation request.

**Steps to reproduce:**
1. Open the merch screen and proceed to the t-shirt product.
2. Select the "Black" or "Navy" colour variant.
3. Trigger mockup generation.
4. Observe: the generated mockup image shows a white shirt instead of the selected colour.

**Expected:** Mockup reflects the selected colour (black or navy).
**Actual:** Mockup always shows white.

**Likely cause:**
The colour/variant ID passed to the Printful v2 mockup API may not be mapping to the correct variant, or the `background_color` / variant selection field is missing or hardcoded. Check the mockup request payload in the merch service — cross-reference with ADR-089 and the Printful variant ID verification done in M33.

**Files to investigate:**
- `apps/mobile_flutter/lib/features/merch/` — mockup request construction
- Any Printful API service/client code handling mockup generation
