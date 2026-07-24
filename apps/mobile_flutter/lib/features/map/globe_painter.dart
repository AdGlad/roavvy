import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';

import 'country_centroids.dart';
import 'country_visual_state.dart';
import 'globe_photo_heatmap.dart';
import 'globe_projection.dart';
import 'photo_heatmap_layer.dart';

// ── Colour constants (mirror country_polygon_layer.dart — ADR-116) ─────────────

// Dark palette (default — deep navy globe).
const _kOcean = Color(0xFF1B3A5C);
const _kAtmosphere = Color(0xFF3A6A9A);
const _kUnvisitedFill = Color(0xFF2D5280);
const _kUnvisitedBorder = Color(0xFF3D6490);
const _kVisitedBorder = Color(0xFFFFD700);
const _kReviewedFill = Color(0xFFC8860A);
const _kNewFill = Color(0xFFFFD700);
const _kNewBorder = Color(0xFFFFFFFF);
const _kDepth1Fill = Color(0xFFD4A017);
const _kDepth2Fill = Color(0xFFC8860A);
const _kDepth3Fill = Color(0xFFB86A00);
const _kDepth4Fill = Color(0xFF8B4500);

// Light palette — bright azure ocean, darker slate land for UNESCO dot contrast.
const _kOceanLight = Color(0xFF7DCEF8);
const _kAtmosphereLight = Color(0xFFAEDCFA);
const _kUnvisitedFillLight = Color(0xFF6B8FA3);
const _kUnvisitedBorderLight = Color(0xFF4E7287);
const _kVisitedBorderLight = Color(0xFFC8930A);
const _kReviewedFillLight = Color(0xFFD4920A);
const _kNewFillLight = Color(0xFFFFD700);
const _kNewBorderLight = Color(0xFF002244);
const _kDepth1FillLight = Color(0xFFE8A800);
const _kDepth2FillLight = Color(0xFFD49200);
const _kDepth3FillLight = Color(0xFFBF7500);
const _kDepth4FillLight = Color(0xFF8B5000);

// Ocean lit/shadow variants — endpoints of the sun-biased radial gradient.
const _kOceanLit = Color(0xFF2E5C86);
const _kOceanShadow = Color(0xFF0E2136);
const _kOceanLitLight = Color(0xFFB9E8FF);
const _kOceanShadowLight = Color(0xFF4A9CC7);

Color _depthFillColor(int tripCount) {
  if (tripCount <= 0) return _kDepth1Fill;
  if (tripCount == 1) return _kDepth1Fill;
  if (tripCount <= 3) return _kDepth2Fill;
  if (tripCount <= 5) return _kDepth3Fill;
  return _kDepth4Fill;
}

Color _depthFillColorLight(int tripCount) {
  if (tripCount <= 0) return _kDepth1FillLight;
  if (tripCount == 1) return _kDepth1FillLight;
  if (tripCount <= 3) return _kDepth2FillLight;
  if (tripCount <= 5) return _kDepth3FillLight;
  return _kDepth4FillLight;
}

// ── Sun direction (day/night + lighting) ────────────────────────────────────

/// Approximate subsolar point (lat, lng in degrees) for [utc].
///
/// Stylistic approximation only (no equation-of-time correction) — good
/// enough for a soft day/night wash, not for navigation.
(double lat, double lng) _subsolarPoint(DateTime utc) {
  final dayOfYear = utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;
  final decl = 23.44 * math.sin(2 * math.pi * (284 + dayOfYear) / 365.0);
  final hours = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
  final lng = ((12.0 - hours) * 15.0 + 180.0) % 360.0 - 180.0;
  return (decl, lng);
}

// ── Graticule (lat/long grid) ───────────────────────────────────────────────

const _kGraticuleStepDeg = 5;

List<List<(double, double)>> _buildMeridians() => [
  for (var lng = -180; lng < 180; lng += 30)
    [
      for (var lat = -90; lat <= 90; lat += _kGraticuleStepDeg)
        (lat.toDouble(), lng.toDouble()),
    ],
];

