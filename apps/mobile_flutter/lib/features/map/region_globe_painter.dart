import 'dart:ui' as ui;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:region_lookup/region_lookup.dart';

import 'globe_projection.dart';

// ── Pastel palette (mirrors CountryRegionMapScreen — ADR-111) ─────────────────

const kPastelPalette = [
  Color(0xFFFFD1DC), // pastel pink
  Color(0xFFA8D8EA), // pastel sky blue
  Color(0xFFB7E5B4), // pastel green
  Color(0xFFFFE5A0), // pastel yellow
  Color(0xFFCFB8E8), // pastel lavender
  Color(0xFFFFBD9B), // pastel peach
  Color(0xFFB5EAD7), // pastel mint
  Color(0xFFDCEFF9), // pastel ice blue
  Color(0xFFFFD9A0), // pastel apricot
  Color(0xFFD4E9C8), // pastel sage
  Color(0xFFF7C6C7), // pastel rose
  Color(0xFFE8D5B7), // pastel tan
];

const kOcean          = Color(0xFF1B3A5C); // lighter navy ocean
const kAtmosphere     = Color(0xFF3A6A9A); // atmosphere rim
const kWorldCountry   = Color(0xFF2D5280); // world map background countries
const kWorldBorder    = Color(0xFF3D6490); // world country borders
const kUnvisitedRegion = Color(0xFF3A6080); // unvisited regions of selected country
const kUnvisitedBorder = Color(0xFF4E7AA0); // unvisited region borders (clearly visible)

/// Average-of-vertices centroid for back-face culling.
(double, double) polyCentroid(RegionPolygon p) {
  double sumLat = 0, sumLng = 0;
  for (final v in p.vertices) {
    sumLat += v.$1;
    sumLng += v.$2;
  }
  return (sumLat / p.vertices.length, sumLng / p.vertices.length);
}

/// Average-of-vertices centroid for a [CountryPolygon].
(double, double) countryCentroid(CountryPolygon p) {
  double sumLat = 0, sumLng = 0;
  for (final v in p.vertices) {
    sumLat += v.$1;
    sumLng += v.$2;
  }
  return (sumLat / p.vertices.length, sumLng / p.vertices.length);
}

/// Renders a globe showing regions for a specific country.
class RegionGlobePainter extends CustomPainter {
  const RegionGlobePainter({
    required this.countryPolygons,
    required this.regionPolygons,
    required this.visitedCodes,
    required this.projection,
    this.highlightColor,
  });

  final List<CountryPolygon> countryPolygons;
  final List<RegionPolygon> regionPolygons;
  final Set<String> visitedCodes;
  final GlobeProjection projection;
  
  /// If provided, visited regions use this color instead of the pastel palette.
  final Color? highlightColor;

  static const _kStrokeWidth = 0.4;
  static const _kSuppressed = {'AQ'};

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final r = projection.radius(size);
    final c = projection.centre(size);

    // 1. Ocean.
    canvas.drawCircle(c, r, Paint()..color = kOcean);

    // 2. World country background.
    for (final poly in countryPolygons) {
      if (_kSuppressed.contains(poly.isoCode)) continue;
      final cent = countryCentroid(poly);
      if (!projection.isVisible(cent.$1, cent.$2)) continue;

      for (final ring in projection.splitAtAntimeridian(poly.vertices)) {
        final pts = <ui.Offset>[];
        for (final v in ring) {
          final pt = projection.project(v.$1, v.$2, size);
          if (pt != null) pts.add(pt);
        }
        if (pts.length < 3) continue;

        final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
        path.close();

        canvas.drawPath(path, Paint()..color = kWorldCountry);
        canvas.drawPath(
          path,
          Paint()
            ..color = kWorldBorder
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = _kStrokeWidth,
        );
      }
    }

    // Sort region codes for deterministic pastel assignment.
    final allCodes = regionPolygons.map((p) => p.regionCode).toSet().toList()
      ..sort();
    final codeIndex = {for (var i = 0; i < allCodes.length; i++) allCodes[i]: i};

    // 3. Unvisited regions.
    _drawRegions(canvas, size, visited: false, codeIndex: codeIndex);

    // 4. Visited regions.
    _drawRegions(canvas, size, visited: true, codeIndex: codeIndex);

    // 5. Atmosphere rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = kAtmosphere
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = r * 0.025,
    );
  }

  void _drawRegions(
    ui.Canvas canvas,
    ui.Size size, {
    required bool visited,
    required Map<String, int> codeIndex,
  }) {
    for (final poly in regionPolygons) {
      final isVisited = visitedCodes.contains(poly.regionCode);
      if (isVisited != visited) continue;

      final cent = polyCentroid(poly);
      if (!projection.isVisible(cent.$1, cent.$2)) continue;

      for (final ring in projection.splitAtAntimeridian(poly.vertices)) {
        final pts = <ui.Offset>[];
        for (final v in ring) {
          final pt = projection.project(v.$1, v.$2, size);
          if (pt != null) pts.add(pt);
        }
        if (pts.length < 3) continue;

        final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
        path.close();

        final Color fill;
        final Color border;
        if (isVisited) {
          if (highlightColor != null) {
            fill = highlightColor!;
          } else {
            final idx = codeIndex[poly.regionCode] ?? 0;
            fill = kPastelPalette[idx % kPastelPalette.length]
                .withValues(alpha: 0.92);
          }
          border = fill.withValues(alpha: 0.6);
        } else {
          fill = kUnvisitedRegion;
          border = kUnvisitedBorder;
        }

        canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(
          path,
          Paint()
            ..color = border
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = _kStrokeWidth,
        );
      }
    }
  }

  @override
  bool shouldRepaint(RegionGlobePainter old) =>
      old.projection != projection ||
      old.visitedCodes != visitedCodes ||
      old.regionPolygons != regionPolygons ||
      old.countryPolygons != countryPolygons;
}
