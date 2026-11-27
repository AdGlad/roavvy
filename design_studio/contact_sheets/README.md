# contact_sheets/ — visual review surfaces

The **contact sheet** is the studio's fast visual-review surface for a batch — the
grid the Design Critic and Reference Analyst scan.

For each generated batch, the sheet is written *inside the batch folder* (so it
travels with its `batch.json`), not copied here:

- **Recipe batches** → `../generated_batches/<batchId>/index.html`
  A parameter-level contact sheet: one card per design, colour-coded by composition
  family, showing template · mask · hero · print-style · colour · size and the
  quality bar. Headless and cheap — no rasterisation.
- **Torn PNG batches** → `../generated_batches/torn_v2/index.html`
  A true raster contact sheet (checkerboard background) of rendered PNGs, for
  visual questions the parameters can't answer.

## Use this folder for
- **Curated cross-batch sheets** — when comparing the *same* contexts/seeds across
  experiments (before/after), drop a small combined `E-###-compare.html` here and
  link it from the experiment folder. Keep these lightweight and delete stale ones.

## Reviewing a sheet
Open the `index.html` in a browser, or have the Critic/Analyst read it via the
agent. Judge **systematically** (patterns across cards per context/family), never
one card at a time — see `../OPTIMIZATION_STUDIO.md` §3 and the `design-critic` /
`reference-analyst` agents.

## signature/ — Signature Workbench reviews (M191, ADR-181)
`signature/<pack>/<label>/` holds `contact_sheet.png` (every country's hero with a QA dot) and
`qa_report.json`, written by the Lab's Signature Workbench (Export sheet / Approve) or headlessly:
`PACK=torn_flag flutter test test/signature_qa_cli_test.dart` in `apps/design_lab`.
PNGs and `review-*` folders are git-ignored; each approval's `v<version>/qa_report.json` is committed.