List<List<(double, double)>> _buildParallels() => [
  for (var lat = -60; lat <= 60; lat += 30)
    [
      for (var lng = -180; lng <= 180; lng += _kGraticuleStepDeg)
        (lat.toDouble(), lng.toDouble()),
    ],
];

final _kGraticuleLines = [..._buildMeridians(), ..._buildParallels()];

/// Graticule vertices as unit 3D vectors — computed once so the per-frame
/// cost is rotation multiply-adds, not ~800 lat/lng trig conversions.
final _kGraticuleUnitLines = [
  for (final line in _kGraticuleLines)
    [for (final v in line) GlobeProjection.unitVector(v.$1, v.$2)],
];

// ── Cloud layer ──────────────────────────────────────────────────────────────

class _CloudBlob {
  const _CloudBlob(this.lat, this.lng, this.radiusFactor, this.opacity, this.driftSpeed);
  final double lat, lng, radiusFactor, opacity, driftSpeed;
}

/// Generated once — fixed seed so blob placement is deterministic per install.
final _kCloudBlobs = _buildClouds(24, seed: 0xC10DED);

List<_CloudBlob> _buildClouds(int count, {required int seed}) {
  final rng = math.Random(seed);
  return List.generate(count, (_) {
    return _CloudBlob(
      rng.nextDouble() * 140 - 70, // bias away from the poles
      rng.nextDouble() * 360 - 180,
      0.05 + rng.nextDouble() * 0.09,
      0.05 + rng.nextDouble() * 0.08,
      0.4 + rng.nextDouble() * 0.9, // relative drift speed (parallax)
    );
  });
}

// Full drift cycle for the slowest cloud blob (driftSpeed 1.0).
const _kCloudCycleMs = 40 * 60 * 1000; // 40 minutes

// ── GlobePainter ──────────────────────────────────────────────────────────────

/// [CustomPainter] that renders all country polygons onto a 3D globe using
/// orthographic projection (ADR-116).
///
/// Rendering order:
/// 1. Ocean fill circle — radial gradient biased toward the sun direction.
/// 2. Lat/long graticule (faint grid, shows through ocean gaps only).
/// 3. Country polygon fills + borders (back-face culled by centroid).
/// 4. Atmosphere rim stroke.
/// 5. Day/night + rim-light wash — approximate lighting from wall-clock UTC.
/// 6. Procedural cloud layer (soft, low-opacity, drifts independently).
/// 7. Optional highlight halo on [highlightedCode] (celebration — ADR-123).
/// 8. Heritage/challenge site markers, drawn last so they stay legible.
class GlobePainter extends CustomPainter {
  const GlobePainter({
    required this.polygons,
    required this.visualStates,
    required this.tripCounts,
    required this.projection,
    this.isDark = true,
    this.highlightedCode,
    this.pulseValue = 0.0,
    this.culturalSiteCoords = const [],
    this.naturalSiteCoords = const [],
    this.unvisitedHeritageSiteCoords = const [],
    this.heritagePulseValue = 0.0,
    this.challengeHighlightCoord,
    this.challengeHighlightPulse = 0.0,
    this.photoHeatmap,
    this.afterPainter,
  });

  final List<CountryPolygon> polygons;
  final Map<String, CountryVisualState> visualStates;
  final Map<String, int> tripCounts;
  final GlobeProjection projection;
  final bool isDark;

  /// ISO code of country to render a celebration halo on, or null for none.
  final String? highlightedCode;

  /// Animation value 0.0–1.0 driving the halo opacity and size. 0.0 = hidden.
  final double pulseValue;

  /// GPS coords of Cultural/Mixed UNESCO sites (amber dots) (M126/M128).
  final List<(double lat, double lng)> culturalSiteCoords;

  /// GPS coords of Natural UNESCO sites (green dots) (M128).
  final List<(double lat, double lng)> naturalSiteCoords;

