# M22 — Phase 11 Slice 1: Visual States + XP Foundation

**Milestone:** 22
**Phase:** 11 — Gamified Map & Progression System
**Status:** ✅ Complete — 2026-03-22

## Goal

The map visually encodes travel progress with 5 country visual states. XP is tracked. New country discovery has a full-screen emotional moment.

## Tasks

| Task | Description | Status |
|---|---|---|
| 81 | `CountryVisualState` enum + `countryVisualStateProvider` + `recentDiscoveriesProvider` | ✅ Done |
| 82 | `CountryPolygonLayer` — replaces polygon rendering; 5 visual states with fill/border/animation | ✅ Done |
| 83 | `XpEvent` + `xp_events` Drift table (schema v10) + `XpRepository` + `XpNotifier` | ✅ Done |
| 84 | `XpLevelBar` widget (top strip on MapScreen) + XP award wired into write sites | ✅ Done |
| 85 | `DiscoveryOverlay` full-screen route — new country moment with haptic + XP display | ✅ Done |

## Key files to touch

- `lib/features/map/country_visual_state.dart` (NEW)
- `lib/features/map/country_polygon_layer.dart` (NEW)
- `lib/features/map/xp_level_bar.dart` (NEW)
- `lib/features/map/discovery_overlay.dart` (NEW)
- `lib/features/xp/xp_event.dart` (NEW)
- `lib/features/xp/xp_notifier.dart` (NEW)
- `lib/data/xp_repository.dart` (NEW)
- `lib/data/db/roavvy_database.dart` (schema v10, add `xp_events` table)
- `lib/core/providers.dart` (add `recentDiscoveriesProvider`, `xpRepositoryProvider`, `xpNotifierProvider`)
- `lib/features/map/map_screen.dart` (add `XpLevelBar`, replace `PolygonLayer` with `CountryPolygonLayer`)
- `lib/features/visits/review_screen.dart` (XP award at save)
- `lib/features/merch/travel_card_widget.dart` (XP award on share)
