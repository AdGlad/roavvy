import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'country_centroids.dart';
import 'globe_projection.dart';
import 'region_globe_painter.dart';

String _flagEmoji(String iso) {
  if (iso.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
      String.fromCharCode(base + iso.codeUnitAt(1) - 65);
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
    final mainPolygons =
        _allRegionPolygons.where((p) => !p.regionCode.endsWith('~')).toList();
    _projection = centered.copyWith(
      scale: _autoScale(
        mainPolygons.isNotEmpty ? mainPolygons : _allRegionPolygons,
        centered,
      ),
    );

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
          rotLat: (_projection.rotLat + delta.dy / 150.0).clamp(
            -math.pi / 2,
            math.pi / 2,
          ),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? kOcean : theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$flag  $countryName'),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
          ],
        ),
      ),
      body: FutureBuilder<Set<String>>(
        future: _visitedCodesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
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
