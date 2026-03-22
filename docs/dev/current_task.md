# M24 — Task 91: Preview-first checkout in MerchVariantScreen

**Milestone:** 24
**Phase:** 10 — Commerce Polish
**Status:** ✅ Complete (2026-03-22)

## Current Task

| Task | Description | Status |
|---|---|---|
| 91 | Preview-first checkout in `MerchVariantScreen` | ✅ Done |
| 92 | `MerchPostPurchaseScreen` — post-purchase celebration | ✅ Done |
| 93 | `MerchOrdersScreen` + order history entry point | ✅ Done |

## Task 91 Detail

Refactor `MerchVariantScreen` to a two-stage flow:
1. "Preview my design" → calls `createMerchCart`, shows loading in product image slot
2. On success: shows generated `previewUrl` image; reveals "Complete checkout →" button
3. "Complete checkout →" opens `checkoutUrl` (no second function call)
4. Variant change resets to pre-preview state
