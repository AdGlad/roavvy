# M106 — Improve Flag Grid Artwork Quality, Layout Options, and Default Packed Row Algorithm

**Branch:** `milestone/m106-flag-grid-quality-and-layout`
**Status:** Complete
**Created:** 2026-05-10

---

Improve the flag grid artwork used for t-shirt designs so that flags render at higher quality, preserve their aspect ratios, avoid truncation, and fit cleanly within generated artwork for both portrait and landscape layouts.

Add UI controls on the flag grid image screen to allow switching between layout algorithms. The default layout for all flag grid generation must become **Packed Row**.

Do not break the Printful/mockup pipeline or the purchase flow.
Do not regress passport, tour dates, or other card types.
Extend existing flag grid generation rather than replacing it.

---

## Goal

High-quality, print-ready flag grid artwork with aspect-ratio-preserving layout algorithms and a visually balanced default (Packed Row).

## Scope

- Audit flag grid rendering pipeline for quality bottlenecks
- Implement three layout algorithms: Packed Row (default), Normalized Grid, Treemap/Aspect Fit
- Add layout selector UI on flag grid customisation screen
- Set Packed Row as the default throughout the codebase
- Ensure portrait and landscape both work for all algorithms
- Prevent flag truncation; add safe padding/gutters

## Tasks

- [ ] Task 1: Audit flag grid pipeline — source assets, canvas size, scaling, export resolution, Printful mockup processing; report findings and any quality blockers
- [ ] Task 2: Implement `FlagGridLayoutAlgorithm` enum (packedRow, normalizedGrid, treemap) and a `FlagGridLayoutEngine` that dispatches to the correct algorithm
- [ ] Task 3: Implement Packed Row / Skyline algorithm — dynamic row heights, aspect-ratio-preserving scale, portrait + landscape support, gutters, no truncation
- [ ] Task 4: Implement Normalized Container Grid algorithm — identical cells, contain-fit/letterbox logic, no cropping
- [ ] Task 5: Implement simplified Treemap / Aspect-ratio-aware algorithm — variable-width cells per row based on aspect ratios, fills canvas tightly
- [ ] Task 6: Add layout selector UI (segmented control or button row) on the flag grid image/customisation screen; regenerate preview on change; preserve selected flags and orientation
- [ ] Task 7: Set Packed Row as the default in all existing flag grid generation call sites (t-shirt back artwork and any other entry points)
- [ ] Task 8: ADR-156 + update current_state.md, backlog_active.md + flutter analyze clean

## Acceptance Criteria

- Flag grid output no longer truncates flags
- Flags preserve their aspect ratios in all three algorithms
- Flag image quality is visibly improved, or a clear report is provided explaining why better source assets are required
- Flag grid screen provides controls to switch between Packed Row, Normalized Grid, and Treemap / Aspect Fit
- Packed Row is the default layout mode for all flag grid generation
- Portrait and landscape modes both produce clean output
- Multiple flag counts and mixed aspect ratios render correctly
- Canvas/image dimensions may adapt where appropriate without breaking t-shirt purchase flow
- Existing passport, tour dates, and other card types are not regressed
- `flutter analyze` passes

## Dependencies

- Existing flag grid generation code (likely `flag_grid_*.dart` or `card_templates.dart`)
- Printful placement mapper (back artwork dimensions)
- `CardEditorScreen` / flag grid customisation screen

## Risks

- Source flag images may be low-resolution PNGs with no SVG equivalent — this would cap quality improvement; report clearly if so
- Treemap layout for large flag counts can be complex; a simplified row-based aspect-ratio approach is acceptable and should be documented
- Canvas resizing must stay within Printful print area constraints
