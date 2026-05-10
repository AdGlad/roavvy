# M108 — Cinematic Travel Replay

Branch: milestone/m108-cinematic-travel-replay

## Goal

Cinematic travel replay on the Flutter globe. Animates travel legs between countries
with globe rotation, zoom, great-circle arc, moving marker, and arrival highlight.
Supports allTime / year / trip modes.

## Tasks

- [ ] 1. `travel_replay_engine.dart` — TravelLeg, TravelReplayScript, TravelReplayMode, TravelReplayScriptBuilder
- [ ] 2. `travel_replay_controller.dart` — TravelReplayController (ChangeNotifier, ReplayPhase state machine, per-phase AnimationControllers, TickerProvider)
- [ ] 3. `globe_replay_painter.dart` — GlobeReplayPainter (trail, active arc, marker, arrival pulse, back-face culling)
- [ ] 4. `globe_replay_widget.dart` — GlobeReplayWidget fullscreen overlay: GlobePainter + GlobeReplayPainter, gesture lock, stop button
- [ ] 5. `replay_entry_sheet.dart` — bottom sheet: mode chips (allTime/year/trip) + Play button
- [ ] 6. Map screen entry point — play/replay button in globe mode top bar
- [ ] 7. `flutter analyze` — 0 new warnings; update current_task.md + milestone status
