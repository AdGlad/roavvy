import 'dart:math' as math;
import 'dart:ui';

/// Orthographic projection state for the globe map (ADR-116).
///
/// Holds the current camera orientation ([rotLat], [rotLng] in radians) and
/// [scale] (1.0 = globe fills the shorter canvas dimension).
///
/// All projection math is pure Dart (`dart:math` + `dart:ui` geometry only —
/// no Flutter widget imports).
class GlobeProjection {
  const GlobeProjection({
    this.rotLat = 0.35, // ~20°N default centre
    this.rotLng = 0.0,
    this.scale = 1.0,
  });

  /// Latitude tilt of the camera in radians. Clamped to [−π/2, π/2].
  final double rotLat;

  /// Longitude rotation of the camera in radians.
  final double rotLng;

  /// Zoom scale. 1.0 = globe fills the shorter canvas dimension. Range [0.8, 8.0].
  final double scale;

  GlobeProjection copyWith({
    double? rotLat,
    double? rotLng,
    double? scale,
  }) =>
      GlobeProjection(
        rotLat: (rotLat ?? this.rotLat).clamp(-math.pi / 2, math.pi / 2),
        rotLng: rotLng ?? this.rotLng,
        scale: (scale ?? this.scale).clamp(0.8, 8.0),
      );

  // ── Coordinate helpers ──────────────────────────────────────────────────────

  /// Radius of the globe circle in logical pixels given [canvasSize].
  double radius(Size canvasSize) =>
      canvasSize.shortestSide / 2.0 * scale;

  /// Canvas centre offset.
  Offset centre(Size canvasSize) =>
      Offset(canvasSize.width / 2.0, canvasSize.height / 2.0);

  // ── Projection ──────────────────────────────────────────────────────────────

  /// Projects [lat]/[lng] (degrees) to a screen [Offset] on [canvasSize].
  ///
  /// Returns `null` when the point is on the back face of the globe
  /// (dot product of the rotated unit vector with the view axis < 0).
  Offset? project(double lat, double lng, Size canvasSize) {
    final v = _rotate(_toUnit(lat, lng));
    if (v.$3 < 0) return null; // behind the globe
    final r = radius(canvasSize);
    final c = centre(canvasSize);
    return Offset(c.dx + v.$1 * r, c.dy - v.$2 * r);
  }

  /// Returns true when [lat]/[lng] is on the visible hemisphere.
  bool isVisible(double lat, double lng) =>
      _rotate(_toUnit(lat, lng)).$3 >= 0;

  /// Inverse-projects [screenPoint] on [canvasSize] back to (lat, lng) degrees.
  ///
  /// Returns `null` when [screenPoint] is outside the globe circle.
  (double lat, double lng)? inverseProject(
      Offset screenPoint, Size canvasSize) {
    final c = centre(canvasSize);
    final r = radius(canvasSize);
    final nx = (screenPoint.dx - c.dx) / r;
    final ny = -(screenPoint.dy - c.dy) / r;
    final d2 = nx * nx + ny * ny;
    if (d2 > 1.0) return null; // outside the globe
    final nz = math.sqrt(1.0 - d2);
    final unrotated = _unrotate((nx, ny, nz));
    final lat =
        math.asin(unrotated.$2.clamp(-1.0, 1.0)) * 180.0 / math.pi;
    final lng =
        math.atan2(unrotated.$1, unrotated.$3) * 180.0 / math.pi;
    return (lat, lng);
  }

  // ── Antimeridian splitting ──────────────────────────────────────────────────

  /// Splits [ring] at the antimeridian (±180° longitude) if needed.
  ///
  /// Returns a list of one or two sub-rings. A single-element list means no
  /// crossing was detected.
  List<List<(double, double)>> splitAtAntimeridian(
      List<(double, double)> ring) {
    if (ring.length < 2) return [ring];

    bool hasCrossing = false;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i].$2;
      final b = ring[(i + 1) % ring.length].$2;
      if ((a - b).abs() > 180.0) {
        hasCrossing = true;
        break;
      }
    }
    if (!hasCrossing) return [ring];

    final ringA = <(double, double)>[];
    final ringB = <(double, double)>[];
    var currentRing = ringA;

    for (var i = 0; i < ring.length; i++) {
      final p1 = ring[i];
      final p2 = ring[(i + 1) % ring.length];
      currentRing.add(p1);

      final dLng = p2.$2 - p1.$2;
      if (dLng.abs() > 180.0) {
        final crossLng = dLng > 0 ? -180.0 : 180.0;
        final t = (crossLng - p1.$2) / dLng;
        final crossLat = p1.$1 + t * (p2.$1 - p1.$1);
        currentRing.add((crossLat, crossLng));
        currentRing = (currentRing == ringA) ? ringB : ringA;
        currentRing.add((crossLat, -crossLng));
      }
    }

    if (ringB.isEmpty) return [ringA];
    return [ringA, ringB];
  }

  // ── Internal rotation math ──────────────────────────────────────────────────

  /// Converts [lat]/[lng] (degrees) to a unit 3D vector (x, y, z).
  ///
  /// Convention: z-axis = north pole, x-axis = prime-meridian equator,
  /// y-axis = 90°E equator. View direction is +z.
  static (double, double, double) _toUnit(double lat, double lng) {
    final latR = lat * math.pi / 180.0;
    final lngR = lng * math.pi / 180.0;
    final cosLat = math.cos(latR);
    return (
      cosLat * math.sin(lngR),
      math.sin(latR),
      cosLat * math.cos(lngR),
    );
  }

  /// Applies the camera rotation (rotLng then rotLat) to unit vector [v].
  (double, double, double) _rotate((double, double, double) v) {
    // Rotate around Y axis by rotLng (east-west spin).
    final sinLng = math.sin(rotLng);
    final cosLng = math.cos(rotLng);
    final x1 = v.$1 * cosLng + v.$3 * sinLng;
    final y1 = v.$2;
    final z1 = -v.$1 * sinLng + v.$3 * cosLng;

    // Rotate around X axis by rotLat (north-south tilt).
    final sinLat = math.sin(rotLat);
    final cosLat = math.cos(rotLat);
    final x2 = x1;
    final y2 = y1 * cosLat - z1 * sinLat;
    final z2 = y1 * sinLat + z1 * cosLat;

    return (x2, y2, z2);
  }

  /// Inverse of [_rotate] (transpose of the rotation matrix).
  (double, double, double) _unrotate((double, double, double) v) {
    final sinLat = math.sin(-rotLat);
    final cosLat = math.cos(-rotLat);
    final x1 = v.$1;
    final y1 = v.$2 * cosLat - v.$3 * sinLat;
    final z1 = v.$2 * sinLat + v.$3 * cosLat;

    final sinLng = math.sin(-rotLng);
    final cosLng = math.cos(-rotLng);
    final x2 = x1 * cosLng + z1 * sinLng;
    final y2 = y1;
    final z2 = -x1 * sinLng + z1 * cosLng;

    return (x2, y2, z2);
  }
}
