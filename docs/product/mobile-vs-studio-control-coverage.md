# Mobile ↔ Studio (Mac) — Control-Feature Coverage Audit

Compares every customer-facing control in the **mobile** merch editor
(`apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart` + the
`ProceduralDesignRecipe` genome) against the **Studio** design engine on Mac
(`apps/design_lab/lib/studio_canvas_screen.dart` + `packages/design_forge`).

Status key: ✅ covered (often a superset) · ⚠️ partial · ❌ missing · ⏸ deferred by design.

## Coverage matrix

| Mobile control | Studio equivalent | Status |
|---|---|---|
| Print style (13 ids) | Vibe (13 LabStyles) + Finish presets + Effects/Print/Edges sliders | ✅ superset |
| Garment colour | Tier‑1 Colour swatches | ✅ |
| Clip shape ("Style" carousel) | Detail (Grid/Map/Animals/Plants/Landmarks/Heart/Circle) + silhouette picker | ✅ |
| Layout mode (packedRow/normalized/montage/treemap) | Fill dropdown (grid/treemap/voronoi/mosaic/radial/…) | ✅ superset |
| Image size (print scale) | Tier‑1 Size S/M/L | ✅ |
| Orientation (portrait/landscape) | Tier‑1 Aspect (portrait/landscape/square) | ✅ superset |
| Front placement (Left/Centre/Right/None) | Front fit Full/Chest(Left/Right)/None (same mobile rects) | ✅ |
| Back title text + cycle suggestion | Words editor + Suggest titles | ✅ |
| Passport stamp mode (entry/exit/both) | Graphic → Stamps (entryExit/entryOnly/exitOnly) | ✅ |
| **Passport stamp size** | Graphic → **Stamp size** slider (clip.scale 0.5–1.5) | ✅ **added** |
| Passport scatter | Graphic → Scatter | ✅ |
| Stamp Style / ink (passport) | Colour Multi/Mono | ✅ |
| Effects amounts (distress/grain/halftone/fade) | Effects sliders (+ cracks/acid/tie‑dye/shatter/ripple) | ✅ superset |
| **Ribbon countries — Selected vs All** | Front → **Selected / All** pills (art = ribbon) | ✅ **added** |
| Rows / Count slider | Layout → "Copies" | ⚠️ semantics differ |
| Back placement (Centre / None) | Back = main design (no blank‑back) | ⚠️ |
| **Country source — Countries vs Trips** (per‑visit) | Trips row → **Countries / Trips** pills (rebuilds context) | ✅ **added** |
| **Trip‑year filter** | Trips row → **year RangeSlider** (DateRange.years) | ✅ **added** |
| Region fill — solid vs per‑country (continent outlines) | — | ❌ |
| Timeline text colour | — | ❌ |
| Garment size XS–XXL | — | ⏸ cart/Printful attribute (reconciliation §4) |

## Remaining gaps (prioritised)

**Medium**
- **Region fill** (solid region vs per‑country) for continent outlines.
- **Back = None** (blank back) — the Studio back is always the main design.
- **Rows vs Copies** naming/semantics alignment.
- **Timeline text colour**.

## Not a real gap (neither side renders them)
`ProceduralDesignRecipe` carries **placement anchor, crop mode, whole‑design
rotation, layer mode, flag treatment (tinted/outline), flag‑combination/duo‑blend**
but its own comment notes these "do not yet change pixels" on mobile either — so
they are unrendered genes on both sides, not a Studio regression. `showTitle` /
`showFooter` visibility toggles are mobile‑only and low value.

## Where the Studio leads mobile
Per‑axis **lock 🔒**, **undo/branch** history, **preference learning**
(delete‑to‑learn), **Remix**, richer **Fill/Effects/Edges** sets, front
**Complement / Match‑back** art sources, and a live single‑recipe canvas.

---
_Added: **Passport stamp size**, **Ribbon Selected‑vs‑All**, and **Source
Countries‑vs‑Trips + trip‑year filter** (a "Trips" row shown only when the context
carries trips; rebuilds the effective `DesignContext` via `DateRange.years` +
`TravelHistory.inRange`). All mobile‑parity. lab 78 tests green, analyze clean._
