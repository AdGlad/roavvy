# M110 — Dynamic Achievements & Replay Stats Overlay

**Branch:** milestone/m110-replay-stats-achievement-overlay
**Status:** In Progress

## Goal

Add achievement reveal moments and travel stats overlays to the cinematic travel replay. Achievements appear at the leg where their unlock threshold is crossed. Stats appear every 5 legs. A summary frame closes the replay with Share and Create T-Shirt CTAs.

## Tasks

- [ ] 1. `ReplayOverlayEvent` model — sealed class + `ReplayAchievementEvent` + `ReplayStatEvent` in `travel_replay_engine.dart`
- [ ] 2. `TravelReplayScript` extension — add `overlayEvents: Map<int, List<ReplayOverlayEvent>>` + `summaryStats: List<ReplayStatEvent>` (backward-compatible defaults)
- [ ] 3. `ReplayTimelineBuilder` — pure class in `travel_replay_engine.dart`: achievement detection (walk trips, diff AchievementEngine results) + stat placement (every 5th leg + final) + summary stats; unit tests
- [ ] 4. Controller overlay phase — add `ReplayPhase.overlay` to enum; add `currentOverlayEvents`, `currentOverlayEventIndex`, `overlayProgress` fields; add `_runOverlay` + `_afterHold`; update `_runHold` to call `_afterHold`
- [ ] 5. `replay_overlay_widgets.dart` — `ReplayAchievementOverlay` (achievement card, gold, lower third) + `ReplayStatOverlay` (minimal pill, bottom-anchored); bell-curve opacity from `overlayProgress`
- [ ] 6. `replay_summary_screen.dart` — full-screen summary: title, 4 stats (countries/continents/photos/days), count-up animation, staggered fade-in; 3 CTAs (Replay Again / Share / Create T-Shirt)
- [ ] 7. `GlobeReplayWidget` wiring — render overlay stack during `overlay` phase; animate-in `ReplaySummaryScreen` on `done`
- [ ] 8. `replay_entry_sheet.dart` wiring — call `ReplayTimelineBuilder.build` with `unlockedIds` + `trips`; pass enriched script to `GlobeReplayWidget`
- [ ] 9. `flutter analyze` — 0 new warnings; update docs + milestone status
