# reports

Rolled-up findings from the studio loop — the feedback that changes the grammar,
config, and preference priors.

Typical reports (one JSON or Markdown per run, dated):

- **Batch quality summary** — score distributions per scope/template; where the
  engine is weak (e.g. "trip scope: titles clipped at massive density").
- **Config sweeps** — the same batch under different `engine_config.json`
  values (budget, weights) with quality/latency deltas → recommends defaults.
- **Perf/memory profile** — per-render wall-clock and peak memory at each
  `imageSize`, on-device, to keep stage 4 within the real-time budget.
- **Regression report** — which goldens moved and why.

Reports are the only place that recommends changes to shipped defaults; changes
themselves land in `design_engine/config` + the Dart engine, never here.
