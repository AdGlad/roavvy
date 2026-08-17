# C-00 — Rendered-Evidence Evaluation (fair scoring of render-dependent families)

- **Status:** Lane B ✅ DONE (2026-08-16); Lane A 📋 specced (on-device)
- **Why:** cycles C-01 & C-02 both hit the same wall — the analytic `quality_model`
  scores geometry/parameters and cannot *see* rendered output, so it systematically
  **under-credits families whose quality lives in rendering** (type-hero lockups,
  passport stamps, print/flag treatments). This blocked fair validation of the
  highest-value catalogue multipliers.

## The finding (why a headless render path isn't the answer)
`CardImageRenderer` rasterises a Flutter widget via `RepaintBoundary` + post-frame
capture and depends on SVG flag/stamp asset loads. Its own thumbnailer test
(`card_render_thumbnailer_test.dart`) is **deliberately skipped**: *"headless
frame-capture is timing-flaky … covered by on-device QA (M201)."* The torn family
renders headlessly only because it is pure `dart:ui` on a synthetic flag. So a
*deterministic* headless render path for full composition designs is not reliably
achievable in `flutter test`. C-00 therefore has two lanes.

---

## Lane B — Close the analytic blind spots (DONE, testable now)
Correct the specific mis-measurements that caused the under-crediting, so the
headless scorer judges render-dependent families fairly **without** rendering.

### B1 · Type-led focal credit ✅
`quality_model.dart` gave every type-led design the `else → 0.45` "no focal point"
default. But a bold wordmark/stat **is** a maximally clear focal by construction
(R-VH-01, R-STORY-03). Fix: a `HierarchyMode.typeLed` branch —
`focalContrast = (0.55 + 0.3·heroScale)` (≈0.70–0.79).

**Result (regression, zero regressions — strict improvement):**
| Context | Δ meanQuality |
|---|---|
| lifetime | **+0.014** |
| massive-light | **+0.013** |
| region-europe | +0.010 |
| several-countries | +0.006 |
| year | +0.004 |
| two-countries | +0.001 |
| one-country-* | 0.000 (already had a focal) |

The weakest contexts improved most — exactly where the fairly-credited type-led
families (`statementCount`, `typographicIntegration`) operate. The engine will now
**select** premium type-led designs correctly instead of under-ranking them.
Baseline regenerated to lock in the fairer scores.

### B2 · Future analytic closers (backlog)
- A treatment/template "renderability" proxy so passport-stamp-style families
  (C-02) aren't judged only on geometry.
- Wire the existing **pixel scorers** (`pixel_scorers.dart`, contrast/harmony/edge)
  onto any thumbnail that *does* render, as an optional bonus signal.

## Lane A — Rendered capture (BUILT: best-effort host harness + on-device upgrade)

### A1 · Host best-effort capture harness ✅ BUILT
`test/features/merch/design_engine/procedural/render_capture.dart` — a
`testWidgets` harness that renders representative recipes via the real
`CardRenderThumbnailer`/`CardImageRenderer` and writes PNGs + `manifest.json` +
`index.html` into `design_studio/generated_batches/rendered_<label>/`. It
**tolerates per-design render failures** (bounded pump budget, immediate asset
fallback) so the documented flakiness can't hang it.
Run: `RENDER_CAPTURE=1 flutter test .../procedural/render_capture.dart`.

**First run (2026-08-16): rendered 5 / 12** (singleHero, negativeSpaceCutout,
dominantAccent, duoBlend), 7 skipped. Real flag art + layout captured. This already
paid for itself — two findings the analytic scorer is blind to:
- **Text = tofu.** Custom fonts don't load headless, so titles/footers render as
  solid black boxes. Text-bearing designs — including the type-led `statementCount`
  — need the on-device path (A2) for fidelity; the type-led families are also the
  ones that failed to render here.
- **A genuine generator critique.** One-country `singleHero` rendered as a **3×3
  repeated flag grid**, not one bold hero — contradicting its own intent (R-VH-01)
  despite a 0.85 analytic hierarchy score. Only the pixels caught it. → logged to
  the optimisation roadmap as a real weakness.

**Harness reliability (tuned 2026-08-16):** raising `assetsTimeout` 0→6s + real
wall-clock drive lifted success **5/12 → 5/6**. Renders are deterministic (byte-
identical across timeouts) but NOT verified to match on-device (fonts→tofu; GPU
shaders don't run; some SVG outlines fall back).

**The triage rule (crucial — avoids chasing phantom bugs):**
- A suspect render is a **fixable bug only if the RECIPE confirms it** (like E-005's
  `rowCount 3`, unambiguous from JSON). Fix those headless.
- If the recipe is correct and the defect is render/asset/shader-level, it is
  **deferred to Lane A2 (on-device)** — do NOT tune the generator on an unverified
  headless render.
- First application (2026-08-16): rendered review flagged 3 suspects, recipe
  cross-check cleared all 3 as non-recipe (deferred to A2):
  `negativeSpaceCutout` tiny = `africa` continentOutline SVG didn't load (recipe
  heroScale 0.897 correct); `duoBlend` unblended = GPU shader off headless
  (`layerMode: flat`); `dominantAccent` fragmented = legal but weak params
  (heroScale 0.39 + small + montage + circle) — a low-confidence tuning candidate,
  not a bug. Only E-005 was recipe-confirmable → fixed.

### A2 · On-device capture (full fidelity, the pixel-truth path) — ✅ BUILT
Runbook: `design_studio/tools/LANE_A2_ONDEVICE_CAPTURE.md`. Pieces:
`integration_test/device/design_render_capture_test.dart` (renders on the sim) →
`test_driver/design_render_capture_driver.dart` (host driver writes report.json) →
`design_studio/tools/decode_device_capture.sh` (→ PNGs + contact sheet). One
command: `flutter drive --driver=… --target=… -d <sim>`.

Where headless is unreliable (text, SVG-heavy, large sets), capture on device:
1. **Capture:** an integration-test / debug screen (M201 path) renders the recipe
   set on a booted simulator where `CardImageRenderer` + fonts + SVGs are reliable.
2. **Import:** PNGs → `generated_batches/rendered_<id>/` with the recipe manifest.
3. **Critique:** `design-critic` + `reference-analyst` review the contact sheet vs
   the KB (same protocol as the torn PNG batch).
4. **Calibrate:** best renders → `reference_images/liked/` to seed the deferred
   `referenceAffinity` scorer.

A1 gives an immediate, runnable critique surface today; A2 is the full-fidelity
upgrade that unblocks C-02 (passport-stamp) and the print/flag treatments (C-04/C-05).

---

## Evaluation-criteria update (KB gets smarter)
- **Type-led designs have a real focal** — scored, not defaulted (B1, shipped).
- **Render-dependent families must not be rejected on the analytic proxy alone** —
  route them through Lane A before a keep/reject call (unblocks C-02, C-04, C-05).
- Recorded here + in the discovery roadmap (C-00) + family catalogue.
