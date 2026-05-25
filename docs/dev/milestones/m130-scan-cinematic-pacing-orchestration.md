# M130 — Scan: Cinematic Pacing & Orchestration Engine

**Status:** Complete (2026-05-25)
**Branch:** `milestone/m130-scan-cinematic-pacing-orchestration`
**Phase:** 25 — Scan UX Transformation
**Depends on:** M122 ✅, M123 ✅, M125 ✅

---

## Goal

Decouple the scan discovery speed from the celebration speed. Today, celebrations fire
immediately and simultaneously as countries are detected — rapid scans produce overlapping toasts,
competing confetti bursts, and a sense of chaos rather than ceremony. The scan engine should feel
like a cinematic presentation system: events queue up from the fast scan pipeline, a priority engine
decides their significance, and a presentation engine delivers each moment with controlled timing,
breathing space, and audio that arrives just before the animation completes.

**Core architectural change:**

```
FAST DISCOVERY ENGINE  →  DISCOVERY EVENT BUFFER  →  PRIORITY QUEUE  →  CINEMATIC PRESENTATION ENGINE
     (unchanged)              (new)                     (new)                  (replaces current)
```

The scan itself runs at maximum speed. The presentation engine is the throttle — it drains the
queue at a rate that feels deliberate and emotional, not mechanical.

**Target emotional arc:** each discovery feels earned, each celebration lands cleanly, and the
viewer can absorb every moment even when 30 countries are found in 2 seconds.

---

## Design Principles

- **Decouple scan speed from celebration speed.** The queue absorbs burst; the presentation
  engine controls pacing independently.
- **One primary event at a time.** Never show two toasts, two overlays, or two confetti bursts
  simultaneously. The presentation lock is inviolable.
- **Proportional timing, not proportional complexity.** Small events get short windows; major
  events get room to breathe. The queue waits.
- **Audio precedes completion.** Sound cues fire slightly before the visual animation ends, so the
  user's nervous system registers the event before the screen updates. This is the cinematic
  standard — audio leads, visuals confirm.
- **UNESCO is distinct.** Heritage sites are not faster country discoveries. They get a different
  sound, a different colour register, and a slower reveal.
- **Progressive intensity.** Early scan = small moments (passport stamp sounds). Mid-scan =
  pattern recognition (continent clusters). Late scan = identity reveals (who am I as a traveller).

---

## What Exists Today (post-M125)

| Element | Current state |
|---|---|
| Celebration delivery | Immediate on `didUpdateWidget` — fires confetti + toast synchronously |
| Heritage toasts | 400 ms delay after country toast — sequential, not queued |
| Achievement toasts | Fire on threshold cross — no lock, can overlap country toast |
| Confetti | Three-tier (`micro`/`medium`/`full`) but all play immediately, can stack |
| Audio | Single random sound from `_celebrationSounds`; no event-type differentiation |
| Toast display | Single slot; rapid entry cancels previous after 500 ms minimum |
| Queue | None — all events processed in the frame they arrive |

---

## Priority Model

Events entering the buffer are assigned a priority tier before queuing:

| Tier | Name | Trigger examples | Timing window | Gap after |
|---|---|---|---|---|
| P1 | Passive | Any country (chip feed update only) | 0 ms (no lock) | 0 ms |
| P2 | Discovery | New country toast + `micro` confetti; UNESCO heritage toast | 1,200–1,800 ms | 400–600 ms |
| P3 | Achievement | Country milestone toast (10/25/50); new continent announcement | 2,000–3,000 ms | 800 ms |
| P4 | Major Milestone | First ever country; 100 countries; identity tier unlock | 4,000–5,000 ms | 1,500–2,000 ms |

P1 events never acquire the presentation lock — they update the chip feed and stats bar
freely. P2–P4 events enter the priority queue and are drained one at a time.

**Cooldown rule:** Maximum one P4 event every 6–8 seconds regardless of queue depth. If two P4
events arrive within that window, the second is downgraded to P3 for delivery.

---

## Scope In

### T1 — `_DiscoveryEventBuffer` and `_PriorityQueue`

New data classes and queue infrastructure, all inside `scan_screen.dart`.

#### `_DiscoveryEvent` sealed class

```dart
sealed class _DiscoveryEvent {
  const _DiscoveryEvent({required this.priority, required this.arrivedAt});
  final _EventPriority priority;
  final DateTime arrivedAt;
}

class _CountryEvent extends _DiscoveryEvent { ... isoCode, photoCount, firstSeenYear, heritageSiteNames }
class _HeritageEvent extends _DiscoveryEvent { ... siteName, isoCode, siteType /* cultural | natural */ }
class _AchievementEvent extends _DiscoveryEvent { ... achievementLabel, countThreshold }
class _ContinentEvent extends _DiscoveryEvent { ... continentName, countriesInContinent }
class _MajorMilestoneEvent extends _DiscoveryEvent { ... milestoneType /* first | century | identity */ }

enum _EventPriority { p1, p2, p3, p4 }
```

