# Torn / Ripped Flag Engine v2 — design + plan

**Status:** M1–M6 shipped (2026-08). Engine lives in
`lib/features/merch/design_engine/torn/` (recipe, geometry generator, mask
renderer, quality metrics); `PrintStyleId.edgeTear` routes through it. Studio
batch: `TORN_STUDIO_BATCH=1 flutter test .../torn/torn_studio_batch_test.dart`
(avg score ~0.90, all interior-clean + edge-concentrated). Benchmark refs:
`design_studio/reference_images/liked/torn/`
(torn-through-usa, torn-vertical-usa, usa-torn-color-bw). **Prime requirement:
rips/tears/missing material ORIGINATE FROM and CONCENTRATE ON the outer edges of
the flag** — never random centre holes (centre only very subtle secondary
weathering).

## 1. Reference findings
- **Edge-concentrated, directional fraying** — material dissolves inward from the
  outer edges into long tapering **streamers/fingers** that follow the flag's
  grain (horizontal streamers along the stripes on the fly/right edge; vertical
  hanging strips on the bottom hem).
- **Strong asymmetry** — one or two edges heavily torn; the opposite edge and the
  **star canton stay intact** (a real flag is attached at the hoist).
- **Multi-scale variation** — long intact runs, occasional deep tears / large
  missing sections, small notches, and fine fibre roughness — not uniform noise.
- **Subtle secondary weathering** (grunge/cracks/fade) over the cloth; dominant
  feature remains the edge tearing.
- Transparent gaps (garment shows through); works full-colour and mono; reads
  clearly as a torn flag (apparel-suitable).

## 2. Shortcomings of the current implementation
Current torn = the `edgeTear` print style (`generateTornEdgeBytes`, applied
`dstOut`) + `rippedFlag` (`generateGashBytes`, a central gash).
- **All four edges torn ~uniformly** — no independent per-edge control, no strong
  asymmetry (refs keep hoist/canton intact).
- **No directional streamers/fingers** — it's a ragged *boundary* (a coastline),
  not separated tapering fingers following the grain. **This is the biggest gap.**
- No large-missing-section vs small-notch distinction; no grain awareness; no
  corner-damage control; "fibres" are tiny hash flecks, not long strands.
- It's baked into the print-style pass (gated by `PrintStyleId`), **not** a
  first-class, reproducible geometry system decoupled from the filter.

## 3. Proposed torn-edge algorithm (`TornGeometryGenerator`)
Produces a **grayscale alpha mask** for a W×H artwork; opaque = kept, 0 = torn
away. Applied with `dstIn` to the (single or blended) flag. All randomness from
`hash(seed, edge, featureIndex)` → deterministic. Supersampled 2–4× then
downsampled for clean fibre AA.

Per edge (top/bottom/left/right), independently, with `t` along the edge and `d`
inward distance:
1. **Boundary depth `depth(t)`** — 1-D fBm (5 octaves, persistence ~0.5,
   lacunarity ~1.93, base ~3–6 cycles) × `edgeWeight[edge]`, **gamma-biased**
   (γ 1.8–3.0) / soft-thresholded so ~50–70% stays intact with occasional deep
   bites. Clamp to `maxDepth[edge]`.
2. **Large missing sections** — low-freq Worley/cellular along the edge; a random
   subset of cells (`largeTearProbability`) get depth ×2–3 with straight-ish
   chunk boundaries.
3. **Streamers/fingers (the key step)** — an **anisotropic strand field**
   stretched along the inward/grain axis (3:1–8:1). Keep-test: pixel `(t,d)` is
   kept iff `d < depth(t)` **AND** `strand(t) > d/reach` — the second condition
   turns the boundary into **separated tapering fingers** (each thins to a point
   with a taper envelope, power 1–2).
4. **Domain warp** — bend/split strands via low-amp perpendicular noise (2 octs,
   3–10% of depth) so they read as fabric threads, not a comb.
