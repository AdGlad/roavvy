# M132 — Live Scan Replay

**Status:** Not Started
**Branch:** `milestone/m132-live-scan-replay`
**Phase:** 25 — Scan UX Transformation
**Depends on:** M131 ✅

---

## Goal

Replace the post-scan cinematic (M131: scan finishes → replay plays) with a **concurrent live replay** — the `GlobeReplayWidget` opens the moment scanning begins and receives country/heritage/achievement discoveries in real time. The globe flies to each new country as it is found, heritage and achievement overlays queue up, and when the scan completes and the queue drains, the summary screen appears.

The existing historical replay (launched from the map) must continue working unchanged.

---

## Context

M131 gave us a working post-scan cinematic: scan → complete → build `TravelReplayScript` → push `GlobeReplayWidget`. This is a good fallback but the experience is not truly live — the user watches a spinner during the entire scan then sees a pre-built replay. M132 makes the replay the scan UI.

---

## Architecture

### New files

#### `lib/features/scan/live_scan_event_queue.dart`
```
LiveScanReplayEvent (sealed)
  ├── LegReplayEvent       — new leg: fromCode, toCode, date, gps coords
  ├── OverlayReplayEvent   — heritage / achievement overlays for latest leg
  └── ScanStatusEvent      — scanProgress (processed count) | scanCompleted

LiveScanEventQueue (ChangeNotifier)
  - addLeg(LegReplayEvent)
  - addOverlays(OverlayReplayEvent)
  - markScanComplete()
  - scanIsComplete: bool
  - pendingLegs: Queue<LegReplayEvent>
  - pendingOverlays: Map<int, List<ReplayOverlayEvent>>  // keyed by legIndex
```

Receives raw scan discoveries from `_ScanScreenState` and converts them to typed events. Deduplicates by ISO code + date. Does **not** infer trips — legs come from consecutive country changes in the running `accum`.

#### `lib/features/globe_replay/live_scan_replay_controller.dart`
```
LiveScanReplayState { scanning, waitingForEvents, presentingLeg, queueDraining, completed }

LiveScanReplayController (ChangeNotifier)
  - Mirrors TravelReplayController phases internally
    (departureSettle, flight, pulse, hold, overlay, done)
  - Consumes LiveScanEventQueue one leg at a time
  - Between legs: polls queue; if empty + scanIsComplete → completed
  - Between legs: polls queue; if empty + !scanIsComplete → waitingForEvents
  - Exposes same surface as TravelReplayController:
      projection, arcProgress, pulseValue, phase,
      currentLegIndex, currentOverlayEvents, currentOverlayEventIndex,
      overlayProgress, speedMultiplier, reducedMotion
  - Adds: liveState, processedCount, queuedLegCount
```

Shares `ReplayPacingRules.forLeg()` and `_callAudio` logic with `TravelReplayController` by moving shared helpers to a `replay_animation_helpers.dart` mixin or top-level functions.

### Modified files

#### `lib/features/globe_replay/globe_replay_widget.dart`
- Accept `LiveScanReplayController? liveController` as alternative to `TravelReplayScript script`
- When `liveController` is set, delegate all animation state reads to it instead of the `TravelReplayController`
- Show "Scanning live…" chip when `liveState == waitingForEvents`
- Show queue depth badge when `queuedLegCount >= 2`
- Suppress speed selector in live mode (pace is already controlled by scan speed)
- Suppress `ReplaySummaryScreen` and `onScanComplete` behaviour remains

#### `lib/features/scan/scan_screen.dart`
- On scan start (`_scan()` begins): build `LiveScanEventQueue`, construct `LiveScanReplayController`, push `GlobeReplayWidget(liveController: ...)` immediately
- In scan batch loop: after each batch, call `queue.addLeg(...)` for any new country transition detected in running `accum`; call `queue.addOverlays(...)` for new heritage/achievement events
- On scan complete: call `queue.markScanComplete()`; controller drains remaining queue then fires `onScanComplete` → `ScanSummaryScreen`
- Remove `_buildScanReplayScript()` (M131) — replaced by live feeding

---

## Scope In

- `lib/features/scan/live_scan_event_queue.dart` — new
- `lib/features/globe_replay/live_scan_replay_controller.dart` — new
- `lib/features/globe_replay/globe_replay_widget.dart` — live mode support
- `lib/features/scan/scan_screen.dart` — start replay on scan begin, feed events per batch

## Scope Out

- Modifying `TravelReplayController` or `TravelReplayScript` (historical replay untouched)
- Changing `GlobeReplayPainter`, `ReplayPacingRules`, `ReplayTimelineBuilder`
- Changing achievement definitions, purchase flow, map styling
- Web platform

---

## Sequencing rules (implementation guidance)

- Only one leg animates at a time — `LiveScanReplayController` does not start a new leg until the previous leg + all its overlays have completed
- If scan emits a new country while the controller is mid-leg: `addLeg()` enqueues silently; controller picks it up after current leg finishes
- `waitingForEvents` state shows a pulsing "Scanning…" indicator in the globe UI; the globe stays on the last visited country
- If the scan completes while the controller is in `waitingForEvents` with an empty queue, transition directly to `completed` (no more legs coming)
- Achievements and heritage overlays are attached to the leg during which they were discovered; if discovered between legs they attach to the next leg
- `speedMultiplier` from the user's speed selector applies in live mode

---

## Audio

`LiveScanReplayController` uses the existing `ReplayAudioController` (already covers travel, arrival, achievement, heritage, end sounds). No new audio files needed.

---

## State diagram

```
idle
  → [scan starts, push GlobeReplayWidget] → scanning
scanning
  → [new leg in queue] → presentingLeg
  → [queue empty, scan still running] → waitingForEvents
  → [queue empty, scan complete] → queueDraining → completed
presentingLeg
  → [leg + overlays done, queue non-empty] → presentingLeg (next leg)
  → [leg + overlays done, queue empty, scan running] → waitingForEvents
  → [leg + overlays done, queue empty, scan complete] → completed
waitingForEvents
  → [new leg arrives] → presentingLeg
  → [scan completes with empty queue] → completed
completed
  → onScanComplete fires → pop replay → push ScanSummaryScreen
```

---

## Acceptance Criteria

- [ ] Pushing scan start immediately opens `GlobeReplayWidget` (no waiting for scan to complete)
- [ ] Each new country discovered during scan causes a globe flight animation to that country
- [ ] Heritage overlays show per-country in sequence (gold card, bell-curve fade)
- [ ] Achievement overlays show per-country in sequence after heritage (no overlap)
- [ ] "Scanning live…" indicator visible when waiting for next discovery
- [ ] Queue depth badge shows when ≥ 2 legs are queued
- [ ] Scan engine is not blocked by the replay — runs at full speed concurrently
- [ ] Scan can complete while queue still draining; replay continues until empty
- [ ] Historical replay (from map) continues to work unchanged
- [ ] Speed selector (1×/2×/3×) works in live mode
- [ ] Mute toggle suppresses all audio in live mode
- [ ] `flutter analyze` — 0 new warnings