#### `_PriorityQueue`

- `List<_DiscoveryEvent>` sorted by `_EventPriority` descending, then by `arrivedAt` ascending.
- `enqueue(_DiscoveryEvent event)` — inserts in sorted order.
- `_DiscoveryEvent? dequeue()` — pops the highest-priority, oldest event.
- `int get length` — total queued.
- `bool get isProcessingLocked` — true when the presentation engine holds the lock.

#### `_DiscoveryEventBuffer`

- Sits on `_ScanningViewState` as `_buffer`.
- In `didUpdateWidget`, instead of calling `_showToast()` + `_maybeBurst()` directly, call
  `_buffer.enqueue(...)` for each new entry.
- `_DrainTimer`: a periodic `Timer` (interval 100 ms) on `_ScanningViewState` that calls
  `_drainQueue()` if the presentation lock is free.

Files: `scan_screen.dart` — new classes above `_ScanningView`.

---

### T2 — `_CinematicPresentationEngine`

A single method `_drainQueue()` on `_ScanningViewState` that:

1. Checks `_buffer.isProcessingLocked` — returns early if locked.
2. Calls `_buffer.dequeue()` — returns early if null (queue empty).
3. Acquires the presentation lock.
4. Dispatches to the appropriate presentation method based on event type + priority:
   - P1 → `_presentPassive(event)` (no lock needed; always completes instantly)
   - P2 country → `_presentCountryDiscovery(event)`
   - P2 heritage → `_presentHeritageDiscovery(event)`
   - P3 achievement → `_presentAchievement(event)`
   - P3 continent → `_presentContinent(event)`
   - P4 milestone → `_presentMajorMilestone(event)`
5. Each `_presentX()` method returns a `Future<void>` that:
   - Plays audio cue at the right moment (see T4).
   - Shows the visual element.
   - `await`s its display duration.
   - Plays audio tail if applicable.
   - `await`s the gap duration.
   - Releases the lock.
6. Releases the lock in a `finally` block — never leaked even on error.

**P4 cooldown:**
Track `_lastP4DeliveredAt: DateTime?`. In `_drainQueue()`, before dispatching a P4 event, check
if less than 6 seconds have elapsed since `_lastP4DeliveredAt`. If so, downgrade to P3.

Files: `scan_screen.dart` — `_ScanningViewState`.

---

### T3 — Queue depth indicator

When 3 or more events are queued, show a small pill badge below the toast area:

```
  Next discoveries queued: 5
```

Spec:
- `AnimatedSwitcher` wrapping a `Container` with `BorderRadius.circular(12)`, 24 px height.
- Background: `onSurface.withOpacity(0.12)`.
- Typography: `labelSmall`, muted.
- Appears when `_buffer.length >= 3`, hides when `< 3` (animated fade).
- Text updates live as queue drains — shows current depth, not initial depth.
- Positioned below the toast slot, above the discovery chip list.

Files: `scan_screen.dart` — `_ScanningView.build()`.

---

### T4 — Sound architecture

Four distinct sound categories, each with 2–3 asset slots for variety. Sound fires **slightly
before** the animation peak, not at start. Implement via `_audioStartOffset` delays.

| Category | Use | Timing note | Target feel |
|---|---|---|---|
| `passport_stamp` | P2 country discovery | Fire at animation start | 150–300 ms stamp thud |
| `heritage_chime` | P2 UNESCO discovery | Fire 200 ms into reveal | Crystal chime, historical weight |
| `achievement_rise` | P3 achievement / continent | Fire 300 ms before dismiss | Soft rise + sparkle |
| `orchestral_swell` | P4 major milestone | Fire when overlay appears | Full swell, peaks at dismiss |

Asset registration (`pubspec.yaml` `assets/audio/`):
```
audio/stamp_1.mp3
audio/stamp_2.mp3
audio/stamp_3.mp3
audio/heritage_chime_1.mp3
audio/heritage_chime_2.mp3
audio/achievement_rise_1.mp3
audio/achievement_rise_2.mp3
audio/orchestral_swell_1.mp3
```

**Note:** Placeholder audio files (copy existing `audio/celebration.mp3` to each slot initially).
Real assets to be sourced separately. The architecture must be in place and wired; asset quality
is a follow-up.

