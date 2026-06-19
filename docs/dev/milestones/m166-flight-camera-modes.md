# M166 — World Leap Flight Camera Modes

**Status:** In Progress
**Branch:** milestone/m166-flight-camera-modes

## Goal

Add a camera that follows the projectile during the slingshot flight arc, with two
cinematic modes and a toggle so the player can choose their preferred view.

## Modes

| Mode | Description | Zoom range |
|---|---|---|
| Static | No camera movement (current behaviour) | Fixed at whatever the map was |
| Bird's-eye | Camera tracks projectile at medium altitude; zoom follows a parabola peaking at mid-flight | 2.0 → 3.0 (peak) → 3.5 |
| POV | Close tight follow — feels like riding the quokka; dramatic terrain scroll | 2.5 → 4.5 (peak) → 5.0 |

Zoom is computed with a quadratic formula through three control points (launch, apex,
landing) so the movement is smooth with no abrupt jumps.

## Scope

- `WorldLeapCameraMode` enum (static / birdseye / pov)
- `WorldLeapMapWidget` — move map camera each flight frame from existing `_flightController` listener
- `WorldLeapScreen` — `ValueNotifier<WorldLeapCameraMode>` + cycling toggle button near zoom controls
- After landing, `_flyTo` is skipped when mode != static (camera is already at landing spot)

## Files

| File | Change |
|---|---|
| `lib/features/world_leap/domain/models/world_leap_camera_mode.dart` | New — enum + zoom helpers |
| `lib/features/world_leap/presentation/widgets/world_leap_map_widget.dart` | Accept `cameraMode`, track projectile during flight |
| `lib/features/world_leap/presentation/screens/world_leap_screen.dart` | Toggle button, pass mode to map |

## Acceptance Criteria

- [ ] Static mode: map does not move during flight (existing behaviour preserved)
- [ ] Bird's-eye: camera follows projectile, zoom peaks at midpoint, settles on landing zone
- [ ] POV: same but tighter zoom, more dramatic
- [ ] Toggle button cycles Static → Bird's-eye → POV → Static with icon + label
- [ ] Preference persists for the session (in-memory ValueNotifier)
- [ ] No new flutter analyze warnings
