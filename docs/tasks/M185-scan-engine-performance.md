# M185 — Scan Engine Performance

**Status:** `done`
**Created:** 2026-07-25
**Updated:** 2026-07-25
**Depends on:** none (pure engine; no UI coupling)
**Program:** Living Scan (M181–M186)

---

## Product Rationale

M183 makes the scan *feel* faster; this milestone makes it *actually* faster.
Three concrete hot spots in `scan_screen.dart` cost real wall-clock time on
large libraries. Fixing them benefits every user and frees headroom for the
new live visuals (M181–M184) without regressing scan duration.

All changes are behind identical outputs — pure optimisation, no behaviour
change — and must be guarded by the existing scan integration tests.

---

## Scope

### Delivered
- **Long-lived resolver isolate.** Today each batch calls
  `Isolate.run(() => _resolvePhotos(countryBytes, regionBytes, photos))`
  (`scan_screen.dart:~517`), which **re-initialises country + region geodata in
  a fresh isolate for every batch**. Replace with a single persistent isolate
  (spawned once, geodata init once) that receives batches over a port.
- **Eliminate the double resolve.** When a batch contains already-known photos,
  the code resolves the batch **twice** (`~:675`) — once filtered, once full —
  to recover GPS. Restructure so each unique photo is resolved once and GPS is
  derived without a second pass.
- **Incrementalise trip inference.** `inferTrips(allPhotoDates)` runs on **every
  batch** over the whole accumulated list (`~:781`, `~:795`) — roughly O(n²)
  across the scan. Compute stable trips incrementally (only the open tail can
  change) instead of re-inferring the full history per batch.

### Out of scope
- Native PhotoKit enumeration changes.
- Changing scan *results* (country/trip/heritage output must be identical).

---

## Architecture

- **Isolate:** introduce a `ScanResolverIsolate` that owns `initCountryLookup` /
  `initRegionLookup` once and exposes `resolve(List<PhotoRecord>) → BatchResult`
  via `SendPort`/`ReceivePort`. `_resolveBatch` posts to it instead of
  `Isolate.run`. Keep the `batchResolver` test seam intact.
- **Single resolve + GPS:** `resolveBatch` already returns `photoGps` for all
  resolved photos. Have it also return GPS for T3-filtered (already-known)
  photos in one pass (GPS collection is exempt from the T3 filter per ADR-157),
  removing the second `_resolveBatch(event.photos)` call.
- **Incremental trips:** maintain a running list of stable trips + an open-tail
  buffer keyed by country/day gap so each batch extends the tail rather than
  re-scanning all `allPhotoDates`. Preserve exact output of `inferTrips` (add a
  differential test asserting parity vs. the batch-recompute for a fixed input).

## Tasks
- T1 — `ScanResolverIsolate`: spawn once, init geodata once, resolve batches
  over a port; retire per-batch `Isolate.run`.
- T2 — Single-pass GPS: extend `resolveBatch` to emit GPS for filtered photos;
  delete the double-resolve branch.
- T3 — Incremental trip inference with a parity test vs. `inferTrips`.
- T4 — Benchmark harness: wall-clock + peak memory on a synthetic 25k / 50k
  photo library, before vs. after.
- T5 — Ensure scan integration tests (mock channel) still pass unchanged.
- T6 — `flutter analyze` clean.

## Definition of Done
- [ ] Geodata initialised once per scan, not once per batch.
- [ ] Each unique photo resolved at most once; no double resolve.
- [ ] Trip inference no longer O(n²) over the scan; parity test passes.
- [ ] Measurable wall-clock reduction on 25k+ library (target: ≥ 30% on the
      resolve+infer portion) with **identical** country/trip/heritage output.
- [ ] All existing scan integration tests pass unchanged.
- [ ] `flutter analyze` no new issues.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Long-lived isolate lifecycle bugs (leaks, cancel) | Medium | High | Explicit dispose on scan end/cancel; reuse `_cancelled` guard |
| Incremental trips diverge from `inferTrips` | Medium | High | Differential parity test on fixed fixtures |
| Refactor changes scan output subtly | Low | High | Golden output test on a fixed photo-date fixture |
