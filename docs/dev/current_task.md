# M33 — Commerce Sandbox Validation — All Tasks Complete

**Milestone:** 33
**Phase:** 12 — Commerce & Mobile Completion
**Status:** ✅ Complete

## Tasks

- [x] **Task 115** ✅ — Webhook payload verification: `note_attributes` parsing confirmed correct; `console.error` log of `note_attributes` array added to `shopifyOrderCreated` for Cloud Logging visibility on first test order.
- [x] **Task 116** ✅ — Firestore MerchConfig update logic verified correct: `status`, `shopifyOrderId`, `designStatus`, `printfulOrderId` are all written correctly on success and on error paths. No code change needed.
- [x] **Task 117** ✅ — Printful draft order verified: no `"confirm": true` in request body → orders are created as drafts by default. `console.error` log of Printful API response status and body added for debugging.
- [x] **Task 118** ✅ — Post-purchase Firestore poll implemented in `MerchVariantScreen`: after in-app browser dismiss, polls `users/{uid}/merch_configs/{configId}` every 3s up to 10 attempts (30s); shows celebration only when `status == 'ordered'`; shows neutral "processing" dialog on timeout (ADR-087).
- [x] **Task 119** ✅ — Variant mapping confirmed: White/L = Printful ID 535 ✓, Navy/M = Printful ID 527 ✓. No code change needed.
