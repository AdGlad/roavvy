# M110 — Dynamic Achievements & Replay Stats Overlay

**Status:** ✅ Complete
**Branch:** `milestone/m110-replay-stats-achievement-overlay`

## Goal

Enhance the cinematic travel replay with contextual achievement reveal moments and travel stats overlays. The replay should feel like a personal travel recap — not just a route viewer. Achievement unlocks and key stats appear at the right moment in the sequence, then a clean summary frame closes the experience with Share and Create T-Shirt CTAs.

## Background: What Exists

From the code review before planning:

| System | Current state |
|--------|--------------|
| `TravelReplayController` | Phase state machine: `idle → departureSettle → departureHold → flight → pulse → hold → done`. Has `onLegStart`/`onLegComplete`/`onReplayComplete` hooks. |
| `TravelReplayScript` | Carries `List<TravelLeg>` — no overlay events yet. |
| `TravelLeg` | `fromCode`, `toCode`, `date`, GPS fields (M109). |
| `Achievement` | `id`, `title`, `description`, `category`, `progressTarget`, optional `continentScope`/`regionScope`. 40+ defined in `kAchievements`. |
| `AchievementEngine.evaluate()` | Pure function: takes `List<EffectiveVisitedCountry>` + `tripCount` + `thisYearCountryCount` → `Set<String>` unlocked IDs. |
| `TripRecord` | Has `photoCount`, `startedOn`, `endedOn` — days = `endedOn.difference(startedOn).inDays + 1`. |
| `unlockedAchievements` | Persisted in Drift as `{achievementId, unlockedAt}`. |
| `GlobeReplayWidget` | Full-screen `ConsumerStatefulWidget`; renders globe + painter overlay. |

---

## Architecture

### New phase: `overlay`

Extend `ReplayPhase` enum with an `overlay` phase that fires **after** the `hold` phase when pre-computed events exist for the current leg:

```
flight → pulse → hold → overlay (0..N events) → next leg
```

Overlay events are precomputed before replay starts and stored on `TravelReplayScript`. The controller is never responsible for business logic — it only fires the events it was given.

---

## Data Models (`travel_replay_engine.dart`)

### `ReplayOverlayEvent` — sealed union

```dart
sealed class ReplayOverlayEvent { const ReplayOverlayEvent(); }

/// A travel stat shown after arriving at a country.
class ReplayStatEvent extends ReplayOverlayEvent {
  const ReplayStatEvent({required this.label, required this.value});
  final String label;  // e.g. "Photos", "Days", "Countries", "Continents"
  final String value;  // e.g. "126", "42", "12", "3"
}

/// An achievement reveal moment triggered by the arrival at a country.
class ReplayAchievementEvent extends ReplayOverlayEvent {
  const ReplayAchievementEvent({
    required this.achievementId,
    required this.title,
    required this.subtitle,
  });
  final String achievementId;
  final String title;    // e.g. "Europe Explorer"
  final String subtitle; // e.g. "5 countries in Europe"
}
```

### `TravelReplayScript` — extend with overlay events

```dart
class TravelReplayScript {
  const TravelReplayScript({
    required this.legs,
    required this.mode,
    required this.label,
    this.overlayEvents = const {},
    this.summaryStats = const [],
  });

  final List<TravelLeg> legs;
  final TravelReplayMode mode;
  final String label;

  /// Per-leg overlay events, keyed by leg index.
  /// Events fire in list order after the leg's hold phase.
  final Map<int, List<ReplayOverlayEvent>> overlayEvents;

  /// Stats shown on the end summary screen.
  final List<ReplayStatEvent> summaryStats;

  bool get isEmpty => legs.isEmpty;
}
```

---

## `ReplayTimelineBuilder` (new class, `travel_replay_engine.dart`)

Pure, precomputed. Takes all required data before replay starts. Never called during animation.

