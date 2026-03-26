# M47 — Commerce Template & Placement

**Milestone:** 47
**Phase:** Phase 13 — Identity Commerce
**Architecture:** ADR-099
**Status:** Complete

## Tasks

- [x] **`CardImageRenderer`** — off-screen PNG renderer via `OverlayEntry` ✅ Done
- [x] **Template picker in `MerchVariantScreen`** — Grid/Heart/Passport segmented control; `initialTemplate` param; `cardImageBytes` nav threading removed ✅ Done
- [x] **Placement picker** — Front/Back for t-shirt only; resets preview on change ✅ Done
- [x] **Firebase Function `placement` field** — `CreateMerchCartRequest.placement`, `MerchConfig.placement`, passed to Printful mockup API ✅ Done
- [x] **`clientCardBase64` size guard** — rejects > 5.5M chars with `invalid-argument` ✅ Done
- [x] **BUG-001 diagnostic logging** — `logger.info('mockup_variant_match', ...)` on every mockup completion ✅ Done
- [x] **Tests** — 9 widget tests (`merch_variant_screen_test.dart`), `card_image_renderer_test.dart`; 632 total passing ✅ Done
