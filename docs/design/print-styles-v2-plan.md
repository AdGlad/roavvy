# Print Styles v2 — making the filters convincing

**Status:** ✅ complete (M1–M5 landed). Builds on `print-styles-architecture.md` (the
insertion point, determinism, preview/print tiers, protection mask are all
unchanged). This is a **quality** pass on the effects themselves + new styles.

## Why v1 reads weak (root causes in code)

- **Single-octave noise.** `blotch` / `mottle` / `stampInk` all come from one
  `generateBlotchBytes` (smoothstep value noise, differing only in `cells`), and
  `grain` is single-octave white noise. One octave → soft uniform clouds / TV
  static, not fractal worn ink or film grain.
- **Linear distress erase.** `_erase` maps luminance→alpha linearly, so ink loss
  is gradual and cloudy instead of the sharp, chunky worn edges of real distress.
- **0° halftone grid.** Dots sit on an axis-aligned lattice → looks like a
  regular dot pattern, not a screen. Real AM halftone is rotated ~45° (research:
  darkest ink at 45°, ≥30° apart to avoid moiré; big dots = vintage/comic).

## Research-grounded techniques

- **fBm** (fractal Brownian motion): 4–6 octaves, persistence ~0.6–0.7 for
  jagged natural detail — the standard for grunge/worn surfaces.
- **Two distress modes:** *fade* (fine, low-contrast — many-washes) vs *wearout*
  (thresholded fBm — big worn chunks). One `hardness` param spans both.
- **Halftone:** rotate the AM dot screen ~45°, offset alternate rows; larger
  dots for the vintage/zine look.
- **Riso / newsprint:** limited flat inks (duotone) + angled halftone + grain +
  slight channel misregistration.

## Milestones (all landed — shared files, executed inline)

- ✅ **M1 — fBm noise core.** Added tileable `_valueNoise`/`_fbm` (multi-octave);
  rebuilt `blotch`/`mottle`/`stampInk` on fBm with `octaves`/`persistence`/
  `contrast`; clumped film `grain` (fBm-modulated envelope); varied-angle
  `scratch`. All 15 foundation/determinism tests pass.
- ✅ **M2 — Distress hardness + rotated halftone.** `_erase` gained a contrast
  gain about the midpoint driven by a new `distressHardness` param (0 = soft
  cloudy fade … 1 = sharp worn chunks; cracks/stamp biased crisp). Halftone dot
  screen now rotates to `halftoneAngle` (default 45°) with brick row offset,
  sampling the axis-aligned coverage grid.
- ✅ **M3 — Retuned the 5 presets** (vintage/retro/halftone/stamp/grunge) with
  per-style hardness. Printability guard still passes.
- ✅ **M4 — New styles.** `riso` (duotone + 30° screen), `newsprint` (mono +
  coarse screen), `sunFaded` (heavy warm fade, soft loss), `photocopy` (harsh
  mono toner, hard chips). Enum + preset + label; picker auto-includes them via
  `PrintStyleId.values`.
- ✅ **M5 — Verified.** `flutter analyze` clean on `print_style/` and `merch/`;
  all 34 print_style tests + 11 preview-screen tests green; printability guard
  passes; docs updated.

Determinism, `clean` pass-through, protection mask, and the purchase flow are
unchanged throughout.

## Follow-up styles (post-v2)

- ✅ **Edge Tear.** A ripped-sticker / torn-poster boundary that frays deep into
  the garment. Reuses the torn-edge mask, now with a two-frequency ragged border
  and a strength-scaled depth (`margin = 0.10 + 0.16·strength`) so it tears
  further than the incidental fray on grunge/vintage.
- ✅ **Acid Wash** (researched — trending Y2K/streetwear bleach). A new
  `acidWash` param drives a soft low-frequency `wash` cloud screened over the
  ink (masked to alpha) to lift it toward white in cloudy patches, over a muted,
  faded palette. Lightens ink without erasing it (alpha preserved).

Both added as `PrintStyleId` values + presets + labels; the picker auto-includes
them. Covered by dedicated pipeline tests (edge-tear ring erosion, acid-wash
bleach lift) — 36 print_style tests green.
