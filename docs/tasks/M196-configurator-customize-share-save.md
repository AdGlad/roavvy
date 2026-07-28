# M196 — Configurator: Always-Visible Customize + Share + Save for Later

**Status:** `done`
**Created:** 2026-07-28
**Program:** Purchase-Flow Fixes (M194–M196)

## Requests
1. **Customize not hidden.** The "Customize design" controls are collapsed behind a tap (`_showAdvanced` + `_CustomiseExpander`, local_mockup_preview_screen.dart:197, 2567-2570, `if (_showAdvanced) ...[` 2572-2874). The user wants them **always visible / just scrollable**, with a clearer affordance that you can customize.
2. **Share the design.** Sharing exists (`MerchShareExporter.share`, app-bar share button 2234-2241 → `_shareDesign` 2153-2157) but shares only the raw artwork. Make it obvious and share the nicer mockup + marketing text.
3. **Save design for later.** Add an explicit "Save for later" affordance that saves the design to the cart WITHOUT proceeding to checkout, so it can be revisited.

## Fix
- **Un-collapse:** remove the `if (_showAdvanced) ...[ … ]` gate so the design controls always render inside the scrollable sheet; replace the collapse toggle with a plain, visible section header (e.g. "Customize" with a hint that it scrolls). Raise `initialChildSize`/`maxChildSize` (2270-2271, e.g. ~0.5 / ~0.85) so the taller content is reachable. Keep the primary Colour/Size + pinned CTA.
- **Share:** keep the app-bar share; ensure it's discoverable; share the composited mockup image where available with a short caption.
- **Save for later:** add a secondary action (e.g. next to the CTA or in the sheet) that persists the current design to the cart (reuse the existing save-to-cart path) and confirms "Saved to your cart", without launching checkout.

## Tasks
- T1 — Always render the Customize controls (drop `_showAdvanced` gate); clear "Customize" header + scroll affordance; tune sheet sizes.
- T2 — Share: share the mockup image + caption; make the button obvious.
- T3 — Save for later: explicit action → save to cart, confirm, no checkout.
- T4 — Update the affected widget test (the M180 test that expanded "Customize design" — no longer needed).
- T5 — `flutter analyze` clean; tests pass.

## Definition of Done
- [ ] Design controls are visible/scrollable by default, clearly labelled.
- [ ] Share works and is obvious.
- [ ] "Save for later" saves to cart without checkout.
