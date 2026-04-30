# Milestone 88 — Native Flutter Globe Spin Physics

## Goal
Improve the globe interaction to feel like a real physical object by adding inertia, friction-based decay, and smooth transitions between manual dragging and idle auto-rotation.

## Current Problem
The Roavvy globe currently uses a custom `GlobeMapWidget` (bespoke projection/painter) with the following limitations:
- **Instant Stop:** Movement stops the moment the user lifts their finger.
- **Velocity Discarded:** Swipe speed has no impact on rotation.
- **Dead Timer:** Idle spin resumes after a hard-coded 2-second delay, creating a disjointed experience.

## Desired Interaction Model
1.  **Idle Spin:** Subtle east-to-west rotation (~5°/sec) when no interaction is occurring.
2.  **User Drag:** Direct, responsive control of the globe longitude and latitude.
3.  **Inertia:** On release, the globe continues spinning based on the gesture's exit velocity.
4.  **Decay:** Velocity gradually decreases using simulated friction.
5.  **Resume Idle:** Once inertia slows to the idle spin threshold, it seamlessly blends back into auto-rotation.
6.  **Interrupt:** Any new touch instantly cancels inertia or auto-rotation.

## flutter_map Integration Assessment
- **Audit Result:** Although the "Flat Map" uses `flutter_map`, the **"Globe Map"** is a custom implementation using `CustomPainter` (`GlobePainter`) and `GlobeProjection`.
- **Control Mechanism:** The globe is controlled by updating `rotLng` (longitude) and `rotLat` (latitude) in the `GlobeProjection` state.
- **Physics Target:** Physics must be applied to these rotation values, NOT to a `MapController`.

## Recommended Technical Approach
Create a physics-aware ticker loop inside `GlobeMapWidget` that manages a velocity vector $(v_{lng}, v_{lat})$.

### GlobeSpinController State
- `velocity`: `Offset` (radians per second).
- `isInteracting`: `bool` (true during finger-down).
- `isSnapAnimating`: `bool` (true during flag-strip "snap-to" animation).

### Inertia Physics Model
Using simple Euler integration with a friction coefficient:
```dart
// Each frame:
if (!isInteracting && !isSnapAnimating) {
  // Apply friction
  velocity *= frictionCoefficient; 
  
  // Update rotation
  rotLng += velocity.dx * deltaTime;
  rotLat += velocity.dy * deltaTime;
  
  // Transition to idle spin if below threshold
  if (velocity.distance < idleThreshold) {
    velocity = lerp(velocity, idleVelocity, blendFactor);
  }
}
```

### Conflict Handling
- **Snap Animation:** The existing `_snapController` and `_zoomController` (used for country highlights) must explicitly stop the physics ticker or zero out the velocity to prevent "fighting" for control.
- **Clamping:** `rotLat` must be clamped to $[-\pi/2, \pi/2]$ to prevent flipping over the poles.

## Edge Cases
- **Wraparound:** `rotLng` must be normalized within $[0, 2\pi]$ to prevent floating point precision issues over long sessions.
- **Pinch-to-Zoom:** Capture velocity only from the last focal point change when `pointerCount == 1` to avoid chaotic spinning during zoom.
- **Flick Intensity:** Clamp the maximum exit velocity so the globe doesn't spin too fast.

## Acceptance Criteria
- [ ] Flicking the globe causes it to spin and slow down naturally.
- [ ] The direction of the spin matches the swipe direction.
- [ ] Touching the globe while it's spinning stops it immediately.
- [ ] The globe returns to its slow auto-rotation after the flick finishes.
- [ ] No jitter or "jumping" when transitioning between states.
- [ ] 60/120 FPS performance maintained on modern iOS devices.

## Implementation Tasks
1.  **[ ] Phase 1: Velocity Tracking**
    - Refactor `onScaleUpdate` to calculate instantaneous velocity using `ScaleUpdateDetails`.
    - Add a `velocity` field to the widget state.
2.  **[ ] Phase 2: Inertia & Friction**
    - Update `_onRotationTick` to apply velocity-based movement when `!_isInteracting`.
    - Implement friction decay (e.g., `velocity *= 0.95`).
    - Add `velocity` clamping.
3.  **[ ] Phase 3: State Transitions**
    - Implement the "Idle Spin Blend" once velocity drops below a certain speed.
    - Ensure `_onScaleStart` clears all active velocity.
4.  **[ ] Phase 4: Conflict Resolution**
    - Sync with `_snapController` to ensure flag-strip taps override inertia.
    - Normalize `rotLng` to $[0, 2\pi]$.
5.  **[ ] Phase 5: QA**
    - Verify on iOS Simulator and physical device.
    - Check for memory leaks on the `Ticker`.

## Recommended Build Order
1.  Capture and log exit velocity.
2.  Enable basic inertia (flick to spin).
3.  Add friction and idle resumption.
4.  Handle animation conflicts.