```dart
class ReplayTimelineBuilder {
  const ReplayTimelineBuilder._();

  /// Generates overlay events and summary stats for a replay script.
  ///
  /// Achievement detection: walks trips chronologically, builds a running
  /// visited-country set, calls [AchievementEngine.evaluate] at each step,
  /// and records when an achievement threshold is first crossed.
  ///
  /// Only achievements present in [unlockedIds] are shown — no new unlocks
  /// are computed here; this is presentation only.
  ///
  /// At most 2 events fire per leg (1 stat + 1 achievement) to prevent
  /// overwhelming the user.
  static ({
    Map<int, List<ReplayOverlayEvent>> events,
    List<ReplayStatEvent> summary,
  }) build({
    required List<TravelLeg> legs,
    required List<TripRecord> allTrips,
    required Set<String> unlockedIds,
    required TravelReplayMode mode,
    int? year,
  });
}
```

### Achievement detection algorithm

1. Sort trips chronologically (same order as legs).
2. Maintain a running `seenCountryCodes: Set<String>`.
3. At each leg arrival (`toCode`), add `toCode` to `seenCountryCodes`.
4. Build a minimal `List<EffectiveVisitedCountry>` from `seenCountryCodes`.
5. Call `AchievementEngine.evaluate(runningVisits, tripCount: seenTrips)`.
6. Diff against previous step's result → newly unlocked IDs this step.
7. For each newly unlocked ID in `unlockedIds`, add a `ReplayAchievementEvent` at this leg index.
8. Cap at 1 achievement event per leg; skip excess.

### Stat event placement

- Stat events are shown at **every 5th leg** and at the **final leg**.
- Content depends on `mode`:
  - `trip`: days elapsed + photos seen so far
  - `year`: countries visited so far + continents
  - `allTime`: countries visited so far + continents
- Values are cumulative to the current leg, not total.
- At most 1 stat event per leg (combined with achievement: achievement takes priority if both fire).

### Summary stats

Always produced regardless of mode:
- Countries visited (scope-filtered)
- Continents reached (scope-filtered)
- Total photos (sum of `TripRecord.photoCount` in scope)
- Total days (sum of trip durations in scope)
- Total legs (= `legs.length`)

---

## `TravelReplayController` changes

```dart
enum ReplayPhase {
  idle,
  departureSettle,
  departureHold,
  flight,
  pulse,
  hold,
  overlay,   // NEW — fires per-event after hold
  done,
}

class TravelReplayController extends ChangeNotifier {
  // NEW observable state
  List<ReplayOverlayEvent> currentOverlayEvents = const [];
  int currentOverlayEventIndex = 0;
  double overlayProgress = 0.0; // 0.0–1.0 (fade in/out of current event)
}
```

Phase sequencing change — after `_runHold` completes:

```dart
void _afterHold() {
  final events = script.overlayEvents[currentLegIndex] ?? const [];
  if (events.isEmpty) {
    _advanceLeg();
  } else {
    currentOverlayEvents = events;
    currentOverlayEventIndex = 0;
    _runOverlay();
  }
}

void _runOverlay() {
  // 1600 ms per event: 400 fade-in, 800 hold, 400 fade-out
  final ctrl = _makeCtrl(const Duration(milliseconds: 1600));
  phase = ReplayPhase.overlay;
  overlayProgress = 0.0;
  notifyListeners();

  ctrl.addListener(() {
    overlayProgress = ctrl.value;
    notifyListeners();
  });
  ctrl.addStatusListener((s) {
    if (s != AnimationStatus.completed) return;
    currentOverlayEventIndex++;
    if (currentOverlayEventIndex < currentOverlayEvents.length) {
      _runOverlay(); // next event
    } else {
      currentOverlayEvents = const [];
      _advanceLeg();
    }
  });
  ctrl.forward();
}
```

---

## New widgets

### `replay_overlay_widgets.dart` (new file)

**`ReplayAchievementOverlay`** — shown during `ReplayPhase.overlay` for a `ReplayAchievementEvent`:

