# M111 — Cinematic Audio & Replay Timing System

**Branch:** milestone/m111-cinematic-audio-replay-timing
**Status:** In Progress

## Goal

Transform replay into a cinematic travel memory experience through distance-aware pacing, refined easing curves, layered sound design, and emotional timing orchestration.

## Tasks

- [ ] 1. `LegPacing` + `ReplayPacingRules` — pure class in `travel_replay_engine.dart`; haversine arc distance, classification (short/medium/long), pacing table, `buildPacingList`; add `legPacing` to `TravelReplayScript`; unit tests
- [ ] 2. `replay_entry_sheet.dart` wiring — call `ReplayPacingRules.buildPacingList` and pass into script
- [ ] 3. `TravelReplayController` pacing + easing — use `LegPacing` per-leg durations/scales; upgrade easing curves; improve scale dip; add `reducedMotion` flag
- [ ] 4. `ReplayAudioController` — `audioplayers` wrapper; 5 slots; preload, play, mute, stopAll, dispose
- [ ] 5. Audio assets — copy `celebration.mp3` → 5 placeholder files; register all in `pubspec.yaml`
- [ ] 6. Audio synchronisation + mute button — inject `ReplayAudioController` into controller; wire `_runFlight`/`_runPulse`/`_runOverlay`/done; mute toggle in `GlobeReplayWidget` top bar
- [ ] 7. Cinematic end sequence — globe `AnimatedOpacity` fade on done; `ReplaySummaryScreen` easing/curve/duration upgrades
- [ ] 8. Reduced-motion — read `MediaQuery.disableAnimations` in `GlobeReplayWidget.initState`; set `_ctrl.reducedMotion`
- [ ] 9. `flutter analyze` — 0 new warnings; fix any issues
- [ ] 10. Docs + index — milestone status, backlog, `current_state.md`, `python3 scripts/index_docs.py`
