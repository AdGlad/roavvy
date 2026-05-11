# M111 — Cinematic Audio & Replay Timing System

**Status:** ✅ Complete
**Branch:** `milestone/m111-cinematic-audio-replay-timing`

## Goal

Transform the replay from an animated travel sequence into a cinematic travel memory experience through layered sound design, distance-aware pacing, refined easing curves, and emotional timing orchestration.

---

## Background: Current State

Code review before planning:

| System | Current behaviour |
|--------|------------------|
| `TravelReplayController` | Fixed phase constants: settle=700ms, hold=200ms, pulse=300ms. Hooks `onLegStart`/`onLegComplete`/`onReplayComplete` exist but unused. |
| `TravelReplayScriptBuilder.legDurationMs()` | Flight duration from leg count only: ≤10→3500ms, ≤30→2000ms, ≤80→1200ms, else→700ms. No arc-distance awareness. |
| Camera pan easing | `easeInOutSine` — reasonable, not differentiated by distance. |
| Scale dip (flight) | `sin(π·t) * 0.5` — identical magnitude for short and long arcs. |
| Departure settle | `easeInOutCubic` — adequate. |
| Arrival pulse | `elasticOut`, 300ms — snappy; could be more weighted for long arcs. |
| Overlay progress | Linear 0→1 over 1600ms — adequate. |
| Audio | None. Hooks designed; no implementation. |
| Mute / accessibility | None. |
| End sequence | `AnimatedSlide` from bottom, 500ms `easeOutCubic`. Count-up 900ms. |

**Hooks already in place (just need wiring):**

```dart
void Function(int legIndex)? onLegStart;   // "Hook for future audio/music cues."
VoidCallback? onLegComplete;
VoidCallback? onReplayComplete;
```

---

## Architecture

### Overview

Three new collaborating systems:

```
ReplayPacingRules      — pure: computes per-leg LegPacing from arc distance
ReplayAudioController  — manages audio assets: preload, play, mute, dispose
TravelReplayController — consumes LegPacing durations/scales; fires audio via hooks
```

`ReplayPacingRules` is called once when the script is built (in `replay_entry_sheet.dart`), before replay starts. `ReplayAudioController` is created by `GlobeReplayWidget`, injected into `TravelReplayController` via the existing hooks.

---

## Part 1 — `ReplayPacingRules`

New pure class in `travel_replay_engine.dart`.

### Arc distance classification

Great-circle distance between departure and arrival (degrees):

```
short    < 20°   — e.g. France → Germany, Spain → Portugal
medium  20–90°   — e.g. UK → Thailand, US → Europe
long    > 90°    — e.g. Australia → Europe, US → Japan
```

Distance computed from centroid/GPS lat-lng using the haversine formula.

### `LegPacing` data class

```dart
class LegPacing {
  const LegPacing({
    required this.departureSettleMs,
    required this.departureHoldMs,
    required this.flightMs,
    required this.pulseMs,
    required this.holdMs,
    required this.peakScale,        // globe zoom at arrival
    required this.scaleDipAmount,   // mid-flight scale reduction
  });

  final int departureSettleMs;
  final int departureHoldMs;
  final int flightMs;
  final int pulseMs;
  final int holdMs;
  final double peakScale;
  final double scaleDipAmount;
}
```

### Pacing table

| Distance | settle | hold | flight | pulse | arrive hold | peakScale | scaleDip |
|----------|--------|------|--------|-------|-------------|-----------|----------|
| short    | 500ms  | 150ms| 800ms  | 250ms | 150ms       | 1.8       | 0.2      |
| medium   | 700ms  | 250ms| 1800ms | 300ms | 300ms       | 1.9       | 0.45     |
| long     | 900ms  | 400ms| 3000ms | 400ms | 500ms       | 2.0       | 0.65     |

For scripts with many legs (>30), durations are compressed by a factor derived from leg count (preserving the existing `legDurationMs` compression ratio as an upper cap on flight duration only).

### `ReplayPacingRules` API

```dart
class ReplayPacingRules {
  const ReplayPacingRules._();

  /// Degrees of great-circle arc between two lat/lng points.
  static double arcDistanceDeg(double lat1, double lng1, double lat2, double lng2);

  /// Resolves arc distance for a leg, using GPS when available, falling
  /// back to kCountryCentroids.
  static double legArcDistance(TravelLeg leg);

  /// Computes per-leg pacing. [totalLegs] used for compression factor.
  static LegPacing compute(TravelLeg leg, int totalLegs);

  /// Precomputes pacing for all legs in a script.
  static List<LegPacing> buildPacingList(TravelReplayScript script);
}
```

