# Printful v2 Mockup Generator API — Roavvy Reference

> Synthesised from the Printful developer docs and verified implementation in `apps/functions/src/index.ts`.
> Last verified: 2026-04-23.

---

## Overview

The Printful v2 Mockup Generator is an **async, task-based API**. You submit a task and then poll for the result. It is not instant — generation typically takes 5–30 seconds.

**Base URL:** `https://api.printful.com`
**Auth:** `Authorization: Bearer <PRINTFUL_API_KEY>` header on all requests.

---

## 3-Step Async Flow

```
1. POST /v2/mockup-tasks          → returns task id(s)
2. GET  /v2/mockup-tasks?id={id}  → poll until status = "completed" | "failed"
3. Parse result                   → extract mockup_url from catalog_variant_mockups
```

---

## Step 1 — Create Mockup Task

**`POST /v2/mockup-tasks`**

### Request Body

```json
{
  "products": [
    {
      "source": "catalog",
      "catalog_product_id": 12,
      "catalog_variant_ids": [474],
      "placements": [
        {
          "placement": "front",
          "technique": "dtg",
          "layers": [
            { "type": "file", "url": "https://..." }
          ]
        },
        {
          "placement": "back",
          "technique": "dtg",
          "layers": [
            { "type": "file", "url": "https://..." }
          ]
        }
      ],
      "mockup_style_ids": [24458]
    }
  ]
}
```

### Key Fields

| Field | Type | Notes |
|---|---|---|
| `source` | `"catalog"` | Always `"catalog"` for standard Printful products |
| `catalog_product_id` | integer | Printful product ID (12 = Gildan 64000 Softstyle Tee) |
| `catalog_variant_ids` | integer[] | **Array** — singular `catalog_variant_id` is silently ignored (verified 2026-04-12) |
| `placements` | object[] | One entry per print area |
| `placements[].placement` | string | `"front"` \| `"back"` \| `"left_chest"` \| `"right_chest"` (product-dependent) |
| `placements[].technique` | string | `"dtg"` for t-shirts (Direct-to-Garment); others: `"embroidery"`, `"sublimation"` |
| `placements[].layers` | object[] | Array of layer objects |
| `layers[].type` | string | `"file"` (URL to the print file PNG/PDF) |
| `layers[].url` | string | Publicly accessible URL; Firebase Storage signed URLs work |
| `mockup_style_ids` | integer[] | Optional. Filters which mockup styles are generated (see Mockup Styles below) |

### Response

```json
{
  "data": [
    {
      "id": 12345678,
      "status": "pending"
    }
  ]
}
```

---

## Step 2 — Poll for Result

**`GET /v2/mockup-tasks?id={taskId}`**

Poll every 2–3 seconds. Status transitions: `pending` → `completed` | `failed`.

### Response (completed)

```json
{
  "data": [
    {
      "id": 12345678,
      "status": "completed",
      "catalog_variant_mockups": [
        {
          "catalog_variant_id": 474,
          "mockups": [
            {
              "mockup_style_id": 24458,
              "mockup_url": "https://printful-upload.s3-accelerate.amazonaws.com/..."
            }
          ]
        }
      ]
    }
  ]
}
```

> **Note:** The array field inside `catalog_variant_mockups` entries may be named `mockups` **or** `placements` depending on the API version. The implementation tries both:
> ```typescript
> const mockupItems = matched?.mockups ?? matched?.placements ?? [];
> ```

### Status Values

| Status | Meaning |
|---|---|
| `pending` | Task queued or in progress — keep polling |
| `completed` | Mockups are ready — parse `catalog_variant_mockups` |
| `failed` | Generation failed — log the task id and return null |

### Polling Strategy (Production)

```
maxAttempts = 25
intervalMs  = 3000
maxWait     = 75s
```

In Roavvy the mockup runs in a **fire-and-forget background promise** — the function returns to the client immediately after Shopify cart creation, and the mockup URL is written to Firestore when ready. The Flutter client polls `users/{uid}/merch_configs/{configId}.frontMockupUrl`.

---

## Step 3 — Extract Mockup URL

Navigate the response:

```typescript
const variantMockups = task.catalog_variant_mockups ?? [];
const matched = variantMockups.find(vm => vm.catalog_variant_id === printfulVariantId)
             ?? variantMockups[0];
const mockupItems = matched?.mockups ?? matched?.placements ?? [];
const collageItem = mockupItems.find(m => m.mockup_style_id === 24458) ?? mockupItems[0];
const mockupUrl   = collageItem?.mockup_url ?? null;
```

---

## Mockup Styles

| Style ID | Description |
|---|---|
| `24458` | **Collage — Front and Back combined** (single image showing both sides) |

Request only the style(s) you need via `mockup_style_ids` to reduce generation time. Omitting the field generates all available styles.

---

## Placement Types (T-Shirt)

| Placement | Description |
|---|---|
| `front` | Full front print area (centre chest, full width) |
| `back` | Full back print area |
| `left_chest` | Small logo area, left chest |
| `right_chest` | Small logo area, right chest |

### Chest Position Pre-Compositing (Roavvy-specific)

Printful's `position` layer field has an aspect-ratio constraint that can cause validation errors. Roavvy works around this by **pre-compositing** the design onto the full print canvas at the correct chest position using Sharp, then sending the full canvas as a plain `front` placement:

