import 'dart:math' as math;

import '../../data/photo_gps_repository.dart';
import 'globe_projection.dart';
import 'photo_heatmap_layer.dart';

/// Precomputed photo-heatmap geometry for the 3D globe.
///
/// The globe repaints every frame while rotating, so unlike the flat map the
/// KDE density pass cannot run inside paint(). Density is geographic — it
/// does not change as the globe spins — so unit vectors and heat bands are
/// computed once per (dataset, zoom bucket, canvas radius) and cached; the
/// per-frame cost in [GlobePainter] is projection plus six path fills.
///
/// Zoom is quantised into buckets so blobs still merge at world view and
/// separate when zoomed in, recomputing only on bucket changes (a few ms,
/// a handful of times per session).
class GlobeHeatmapData {
  GlobeHeatmapData._(this.unitVectors, this.bands);

  /// Precomputed unit vectors for [GlobeProjection.projectUnit].
  final List<(double, double, double)> unitVectors;

  /// Heat band index (into [kHeatBandColors]) per point.
  final List<int> bands;

  /// Visual constants matching the flat-map heatmap.
  static const double blobRadiusPx = 12.0;
  static const double _influencePx = blobRadiusPx * 2.4;
  static const double _heatCap = 6.0;
  static const int _maxDrawPts = 800;
  static const int _maxDensityPts = 400;

  // Single-entry cache — the globe only ever needs the current view's data.
  static List<PhotoLocation>? _cacheLocations;
  static int _cacheBucket = -1;
  static double _cacheBaseRadius = 0;
  static GlobeHeatmapData? _cache;

  /// Representative scale per zoom bucket (globe scale range is 0.8–8.0).
  static const _bucketScale = <double>[1.0, 2.1, 3.9, 6.3];

  static int _bucketForScale(double scale) {
    if (scale < 1.5) return 0;
    if (scale < 3.0) return 1;
    if (scale < 5.0) return 2;
    return 3;
  }

  /// Returns cached data for [locations] at [scale], recomputing only when
  /// the dataset identity, zoom bucket, or [baseRadiusPx] (globe radius at
  /// scale 1.0, i.e. shortestSide/2) changes.
  static GlobeHeatmapData of(
    List<PhotoLocation> locations,
    double scale,
    double baseRadiusPx,
  ) {
    final bucket = _bucketForScale(scale);
    if (_cache != null &&
        identical(locations, _cacheLocations) &&
        bucket == _cacheBucket &&
        baseRadiusPx == _cacheBaseRadius) {
      return _cache!;
    }
    final data = _compute(locations, _bucketScale[bucket], baseRadiusPx);
    _cacheLocations = locations;
    _cacheBucket = bucket;
    _cacheBaseRadius = baseRadiusPx;
    _cache = data;
    return data;
  }

  static GlobeHeatmapData _compute(
    List<PhotoLocation> locations,
    double repScale,
    double baseRadiusPx,
  ) {
    // Evenly-strided cap (the whole globe is always "in view").
    final stride = locations.length <= _maxDrawPts
        ? 1
        : (locations.length / _maxDrawPts).ceil();
    final units = <(double, double, double)>[];
    for (int i = 0; i < locations.length; i += stride) {
      units.add(
        GlobeProjection.unitVector(locations[i].lat, locations[i].lng),
      );
    }
    if (units.isEmpty) return GlobeHeatmapData._(const [], const []);

    final dStride = units.length <= _maxDensityPts
        ? 1
        : (units.length / _maxDensityPts).ceil();
    final densityPts = <(double, double, double)>[
      for (int i = 0; i < units.length; i += dStride) units[i],
    ];

    // Angular influence radius equivalent to the flat map's screen-pixel
    // influence at this bucket's representative zoom. For the small angles
    // involved, chord length ≈ angle, so squared chord distance between
    // unit vectors substitutes directly into the Gaussian kernel.
    final influenceRad = _influencePx / (baseRadiusPx * repScale);
    final ir2 = influenceRad * influenceRad;

    double maxHeat = 1.0;
    final heat = List<double>.generate(units.length, (i) {
      double h = 1.0; // self-contribution
      final u = units[i];
      for (final o in densityPts) {
        final dx = u.$1 - o.$1;
        final dy = u.$2 - o.$2;
        final dz = u.$3 - o.$3;
        final c2 = dx * dx + dy * dy + dz * dz;
        if (c2 > 0 && c2 < ir2) {
          h += math.exp(-c2 / (ir2 * 0.4));
        }
      }
      if (h > maxHeat) maxHeat = h;
      return h;
    });

    final normMax = math.max(maxHeat, _heatCap);
    final bands = <int>[
      for (final h in heat) heatBandIndex((h / normMax).clamp(0.0, 1.0)),
    ];
    return GlobeHeatmapData._(units, bands);
  }
}
