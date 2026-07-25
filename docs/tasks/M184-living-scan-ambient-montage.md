# M184 — Living Scan: Ambient Photo Montage

**Status:** `done`
**Created:** 2026-07-25
**Updated:** 2026-07-25
**Depends on:** M181 (representative-assetId threading + throttled thumbnail infra)
**Program:** Living Scan (M181–M186)

---

## Product Rationale

Beyond per-country postcards (M181), a slow ambient crossfade of the user's
photos as they stream past gives the whole scan a "these are the memories we're
reading" mood — the difference between a data process and watching your life
scroll by. It is the layer that makes the wait *pleasant* rather than merely
*informative*.

---

## Scope

### Delivered
- A low-opacity Ken-Burns / crossfade montage layer above/behind the globe that
  cycles representative photos as batches arrive.
- Throttled to ~1 image/second (mood, not strobe).
- Sourced from the representative `assetId`s already captured in M181 (prefer
  existing heroes on re-scan once M186 lands).
- Fully respects reduce-motion (static single image or disabled).
- Degrades cleanly on sparse libraries (falls back to no montage below a
  threshold).

### Out of scope
- Hero-quality curation of montage frames (M186 improves the source).

---

## UX Design

- Placement: subtle full-width band behind the stats/header or a soft backdrop
  behind the globe — tuned in design QA so it never competes with the globe or
  reduces legibility of headline copy (dark scrim as needed).
- Timing: ~1s hold, ~600ms crossfade, gentle scale (Ken-Burns) ≤ 4%.
- Only advances when new photos are available; pauses gracefully at batch gaps.
- Reduce-motion: show a single static representative photo or nothing.

## Architecture

- New `_ScanMontage` widget fed a rolling queue of `assetId`s emitted by the
  scan loop (extend the M181 representative-asset stream to also push a
  bounded FIFO of recent geotagged assetIds, not only per-country firsts).
- Reuse the M181 throttled thumbnail queue; montage and postcards share the
  concurrency cap so combined I/O stays bounded.
- Wire into both the in-screen `_ScanningView` and the M134 overlay surface.
- Memory: keep at most ~2 decoded frames alive (current + next); evict on
  advance.

## Tasks
- T1 — Bounded FIFO of recent geotagged assetIds emitted from the scan loop.
- T2 — `_ScanMontage` crossfade + Ken-Burns widget; shared thumbnail queue.
- T3 — Reduce-motion + sparse-library fallbacks.
- T4 — Integrate into `_ScanningView` and the M134 overlay.
- T5 — Tests: advances on new frames, pauses on gaps, static under
  reduce-motion, disabled below threshold.
- T6 — `flutter analyze` clean; device QA for memory + frame rate.

## Definition of Done
- [ ] Ambient montage crossfades user photos during scan at ~1/s.
- [ ] Never harms globe legibility or headline readability.
- [ ] Reduce-motion and sparse-library paths handled.
- [ ] ≤ 2 decoded frames alive at once; no memory growth over a long scan.
- [ ] Combined montage+postcard thumbnail I/O respects one shared cap.
- [ ] `flutter analyze` no new issues; tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Montage + postcards contend for I/O, slow scan | Medium | High | Shared concurrency cap; small sizes |
| Distracts from globe/heat | Medium | Medium | Low opacity, design QA, easy kill-switch |
| Memory growth over long scans | Medium | Medium | Strict 2-frame retention + eviction |
