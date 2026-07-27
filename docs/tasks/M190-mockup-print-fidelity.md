# M190 — Mockup Print Fidelity (back-first, accurate print area, real Image Size)

**Status:** `done`
**Created:** 2026-07-27
**Depends on:** none
**Program:** Purchase-Flow Tuning (M190–M193)

## Problem
1. The preview opens on the **front**; the main design is on the **back** — the user should see the back first.
2. The local back print area (`_kTshirtBackPrintArea = 0.30,0.22,0.40,0.50`, aspect 0.80) renders the design **larger than Printful actually prints**, and its aspect doesn't match Printful's **12″×16″** DTG back area (aspect 0.75).
3. **Image Size (S/M/L) is preview-only cosmetics.** `merch_image_processor.processBack` contain-fits the artwork into the **full** 1800×2400 printfile regardless of `imageSize`, and the M189 scaling grows the *print rect* about its centre (so **Large exceeds the printable area** — "much bigger than allowed in Printful"). Preview ≠ print.

## Fix
- **Default to back:** `_showingFront = false` (local_mockup_preview_screen.dart:312). Flip toggle unaffected.
- **Accurate printable area:** recalibrate `_kTshirtBackPrintArea` to a **0.75 aspect** rect matching the real 12×16 area on the back mockup photo, erring slightly conservative (user reports it's too big). Same for the poster/front where relevant (leave front chest as-is unless obviously wrong).
- **Redefine Image Size semantics:** the printable-area rect is **fixed**; `imageSize` scales the **artwork within** that fixed rect (contain-fit into a centred sub-rect), **capped at 100% (Large)** so it never exceeds the printable area. Small ≈ 0.65, Medium ≈ 0.85, Large = 1.0 of the printable area. Remove the "scale the rect about centre / per-placement max" model that could exceed bounds.
- **Make Image Size real in the order:** `processBack` (and front) must inset the artwork within the 1800×2400 printfile by the **same** `imageSize` fraction, so the printed design matches the preview. Thread `imageSize` into `processBack` and the `createMerchCart` path.

## Tasks
- T1 — Default face = back.
- T2 — Recalibrate back (and poster/front if needed) printable-area rect to 0.75 aspect, conservative size; document the numbers.
- T3 — Reframe `ImageSize` as an artwork scale *within* the fixed printable rect (S/M/L → 0.65/0.85/1.0), capped at 1.0; update `product_mockup_specs.dart` + the painter path so the preview draws the artwork at that sub-scale, centred.
- T4 — Thread `imageSize` into `merch_image_processor.processBack` (+ front) so the print file insets the artwork by the same fraction; verify `createMerchCart` payload carries it.
- T5 — Update/extend `product_mockup_specs_test.dart` + `merch_image_processor` tests for the new semantics (Medium default, Large == full printable, Small centred inset).
- T6 — `flutter analyze` clean; note that exact rect needs a Printful side-by-side device QA.

## Definition of Done
- [ ] Preview opens on the back.
- [ ] Design in the preview is no larger than the real Printful printable area; Large never exceeds it.
- [ ] S/M/L visibly change the size **and** are reflected in the print file sent to Printful (preview == print).
- [ ] `flutter analyze` clean; tests pass.
