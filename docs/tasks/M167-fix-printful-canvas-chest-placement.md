# M167 — Fix Printful Print Canvas Size & Chest Placement Coordinates

**Status:** `done`
**Severity:** `high`
**Created:** 2026-06-24
**Reported by:** internal audit before live order test

---

## Description

Two related bugs in the DTG print file generation:

1. **Wrong canvas size**: `printDimensions.ts` specified the t-shirt print canvas as 4500×5400px
   (30"×36" at 150 DPI). Printful's actual printfile spec (confirmed via `GET /mockup-generator/printfiles/12`)
   is **1800×2400px at 150 DPI** (12"×16"). Submitting an oversized file with a different
   aspect ratio (5:6 vs 3:4) caused Printful to scale the image down to 1800×2160 with
   ~0.8" of empty padding top and bottom.

2. **Wrong chest placement coordinates**: The `left_chest` / `right_chest` compositing
   offsets were percentages of the wrong (4500×5400) canvas, producing incorrect absolute
   positions on the actual print area. Left chest landed at ~1.8" from the top of the print
   area; industry standard is 3–4" below neckline.

---

## Root Cause

Canvas size was set by estimation rather than from Printful's API spec. The chest placement
percentages were then tuned against that wrong canvas, making them doubly incorrect.

---

## Fix

### `printDimensions.ts`
- `widthPx: 4500 → 1800`, `heightPx: 5400 → 2400` for all t-shirt variants

### `index.ts` (chest compositing)
Positioning recalculated using industry standard (verified via Printful blog, Swagify, DTF Station):
- Logo size: 3.5"×3.5" = 525×525px at 150 DPI
- Top: 3.0" below top of print area = 450px
- Left chest (wearer's left = viewer's right): logo center at 10" from canvas left (4" right of shirt center = 900px)
- Right chest (wearer's right = viewer's left): logo center at 2" from canvas left (4" left of shirt center)

### Canvas verified against:
- Printful API: `GET /mockup-generator/printfiles/12` → printfile_id 1: 1800×2400 at 150 DPI
- Printful API: `GET /v2/catalog-variants/567` → `placement_dimensions.front`: 12.0"×16.0"

---

## Regression Test

- [ ] Submit a test print file for `left_chest` position and verify the logo appears at
  wearer's left chest (not center, not misaligned) on the Printful order mockup.
- [ ] Verify canvas dimensions are 1800×2400 in generated print files.

---

## Definition of Done

- [x] `printDimensions.ts` canvas corrected to 1800×2400
- [x] `index.ts` left_chest / right_chest pixel coordinates corrected
- [x] TypeScript compiles cleanly (`npm run build`)
- [x] Deployed via `firebase deploy --only functions`
