// lib/features/world_leap/domain/models/world_leap_camera_mode.dart

/// Camera behaviour during the slingshot flight arc.
enum WorldLeapCameraMode {
  /// No camera movement — map stays where the player left it.
  stationary,

  /// Camera follows the projectile at medium zoom.
  /// Zoom follows a parabola: wide at launch, tighter at apex, settled on landing.
  birdseye,

  /// Close tight follow — higher zoom, dramatic terrain scroll.
  pov,
}

extension WorldLeapCameraModeX on WorldLeapCameraMode {
  /// Label shown on the toggle button.
  String get label => switch (this) {
        WorldLeapCameraMode.stationary => 'Static',
        WorldLeapCameraMode.birdseye => "Bird's-eye",
        WorldLeapCameraMode.pov => 'POV',
      };

  /// Icon for the toggle button.
  String get iconAsset => switch (this) {
        WorldLeapCameraMode.stationary => 'location_on',
        WorldLeapCameraMode.birdseye => 'satellite_alt',
        WorldLeapCameraMode.pov => 'flight',
      };

  /// Next mode in the cycle: stationary → birdseye → pov → stationary.
  WorldLeapCameraMode get next => switch (this) {
        WorldLeapCameraMode.stationary => WorldLeapCameraMode.birdseye,
        WorldLeapCameraMode.birdseye => WorldLeapCameraMode.pov,
        WorldLeapCameraMode.pov => WorldLeapCameraMode.stationary,
      };

  /// Whether the camera should track the projectile in this mode.
  bool get isTracking => this != WorldLeapCameraMode.stationary;

  /// Compute map zoom for flight progress [t] ∈ [0, 1].
  ///
  /// Uses a quadratic through three control points:
  ///   Bird's-eye : launch=2.0, apex=3.0, landing=3.5
  ///   POV        : launch=2.5, apex=4.5, landing=5.0
  double zoomAt(double t) => switch (this) {
        // zoom(t) = 2.0 + 2.5t − t²
        WorldLeapCameraMode.birdseye => 2.0 + 2.5 * t - t * t,
        // zoom(t) = 2.5 + 5.5t − 3.0t²
        WorldLeapCameraMode.pov => 2.5 + 5.5 * t - 3.0 * t * t,
        WorldLeapCameraMode.stationary => 0, // unused
      };
}