  /// GPS coords of unvisited UNESCO sites — dim static amber (M129).
  final List<(double lat, double lng)> unvisitedHeritageSiteCoords;

  /// Animation value 0.0–1.0 driving heritage site dot pulse. 0.0 = hidden glow.
  final double heritagePulseValue;

  /// GPS coord of the challenge site to highlight with a red dot, or null.
  final (double, double)? challengeHighlightCoord;

  /// Animation value 0.0–1.0 driving the red highlight pulse. 0.0 = no glow.
  final double challengeHighlightPulse;

  /// Precomputed photo heatmap (unit vectors + bands), or null when the
  /// globe heatmap toggle is off. Density is precomputed per zoom bucket in
  /// [GlobeHeatmapData]; painting is projection + six path fills per frame.
  final GlobeHeatmapData? photoHeatmap;

  /// Optional painter called after the globe is drawn (e.g. replay arc layer).
  final CustomPainter? afterPainter;

  static const _kSuppressed = {'AQ'};
  static const _kStrokeWidth = 0.3;

  // ── Per-geometry caches (UI isolate only) ─────────────────────────────────
  // Polygon lists come from providers and are identity-stable across frames,
  // so geometry-derived values are cached per CountryPolygon instance:
  // centroid (back-face cull), antimeridian-split rings, and the rings as
  // precomputed unit vectors for the fast projection path.
  static final _centroidCache = Expando<(double, double)>();
  static final _unitRingsCache =
      Expando<List<List<(double, double, double)>>>();

  // Shader caches — keyed by quantised inputs so shaders are rebuilt a few
  // times per second at most (sun direction drifts slowly) instead of every
  // frame. Bounded: keys change only with canvas size / theme / sun drift.
  static int? _oceanShaderKey;
  static ui.Shader? _oceanShader;
  static int? _washShaderKey;
  static ui.Shader? _washShader;
  static final _cloudShaderCache = <int, ui.Shader>{};

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final r = projection.radius(size);
    final c = projection.centre(size);

    // Approximate sun direction in screen space — reused below for the ocean
    // gradient and the day/night + rim-light wash. Recomputed every frame
    // from wall-clock UTC; the globe already repaints continuously via the
    // rotation ticker (GlobeMapWidget) so this stays live without extra state.
    final sun = _subsolarPoint(DateTime.now().toUtc());
    final sunView = projection.viewVector(sun.$1, sun.$2);
    final sunDir = Offset(sunView.$1, -sunView.$2); // flip y: screen-down axis
    final sunDirNorm =
        sunDir.distance > 0.01 ? sunDir / sunDir.distance : Offset.zero;