```
Canvas: 4500×5400px (150 DPI)
Left chest:  top=7% of canvas height, left=58% of canvas width, max 29%×30% of canvas
Right chest: top=7% of canvas height, left=13% of canvas width, max 29%×30% of canvas
```

---

## Print File Requirements (T-Shirt DTG)

| Property | Value |
|---|---|
| Format | PNG (transparent background supported) |
| Canvas size | 4500 × 5400 px |
| DPI | 150 |
| Background | Transparent (`rgba(0,0,0,0)`) |
| Colour space | sRGB |
| Max upload size | ~10 MB practical limit; Roavvy resizes client artwork to 600px before encoding |

### Back Artwork Centering (Roavvy-specific)

Portrait cards (e.g. passport template, ~2:3 aspect ratio) fill the full 5400px canvas height when scaled with `fit: 'inside'`, making the design start at the collar (`top=0`). The fix caps artwork to **65% of canvas dimensions** before centering:

```typescript
const maxW   = Math.round(4500 * 0.65); // 2925
const maxH   = Math.round(5400 * 0.65); // 3510
const scaled = await sharp(clientBuf).resize(maxW, maxH, { fit: 'inside' }).png().toBuffer();
const meta   = await sharp(scaled).metadata();
const left   = Math.round((4500 - meta.width)  / 2);
const top    = Math.round((5400 - meta.height) / 2);
// composite onto transparent 4500×5400 canvas at (left, top)
```

---

## Orders API (v2)

**`POST /v2/orders`** — places a fulfillment order after checkout.

```json
{
  "external_id": "shopify-order-id",
  "recipient": {
    "name": "...",
    "address1": "...",
    "city": "...",
    "state_code": "...",
    "zip": "...",
    "country_code": "GB"
  },
  "items": [
    {
      "variant_id": 474,
      "quantity": 1,
      "files": [
        { "url": "https://...", "type": "default" },
        { "url": "https://...", "type": "back" }
      ]
    }
  ]
}
```

| File type | Placement |
|---|---|
| `"default"` | Front print area |
| `"back"` | Back print area |

---

## Product Reference (Roavvy)

### Gildan 64000 Unisex Softstyle T-Shirt

| Property | Value |
|---|---|
| Printful product ID | `12` |
| Technique | DTG (`"dtg"`) |
| Print canvas | 4500 × 5400 px @ 150 DPI |
| Background | Transparent |

**Variant IDs (verified 2026-03-24 via `GET /v2/sync-products/{id}/sync-variants`):**

| Colour | S | M | L | XL | 2XL |
|---|---|---|---|---|---|
| Black | 474 | 505 | 536 | 567 | 598 |
| White | 473 | 504 | 535 | 566 | 597 |
| Navy | 496 | 527 | 558 | 589 | 620 |
| Heather Grey | 22352 | 22353 | 22354 | 22355 | 22356 |
| Red | 499 | 530 | 561 | 592 | 623 |

---

## Rate Limits

- General: **120 API calls/minute**
- Mockup Generator: **lower limit** (exact number not published by Printful; treat as ~20–30 RPM)
- Unauthenticated catalog requests: 30/60s; 60s lockout on breach

---

## Authentication

```
Authorization: Bearer <PRINTFUL_API_KEY>
Content-Type: application/json
```

The API key is a private token created in the Printful Developer Portal. It is stored in Firebase Functions environment config as `PRINTFUL_API_KEY`.

---

## Sync Products API

**`GET /v2/sync-products/{id}/sync-variants`** — returns `catalog_variant_id` for each sync variant. Used to build the `PRINTFUL_VARIANT_IDS` lookup table in `printDimensions.ts`.

---

## Roavvy Integration Architecture

```
Flutter client
  │  POST createMerchCart (Firebase onCall)
  ▼
Firebase Function
  ├─ Sharp: resize artwork → transparent PNG (4500×5400, 65% cap + centred)
  ├─ Upload to Firebase Storage → 7-day signed URL
  ├─ Shopify cartCreate (GraphQL) → checkoutUrl
  ├─ Return to client immediately (~5–10s)
  └─ Background promise:
       POST /v2/mockup-tasks → poll every 3s → on completed:
         Firestore users/{uid}/merch_configs/{configId}.frontMockupUrl = url

Flutter client
  └─ Poll Firestore every 3s (up to 20 attempts = 60s) for frontMockupUrl
       On arrival: display Printful photorealistic mockup image
       Meanwhile: show local shirt preview + "Generating preview…" overlay
```

---

## Common Gotchas

| Issue | Root Cause | Fix |
|---|---|---|
| `catalog_variant_id` silently ignored | Field name is singular; Printful v2 requires the plural array form | Use `catalog_variant_ids: [id]` |
| Back image top-aligned on shirt | Portrait card fills full canvas height (`top=0`) | Cap artwork to 65% of canvas, then centre |
| Function timeout (25s) | Printful polling (up to 75s) was blocking the response | Fire-and-forget; client polls Firestore |
| Duplicate Shopify carts on retry | Client retried when `mockupUrl` was null | Removed `mockupUrl` null check as retry condition |
| Large payload (>5MB) | Transparent PNG cannot be JPEG-compressed | Resize to 600px wide with `dart:ui.instantiateImageCodec(targetWidth: 600)` before sending |
| `mockups` vs `placements` field name | Printful API inconsistency across versions | Try both: `matched?.mockups ?? matched?.placements` |