`buildPacingList` is called once in `replay_entry_sheet.dart` before launching `GlobeReplayWidget`. The resulting `List<LegPacing>` is stored on an extended `TravelReplayScript`.

### `TravelReplayScript` extension

Add one field (backward-compatible default):

```dart
final List<LegPacing> legPacing;  // defaults to const []
```

When empty, the controller falls back to current fixed constants (safe default).

---

## Part 2 — Easing Curve Improvements

All changes are in `TravelReplayController`.

### Current → improved

| Phase | Current curve | Improved curve | Rationale |
|-------|--------------|----------------|-----------|
| Departure settle | `easeInOutCubic` | `Curves.easeInOutQuart` | Slightly more weighted; camera feels heavier |
| Flight — camera pan | `easeInOutSine` | `Curves.easeInOutCubic` | More cinematic; stronger ease-in/out |
| Flight — arc draw | linear (ctrl.value) | `Curves.easeIn` | Arc starts slowly, accelerates — feels launched |
| Arrival pulse | `elasticOut` | `Curves.elasticOut` (unchanged — good) | — |
| Hold | — | — | Duration now from LegPacing |
| Overlay fade | `sin(π·t)` | `sin(π·t)` (unchanged — good) | — |
| Summary count-up | `easeOutCubic` | `Curves.easeOutExpo` | More dramatic number reveal |
| Summary slide | `easeOutCubic` | `Curves.easeOutQuart` | Weightier entrance |

### Scale dip improvement

Currently: `newScale = lerp(1.7, peakScale, t) - 0.5 * sin(π·t)`

Improved: scale dip uses `LegPacing.scaleDipAmount` (0.2 for short, 0.45 for medium, 0.65 for long) so long arcs visually "pull back" more, creating a sense of scale.

```dart
final newScale = _lerp(1.7, pacing.peakScale, rawT)
    - pacing.scaleDipAmount * math.sin(math.pi * rawT);
```

---

## Part 3 — `ReplayAudioController`

New file: `lib/features/globe_replay/replay_audio_controller.dart`.

Uses the `audioplayers` package (already common in Flutter; minimal footprint).

### Sound slots

| Slot | File | When | Duration |
|------|------|------|----------|
| `travel_short` | `assets/audio/replay_travel_short.ogg` | flight start, short arc | ~0.6s |
| `travel_long` | `assets/audio/replay_travel_long.ogg` | flight start, long arc | ~1.2s |
| `arrival` | `assets/audio/replay_arrival.ogg` | pulse phase start | ~0.5s |
| `achievement` | `assets/audio/replay_achievement.ogg` | achievement overlay start | ~1.8s |
| `replay_end` | `assets/audio/replay_end.ogg` | ReplayPhase.done | ~2.0s |

Sound design guidelines (for asset selection/production):
- **Travel**: subtle air movement / soft whoosh. Not dramatic. Low frequency.
- **Arrival**: soft pulse / chime hit. Clean, not percussive.
- **Achievement**: brief orchestral swell or warm unlock tone. Not arcade.
- **End**: gentle cinematic resolve. Warm, emotional — not triumphant fanfare.
- All sounds ≤ –12 dBFS peak. Stereo acceptable; mono preferred for small size.

### API

```dart
class ReplayAudioController {
  ReplayAudioController();

  bool isMuted = false;

  /// Preloads all audio assets. Call before replay starts.
  Future<void> preload();

  /// Plays the appropriate travel whoosh based on arc distance.
  void playTravelMovement(double arcDistanceDeg);

  /// Plays arrival chime.
  void playArrival();

  /// Plays achievement swell.
  void playAchievement();

  /// Plays end sequence cue.
  void playReplayEnd();

  /// Stops all active sounds immediately.
  void stopAll();

  void dispose();
}
```

`isMuted` is checked inside each `play*` method — no callers need to check it.

### Audio synchronisation

Wire into `TravelReplayController` hooks:

