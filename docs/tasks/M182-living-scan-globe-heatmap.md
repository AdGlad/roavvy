# M182 — Living Scan: Globe Heat Map

**Status:** `done`
**Created:** 2026-07-25
**Updated:** 2026-07-25
**Depends on:** none (independent; reuses existing `GlobeHeatmapData`)
**Program:** Living Scan (M181–M186)

---

## Product Rationale

The scan globe is currently **binary** — a country is gold (visited) or not.
The user asked to "build up the heat map." Intensity is meaningful data we
already collect live (per-country `photoCount`, and raw per-photo GPS in
`allPhotoGps`). Making the globe visibly *heat up* as batches stream in —
countries you lived in blazing, a single-photo layover glowing faintly — turns
a progress wait into something inherently satisfying to watch.

Low risk: `GlobePainter` already accepts `GlobeHeatmapData? photoHeatmap`
(used on the Map screen). This milestone wires that existing pathway into the
live scan globe and animates it during the scan.

---

## Scope

### Delivered
- **Density glow:** each country's fill intensity / soft bloom scales with its
  live accumulated `photoCount`.
- **Point-level heat:** faint accumulating heat contribution at photo GPS
  clusters (Paris hotter than rural France), fed from `allPhotoGps`.
- Heat layer coexists with the existing travel-arc replay, newly-discovered
  gold highlight, pulse halo, and heritage dots.
- Reduce-motion: heat renders as a static final-state layer (no pulsing/ramp).

### Out of scope
- Redesign of the resting Map-screen globe (only the scan surface changes here).
- New heat colour ramp design system (reuse the Map screen's existing ramp).

---

## UX Design

- Heat is an **additive layer** under the gold country fills, not a replacement.
- As each batch lands, affected cells ramp up smoothly (short tween) so the
  globe "warms" progressively rather than popping.
- Keep gold newly-discovered highlight + pulse on top for readability.
- Colour ramp reuses `GlobeHeatmapData`'s existing scheme for visual
  consistency with the Map tab.

## Architecture

- `_ScanGlobeWidget` currently passes `tripCounts: const {}` and no heatmap to
  `GlobePainter`. Populate `photoHeatmap: GlobeHeatmapData(...)` built live.
- Accumulate heat from two sources already in memory during `_scan()`:
  - per-country `photoCount` (from `accum` / `_DiscoveryEntry.photoCount`)
  - raw `allPhotoGps` points for point-level density.
- Thread the accumulating heat data into `_ScanningView` → `_ScanGlobeWidget`
  the same way `liveHeritageSites` is threaded today (new widget field).
- For the **M134 overlay surface**, emit heat updates through the live source
  (or recompute from the codes/GPS the overlay already receives).
- Throttle heat recomputation to once per batch (not per photo) and reuse the
  bucketed GPS grid already computed in `resolveBatch` to keep it cheap.

## Tasks
- T1 — Confirm `GlobeHeatmapData` construction API from the Map screen usage;
  document the minimal inputs needed.
- T2 — Accumulate live heat (country counts + GPS point density) in `_scan()`;
  expose via new `_ScanningView` field.
- T3 — Wire `photoHeatmap` into `_ScanGlobeWidget`'s `GlobePainter`.
- T4 — Smooth per-batch ramp tween; static render under reduce-motion.
- T5 — Wire heat into the M134 overlay scan globe.
- T6 — Widget/golden-free tests: painter receives non-null heatmap when photos
  present; empty when none.
- T7 — `flutter analyze` clean; device QA for perf (no frame drops on large
  libraries).

## Definition of Done
- [ ] Scan globe visibly heats up as batches arrive, scaled by photo density.
- [ ] Point-level clusters read as hotter than sparse regions.
- [ ] Heat coexists with gold fills, pulse, arcs, heritage dots.
- [ ] Reduce-motion renders a static heat layer.
- [ ] No frame-rate regression on a 20k+ photo library.
- [ ] `flutter analyze` no new issues.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Heat recompute per batch drops frames | Medium | Medium | Reuse bucketed grid; throttle to 1/batch |
| Heat visually clashes with gold fills | Medium | Medium | Additive-under layer; tune opacity in QA |
| `GlobeHeatmapData` API not scan-friendly | Low | Medium | Adapter in scan layer; small refactor if needed |
