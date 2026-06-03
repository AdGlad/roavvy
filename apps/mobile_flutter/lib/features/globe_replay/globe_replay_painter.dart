import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../map/country_centroids.dart';
import '../map/globe_projection.dart';
import 'travel_replay_engine.dart';

/// Renders the arc, moving marker, completed trail, and arrival pulse ring
/// on top of [GlobePainter] during a cinematic travel replay (M108).
///
/// All drawing uses back-face culling via [GlobeProjection.project()] —
/// arc points that return null (z < 0) are invisible and skipped.
class GlobeReplayPainter extends CustomPainter {
  const GlobeReplayPainter({
    required this.projection,
    required this.script,
    required this.currentLegIndex,
    required this.arcProgress,
    required this.pulseValue,
  });

  final GlobeProjection projection;
  final TravelReplayScript script;
  final int currentLegIndex;

  /// 0.0–1.0 fraction of the current leg's arc that has been drawn.
  final double arcProgress;

  /// 0.0–1.0 expansion of the arrival pulse ring.
  final double pulseValue;

  // ── Colour constants ──────────────────────────────────────────────────────

  static const _kTrailColor = Color(0x40FFFFFF);
  static const _kArcColor = Color(0xFFFFD700); // gold, matches visited border
  static const _kMarkerColor = Colors.white;
  static const _kPulseColor = Color(0xFFFFD700);

  static const _kArcStrokeWidth = 2.0;
  static const _kTrailStrokeWidth = 1.2;
  static const _kMarkerRadius = 5.0;
  static const _kDepartureRadius = 3.5;
  static const _kArcPoints = 64; // segments per great-circle arc
  static const _kMaxElevationFraction =
      0.06; // arc lift as fraction of globe radius

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // 1. Completed trail (previous legs, faded dashes).
    for (var i = 0; i < currentLegIndex && i < script.legs.length; i++) {
      _drawArc(
        canvas,
        size,
        script.legs[i],
        1.0,
        _kTrailStrokeWidth,
        _kTrailColor,
        elevation: false,
      );
    }

    if (currentLegIndex >= script.legs.length) return;
    final leg = script.legs[currentLegIndex];

    // 2. Active arc (drawn to arcProgress).
    _drawArc(
      canvas,
      size,
      leg,
      arcProgress,
      _kArcStrokeWidth,
      _kArcColor,
      elevation: true,
    );

    // 3. Departure dot.
    final depPt = _resolveProject(leg.fromLat, leg.fromLng, leg.fromCode, size);
    if (depPt != null) {
      canvas.drawCircle(depPt, _kDepartureRadius, Paint()..color = _kArcColor);
    }

    // 4. Moving marker at arcProgress along the arc.
    if (arcProgress > 0) {
      final markerPt = _arcPoint(leg, arcProgress, size);
      if (markerPt != null) {
        // Drop shadow.
        canvas.drawCircle(
          markerPt + const Offset(1, 1),
          _kMarkerRadius,
          Paint()..color = Colors.black38,
        );
        canvas.drawCircle(
          markerPt,
          _kMarkerRadius,
          Paint()..color = _kMarkerColor,
        );
      }
    }

