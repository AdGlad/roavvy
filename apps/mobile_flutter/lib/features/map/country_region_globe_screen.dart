import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'country_centroids.dart';
import 'globe_projection.dart';

// ── Pastel palette (mirrors CountryRegionMapScreen — ADR-111) ─────────────────

const _kPastelPalette = [
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

// ── Colours (same system as main globe — globe_painter.dart) ─────────────────

const _kOcean          = Color(0xFF1B3A5C); // lighter navy ocean
const _kAtmosphere     = Color(0xFF3A6A9A); // atmosphere rim
const _kWorldCountry   = Color(0xFF2D5280); // world map background countries
const _kWorldBorder    = Color(0xFF3D6490); // world country borders
const _kUnvisitedRegion = Color(0xFF3A6080); // unvisited regions of selected country
const _kUnvisitedBorder = Color(0xFF4E7AA0); // unvisited region borders (clearly visible)

// ── Helpers ───────────────────────────────────────────────────────────────────

String _flagEmoji(String iso) {
  if (iso.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
      String.fromCharCode(base + iso.codeUnitAt(1) - 65);
}

/// Average-of-vertices centroid for back-face culling.
(double, double) _polyCentroid(RegionPolygon p) {
  double sumLat = 0, sumLng = 0;
  for (final v in p.vertices) {
    sumLat += v.$1;
    sumLng += v.$2;
  }
  return (sumLat / p.vertices.length, sumLng / p.vertices.length);
}

/// Average-of-vertices centroid for a [CountryPolygon].
(double, double) _countryCentroid(CountryPolygon p) {
  double sumLat = 0, sumLng = 0;
  for (final v in p.vertices) {
    sumLat += v.$1;
    sumLng += v.$2;
  }
  return (sumLat / p.vertices.length, sumLng / p.vertices.length);
}

/// Scale that makes the selected country fill ~65% of the globe face.
double _autoScale(List<RegionPolygon> polygons, GlobeProjection centered) {
  const kNorm = Size(1000, 1000);
  const kRadius = 500.0;
  const kTargetFraction = 0.65;

  final proj = centered.copyWith(scale: 1.0);
  var maxDist = 0.0;
  for (final p in polygons) {
    for (final v in p.vertices) {
      final pt = proj.project(v.$1, v.$2, kNorm);
      if (pt == null) continue;
      final dx = pt.dx - 500;
      final dy = pt.dy - 500;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > maxDist) maxDist = d;
    }
  }
  if (maxDist < 1.0) return 2.0;
  // Upper bound raised to 14.0 so tiny island nations (e.g. Seychelles) start
  // fully visible rather than as an invisible speck.
  return ((kRadius * kTargetFraction) / maxDist).clamp(1.2, 14.0);
}

// ── RegionGlobePainter ────────────────────────────────────────────────────────

/// Renders a globe showing:
///  1. Ocean background.
///  2. All world country polygons (background context — same fill as main globe).
///  3. Unvisited regions of [countryCode] (lighter than world countries).
///  4. Visited regions of [countryCode] (pastel palette — high contrast).
///  5. Atmosphere rim.
///
/// Mirrors the main globe's colour system (ADR-116) for visual consistency.
class RegionGlobePainter extends CustomPainter {
  const RegionGlobePainter({
    required this.countryPolygons,
    required this.regionPolygons,
    required this.visitedCodes,
    required this.projection,
  });

  /// All world country polygons (from [polygonsProvider]) for background.
  final List<CountryPolygon> countryPolygons;

  /// All region polygons for the selected country.
  final List<RegionPolygon> regionPolygons;

  final Set<String> visitedCodes;
  final GlobeProjection projection;

  static const _kStrokeWidth = 0.4;
  static const _kSuppressed = {'AQ'};

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final r = projection.radius(size);
    final c = projection.centre(size);

    // 1. Ocean.
    canvas.drawCircle(c, r, Paint()..color = _kOcean);

    // 2. World country background — same approach as GlobePainter.
    for (final poly in countryPolygons) {
      if (_kSuppressed.contains(poly.isoCode)) continue;
      final cent = _countryCentroid(poly);
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

        canvas.drawPath(path, Paint()..color = _kWorldCountry);
        canvas.drawPath(
          path,
          Paint()
            ..color = _kWorldBorder
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = _kStrokeWidth,
        );
      }
    }

    // Sort region codes for deterministic pastel assignment.
    final allCodes = regionPolygons.map((p) => p.regionCode).toSet().toList()
      ..sort();
    final codeIndex = {for (var i = 0; i < allCodes.length; i++) allCodes[i]: i};

    // 3. Unvisited regions (drawn first so visited appear on top).
    _drawRegions(canvas, size, visited: false, codeIndex: codeIndex);

    // 4. Visited regions.
    _drawRegions(canvas, size, visited: true, codeIndex: codeIndex);

    // 5. Atmosphere rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _kAtmosphere
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

      final cent = _polyCentroid(poly);
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
          final idx = codeIndex[poly.regionCode] ?? 0;
          fill = _kPastelPalette[idx % _kPastelPalette.length]
              .withValues(alpha: 0.92);
          border = fill.withValues(alpha: 0.6);
        } else {
          fill = _kUnvisitedRegion;
          border = _kUnvisitedBorder;
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

// ── CountryRegionGlobeScreen ──────────────────────────────────────────────────

/// Full-screen interactive globe showing regions for [countryCode].
///
/// Auto-centres and auto-zooms to the country on load. Drag/pinch to explore.
///
/// Replaces [TripMapScreen] (journal) and [CountryRegionMapScreen] (stats
/// region breakdown) with a globe-consistent presentation. (M86)
class CountryRegionGlobeScreen extends ConsumerStatefulWidget {
  const CountryRegionGlobeScreen({
    super.key,
    required this.countryCode,
    this.tripFilter,
    this.subtitle,
  });

  final String countryCode;

  /// When non-null, only regions visited during this trip are highlighted.
  final TripRecord? tripFilter;

  /// Optional subtitle shown in the AppBar (e.g. trip date range).
  final String? subtitle;

  @override
  ConsumerState<CountryRegionGlobeScreen> createState() =>
      _CountryRegionGlobeScreenState();
}

class _CountryRegionGlobeScreenState
    extends ConsumerState<CountryRegionGlobeScreen> {
  late final List<RegionPolygon> _allRegionPolygons;
  late final Future<Set<String>> _visitedCodesFuture;

  GlobeProjection _projection = const GlobeProjection();
  double _baseScale = 1.0;
  Size _canvasSize = Size.zero;
  Offset _lastFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();

    _allRegionPolygons = regionPolygonsForCountry(widget.countryCode);

    // Centre projection on country centroid, then auto-scale to fit.
    final centroid = kCountryCentroids[widget.countryCode];
    final lat = centroid?.$1 ?? 0.0;
    final lng = centroid?.$2 ?? 0.0;
    final centered = GlobeProjection(
      rotLat: lat * math.pi / 180.0,
      rotLng: -lng * math.pi / 180.0,
      scale: 1.0,
    );
    _projection = centered.copyWith(scale: _autoScale(_allRegionPolygons, centered));

    // Load visited region codes.
    final tripFilter = widget.tripFilter;
    if (tripFilter != null) {
      _visitedCodesFuture = ref
          .read(regionRepositoryProvider)
          .loadRegionCodesForTrip(tripFilter)
          .then((codes) => codes.toSet());
    } else {
      _visitedCodesFuture = ref
          .read(regionRepositoryProvider)
          .loadByCountry(widget.countryCode)
          .then((visits) => visits.map((v) => v.regionCode).toSet());
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _projection.scale;
    _lastFocalPoint = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _projection = _projection.copyWith(
          scale: (_baseScale * d.scale).clamp(0.8, 20.0),
        );
      } else {
        final delta = d.focalPoint - _lastFocalPoint;
        _projection = _projection.copyWith(
          rotLng: _projection.rotLng + delta.dx / 150.0,
          rotLat: (_projection.rotLat + delta.dy / 150.0)
              .clamp(-math.pi / 2, math.pi / 2),
        );
      }
    });
    _lastFocalPoint = d.focalPoint;
  }

  @override
  Widget build(BuildContext context) {
    final flag = _flagEmoji(widget.countryCode);
    final countryName = kCountryNames[widget.countryCode] ?? widget.countryCode;

    // World country polygons for background context (same provider as main globe).
    final countryPolygons = ref.watch(polygonsProvider);

    return Scaffold(
      backgroundColor: _kOcean,
      appBar: AppBar(
        backgroundColor: _kOcean,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$flag  $countryName'),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
          ],
        ),
      ),
      body: FutureBuilder<Set<String>>(
        future: _visitedCodesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final visitedCodes = snapshot.data!;

          return GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return CustomPaint(
                  size: _canvasSize,
                  painter: RegionGlobePainter(
                    countryPolygons: countryPolygons,
                    regionPolygons: _allRegionPolygons,
                    visitedCodes: visitedCodes,
                    projection: _projection,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