Implementation:
- Add `_AudioCategory` enum with the four values above.
- `_playAudio(_AudioCategory category)` on `_ScanningViewState` — picks randomly from the
  category's slots, plays via `AudioPlayer`.
- Each `_presentX()` method calls `_playAudio()` at the correct offset via `Future.delayed`.
- Mute guard: check `_muteNotifier.value` (or `MediaQuery.disableAnimationsOf` as proxy) before
  playing. Add a mute toggle `IconButton` in the scan screen app bar (speaker icon).

Files: `scan_screen.dart`, `pubspec.yaml`.

---

### T5 — UNESCO distinctiveness in presentation

`_presentHeritageDiscovery` must feel different from `_presentCountryDiscovery`:

- **Color register:** amber/gold background (#FFB300) instead of primary colour.
- **Icon:** `🏛` at 32 px, displayed before site name.
- **Toast duration:** 2,200 ms (longer than country's ~1,500 ms).
- **Sound:** `heritage_chime` category, fires 200 ms into the toast appear animation.
- **Timing window:** 1,800 ms total (200 ms appear + 1,200 ms hold + 400 ms fade + 400 ms gap).
- **No confetti** for heritage — the chime is the celebration. Confetti is for geography.
- **Site type chip:** small pill below site name: "Cultural" (amber) or "Natural" (green).

`_HeritageToastBanner` (from M123) is used; extend it with `siteType` param and the chip.

Files: `scan_screen.dart`.

---

### T6 — Achievement completion moments

When a P3/P4 event is dismissed, play a clean completion transition:
- Fade the toast/overlay to 0.0 opacity over 300 ms.
- Play the audio tail (last 200 ms of the sound, or a short chime for P3).
- Hold empty screen for the gap duration before releasing the lock.

This "clean exit" is implemented as the final steps in each `_presentX()` Future. The gap duration
is the breathing space — no new primary event starts during this window.

For P4 events, add a brief globe pulse (increase `_globePulseCtrl` amplitude once) to mark the
moment. Reuse the existing heritage pulse animation controller if already on `_ScanGlobeWidget`.

Files: `scan_screen.dart`.

---

### T7 — Progressive intensity mapping

The presentation engine tracks `_scanPhase: _ScanPhase` (early / building / revealing):

```dart
enum _ScanPhase { early, building, revealing }
```

Phase transitions:
- `early` → `building`: when 10 countries discovered.
- `building` → `revealing`: when 30 countries discovered, OR at 70% of total expected photos.

Phase affects:
- `early`: P2 country events play `stamp` audio; toast uses compact style (no year line).
- `building`: P2 events show year line; continent clusters visible in stats bar.
- `revealing`: P3/P4 events get the full emotional treatment; orchestral sounds permitted.

This is a soft modulation — the priority tier still determines the event type, the phase modulates
the richness of the delivery within that tier.

Files: `scan_screen.dart` — `_ScanningViewState` + all `_presentX()` methods.

---

### T8 — Docs update

- Update `docs/dev/next_tasks.md` to M131 (or clear for next milestone).
- Update `docs/dev/backlog_active.md` — mark M130 status and add any successor milestone.
- Run `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt`.
- Run `python3 scripts/index_docs.py`.

---

## Scope Out

| Feature | Reason |
|---|---|
| Real production audio assets | Asset sourcing is a creative/licensing task; architecture ships with placeholders |
| Background scan (scan-while-app-closed) | Platform channel requires foreground; separate milestone |
| Android / web | iOS-first per project policy |
| Video/GIF capture of scan moment | Export pipeline is a separate milestone |
| Server-side event orchestration | All orchestration is on-device only |
| Rovy mascot reactions | Needs mascot system + asset pipeline |
| Haptic choreography beyond current `HapticFeedback.heavyImpact()` | Haptic design is a separate pass |

---

## Acceptance Criteria

- [x] New countries during rapid scan do not trigger immediate overlapping celebrations.
- [x] All P2/P3/P4 events pass through the priority queue before presentation.
- [x] Only one primary celebration is visible at any time (presentation lock is never double-held).
- [x] P2 country: toast appears, audio fires at start, dismisses after ~1,500 ms.
- [x] P2 heritage: amber toast appears, chime fires 200 ms in, holds 2,200 ms total.
- [x] Heritage toast shows site type chip (Cultural/Natural).
- [x] P3: achievement/continent toast, audio, 2,000–3,000 ms window.
- [x] P4: full cinematic overlay, audio, 4,000–5,000 ms window.
- [x] P4 cooldown: no two P4 events delivered within 6 seconds; second is downgraded to P3.
- [x] Queue depth indicator appears when 3+ events queued; hides when < 3.
- [x] Queue depth count updates live as queue drains.
- [x] Mute toggle (speaker icon) suppresses all audio.
- [x] `_ScanPhase` transitions at 10 countries (`early` → `building`) and 30 (`building` → `revealing`).
- [x] P1 events (chip feed, stats bar) are never blocked by the presentation lock.
- [x] Completion transition: fade out + brief hold before next event.
- [x] `flutter analyze` — 0 new errors or warnings introduced.
- [x] All M122, M123, M125 acceptance criteria still met.

---

## Technical Notes

### Lock implementation

The simplest correct lock is a `bool _presentationLocked` on `_ScanningViewState`. The drain
timer checks this flag before dequeueing. The `_presentX()` futures set it true at start and false
in a `finally` block at end. No `Mutex` package needed — all state mutations happen on the widget's
`setState` thread.

```dart
bool _presentationLocked = false;

Future<void> _drainQueue() async {
  if (_presentationLocked) return;
  final event = _buffer.dequeue();
  if (event == null) return;
  _presentationLocked = true;
  try {
    await _dispatchPresentation(event);
  } finally {
    _presentationLocked = false;
  }
}
```

### Timer management

The drain timer is a periodic `Timer.periodic(const Duration(milliseconds: 100), ...)` created
in `_ScanningViewState.initState()` and cancelled in `dispose()`. 100 ms polling is imperceptible
and adds negligible CPU load. This avoids complex event-driven wake-up logic.

### Audio offset pattern

```dart
Future<void> _presentCountryDiscovery(_CountryEvent event) async {
  _showCountryToast(event); // visual: starts immediately
  _playAudio(_AudioCategory.passportStamp); // audio: fires at start
  await Future.delayed(const Duration(milliseconds: 1500));
  _hideCountryToast();
  await Future.delayed(const Duration(milliseconds: 500)); // gap
}

Future<void> _presentHeritageDiscovery(_HeritageEvent event) async {
  _showHeritageToast(event); // visual: starts immediately
  await Future.delayed(const Duration(milliseconds: 200));
  _playAudio(_AudioCategory.heritageChime); // audio: 200 ms into reveal
  await Future.delayed(const Duration(milliseconds: 2000));
  _hideHeritageToast();
  await Future.delayed(const Duration(milliseconds: 400)); // gap
}
```

### Existing toasts coexist with queue

The discovery chip feed (P1) is not affected — it updates freely on every `setState`. Only the
toast/overlay layer is gated by the presentation lock. `_DiscoveryChip` slide-ins continue to
appear in real time.

### P4 globe pulse

`_ScanGlobeWidget` already has a `_heritagePulseCtrl` from M126. For P4 events, trigger a
single extra `forward()` + `reverse()` on this controller at the moment of presentation. Pass a
`VoidCallback? onMajorMilestone` prop from `_ScanningView` down to `_ScanGlobeWidget`.

---

## Risks

| Risk | Mitigation |
|---|---|
| Queue depth grows unbounded on very large photo libraries | Cap queue at 50 events; oldest P2 events are dropped (P3/P4 always kept) |
| Drain timer fires during `dispose()` | Cancel timer in `dispose()` before any async work |
| Audio `Future.delayed` drift causes audio/visual desync | Use `Stopwatch` instead of chained delays if drift is measurable (measure first) |
| Placeholder audio sounds jarring | Default to silent (no audio call) for empty slots — add `try/catch` around `play()` |
| `_presentationLocked` stuck true if `_presentX` throws | `finally` block guarantees unlock; verified by error test |

---

## ADR-172

**Scan screen: decoupled discovery event buffer and cinematic pacing (M130)**

Decision: Introduce `_DiscoveryEventBuffer` + `_PriorityQueue` to decouple scan detection speed
from celebration delivery speed. A `_CinematicPresentationEngine` drains the queue at a
controlled rate (P2: 1.2–1.8s; P3: 2–3s; P4: 4–5s) with enforced breathing gaps. A
presentation lock ensures at most one primary event is visible at any time. Four audio categories
(passport stamp, heritage chime, achievement rise, orchestral swell) are routed based on event
priority. UNESCO heritage events receive a distinct colour register, slower timing, and a chime
rather than confetti.

Rationale: Rapid scans currently produce overlapping celebrations that feel chaotic. Users need
time to process each discovery. The scan engine speed (platform-controlled) cannot be throttled,
so the buffer is the right architectural layer. Decoupling also enables future features (replay,
slow-reveal mode) without changing the scan pipeline.

Status: Accepted
