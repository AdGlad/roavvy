# Topic: Print Techniques

**What it governs:** emulating a premium screen-print look in a digital pipeline
that outputs to DTG (Printful). The gap: you print full-colour DTG, but the
aesthetic that reads premium is limited-spot-colour screen-print.

## Principles
- **Emulate fades with halftones, never smooth gradients** — the dot is the
  fingerprint of real screen-print; gradients band/halo on DTG dark garments.
  (R-PRINT-01)
- **Halftone 35–65 LPI, rotated angle (15/45/75°, never 0/90°)**, scaled to print
  size. Coarse dots read as intentional retro and hold ink. (R-PRINT-02)
- **Rasterize effects at true print DPI; smallest feature ≥ printable.** The #1
  procedural failure is grain tuned on a small preview then upscaled to mud.
  (R-PRINT-03)
- **Reproduction limits:** min line ≥~1.5 pt, text ≥~6–7 pt, knockout ≥8 pt. DTG
  ink spreads; hairlines break, counters fill, small type mushes. (R-PRINT-04;
  gate already enforces `minFeaturePx`)
- **Break large solid fills; avoid full-bleed** (wrinkle/banding/halo). **Trap /
  slightly overlap adjacent colours.** (R-PRINT-05, R-PRINT-06)
- **Export 300 DPI transparent PNG at physical size, clean alpha edge** — a white
  box prints as a rectangle; a 1px halo prints as a grey underbase fringe.
  (R-PRINT-07)
- **Design for the garment; off-white>white, warm-black>black** (underbase halo).
  (R-COL-02, R-COL-08)

## Rules in this topic
R-PRINT-01 … R-PRINT-07 (with R-COL-02/08, R-TEX-01…05, R-TREND-02).

## Scorers / gates
Mostly the **`printabilityGate`** (hard: min feature, coverage band, garment
contrast, DPI). `edgeDensity` catches over-busy halftone/detail.

## Engine implication
Most of this is already enforced by `printability.dart`
(`minFeaturePx: 90`, coverage `[0.12, 0.98]`, ΔL `0.30`, 1800×2400 @150 DPI).
The KB adds: promote "≤N stacked effects" and "grain ≥ printable at final DPI" to
gate status, and ensure every generated asset is validated at printfile resolution
— not preview resolution — before scoring. See `engine_recommendations.md` §3a.
