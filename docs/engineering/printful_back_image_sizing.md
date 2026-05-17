# Printful API v2 — Back Image Sizing Investigation

**Date:** 2026-05-17
**Status:** Investigation complete — root cause confirmed, no code changes made

---

## Problem

The back-print artwork on ordered t-shirts appears smaller than expected.

---

## Current implementation (what the app sends)

The app calls the `createMerchCart` Firebase Function with:

```dart
'backImageBase64':  backImageBase64,   // PNG, downscaled to max 600 px wide
'backPosition':     PrintfulPlacementMapper.mapBack(_backPosition),  // 'back'
```

The function handles all Printful API v2 calls server-side. The app has no visibility into the exact Printful request shape.

**Upload resolution cap:** `_kUploadMaxWidth = 600` in `local_mockup_preview_screen.dart` (line ~897). The comment notes "the server upscales to print dimensions anyway."

**Local preview print area** (`product_mockup_specs.dart`):
`_kTshirtBackPrintArea = Rect.fromLTWH(0.30, 0.22, 0.40, 0.50)` — this is only used for the in-app composite preview and does **not** control Printful print dimensions.

---

## Can Printful v2 control back artwork size?

**Yes.** Printful API v2 order creation supports placement-level options via the `files` array. Each file entry can carry:

| Field | Purpose |
|---|---|
| `type` | Placement key, e.g. `"back"` |
| `url` / `contents` | Image (URL or base64) |
| `position` → `area_width` | Print width in inches |
| `position` → `area_height` | Print height in inches |
| `position` → `width` | Image width within area |
| `position` → `height` | Image height within area |
| `position` → `top` / `left` | Offset within print area |

For **product 12** (Gildan 64000 Unisex T-shirt), the back print area is defined by Printful as approximately **12 × 16 inches** at 150 DPI (the `generatePrintfulMockup` function uses `150` as the `print_resolution`).

### Mockup generation API

Printful's mockup task endpoint also accepts explicit `position` objects that control how artwork is placed within the print area, independently of the order API.

---

## Is the app currently sending sizing fields?

**Confirmed: No.** Both Printful API calls in `apps/functions/src/index.ts` send the back file without any `position` block:

**Mockup API** (`generatePrintfulMockup`, ~line 110):
```typescript
placements.push({
  placement: 'back',
  technique: 'dtg',
  layers: [{ type: 'file', url: backPrintFileUrl }],
  // ← no position block
});
```

**Order API** (`shopifyOrderCreated`, ~line 882):
```typescript
files.push({ url: backPrintFileSignedUrl, type: 'back' });
// ← no position block
```

By contrast, the front chest placement already sends explicit inch-based positioning (e.g. `{ top: 1.12, left: 6.96, width: 3.5, height: 3.5 }`). The back has never had equivalent positioning.

**Root cause:** Without a `position` block, Printful auto-centres the image at a default size that is significantly smaller than the available 12 × 16 inch print area. This is why the back artwork prints small.

---

## What change would be needed

### 1. Add `position` to the mockup API call

In `generatePrintfulMockup` (`apps/functions/src/index.ts`), change the back placement push to:
```typescript
placements.push({
  placement: 'back',
  technique: 'dtg',
  layers: [{ type: 'file', url: backPrintFileUrl }],
  position: {
    area_width:  12,
    area_height: 16,
    width:       12,
    height:      16,
    top:          0,
    left:         0,
  },
});
```

### 2. Add `position` to the order API call

In `shopifyOrderCreated` (`apps/functions/src/index.ts`, ~line 882), change the back file push to:
```typescript
files.push({
  url: backPrintFileSignedUrl,
  type: 'back',
  position: {
    area_width:  12,
    area_height: 16,
    width:       12,
    height:      16,
    top:          0,
    left:         0,
  },
});
```

### 3. Upload resolution

Consider raising `_kUploadMaxWidth` (currently 600 px in `local_mockup_preview_screen.dart`) for back artwork. At 12 inches × 150 DPI the required pixel width is 1800 px; 600 px is well below that. The server comment "the server upscales to print dimensions anyway" may explain past behaviour with Printful's auto-sizing, but with explicit inch dimensions Printful will expect enough source pixels.

### 4. Aspect ratio alignment

The card artwork used for the back (`merchBackCardAspectRatio`) returns `3:2` (landscape) for grid/timeline and `2:3` (portrait) for passport. The Printful back area is portrait (`12 × 16` = `3:4`). A `3:2` landscape artwork in a `3:4` portrait print area will letterbox badly. Either:
- Force back artwork to `3:4` portrait, or
- Set `width`/`height` in the `position` block to fit the artwork's own aspect ratio and let Printful centre it with whitespace rather than stretching.

---

## Risks of changing

| Risk | Severity | Mitigation |
|---|---|---|
| Breaking existing orders | High | Test in Printful sandbox before prod deploy |
| Position values outside Printful's accepted range for product 12 | Medium | Validate against Printful product spec endpoint |
| Different products need different position values | Medium | Look up per-product print area specs; don't hardcode for one product |
| Raising upload resolution increases Function memory/timeout | Low | Profile; Function already handles ~1.7 MB base64 at 600 px |

---

## Recommended next step

1. Verify the exact `area_width`/`area_height` for product 12 (Gildan 64000) against Printful's product spec endpoint (`GET /v2/catalog/products/12`) — confirm the 12 × 16 inch print area before hardcoding.
2. Test in Printful sandbox: add the `position` block to the mockup call first and confirm the preview looks full-bleed before touching the order API.
3. Decide on back artwork aspect ratio (see §4 above) — this affects what `width`/`height` to set in the position block and whether the Flutter card renderer needs a new aspect ratio for back-print renders.
