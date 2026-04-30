# Milestone 88 — Native Flutter Globe Spin Physics

## Goal
Elevate the globe interaction from a static drag-and-stop model to a physical-feeling experience with inertia, friction, and seamless transitions between user control and idle auto-rotation.

## Scope
- **In:** `GlobeMapWidget` gesture logic, physics ticker integration, velocity-based rotation, state blending.
- **Out:** `flutter_map` Mercator view, Mapbox APIs, non-globe UI components.

## Tasks

- [ ] T1 — Velocity Tracking & Gesture Refactor
  - **Files:** `lib/features/map/globe_map_widget.dart`
  - **Deliverable:** Update `onScaleUpdate` to calculate instantaneous velocity (radians/sec) for both longitude and latitude when `pointerCount == 1`. Store this in a new `_velocity` Offset field.
  - **Acceptance Criteria:** Velocity is correctly calculated during drag; velocity is zeroed on interaction start; velocity is preserved when the finger is lifted.

- [ ] T2 — Inertia Physics & Friction Decay
  - **Files:** `lib/features/map/globe_map_widget.dart`
  - **Deliverable:** 
    - Integrate `_velocity` into the `_onRotationTick`.
    - When `!_isInteracting`, apply `_velocity` to `rotLng` and `rotLat`.
    - Implement a friction coefficient (e.g., `0.95` per frame) to decay velocity over time.
    - Clamp `rotLat` to prevent pole-flipping.
    - Clamp maximum exit velocity to prevent "infinite spin" on extreme flicks.
  - **Acceptance Criteria:** Flicking the globe causes it to spin and slow down naturally; rotation direction matches flick direction.

- [ ] T3 — Idle Spin Resumption & Blending
  - **Files:** `lib/features/map/globe_map_widget.dart`
  - **Deliverable:**
    - Define an `_kIdleVelocity` constant (~5°/sec).
    - When the inertia velocity drops below a threshold (e.g., 2.0 * `_kIdleVelocity`), gradually `lerp` the current velocity towards the idle velocity.
    - Remove the hard-coded 2-second `Timer` delay for resuming auto-rotation.
  - **Acceptance Criteria:** Globe transition from flick-inertia to idle-spin is smooth and gapless; no more 2-second "frozen" state.

- [ ] T4 — Animation Conflict Resolution & Normalization
  - **Files:** `lib/features/map/globe_map_widget.dart`
  - **Deliverable:**
    - Ensure `_snapController` and `_zoomController` (flag-strip taps) zero out `_velocity` and stop the physics loop.
    - Normalize `rotLng` within `[0, 2π]` on every tick to prevent precision drift.
    - Ensure `_onScaleStart` immediately kills all active inertia and idle spin.
  - **Acceptance Criteria:** Manual taps and automated country-zooms work without jitter; longitude values remain stable over time.
