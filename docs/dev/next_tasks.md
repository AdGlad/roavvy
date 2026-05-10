# M106 — Improve Flag Grid Artwork Quality, Layout Options, and Default Packed Row Algorithm

Branch: milestone/m106-flag-grid-quality-and-layout

## Goal

Improve flag grid artwork quality, add three selectable layout algorithms (Packed Row default, Normalized Grid, Treemap/Aspect Fit), and add a layout selector UI on the flag grid screen.

## Tasks

- [ ] Task 1: Audit flag grid pipeline — source assets, canvas size, scaling, export resolution, Printful mockup processing; report findings and any quality blockers
- [ ] Task 2: Implement `FlagGridLayoutAlgorithm` enum (packedRow, normalizedGrid, treemap) and a `FlagGridLayoutEngine` dispatcher
- [ ] Task 3: Implement Packed Row / Skyline algorithm — dynamic row heights, aspect-ratio-preserving scale, portrait + landscape, gutters, no truncation
- [ ] Task 4: Implement Normalized Container Grid algorithm — identical cells, contain-fit/letterbox, no cropping
- [ ] Task 5: Implement simplified Treemap / Aspect-ratio-aware algorithm — variable-width cells per row based on aspect ratios
- [ ] Task 6: Add layout selector UI on flag grid screen; regenerate preview on change; preserve flags and orientation state
- [ ] Task 7: Set Packed Row as default in all existing flag grid generation call sites
- [ ] Task 8: ADR-156 + update current_state.md, backlog_active.md + flutter analyze clean
