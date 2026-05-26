# M131 — Scan: Cinematic Discovery Replay Sequence

**Status:** Complete (2026-05-26)
**Branch:** `milestone/m131-scan-cinematic-replay-sequence`
**Phase:** 25 — Scan UX Transformation
**Depends on:** M130 ✅

---

## Goal

After scan completes, present all discoveries as a full cinematic replay using the existing `GlobeReplayWidget` — chronologically ordered from the user's first-ever trip to today. Heritage sites and achievements are woven into the replay as overlay cards. The replay concludes by pushing `ScanSummaryScreen`.

**Sequence:**
```
Scan runs to completion (fast, in background)
  → GlobeReplayWidget pushed (full-screen cinematic)
  → Globe flies leg by leg, chronologically (earliest → present day)
  → Per-leg: heritage overlays (gold) → achievement overlays (purple) → stat overlays
  → Replay done → onScanComplete fires → GlobeReplayWidget popped
  → ScanSummaryScreen pushed
```

---

## Architecture

Reuse `GlobeReplayWidget` unchanged (except `onScanComplete` param + `ReplayHeritageEvent` support).

Changes:
- **`travel_replay_engine.dart`** — added `ReplayHeritageEvent` sealed subclass; `TravelReplayScript.visitedHeritageSiteCoords`
- **`replay_overlay_widgets.dart`** — added `ReplayHeritageOverlay` widget (amber/green UNESCO card)
- **`globe_replay_widget.dart`** — `onScanComplete: VoidCallback?` param; `_heritagePulseCtrl`; heritage dots via `_CombinedGlobePainter`; suppress `ReplaySummaryScreen` in scan mode
- **`scan_screen.dart`** — `_buildScanReplayScript()` helper builds `TravelReplayScript` from `inferredTrips`; `_NewCountriesFound` branch pushes `GlobeReplayWidget` instead of `ScanSummaryScreen` directly; removed M131 real-time presenter infrastructure

---

## Scope In

- `lib/features/globe_replay/travel_replay_engine.dart` — `ReplayHeritageEvent`, `TravelReplayScript.visitedHeritageSiteCoords`
- `lib/features/globe_replay/replay_overlay_widgets.dart` — `ReplayHeritageOverlay`
- `lib/features/globe_replay/globe_replay_widget.dart` — scan mode support, heritage dots
- `lib/features/scan/scan_screen.dart` — `_buildScanReplayScript()`, replay push on completion

## Scope Out

- Arc flight line (deferred)
- 70% photo threshold for scan phase
- Replay of past scans (separate feature)
- Web

---

## Acceptance Criteria

- [x] Scan runs at full speed — no slowdown during scanning
- [x] After scan completes with new countries, `GlobeReplayWidget` is pushed full-screen
- [x] Replay is chronological — earliest trip first, progressing to present day
- [x] Heritage site overlays show sequentially per leg (gold card, bell-curve fade)
- [x] Achievement overlays show sequentially per leg (purple card, bell-curve fade)
- [x] Visited heritage sites render as amber dots on globe during replay
- [x] `onScanComplete` navigates to `ScanSummaryScreen` after replay finishes
- [x] `ReplaySummaryScreen` suppressed in scan mode (replaced by `ScanSummaryScreen`)
- [x] Existing replay (from map) unchanged
- [x] `flutter analyze` — 0 new warnings