5. **Fibre roughening** — a thin (2–5 px) very-high-freq perturbation only in the
   boundary band; centre stays crisp.
6. **Corner damage** — sum adjacent edges near corners + a radial corner tear
   (`cornerDamage`, +30–60%).
7. **Protection & asymmetry** — hard-zero damage over the canton/protected region;
   defaults bias fly/bottom heavy, hoist/top near-intact.
8. **Connectivity** — keep-test monotone in `d` (+ optional small connected-
   component cull) so no floating islands.

Per-edge **grain direction**: fingers elongate perpendicular-inward (horizontal
on L/R fly edges = along stripes; vertical on top/bottom = along hang).

## 4. Recipe model (`TornRecipe`)
```
TearStyle style;                 // named family
Map<FlagEdge,double> edgeWeights;// per-edge damage (asymmetry)
double edgeDamageAmount;         // global 0..1
double maxTearDepth;             // fraction of dim
double tearFrequency;            // bays/notches per edge
double largeTearProbability;
double notchScale;
double frayAmount;               // fibre band + strand density
double cornerDamage;
double asymmetry;                // spread of edgeWeights
int seed;
```
**Curated families** (each = bounded ranges + seed variation): Lightly Worn ·
Ragged · Torn Corners · Battle Worn · Deep Rips · Frayed · Asymmetric Tear ·
Heavy Edge Damage. Every family yields many variations by seed within its ranges.

## 5. Rendering approach
- **CPU-generated alpha mask** in Dart (the algorithm above), decoded to a
  `ui.Image`, applied `dstIn` to the flag artwork on a `ui.Canvas` — cross-
  platform (Skia/Impeller), local, deterministic, cacheable. (Connectivity +
  fingers are far simpler + cacheable on CPU than in a fragment shader; shader is
  a later perf option only if needed.)
- **Multi-flag**: blend flags FIRST (existing composite / `MergedFlagRenderer`),
  then apply the perimeter mask to the composite → one shared torn silhouette.
  The geometry is flag-agnostic.
- **Secondary weathering**: optional subtle distress/grain/fade via the existing
  `PrintStylePipeline` after masking.
- **Realtime feed**: low-res mask (≈512–768) for previews, prefetch + cache by
  `TornRecipe` content hash; high-res only for saved/purchased designs.

## 6. Architecture, milestones & acceptance
`TornRecipe → TornGeometryGenerator → Mask(ui.Image) → Renderer`. No per-country
PNGs; one deterministic geometry system for every flag.

- **M1 — Recipe model + curated families** (data + tests).
- **M2 — Edge-boundary geometry**: per-edge fBm depth + gamma bias + per-edge
  weights + asymmetry → mask (no fingers yet). *Delivers the core edge-
  concentration + asymmetry.*
- **M3 — Streamers/fingers**: anisotropic strand field + taper + warp + grain-per-
  edge. *The key visual.*
- **M4 — Large sections + corners + fibre roughening + connectivity + AA
  supersample.**
- **M5 — Renderer integration**: apply mask to single/blended flag; wire into the
  Auto-designs flow (new torn path) + secondary weathering; preview/print tiers +
  cache.
- **M6 — Design Studio evaluation**: batch into `design_studio`, compare vs refs,
  scoring criteria, tune to reference quality.

### Acceptance tests
- **Edge concentration**: removed alpha lies within an outer band; inner ~60% has
  ≈0 removed (no random holes).
- **Asymmetry**: an asymmetric recipe removes far more on one edge than its
  opposite; canton region preserved.
- **Fingers**: near a torn edge the alpha profile shows *separated* strands
  (alternating kept/gap along the edge, varying depth) — not one monotone edge.
- **Determinism**: same recipe+seed → byte-identical mask.
- **Variation**: different seeds → materially different silhouettes.
- **Multi-flag**: applying to a 2-flag composite yields one shared silhouette.
- **Readability**: canton/key detail preserved.
- **Perf**: preview-resolution mask under budget for the feed.
- **Studio**: generated batches visually approach the references.