- Dark semi-transparent pill / card, centred vertically in lower third of screen
- "Achievement Unlocked" label (small caps, gold)
- Title in large weight (e.g. "Europe Explorer")
- Subtitle in regular weight (e.g. "5 countries in Europe")
- Gold star / trophy icon
- Fade-in (0→1 over 400 ms), hold, fade-out (1→0 over 400 ms) — driven by `overlayProgress`

**`ReplayStatOverlay`** — shown for a `ReplayStatEvent`:

- Single-line pill: value prominent, label secondary
- Example: **"12"** _Countries_
- Minimal, bottom-anchored, does not obscure globe arc
- Same fade timing as achievement overlay

**Visibility logic** (in `GlobeReplayWidget`):

```dart
if (controller.phase == ReplayPhase.overlay) {
  final event = controller.currentOverlayEvents[controller.currentOverlayEventIndex];
  final opacity = _overlayOpacity(controller.overlayProgress); // 0→1→0
  return switch (event) {
    ReplayAchievementEvent e => ReplayAchievementOverlay(event: e, opacity: opacity),
    ReplayStatEvent e        => ReplayStatOverlay(event: e, opacity: opacity),
  };
}
```

Opacity curve: `sin(π * overlayProgress)` — natural bell-curve fade that peaks at midpoint.

---

### `replay_summary_screen.dart` (new file)

Shown when `ReplayPhase.done`. Replaces the globe or slides up over it.

```
┌──────────────────────────────────┐
│                                  │
│     Your 2024 Journey            │
│                                  │
│   12 Countries  •  3 Continents  │
│   246 Photos    •  42 Days       │
│                                  │
│  [ Replay Again ]                │
│  [ Share ]                       │
│  [ Create T-Shirt ]              │
│                                  │
└──────────────────────────────────┘
```

- Black background with subtle globe silhouette
- Animated count-up numbers (0 → final value over 800 ms) for Countries and Photos
- Staggered fade-in for each stat row (100 ms delay per row)
- CTAs: `Replay Again` (calls `controller.play()`), `Share` (hooks into existing sharing flow), `Create T-Shirt` (hooks into existing merch flow)

---

## `GlobeReplayWidget` changes

1. Pass `overlayEvents` when building script (via `ReplayTimelineBuilder.build`).
2. After `controller.phase == ReplayPhase.done`, slide up `ReplaySummaryScreen`.
3. Render overlay widget stack on top of globe during `overlay` phase.
4. No changes to globe painter or animation controller timing outside the new `overlay` phase.

## `replay_entry_sheet.dart` changes

Pass `unlockedIds` + `trips` to `ReplayTimelineBuilder` when building the script before launching `GlobeReplayWidget`.

---

## Scope

### In scope

- `ReplayOverlayEvent` sealed class + `ReplayAchievementEvent` + `ReplayStatEvent`
- `ReplayTimelineBuilder` (pure, precomputed, uses existing `AchievementEngine`)
- `TravelReplayScript.overlayEvents` + `summaryStats` fields
- `ReplayPhase.overlay` + controller overlay phase sequencer
- `TravelReplayController.currentOverlayEvents`, `currentOverlayEventIndex`, `overlayProgress`
- `ReplayAchievementOverlay` widget
- `ReplayStatOverlay` widget
- `ReplaySummaryScreen` with count-up animation + 3 CTAs
- Wiring in `GlobeReplayWidget` and `replay_entry_sheet.dart`
- Unit tests for `ReplayTimelineBuilder` (achievement detection, stat placement, cap enforcement)

### Out of scope

- New achievements beyond existing `kAchievements`
- Hero image display during overlay (hero layer deferred — no PHAsset access during replay)
- Audio cues (hooks exist; deferred)
- Video/GIF export
- Continent replay mode entry point (still deferred from M108)
- Web / Android

---

## Modified files