    // 5. Arrival pulse ring.
    if (pulseValue > 0) {
      final arrPt = _resolveProject(leg.toLat, leg.toLng, leg.toCode, size);
      if (arrPt != null) {
        final r = projection.radius(size);
        final ringRadius = r * 0.05 + r * 0.12 * pulseValue;
        canvas.drawCircle(
          arrPt,
          ringRadius,
          Paint()
            ..color = _kPulseColor.withValues(alpha: (1.0 - pulseValue) * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }
  }

  void _drawArc(
    ui.Canvas canvas,
    ui.Size size,
    TravelLeg leg,
    double fraction,
    double strokeWidth,
    Color color, {
    required bool elevation,
  }) {
    if (fraction <= 0) return;

    final from = _resolveUnit(leg.fromLat, leg.fromLng, leg.fromCode);
    final to = _resolveUnit(leg.toLat, leg.toLng, leg.toCode);
    if (from == null || to == null) return;

    final r = projection.radius(size);
    final maxElevPx = elevation ? r * _kMaxElevationFraction : 0.0;

    final totalPoints = (_kArcPoints * fraction).round().clamp(2, _kArcPoints);
    final path = Path();
    bool started = false;

    for (var i = 0; i <= totalPoints; i++) {
      final t = i / _kArcPoints.toDouble();
      if (t > fraction) break;

      final pt = _slerpProject(from, to, t, maxElevPx, size);
      if (pt == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Projects a point along the great-circle arc at parameter [t] (0–1),
  /// elevated by [maxElevPx * sin(π*t)] above the globe surface.
  Offset? _slerpProject(
    (double, double, double) a,
    (double, double, double) b,
    double t,
    double maxElevPx,
    ui.Size size,
  ) {
    final v = _slerp(a, b, t);
    final elev = maxElevPx * math.sin(math.pi * t);

    // Back-face cull: rotate the unit vector and check z.
    // We manually rotate using the same logic as GlobeProjection._rotate.
    final rotated = _rotate(v);
    if (rotated.$3 < 0) return null;

    final r = projection.radius(size);
    final c = projection.centre(size);
    // Project with elevation (move toward viewer by elev px).
    return Offset(
      c.dx + rotated.$1 * (r + elev),
      c.dy - rotated.$2 * (r + elev),
    );
  }

  /// Spherical linear interpolation between two unit 3D vectors.
  static (double, double, double) _slerp(
    (double, double, double) a,
    (double, double, double) b,
    double t,
  ) {
    final dot = (a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3).clamp(-1.0, 1.0);
    if ((dot - 1.0).abs() < 1e-6) return a;
    if ((dot + 1.0).abs() < 1e-6) {
      // Antipodal — use perpendicular axis to avoid degenerate path.
      final perp = _perp(a);
      return _slerp(_slerp(a, perp, 2 * t), b, t);
    }
    final theta = math.acos(dot);
    final sinTheta = math.sin(theta);
    final wa = math.sin((1 - t) * theta) / sinTheta;
    final wb = math.sin(t * theta) / sinTheta;
    return (
      a.$1 * wa + b.$1 * wb,
      a.$2 * wa + b.$2 * wb,
      a.$3 * wa + b.$3 * wb,
    );
  }

  static (double, double, double) _perp((double, double, double) v) {
    // Returns any unit vector perpendicular to v.
    final abs = (v.$1.abs(), v.$2.abs(), v.$3.abs());
    if (abs.$1 <= abs.$2 && abs.$1 <= abs.$3) {
      return _normalize((0.0, -v.$3, v.$2));
    } else if (abs.$2 <= abs.$3) {
      return _normalize((-v.$3, 0.0, v.$1));
    } else {
      return _normalize((-v.$2, v.$1, 0.0));
    }
  }

  static (double, double, double) _normalize((double, double, double) v) {
    final len = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2 + v.$3 * v.$3);
    if (len < 1e-10) return v;
    return (v.$1 / len, v.$2 / len, v.$3 / len);
  }

  /// Converts a lat/lng pair to a unit 3D vector on the globe sphere.
  static (double, double, double) _latLngToUnit(double lat, double lng) {
    final latR = lat * math.pi / 180.0;
    final lngR = lng * math.pi / 180.0;
    final cosLat = math.cos(latR);
    return (cosLat * math.sin(lngR), math.sin(latR), cosLat * math.cos(lngR));
  }

  /// Resolves a unit 3D vector from explicit GPS or centroid fallback.
  ///
  /// Prefers [lat]/[lng] when both are non-null; falls back to
  /// [kCountryCentroids[code]] otherwise.
  static (double, double, double)? _resolveUnit(
    double? lat,
    double? lng,
    String code,
  ) {
    if (lat != null && lng != null) return _latLngToUnit(lat, lng);
    final c = kCountryCentroids[code];
    if (c == null) return null;
    return _latLngToUnit(c.$1, c.$2);
  }

  /// Projects a screen position from explicit GPS or centroid fallback.
  Offset? _resolveProject(double? lat, double? lng, String code, ui.Size size) {
    if (lat != null && lng != null) {
      return projection.project(lat, lng, size);
    }
    final c = kCountryCentroids[code];
    if (c == null) return null;
    return projection.project(c.$1, c.$2, size);
  }

  /// Projects an arc point along [leg] at parameter [t] (0–1).
  Offset? _arcPoint(TravelLeg leg, double t, ui.Size size) {
    final from = _resolveUnit(leg.fromLat, leg.fromLng, leg.fromCode);
    final to = _resolveUnit(leg.toLat, leg.toLng, leg.toCode);
    if (from == null || to == null) return null;
    final r = projection.radius(size);
    final elev = r * _kMaxElevationFraction * math.sin(math.pi * t);
    return _slerpProject(from, to, t, elev, size);
  }

  /// Applies the same camera rotation as [GlobeProjection._rotate].
  (double, double, double) _rotate((double, double, double) v) {
    final sinLng = math.sin(projection.rotLng);
    final cosLng = math.cos(projection.rotLng);
    final x1 = v.$1 * cosLng + v.$3 * sinLng;
    final y1 = v.$2;
    final z1 = -v.$1 * sinLng + v.$3 * cosLng;

    final sinLat = math.sin(projection.rotLat);
    final cosLat = math.cos(projection.rotLat);
    final x2 = x1;
    final y2 = y1 * cosLat - z1 * sinLat;
    final z2 = y1 * sinLat + z1 * cosLat;
    return (x2, y2, z2);
  }

  @override
  bool shouldRepaint(GlobeReplayPainter old) =>
      !identical(projection, old.projection) ||
      currentLegIndex != old.currentLegIndex ||
      arcProgress != old.arcProgress ||
      pulseValue != old.pulseValue;
}
