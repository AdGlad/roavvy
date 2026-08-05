# reference_analysis

Machine-readable analysis of each reference image — the bridge from a picture to
**recipe-space features** the engine understands. One JSON per reference image
(matching stem), conforming to `reference_record.schema.json`.

Purpose:

1. **Provenance & rights** — where the image came from, whether we can keep it.
2. **Feature extraction** — the closest `DesignRecipe`-space description
   (template, layout, density, palette, print-style feel) plus free-form tags.
3. **Verdict** — liked/disliked + why, which becomes preference-learning signal
   and calibration data for the scorers.

Analyses can be produced by hand or by an offline tool (and may reuse the native
`roavvy/hero_analysis` saliency/colour bridge for palette/focal features). Keep
them in git — they are small and rights-clean even when the source image isn't.
