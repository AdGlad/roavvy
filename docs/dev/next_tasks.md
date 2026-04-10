# M63 — Dual-Placement T-Shirt: Next Tasks

**Goal:** The t-shirt purchase flow uses both the front chest ribbon image and the back travel card image, with correct Printful mockups for both sides, correct shirt color in mockups, and correct multi-file fulfillment orders.

---

## Scope

**Included:**
- Data model update: dual print file + dual mockup URL fields in MerchConfig
- `createMerchCart` function: accept front + back images; generate two print files; call dual-placement mockup; return both URLs
- `generatePrintfulMockup` → `generateDualPlacementMockups`: single Printful task covering both placements
- Front ribbon canvas pre-positioning on 4500×5400 transparent canvas
- `shopifyOrderCreated` webhook: submit Printful order with two files (`type: 'front'` + `type: 'back'`)
- Mobile `LocalMockupPreviewScreen`: store `_frontRibbonBytes`; send both images to server; display front/back mockup based on flip state
- Backward compatibility for old single-file MerchConfig documents in webhook handler

**Excluded:**
- Printful catalog variant ID verification (manual step — user must call Printful API)
- Per-color photoreal shirt assets in local mockup (deferred per ADR-115)
- Poster variant fulfillment (already blocked with `0` placeholder; unchanged)
- Shopify product/variant changes
- Web commerce flow changes

---

## Tasks

### Task 1 — [MANUAL] Verify Printful catalog variant IDs
**Deliverable:** Confirmation that `PRINTFUL_VARIANT_IDS` in `printDimensions.ts` contains correct Gildan 64000 catalog variant IDs.
**Acceptance criteria:**
- User calls `GET https://api.printful.com/v2/catalog-products/12/catalog-variants`
- Compares returned IDs against table in `printDimensions.ts`
- If wrong: table updated with correct IDs
**Note:** Can proceed with remaining tasks; catalog ID fix is isolated to `printDimensions.ts`.
**Status:** ⏳ Pending manual verification

---

### Task 2 — Update MerchConfig types and request/response interfaces ⬅ IN PROGRESS
**Deliverable:** `apps/functions/src/types.ts` updated with dual print file + dual mockup fields.
**Acceptance criteria:**
- `MerchConfig` has: `frontPrintFileStoragePath`, `frontPrintFileSignedUrl`, `frontPrintFileExpiresAt`, `backPrintFileStoragePath`, `backPrintFileSignedUrl`, `backPrintFileExpiresAt`, `frontMockupUrl`, `backMockupUrl`
- `MerchConfig` retains deprecated single-file fields as optional for backward compat
- `CreateMerchCartRequest` has `frontCardBase64?: string` and `backCardBase64?: string`
- `CreateMerchCartResponse` has `frontMockupUrl: string | null` and `backMockupUrl: string | null`
- TypeScript compiles cleanly

---

### Task 3 — Update `generatePrintfulMockup` to dual-placement
**Deliverable:** Renamed `generateDualPlacementMockups` that submits one Printful task with both placements.
**Acceptance criteria:**
- Single `POST /v2/mockup-tasks` body contains two entries in `placements`: `'front'` and `'back'`
- Poll loop extracts mockup URLs for both placements
- Returns `{ frontMockupUrl: string | null, backMockupUrl: string | null }`
- Old `generatePrintfulMockup` removed

---

### Task 4 — Update `createMerchCart` for dual print files
**Deliverable:** `createMerchCart` generates two print files and returns both mockup URLs.
**Acceptance criteria:**
- Accepts `frontCardBase64` and `backCardBase64` (legacy `clientCardBase64` aliased to `backCardBase64`)
- Generates `print_files/{configId}_front.png` (front ribbon, transparent canvas, left-chest composited)
- Generates `print_files/{configId}_back.png` (back card, full canvas)
- Both signed URLs generated; both mockup URLs fetched
- `MerchConfig` written with all dual-file fields
- Returns `{ frontMockupUrl, backMockupUrl, checkoutUrl, cartId, merchConfigId, previewUrl }`

---

### Task 5 — Front ribbon canvas compositing logic
**Deliverable:** Front ribbon composited onto transparent 4500×5400 canvas at left-chest position.
**Acceptance criteria:**
- Ribbon scaled to ~600 px wide
- Composited at left-chest position: ~x=800, y=900 from top-left of 4500×5400 canvas
- Named constants for position values
- Resulting PNG has transparent background outside ribbon area

---

### Task 6 — Update `shopifyOrderCreated` for dual-file Printful orders
**Deliverable:** Webhook submits both front and back print files to Printful.
**Acceptance criteria:**
- `files: [{ url: frontUrl, type: 'front' }, { url: backUrl, type: 'back' }]`
- Backward compat: if `frontPrintFileStoragePath` null → falls back to single-file legacy behavior
- Signed URL refresh applies to both files

---

### Task 7 — Store `_frontRibbonBytes` in `LocalMockupPreviewScreen`
**Deliverable:** Flutter screen stores `Uint8List _frontRibbonBytes` alongside `_frontRibbonImage`.
**Acceptance criteria:**
- `_frontRibbonBytes` populated from `CardRenderResult.bytes` when ribbon renders
- Updated on color change alongside `_frontRibbonImage`
- Null for poster product

---

### Task 8 — Update `_onApprove()` to send both images
**Deliverable:** `_onApprove()` sends `frontCardBase64` + `backCardBase64`.
**Acceptance criteria:**
- `frontCardBase64: base64Encode(_frontRibbonBytes)` when `_isTshirt && _frontRibbonBytes != null`
- `backCardBase64: base64Encode(_artworkBytes)` replaces `clientCardBase64`
- `_placement` removed from payload
- Response parsed for `frontMockupUrl` and `backMockupUrl`

---

### Task 9 — Update ready-state mockup display
**Deliverable:** Ready state shows front mockup when shirt is front-facing, back mockup when back-facing.
**Acceptance criteria:**
- `_frontMockupUrl` and `_backMockupUrl` replace `_mockupUrl`
- `_showingFront` tracks flip state; updated by `_onFlipped`
- Displayed URL = `_showingFront ? _frontMockupUrl : _backMockupUrl`
- Falls back to local mockup if active side's URL is null

---

## Dependencies

```
Task 2 (types) → Tasks 3, 4, 6
Task 5 (compositing) → Task 4
Task 3 (dual mockup fn) → Task 4
Task 4 → Task 8 (mobile)
Task 7 → Task 8
Task 8 → Task 9
```

---

## Risks / Open Questions

1. Printful `type` field name in v2 orders API — confirm `type: 'front'`/`'back'` (not `placement`).
2. Catalog variant IDs — Task 1 (manual) unblocks color-correct mockups.
3. Front ribbon canvas position — Task 5 uses estimated coords; needs test order to calibrate.
4. Old MerchConfig backward compat — guarded in Task 6.
