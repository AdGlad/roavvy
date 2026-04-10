# Milestone 63 — Dual-Placement T-Shirt: Front + Back Print + Mockup Sync

**Status:** ✅ Complete
**Branch:** milestone/m63-dual-placement-tshirt
**Completed:** 2026-04-11

---

## Goal

The t-shirt purchase flow uses both front chest ribbon and back travel card images through the full pipeline: upload, Printful mockup, fulfillment order, and mobile display.

---

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Verify Printful catalog variant IDs (manual) | ⏳ Pending manual verification |
| 2 | Update MerchConfig types + request/response interfaces | ✅ Complete |
| 3 | Update generatePrintfulMockup → generateDualPlacementMockups | ✅ Complete |
| 4 | Update createMerchCart for dual print files | ✅ Complete |
| 5 | Front ribbon canvas compositing logic | ✅ Complete |
| 6 | Update shopifyOrderCreated for dual-file Printful orders | ✅ Complete |
| 7 | Store _frontRibbonBytes in LocalMockupPreviewScreen | ✅ Complete |
| 8 | Update _onApprove() to send both images | ✅ Complete |
| 9 | Update ready-state mockup display | ✅ Complete |
