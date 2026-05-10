# M108 — Cinematic Travel Replay System

**Status:** Planned
**Branch:** `milestone/m108-cinematic-travel-replay`

## Goal

Build a cinematic travel replay system on the existing Flutter globe. The replay animates travel legs between countries with globe rotation, zoom, arc paths, and a moving marker — not individual photos.

## Scope

- Replay modes: trip, year, all-time travel, continent travel
- Per-leg animation: rotate globe → zoom in → draw arc → move marker → highlight arrival → hold
- Entry point: bottom sheet launched from Map screen, Achievements, or Trips
- Architecture designed to support future video export / social sharing / yearly recap reels / audio

## Out of Scope (M108)

- Video/GIF export (hooks designed in, deferred)
- Audio/music layer (callback hooks designed in, deferred)
- Photo integration (never animates individual photos)
- Continent-specific entry point UI (data model supports it; entry points deferred)

---

## Architecture

### New files

| File | Purpose |
|------|---------|
| `lib/features/globe_replay/travel_replay_engine.dart` | Data models: `TravelLeg`, `TravelReplayScript`, `TravelReplayMode`, `TravelReplayScriptBuilder` |
| `lib/features/globe_replay/travel_replay_controller.dart` | `TravelReplayController extends ChangeNotifier` — drives per-leg animation state machine |
| `lib/features/globe_replay/globe_replay_widget.dart` | Drop-in globe widget that accepts a `TravelReplayController` |
| `lib/features/globe_replay/globe_replay_painter.dart` | `CustomPainter` that renders arcs, marker, pulse rings on top of the globe |
| `lib/features/globe_replay/replay_entry_sheet.dart` | Bottom sheet: mode picker + Play button |

### Modified files

| File | Change |
|------|--------|
| `lib/features/map/map_screen.dart` | Add replay FAB / entry point |
| `lib/core/providers.dart` | Add `replayControllerProvider` |
| `packages/shared_models/lib/src/` | No change — `TripRecord` already has `countryCode` + `startedOn` |

---

## Data Models (`travel_replay_engine.dart`)

```dart
enum TravelReplayMode { trip, year, allTime, continent }

class TravelLeg {
  final String fromCode;   // ISO 3166-1 alpha-2
  final String toCode;
  final DateTime date;
  const TravelLeg({required this.fromCode, required this.toCode, required this.date});
}

class TravelReplayScript {
  final List<TravelLeg> legs;
  final TravelReplayMode mode;
  final String label; // e.g. "2024 Travels", "Europe Explorer"
  const TravelReplayScript({required this.legs, required this.mode, required this.label});
}
```

`TravelReplayScriptBuilder` produces a `TravelReplayScript` from:
- `List<TripRecord>` sorted by `startedOn`
- Consecutive records with different `countryCode` → each pair = one `TravelLeg`
- Deduplication: skip leg if `fromCode == toCode`
- Mode filter: `year` filters to `DateTime.now().year`; `continent` filters by `kCountryContinent[code]`

---

## Animation Chain Per Leg

Total default duration: **3 500 ms**

| Phase | Duration | Curve | Action |
|-------|----------|-------|--------|
| Globe rotate | 600 ms | easeInOutCubic | Snap globe to midpoint of departure + arrival |
| Zoom in | 400 ms | easeOutCubic | Scale 1.0 → 1.8× |
| Arc + marker | 1 800 ms | easeInOutSine | Draw great-circle arc, move dot along it |
| Arrival zoom | 400 ms | easeInCubic | Scale 1.8 → 2.2×, re-center on arrival |
| Pulse + hold | 300 ms | elasticOut | Country highlight pulse ring |

Speed compression for all-time mode:

| Legs | Duration per leg |
|------|-----------------|
| ≤ 10 | 3 500 ms |
| 11–30 | 2 000 ms |
| 31–80 | 1 200 ms |
| > 80 | 700 ms |

---

## `TravelReplayController`

```dart
enum ReplayPhase { idle, rotating, zoomIn, arc, arrivalZoom, pulse, hold, done }

class TravelReplayController extends ChangeNotifier {
  final TravelReplayScript script;
  int currentLegIndex = 0;
  ReplayPhase phase = ReplayPhase.idle;
  double arcProgress = 0.0;   // 0.0–1.0
  double pulseRadius = 0.0;   // 0.0–1.0

  void play();
  void pause();
  void stop();
  void skipToLeg(int index);

  // Callbacks for future hooks
  VoidCallback? onLegComplete;
  VoidCallback? onReplayComplete;
  void Function(int legIndex)? onLegStart; // audio cue hook
}
```

