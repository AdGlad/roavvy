# M183 — Living Scan: Perceived Speed

**Status:** `done`
**Created:** 2026-07-25
**Updated:** 2026-07-25
**Depends on:** none (native change in T1 unblocks the rest)
**Program:** Living Scan (M181–M186)

---

## Product Rationale

Perceived speed is mostly a feedback/pacing problem. Today the scan shows an
**indeterminate** bar (`LinearProgressIndicator(value: null)`) — the user has no
sense of a finish line, and the first empty moments (before batch 1) are just a
spinner pill. Knowing "reading 12,400 of 18,000 memories" and seeing the first
recognizable country within a second makes the *same* duration feel far shorter.

This is cheap, high-impact, and complementary to the real-speed work in M185.

---

## Scope

### Delivered
- Native emits an **estimated total** photo count up-front so the Dart layer can
  show determinate progress ("reading N of M").
- Determinate progress bar + a live "N of M memories" counter in the scan
  header, replacing the indeterminate bar.
- **Front-loaded first reveal:** ensure the first recognizable country/photo
  surfaces within ~1–2s (warm-up copy/flourish fills any pre-batch gap).
- Refined phase headline thresholds driven by % complete rather than raw
  processed count.

### Out of scope
- Actual engine throughput changes (M185).

---

## UX Design

- Progress bar becomes determinate once the estimated total arrives; falls back
  to indeterminate gracefully if the estimate is unavailable.
- Counter copy: "Reading 12,400 of 18,000 memories" (comma-formatted, reuse
  `_ScanStatsBar._fmtN`).
- Pre-batch "warming up the globe…" state replaces dead spinner air; dissolves
  into the first postcard/heat update.
- Phase headlines keyed to progress %: Discovering (<33%) → Building your travel
  story (33–80%) → Almost there (>80%).

## Architecture

- **Native (Swift `PhotoScanPlugin`):** add a `ScanStartedEvent` (or reuse
  fetch result count) carrying `estimatedTotal` — the `PHFetchResult.count`
  after applying the `sinceDate` predicate — emitted before the first
  `ScanBatchEvent`. `ScanDoneEvent` already carries `inspected`/`withLocation`.
- **Dart:** extend the sealed `ScanEvent` set with `ScanStartedEvent`; handle it
  in `_scan()` to seed `_ScanProgress.estimatedTotal`.
- `_ScanProgress` gains `int? estimatedTotal`; `_buildScanHeader` renders
  determinate value = `processed / estimatedTotal` when known.
- Incremental scans: estimated total reflects the filtered (`sinceDate`) count
  so the bar isn't dominated by already-known photos.

## Tasks
- T1 — Swift: emit `estimatedTotal` (filtered `PHFetchResult.count`) as a
  start event before batches.
- T2 — Dart: add `ScanStartedEvent`; parse and route in `photo_scan_channel`.
- T3 — `_ScanProgress.estimatedTotal`; determinate bar + "N of M" counter.
- T4 — Pre-batch "warming up" state; guarantee first reveal ≤ ~2s.
- T5 — Progress-%-based phase headline thresholds.
- T6 — Tests: header shows determinate value with estimate, indeterminate
  fallback without; counter formats correctly.
- T7 — `flutter analyze` clean; device QA on large + incremental scans.

## Definition of Done
- [ ] Determinate progress + "N of M memories" shown when estimate available.
- [ ] Graceful indeterminate fallback when estimate missing.
- [ ] First country/photo visible within ~2s of scan start.
- [ ] No dead spinner-only gap before the first batch.
- [ ] Phase headlines track % complete.
- [ ] `flutter analyze` no new issues; tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Estimated total inaccurate (photos added mid-scan) | Medium | Low | Cap bar at 99% until `ScanDoneEvent`; then snap to 100% |
| Native change regresses scan start | Low | High | Keep event optional; Dart tolerates its absence |
