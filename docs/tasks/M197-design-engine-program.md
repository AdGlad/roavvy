# Program — AI T-Shirt Design Engine (Phase 1 + AI Critic)

**Created:** 2026-07-28
**Architecture:** `docs/design/ai-tshirt-design-engine.md` (APPROVED)
**Constraints:** ≤5 s to present 3 designs · magical (no score badges) · added
alongside the existing carousel · purchase flow untouched · always Printful-printable.

Implemented as a new self-contained package area under
`lib/features/merch/design_engine/`. Output is a `MerchPresetConfig` (+ flag-grid
params/colour/title) → existing `LocalMockupPreviewScreen(initialPreset:)`.

## Milestones

- **M197 — Genome + Travel Profile + contracts** (foundation).
  `DesignParams` (genome, validity/normalize, stable content hash),
  `TravelProfile` + `TravelProfileAnalyzer` (pure, from trips/codes/continents/
  heritage/heroes/persona), and the core interfaces `DesignScorer`,
  `PrintabilityConstraint`, `CandidateGenerator`, `Mutator`, `DesignRenderer`
  (injected). Pure Dart, isolate-safe, fully unit-tested. Blocks the rest.

- **M198 — Printability gate + analytic scorer** (pure). Hard `PrintabilityGate`
  (12×16 @150dpi / M190 area, min feature size, coverage bounds, garment
  contrast, legibility) + geometry `AnalyticScorer` using
  `FlagGridLayoutEngine.compute`. No raster. Depends M197.

- **M199 — Candidate generator + evolutionary loop** (pure orchestration).
  Ranker-seeded generator (`MerchTemplateRanker` priors + `kMerchPresets` +
  persona + diversity injection), `Mutator`/`Crossover`, the budget/cancellation
  loop with injected renderer + scorer, diversity-filtered top-3. Depends M197/M198.

- **M200 — Render queue + pixel scorer**. Throttled UI-thread render queue over
  `CardImageRenderer` (thumbnail pixelRatio) with LRU byte cache; `PixelScorer`
  (contrast/harmony/legibility/measured printability on bytes). Depends M197/M198.

- **M201 — "Design for me" gallery + integration**. New entry alongside the
  carousel; progressive 3-design gallery (best-first, silent upgrade); selection
  → `LocalMockupPreviewScreen(initialPreset:)`. Telemetry on chosen params.
  Depends M197–M200.

- **M202 — AI Art Director (cloud critic)**. Firebase function scoring the 3
  finalist thumbnails + suggesting genome nudges; strict timeout within the 5 s
  budget, thumbnail-only (no photos), cached per params-hash; progressive
  re-rank. Scorer weights + caps + critic flag in RemoteConfig. Depends M199–M201.

## Definition of Done (program)
- [ ] "Design for me" presents 3 printable designs in ≤5 s, best-first.
- [ ] Selecting one opens the existing preview with that design; purchase flow unchanged.
- [ ] Every presented design passes the printability gate.
- [ ] AI critic refines the 3 within budget (or defers, silently upgrading).
- [ ] `flutter analyze` clean; engine unit-tested.