    // 1. Ocean fill — radial gradient biased toward the lit side. The sun
    // direction is quantised so the shader is only rebuilt when it visibly
    // moves (idle spin drifts it ~5°/sec), not on every frame.
    final qSunX = (sunDirNorm.dx * 50).round();
    final qSunY = (sunDirNorm.dy * 50).round();
    final oceanKey = Object.hash(qSunX, qSunY, r.round(), c.dx, c.dy, isDark);
    if (_oceanShaderKey != oceanKey) {
      _oceanShaderKey = oceanKey;
      _oceanShader = RadialGradient(
        center: Alignment(qSunX / 50 * 0.6, qSunY / 50 * 0.6),
        radius: 1.15,
        colors:
            isDark
                ? const [_kOceanLit, _kOcean, _kOceanShadow]
                : const [_kOceanLitLight, _kOceanLight, _kOceanShadowLight],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    }
    canvas.drawCircle(c, r, Paint()..shader = _oceanShader);

    // 2. Lat/long graticule — faint, shows through ocean gaps; land polygons
    // painted next cover it over landmasses (ADR-116 layering).
    _paintGraticule(canvas, size);

    // 3. Country polygons — back-face culled. Centroids, antimeridian splits
    // and unit vectors depend only on the (identity-stable) geometry, so they
    // are computed once per polygon and cached.
    for (final poly in polygons) {
      if (_kSuppressed.contains(poly.isoCode)) continue;
      if (poly.vertices.isEmpty) continue;

      var centroid = _centroidCache[poly];
      if (centroid == null) {
        final centroidLat =
            poly.vertices.fold(0.0, (s, v) => s + v.$1) / poly.vertices.length;
        final centroidLng =
            poly.vertices.fold(0.0, (s, v) => s + v.$2) / poly.vertices.length;
        centroid = (centroidLat, centroidLng);
        _centroidCache[poly] = centroid;
      }
      if (!projection.isVisible(centroid.$1, centroid.$2)) continue;

      final state = visualStates[poly.isoCode] ?? CountryVisualState.unvisited;
      final fillColor = _fillColor(poly.isoCode, state);
      final borderColor = _borderColor(state);

      // Each CountryPolygon has one contiguous ring; split at antimeridian.
      var unitRings = _unitRingsCache[poly];
      if (unitRings == null) {
        unitRings = [
          for (final ring in projection.splitAtAntimeridian(poly.vertices))
            [for (final v in ring) GlobeProjection.unitVector(v.$1, v.$2)],
        ];
        _unitRingsCache[poly] = unitRings;
      }
      for (final ring in unitRings) {
        _paintRing(canvas, size, ring, fillColor, borderColor);
      }
    }

    // 4. Atmosphere rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = isDark ? _kAtmosphere : _kAtmosphereLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 5. Day/night + rim-light wash. A single linear gradient along the sun
    // axis: a soft highlight on the lit limb, transparent through the middle,
    // a dark wash on the night limb. Approximate (per-globe, not per-country)
    // but gives a convincing "one lit sphere" read without per-vertex lighting.
    // Reuses the quantised sun direction from the ocean pass so the gradient
    // is rebuilt only when the sun direction visibly moves.
    final washKey = Object.hash(qSunX, qSunY, r.round(), c.dx, c.dy, isDark);
    if (_washShaderKey != washKey) {
      _washShaderKey = washKey;
      final qSunDir = Offset(qSunX / 50, qSunY / 50);
      _washShader = ui.Gradient.linear(
        c - qSunDir * r,
        c + qSunDir * r,
        isDark
            ? [
              const Color(0xFF01060D).withValues(alpha: 0.45),
              const Color(0xFF01060D).withValues(alpha: 0.12),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.10),
            ]
            : [
              const Color(0xFF0B2438).withValues(alpha: 0.28),
              const Color(0xFF0B2438).withValues(alpha: 0.08),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.22),
            ],
        const [0.0, 0.32, 0.62, 1.0],
      );
    }
    canvas.drawCircle(c, r, Paint()..shader = _washShader);

    // 6. Cloud layer — soft, low-opacity, drifts independently of rotation.
    // Drawn above the lighting wash but below markers so tap targets stay crisp.
    _paintClouds(canvas, size);

    // 6b. Photo heatmap (optional, toggle-gated) — above the lighting wash
    // and clouds so the bands stay true to their colours, below markers and
    // halos so tap targets stay crisp. No blur on the globe: the banded
    // alpha carries the contour look and blur would force per-frame layer
    // work on a canvas that repaints continuously while rotating.
    final heatmapData = photoHeatmap;
    if (heatmapData != null && heatmapData.unitVectors.isNotEmpty) {
      final projected = List<Offset?>.generate(
        heatmapData.unitVectors.length,
        (i) => projection.projectUnit(heatmapData.unitVectors[i], size),
      );
      for (var b = 0; b < kHeatBandColors.length; b++) {
        final bandRadius =
            GlobeHeatmapData.blobRadiusPx * kHeatBandRadiusFactor[b];
        final path = ui.Path();
        var any = false;
        for (var i = 0; i < projected.length; i++) {
          if (heatmapData.bands[i] < b) continue;
          final pt = projected[i];
          if (pt == null) continue; // back face
          path.addOval(Rect.fromCircle(center: pt, radius: bandRadius));
          any = true;
        }
        if (!any) break;
        canvas.drawPath(path, Paint()..color = kHeatBandColors[b]);
      }
    }

    // 7. Celebration halo — drawn on top of everything (ADR-123).
    if (highlightedCode != null && pulseValue > 0.0) {
      final centroid = kCountryCentroids[highlightedCode];
      if (centroid != null) {
        final haloCenter = projection.project(centroid.$1, centroid.$2, size);
        if (haloCenter != null) {
          final haloRadius = r * 0.06 * (1.0 + pulseValue * 0.5);
          canvas.drawCircle(
            haloCenter,
            haloRadius,
            Paint()..color = Colors.white.withValues(alpha: pulseValue * 0.35),
          );
        }
      }
    }

    // 8. Heritage site dots (M126/M128).
    // Cultural/Mixed = amber; Natural = green.
    // Inner dot always visible; outer glow ring pulses.
    void paintHeritageDots(
      List<(double, double)> coords,
      Color dotColor,
      Color glowColor,
    ) {
      for (final coord in coords) {
        final pt = projection.project(coord.$1, coord.$2, size);
        if (pt == null) continue;
        if (heritagePulseValue > 0.0) {
          canvas.drawCircle(
            pt,
            r * 0.008 * (1.0 + heritagePulseValue * 0.6),
            Paint()
              ..color = glowColor.withValues(alpha: heritagePulseValue * 0.30),
          );
        }
        canvas.drawCircle(
          pt,
          r * 0.0036,
          Paint()..color = dotColor.withValues(alpha: 0.90),
        );
      }
    }

    // Unvisited sites — dim amber static dots (no pulse), drawn first (M129).
    if (unvisitedHeritageSiteCoords.isNotEmpty) {
      final dotColor =
          isDark
              ? Colors.amber[200]!.withValues(alpha: 0.40)
              : Colors.amber[700]!.withValues(alpha: 0.60);
      for (final coord in unvisitedHeritageSiteCoords) {
        final pt = projection.project(coord.$1, coord.$2, size);
        if (pt == null) continue;
        canvas.drawCircle(pt, r * 0.002, Paint()..color = dotColor);
      }
    }
    if (culturalSiteCoords.isNotEmpty) {
      paintHeritageDots(
        culturalSiteCoords,
        Colors.amber[300]!,
        Colors.amber[400]!,
      );
    }
    if (naturalSiteCoords.isNotEmpty) {
      paintHeritageDots(
        naturalSiteCoords,
        Colors.green[400]!,
        Colors.green[300]!,
      );
    }

    // 9. Challenge site highlight — large pulsing red dot (M134+).
    final challengeCoord = challengeHighlightCoord;
    if (challengeCoord != null) {
      final pt = projection.project(challengeCoord.$1, challengeCoord.$2, size);
      if (pt != null) {
        // Outer glow ring — pulses.
        canvas.drawCircle(
          pt,
          r * 0.022 * (1.0 + challengeHighlightPulse * 0.6),
          Paint()
            ..color = Colors.red.withValues(
              alpha: 0.30 * challengeHighlightPulse,
            ),
        );
        // Solid red dot.
        canvas.drawCircle(pt, r * 0.014, Paint()..color = Colors.redAccent);
      }
    }

    // 10. Optional overlay painter (e.g. replay arc layer — M134).
    afterPainter?.paint(canvas, size);
  }

  /// Draws faint meridian/parallel lines, back-face culled per-segment like
  /// [_paintRing] but as open polylines (stroke only, no fill/close).
  void _paintGraticule(ui.Canvas canvas, ui.Size size) {
    final color =
        isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
    for (final line in _kGraticuleUnitLines) {
      final path = Path();
      var started = false;
      for (final vertex in line) {
        final pt = projection.projectUnit(vertex, size);
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
      canvas.drawPath(path, paint);
    }
  }

  /// Draws soft, low-opacity cloud blobs that drift slowly in longitude,
  /// independent of globe rotation (driven by wall-clock time).
  void _paintClouds(ui.Canvas canvas, ui.Size size) {
    final r = projection.radius(size);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final blob in _kCloudBlobs) {
      final cycleT = (nowMs % _kCloudCycleMs) / _kCloudCycleMs; // 0..1
      final driftedLng = blob.lng + cycleT * 360.0 * blob.driftSpeed;
      final pt = projection.project(blob.lat, driftedLng, size);
      if (pt == null) continue;
      // Shader is origin-centred and cached by (radius, opacity); the canvas
      // is translated per blob so drift/rotation never rebuilds shaders.
      // Radius is quantised to whole pixels to keep the cache bounded while
      // zooming.
      final blobRadius = (r * blob.radiusFactor).roundToDouble();
      if (blobRadius < 1) continue;
      final key = Object.hash(blobRadius, blob.opacity);
      if (_cloudShaderCache.length > 256) _cloudShaderCache.clear();
      final shader = _cloudShaderCache.putIfAbsent(
        key,
        () => RadialGradient(
          colors: [
            Colors.white.withValues(alpha: blob.opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: blobRadius)),
      );
      canvas.save();
      canvas.translate(pt.dx, pt.dy);
      canvas.drawCircle(Offset.zero, blobRadius, Paint()..shader = shader);
      canvas.restore();
    }
  }

  void _paintRing(
    ui.Canvas canvas,
    ui.Size size,
    List<(double, double, double)> ring,
    Color fill,
    Color border,
  ) {
    if (ring.length < 3) return;

    Offset? firstVisible;
    final path = Path();
    bool started = false;

    for (final vertex in ring) {
      final pt = projection.projectUnit(vertex, size);
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

  Color _fillColor(String isoCode, CountryVisualState state) => switch (state) {
    CountryVisualState.newlyDiscovered =>
      isDark ? _kNewFill : _kNewFillLight,
    CountryVisualState.reviewed =>
      isDark ? _kReviewedFill : _kReviewedFillLight,
    CountryVisualState.visited ||
    CountryVisualState.target =>
      isDark
          ? _depthFillColor(tripCounts[isoCode] ?? 0)
          : _depthFillColorLight(tripCounts[isoCode] ?? 0),
    CountryVisualState.unvisited =>
      isDark ? _kUnvisitedFill : _kUnvisitedFillLight,
  };

  Color _borderColor(CountryVisualState state) => switch (state) {
    CountryVisualState.newlyDiscovered =>
      isDark ? _kNewBorder : _kNewBorderLight,
    CountryVisualState.reviewed ||
    CountryVisualState.visited ||
    CountryVisualState.target =>
      isDark ? _kVisitedBorder : _kVisitedBorderLight,
    CountryVisualState.unvisited =>
      isDark ? _kUnvisitedBorder : _kUnvisitedBorderLight,
  };

  @override
  bool shouldRepaint(GlobePainter old) =>
      isDark != old.isDark ||
      !identical(projection, old.projection) ||
      !identical(visualStates, old.visualStates) ||
      !identical(tripCounts, old.tripCounts) ||
      !identical(polygons, old.polygons) ||
      highlightedCode != old.highlightedCode ||
      pulseValue != old.pulseValue ||
      !identical(culturalSiteCoords, old.culturalSiteCoords) ||
      !identical(naturalSiteCoords, old.naturalSiteCoords) ||
      !identical(
        unvisitedHeritageSiteCoords,
        old.unvisitedHeritageSiteCoords,
      ) ||
      heritagePulseValue != old.heritagePulseValue ||
      challengeHighlightCoord != old.challengeHighlightCoord ||
      challengeHighlightPulse != old.challengeHighlightPulse ||
      !identical(photoHeatmap, old.photoHeatmap) ||
      afterPainter != old.afterPainter;
}