Uses a single `AnimationController` per phase; transitions via `addStatusListener`.

---

## Great-Circle Arc Interpolation

```dart
// Slerp two unit vectors on the unit sphere
Offset3D _slerp(Offset3D a, Offset3D b, double t) {
  final dot = a.dot(b).clamp(-1.0, 1.0);
  final theta = math.acos(dot);
  if (theta.abs() < 1e-6) return a;
  return (a * math.sin((1 - t) * theta) + b * math.sin(t * theta))
      * (1.0 / math.sin(theta));
}

// Arc elevation — lifts midpoint off sphere surface for visual clarity
double _arcElevation(double t, double maxElevationPx) =>
    math.sin(math.pi * t) * maxElevationPx;
```

Back-face culling: skip arc segment if `z < 0` after projection. Antipodal guard: if `dot(a,b) < -0.98` split into two arcs via midpoint.

---

## `GlobeReplayPainter` (CustomPainter)

Layered on top of existing `GlobePainter`:

1. **Completed trail** — faded dashed polyline of all previous legs
2. **Active arc** — animated great-circle arc in accent colour, drawn to `arcProgress`
3. **Marker dot** — circle moving along arc at `arcProgress`
4. **Departure marker** — static dot on from-country centroid
5. **Arrival pulse ring** — expanding ring on arrival country centroid, driven by `pulseRadius`

Colors:
- Trail: `Colors.white.withOpacity(0.25)`
- Arc: `Colors.amber` (or theme accent)
- Marker: `Colors.white` with drop shadow
- Pulse: `Colors.amber.withOpacity(1.0 - pulseRadius)`

---

## `GlobeReplayWidget`

Drop-in replacement for `GlobeMapWidget` during replay. Accepts `TravelReplayController`. Internally composes:
- Existing `GlobeMapWidget` (disabled gestures during playback)
- `GlobeReplayPainter` overlay via `CustomPaint`

Globe orientation is driven by `TravelReplayController` phases — delegates rotation snap to existing `GlobeProjection.copyWith()`.

---

## `ReplayEntrySheet`

Bottom sheet launched from map FAB:

```
[ Trip Replay ] [ 2024 ] [ All Time ] [ Continent ]
                    [ ▶ Play ]
```

- Mode selector chips
- Leg count preview: "23 travel legs"
- Play button → pushes `GlobeReplayWidget` full-screen or overlays on map

---

## Tasks

1. **Create `kCountryCentroids` map** — `Map<String, (double lat, double lng)>` for ~195 countries. Store in `lib/core/country_centroids.dart`.
2. **`travel_replay_engine.dart`** — `TravelLeg`, `TravelReplayScript`, `TravelReplayMode`, `TravelReplayScriptBuilder`.
3. **`travel_replay_controller.dart`** — `TravelReplayController` with full phase state machine + `AnimationController` per phase.
4. **`globe_replay_painter.dart`** — `GlobeReplayPainter`: trail, arc, marker, pulse rendering with back-face culling.
5. **`globe_replay_widget.dart`** — `GlobeReplayWidget` composing existing globe + painter overlay; gesture lock during playback.
6. **`replay_entry_sheet.dart`** — Mode picker bottom sheet.
7. **Map screen entry point** — FAB / replay button on `MapScreen`, wires up `TravelReplayScriptBuilder` from trip provider.
8. **Speed compression** — Auto-apply per-leg duration based on leg count in `TravelReplayController`.
9. **Future hooks** — `onLegStart`, `onLegComplete`, `onReplayComplete` callbacks; document video-export integration path.

---

## Acceptance Criteria

- [ ] Replay launches from map screen for at least one mode (all-time)
- [ ] Globe rotates to each leg's midpoint before arc draws
- [ ] Arc animates along great-circle path between country centroids
- [ ] Marker dot moves along arc
- [ ] Arrival country highlights with pulse ring
- [ ] Speed compression applies for all-time replay with > 30 legs
- [ ] Back-face culling skips arc segments behind globe
- [ ] Gestures are disabled during playback; restored on stop
- [ ] `flutter analyze` reports 0 new issues
- [ ] No jank: replay runs at 60 fps on iPhone 12+

---

## Future Integration Hooks (deferred)

- **Video export**: `ffmpeg_kit_flutter` frame-capture of `GlobeReplayWidget` at 30 fps
- **Social GIF**: downsampled frame sequence → GIF encoder
- **Audio**: `onLegStart(legIndex)` callback drives music tempo / sound effect cues
- **Yearly recap reel**: pre-built `TravelReplayScript` for past year, triggered from achievements
- **Continent replay**: `TravelReplayMode.continent` already in enum; entry UI deferred