```dart
// In TravelReplayController — inject audio controller
ReplayAudioController? audioController;

void _runFlight() {
  final dist = _currentLegPacing?.arcDistanceDeg ?? 45.0;
  audioController?.playTravelMovement(dist);
  // ... existing flight logic
}

void _runPulse() {
  audioController?.playArrival();
  // ... existing pulse logic
}

void _runOverlay() {
  final event = currentOverlayEvents[currentOverlayEventIndex];
  if (event is ReplayAchievementEvent) {
    audioController?.playAchievement();
  }
  // ... existing overlay logic
}

// In _startLeg when legIndex >= script.legs.length (done):
audioController?.playReplayEnd();
```

`audioController` is set by `GlobeReplayWidget` after construction, before `play()` is called.

---

## Part 4 — Mute Toggle & Accessibility

### Mute button

Added to `GlobeReplayWidget` top bar (beside the existing close button):

```dart
IconButton(
  icon: Icon(
    _audioCtrl.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
    color: Colors.white,
  ),
  onPressed: () => setState(() {
    _audioCtrl.isMuted = !_audioCtrl.isMuted;
    _audioCtrl.stopAll();
  }),
)
```

State is session-only — not persisted.

### Reduced motion

In `GlobeReplayWidget.initState`:

```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;
if (reduceMotion) {
  _ctrl.reducedMotion = true;  // new flag on TravelReplayController
}
```

When `reducedMotion = true`, `TravelReplayController` uses minimum durations:
- All `LegPacing` durations halved
- Scale dip set to 0 (no zoom variation)
- Pulse duration minimal (150ms)
- Audio still plays (mute is separate)

---

## Part 5 — Cinematic End Sequence

### Globe fade

When `ReplayPhase.done` fires, `GlobeReplayWidget` fades the globe to near-black before the summary slides up:

```dart
AnimatedOpacity(
  opacity: isDone ? 0.15 : 1.0,
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeInQuad,
  child: /* globe CustomPaint */,
)
```

The summary screen slides over the dimmed globe at 600ms offset.

### Summary screen improvements

- Slide curve: `easeOutQuart` (currently `easeOutCubic`)
- Count-up curve: `easeOutExpo` (currently `easeOutCubic`)
- Count-up duration: 1200ms (currently 900ms) — more dramatic
- Stagger: 180ms per row (currently 150ms)
- Title: add subtle `AnimatedOpacity` fade-in (300ms delay after slide starts)

---

## Part 6 — `pubspec.yaml` / Asset Registration

Add `audioplayers: ^6.0.0` (or latest stable) to `apps/mobile_flutter/pubspec.yaml`.

Register audio assets:

```yaml
flutter:
  assets:
    - assets/audio/replay_travel_short.ogg
    - assets/audio/replay_travel_long.ogg
    - assets/audio/replay_arrival.ogg
    - assets/audio/replay_achievement.ogg
    - assets/audio/replay_end.ogg
```

Audio files are sourced from royalty-free libraries (e.g. Freesound, ZapSplat) or produced in-house. Placeholder silent OGG files are bundled for the milestone so the build passes; final audio assets are a post-build drop-in.

---

## Modified Files

| File | Change |
|------|--------|
| `lib/features/globe_replay/travel_replay_engine.dart` | Add `LegPacing`, `ReplayPacingRules`; add `legPacing` field to `TravelReplayScript` |
| `lib/features/globe_replay/travel_replay_controller.dart` | Consume `LegPacing` per leg; wire `audioController`; add `reducedMotion` flag; improve easing curves; improve scale dip |
| `lib/features/globe_replay/globe_replay_widget.dart` | Globe fade on done; mute button; inject `ReplayAudioController`; reduced-motion detection |
| `lib/features/globe_replay/replay_summary_screen.dart` | Improved easing curves; longer count-up; title fade-in |
| `lib/features/globe_replay/replay_entry_sheet.dart` | Call `ReplayPacingRules.buildPacingList`; pass pacing to script |
| `apps/mobile_flutter/pubspec.yaml` | Add `audioplayers` dependency; register audio assets |

### New Files

| File | Purpose |
|------|---------|
| `lib/features/globe_replay/replay_audio_controller.dart` | Audio preloading, playback, mute |
| `assets/audio/replay_travel_short.ogg` | Short travel whoosh (placeholder or final) |
| `assets/audio/replay_travel_long.ogg` | Long travel whoosh (placeholder or final) |
| `assets/audio/replay_arrival.ogg` | Arrival chime |
| `assets/audio/replay_achievement.ogg` | Achievement swell |
| `assets/audio/replay_end.ogg` | End sequence cue |

