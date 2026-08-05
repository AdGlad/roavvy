# reference_images/liked

Curated exemplars of T-shirt designs we **want the engine to emulate**.

- One image per file. Name descriptively: `grid-montage-europe-vintage-01.png`.
- For **every** image add a sibling record in `../../reference_analysis/`
  (`<same-stem>.json`) capturing provenance/rights and the recipe-space features
  it exemplifies. An image without an analysis record is incomplete.
- Prefer our own renders. Third-party images only with rights cleared, recorded
  in the analysis record.
- Images are git-ignored by default (see `design_studio/.gitignore`); commit a
  specific one with `git add -f` once rights are logged.

These positives define the quality bar and, via `reference_analysis`, seed the
"looks like liked" signal and the initial `featureWeights` priors.
