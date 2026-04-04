import 'dart:ui' as ui;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/rendering.dart';

import 'country_visual_state.dart';
import 'globe_projection.dart';

// ── Colour constants (mirror country_polygon_layer.dart — ADR-116) ─────────────

const _kOcean = Color(0xFF0D2137);
const _kAtmosphere = Color(0xFF2A4F7A);

const _kUnvisitedFill = Color(0xFF1E3A5F);
const _kUnvisitedBorder = Color(0xFF2A4F7A);

const _kVisitedBorder = Color(0xFFFFD700);
const _kReviewedFill = Color(0xFFC8860A);

const _kNewFill = Color(0xFFFFD700);
const _kNewBorder = Color(0xFFFFFFFF);

const _kDepth1Fill = Color(0xFFD4A017);
const _kDepth2Fill = Color(0xFFC8860A);
const _kDepth3Fill = Color(0xFFB86A00);
const _kDepth4Fill = Color(0xFF8B4500);

Color _depthFillColor(int tripCount) {
  if (tripCount <= 0) return _kDepth1Fill;
  if (tripCount == 1) return _kDepth1Fill;
  if (tripCount <= 3) return _kDepth2Fill;
  if (tripCount <= 5) return _kDepth3Fill;
  return _kDepth4Fill;
}

// ── GlobePainter ──────────────────────────────────────────────────────────────

/// [CustomPainter] that renders all country polygons onto a 3D globe using
/// orthographic projection (ADR-116).
///
/// Rendering order:
/// 1. Ocean fill circle.
/// 2. Country polygon fills + borders (back-face culled by centroid).
/// 3. Atmosphere rim stroke.
class GlobePainter extends CustomPainter {
  const GlobePainter({
    required this.polygons,
    required this.visualStates,
    required this.tripCounts,
    required this.projection,
  });

  final List<CountryPolygon> polygons;
  final Map<String, CountryVisualState> visualStates;
  final Map<String, int> tripCounts;
  final GlobeProjection projection;

  static const _kSuppressed = {'AQ'};
  static const _kStrokeWidth = 0.3;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final r = projection.radius(size);
    final c = projection.centre(size);

    // 1. Ocean circle.
    canvas.drawCircle(c, r, Paint()..color = _kOcean);

    // 2. Country polygons — back-face culled.
    for (final poly in polygons) {
      if (_kSuppressed.contains(poly.isoCode)) continue;

      // Centroid back-face cull: compute approximate centroid from first ring.
      if (poly.vertices.isEmpty) continue;
      final centroidLat =
          poly.vertices.fold(0.0, (s, v) => s + v.$1) / poly.vertices.length;
      final centroidLng =
          poly.vertices.fold(0.0, (s, v) => s + v.$2) / poly.vertices.length;
      if (!projection.isVisible(centroidLat, centroidLng)) continue;

      final state =
          visualStates[poly.isoCode] ?? CountryVisualState.unvisited;
      final fillColor = _fillColor(poly.isoCode, state);
      final borderColor = _borderColor(state);

      // Each CountryPolygon has one contiguous ring; split at antimeridian.
      final rings = projection.splitAtAntimeridian(poly.vertices);
      for (final ring in rings) {
        _paintRing(canvas, size, ring, fillColor, borderColor);
      }
    }

    // 3. Atmosphere rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _kAtmosphere
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintRing(
    ui.Canvas canvas,
    ui.Size size,
    List<(double, double)> ring,
    Color fill,
    Color border,
  ) {
    if (ring.length < 3) return;

    Offset? firstVisible;
    final path = Path();
    bool started = false;

    for (final vertex in ring) {
      final pt = projection.project(vertex.$1, vertex.$2, size);
      if (pt == null) {
        // Back-face vertex: if we were drawing, close the sub-path.
        if (started) {
          path.close();
          started = false;
        }
        continue;
      }
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        firstVisible ??= pt;
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    if (started) path.close();
    if (firstVisible == null) return;

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kStrokeWidth,
    );
  }

  Color _fillColor(String isoCode, CountryVisualState state) =>
      switch (state) {
        CountryVisualState.newlyDiscovered => _kNewFill,
        CountryVisualState.reviewed => _kReviewedFill,
        CountryVisualState.visited ||
        CountryVisualState.target =>
          _depthFillColor(tripCounts[isoCode] ?? 0),
        CountryVisualState.unvisited => _kUnvisitedFill,
      };

  Color _borderColor(CountryVisualState state) => switch (state) {
        CountryVisualState.newlyDiscovered => _kNewBorder,
        CountryVisualState.reviewed ||
        CountryVisualState.visited ||
        CountryVisualState.target =>
          _kVisitedBorder,
        CountryVisualState.unvisited => _kUnvisitedBorder,
      };

  @override
  bool shouldRepaint(GlobePainter old) =>
      !identical(projection, old.projection) ||
      !identical(visualStates, old.visualStates) ||
      !identical(tripCounts, old.tripCounts) ||
      !identical(polygons, old.polygons);
}