---

## Tasks

1. **Audit current timing** — document all phase constants and easing curves in one reference table; identify all call sites in `TravelReplayController`
2. **`LegPacing` data class + `ReplayPacingRules`** — pure class: haversine arc distance, distance classification, pacing table, `buildPacingList`; unit tests for arc distance + pacing classification
3. **`TravelReplayScript.legPacing` field** — add field with empty default; update `TravelReplayScriptBuilder.build` to accept pre-computed pacing; update `replay_entry_sheet.dart` to call `buildPacingList`
4. **`TravelReplayController` pacing integration** — replace fixed constants with `LegPacing` values per leg; add `reducedMotion` flag with halved durations; improve scale dip using `LegPacing.scaleDipAmount`
5. **Easing curve improvements** — upgrade curves as per Part 2 table; verify motion feels cinematic for short, medium, and long arcs
6. **`ReplayAudioController`** — `audioplayers` wrapper; preload, play, mute, dispose; wire `isMuted` guard; add `audioplayers` to `pubspec.yaml`
7. **Bundle audio assets** — add placeholder silent OGG files for all 5 slots; register in `pubspec.yaml`; document asset-swap process for final audio
8. **Audio synchronisation** — inject `ReplayAudioController` into `TravelReplayController`; wire into `_runFlight`, `_runPulse`, `_runOverlay` (achievement), done phase; verify timing feels correct
9. **Cinematic end sequence** — globe fade to 15% opacity on done; slide-up curve upgrade; count-up duration/curve upgrade; title fade-in stagger
10. **Mute toggle + reduced-motion** — mute `IconButton` in top bar; session-only state; `MediaQuery.disableAnimations` → `reducedMotion` flag
11. **`flutter analyze` + QA** — 0 new warnings; smoke-test short/medium/long legs; verify mute works; verify reduced-motion halves durations; check 60 fps on device
12. **Docs + index** — update milestone status, `backlog_active.md`, `current_state.md`; run `python3 scripts/index_docs.py`

---

## Build Order

1. Tasks 2–3 (pacing rules + data model — pure, testable first)
2. Task 4 (controller pacing integration)
3. Task 5 (easing improvements)
4. Tasks 6–7 (audio infrastructure + assets)
5. Task 8 (audio synchronisation)
6. Task 9 (end sequence)
7. Task 10 (mute/accessibility)
8. Task 11 (QA)
9. Task 12 (docs)

---

## Acceptance Criteria

- [ ] Long-haul legs (>90°) feel dramatically slower and more sweeping than short regional legs
- [ ] Scale dip is proportional to arc distance — long arcs zoom out more at mid-flight
- [ ] Easing curves feel cinematic: no abrupt starts or stops
- [ ] Audio plays at correct moments: whoosh on flight start, chime on arrival, swell on achievement, resolve on done
- [ ] Mute toggle silences all audio immediately without disrupting animation
- [ ] `MediaQuery.disableAnimations = true` halves all durations; replay still completes correctly
- [ ] Globe fades to near-black before summary screen appears on done
- [ ] Summary count-up feels more dramatic and satisfying
- [ ] `flutter analyze` reports 0 new issues
- [ ] Replay maintains ≥ 60 fps on iPhone 12+ with audio active
- [ ] `audioplayers` preload completes before `play()` is called (no audio lag on first leg)

---

## Non-Negotiable Rules

- Audio must remain subtle and premium. Never loud or arcade-style.
- Mute mode must be fully functional — replay must feel complete without sound.
- Pacing variation must be noticeable to the user — short and long arcs must feel different.
- No blocking I/O on the animation thread. Audio preloads async before replay starts.
- Do not hardcode audio file names or pacing values in `TravelReplayController` — all behaviour flows through `LegPacing` and `ReplayAudioController`.

---

## Future Hooks (Out of Scope)

- Replay themes / music packs (architecture supports this via `ReplayAudioController` asset swapping)
- Airline mode, retro passport mode — `ReplayPacingRules` can be subclassed/replaced
- Video export with audio — `ReplayAudioController` designed as injectable, not singleton
- Android / web
