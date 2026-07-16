# M171 — World Leap: Performance Overhaul

**Status:** Complete

## Problem
The game rebuilds ~250 `Polygon` Flutter objects on every 60fps animation frame. Three `AnimationController` listeners each call `setState` on the full map widget: `_pulseController`, `_flightController`, `_splashController`. This makes aiming and the flight animation lag on any device.

## Goal
Lock the frame rate to a smooth 60fps during all game states. Polygon layer must only rebuild when game state changes (new target, visited country), not on every animation tick.

## Solution
1. Split `PolygonLayer` into **static** (all non-target countries, ~248) and **dynamic** (current + target only, 2 polygons).
2. Wrap the static layer in `RepaintBoundary` so Flutter skips its render tree on animation frames.
3. Drive target-pulse colour with `AnimatedBuilder` scoped only to the dynamic layer.
4. Move flight arc, splash ring, and pulse ring into a dedicated `CustomPainter` overlay (`WorldLeapAnimationPainter`) wired to `Listenable.merge([_flightController, _pulseController, _splashController])` — no `setState` at all for animations.
5. Remove the `setState` calls from all three `AnimationController.addListener` callbacks.
6. Fix `_onAimChanged`: trajectory dot computation stays, but drive slingshot painter via its own `repaint` notifier instead of map widget `setState`.

## Acceptance Criteria
- [ ] Aiming drag is smooth (no jank, no frame drops)
- [ ] Flight animation is smooth
- [ ] `flutter analyze` clean
- [ ] Polygon rebuild count drops from every frame to only on state transitions