| File | Change |
|------|--------|
| `lib/features/globe_replay/travel_replay_engine.dart` | Add `ReplayOverlayEvent` sealed class + subtypes; add `overlayEvents`/`summaryStats` to `TravelReplayScript`; add `ReplayTimelineBuilder` class |
| `lib/features/globe_replay/travel_replay_controller.dart` | Add `ReplayPhase.overlay`; add overlay observable state; add `_runOverlay`/`_afterHold` sequencer |
| `lib/features/globe_replay/globe_replay_widget.dart` | Render overlay widgets during `overlay` phase; show `ReplaySummaryScreen` on `done` |
| `lib/features/globe_replay/replay_entry_sheet.dart` | Call `ReplayTimelineBuilder.build` when constructing script; pass `unlockedIds` |

### New files

| File | Purpose |
|------|---------|
| `lib/features/globe_replay/replay_overlay_widgets.dart` | `ReplayAchievementOverlay`, `ReplayStatOverlay` |
| `lib/features/globe_replay/replay_summary_screen.dart` | End-of-replay summary frame + CTAs |

---

## Tasks

1. **`ReplayOverlayEvent` model** — sealed class + `ReplayAchievementEvent` + `ReplayStatEvent` in `travel_replay_engine.dart`
2. **`TravelReplayScript` extension** — add `overlayEvents` + `summaryStats` fields (backward-compatible defaults: empty map/list)
3. **`ReplayTimelineBuilder`** — pure class: achievement detection algorithm + stat event placement + summary stats; unit tests
4. **Controller: `ReplayPhase.overlay`** — add phase to enum; add `currentOverlayEvents`, `currentOverlayEventIndex`, `overlayProgress` to controller; add `_runOverlay`/`_afterHold` sequencer; update `_runHold` to call `_afterHold`
5. **`replay_overlay_widgets.dart`** — `ReplayAchievementOverlay` + `ReplayStatOverlay` widgets with bell-curve opacity animation
6. **`replay_summary_screen.dart`** — summary frame: count-up stats + staggered fade-ins + 3 CTAs
7. **`GlobeReplayWidget` wiring** — overlay stack during `overlay` phase; slide-up `ReplaySummaryScreen` on `done`
8. **`replay_entry_sheet.dart` wiring** — call `ReplayTimelineBuilder.build`; pass `unlockedIds` + trips
9. **`flutter analyze`** — 0 new warnings; update docs + milestone status

---

## Acceptance Criteria

- [ ] Achievement events appear at the correct leg (the one that crossed the unlock threshold) for all-time and year modes
- [ ] No more than 1 achievement + 1 stat event fires per leg
- [ ] Stat events appear every 5th leg and at the final leg
- [ ] Overlay fades in and out smoothly without frame drops
- [ ] Globe animation is not interrupted — overlay runs during the `hold` window, not during `flight`
- [ ] End summary screen appears after the final leg with correct scope-filtered stats
- [ ] "Replay Again" restarts playback; "Share" and "Create T-Shirt" navigate to correct flows
- [ ] `ReplayTimelineBuilder` is pure (no I/O, deterministic) and unit-tested
- [ ] `flutter analyze` reports 0 new issues
- [ ] Replay remains ≥ 60 fps on iPhone 12+ with overlay active

---

## Timing summary (updated phase table)

| Phase | Duration | Purpose |
|-------|----------|---------|
| departureSettle | 700 ms | Camera rotates to departure |
| departureHold | 250 ms | Brief pause before arc |
| flight | variable (700–3500 ms) | Arc draws; camera pans to arrival |
| pulse | 300 ms | Arrival country pulse ring |
| hold | 200 ms | Buffer before overlay or next leg |
| **overlay** | **1600 ms × N events** | **Achievement / stat reveal (NEW)** |
| *(next leg)* | | |
| done | — | Summary screen slides up |

---

## Future Integration Hooks (deferred)

- **Hero image moment:** show hero photo thumbnail during overlay phase between stat and achievement events (requires PHAsset thumbnail fetch during replay — deferred)
- **Audio:** `onLegStart`/`onLegComplete` hooks already in controller; music/sound-effect layer deferred
- **Video export:** overlay frames composited into video reel — hooks designed in; deferred
