import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';

/// Google Photos-style photo density heatmap.
///
/// Uses Gaussian kernel density estimation so nearby points compound into
/// hotspots, rendered with Google Photos' "Your Map" colour ramp:
/// violet (sparse) → blue → teal → yellow → orange → hot pink (dense).
/// Colours are banded rather than smoothly interpolated to reproduce the
/// contour-ring / weather-radar look of the original, at ~55% opacity so
/// the map stays readable underneath.
///
/// Like Google Photos, the heatmap persists at every zoom level — there is
/// no cluster handoff; blob radius is constant in screen pixels.
class PhotoHeatmapLayer extends ConsumerWidget {
  const PhotoHeatmapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const SizedBox.shrink();
    final locationsAsync = ref.watch(photoLocationsProvider);
    final locations = locationsAsync.valueOrNull;
    if (locations == null || locations.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    return SizedBox.expand(
      child: CustomPaint(
        painter: _HeatmapPainter(locations: locations, camera: camera),
      ),
    );
  }
}

/// Google Photos heat bands, outermost (sparse) → innermost (dense core).
///
/// Colours sampled from Google Photos "Your Map" screenshots: violet sparse
/// field, blue/teal/yellow/orange transition rings, hot-pink core. Alpha is
/// baked in (~45-55%); bands composite on top of each other so cores read
/// stronger, matching the original.
const _kBandColors = <Color>[
  Color(0x78A574EC), // violet — sparse field
  Color(0x785C7EDC), // periwinkle blue
  Color(0x784FBFA0), // teal
  Color(0x82E8C93F), // yellow
  Color(0x8CF08A3C), // orange
  Color(0x96F37DC6), // hot pink — dense core
];

/// Per-band circle radius as a fraction of the base blob radius — hotter
/// bands are drawn smaller, producing the nested contour-ring look.
const _kBandRadiusFactor = <double>[1.0, 0.80, 0.63, 0.48, 0.36, 0.26];

/// Band index (0-5) for normalised heat t ∈ [0, 1].
int _bandIndex(double t) {
  if (t < 0.30) return 0;
  if (t < 0.45) return 1;
  if (t < 0.58) return 2;
  if (t < 0.70) return 3;
  if (t < 0.84) return 4;
  return 5;
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({required this.locations, required this.camera});

  final List<PhotoLocation> locations;
  final MapCamera camera;

  /// Blob radius in screen pixels — constant like Google Photos, where an
  /// isolated photo reads as a small subtle violet dot (~3% of screen width).
  static const double _blobRadius = 12.0;

  /// Influence radius for density accumulation; wider = smoother merging.
  static const double _influenceRadius = _blobRadius * 2.4;

  /// Heat value that reaches full pink/red.
  /// Keeps isolated points cool (blue) rather than falsely hot.
  static const double _heatCap = 6.0;

  /// Cap on points in the O(N²) density pass to preserve 60 fps.
  static const int _maxDensityPts = 400;

  /// Hard cap on points that are projected and drawn per paint. Without this
  /// a large library (tens of thousands of geotagged photos) allocates a
  /// shader and draws a blob per photo at world zoom — seconds per frame.
  /// The heatmap is a density visual, so an evenly-strided subsample reads
  /// identically.
  static const int _maxDrawPts = 800;

  /// Blob shaders keyed by quantised (heat, opacity) — radius is constant, so
  @override
  void paint(Canvas canvas, Size size) {
    const margin = _blobRadius * 2.0;
    final ir2 = _influenceRadius * _influenceRadius;

    // Evenly-strided subsample of the source list, projected and filtered to
    // the viewport. Bounds both the projection pass and the draw pass below.
    final srcStride = locations.length <= _maxDrawPts
        ? 1
        : (locations.length / _maxDrawPts).ceil();
    final pts = <Offset>[];
    for (int i = 0; i < locations.length; i += srcStride) {
      final loc = locations[i];
      final p = camera.latLngToScreenPoint(LatLng(loc.lat, loc.lng));
      final o = Offset(p.x, p.y);
      if (o.dx >= -margin &&
          o.dx <= size.width + margin &&
          o.dy >= -margin &&
          o.dy <= size.height + margin) {
        pts.add(o);
      }
    }
    if (pts.isEmpty) return;

    // Evenly-spaced subsample for the density pass (performance guard).
    final stride = pts.length <= _maxDensityPts
        ? 1
        : (pts.length / _maxDensityPts).ceil();
    final densityPts = <Offset>[
      for (int i = 0; i < pts.length; i += stride) pts[i],
    ];

    // Gaussian KDE: each point accumulates contributions from neighbours.
    double maxHeat = 1.0;
    final heat = List<double>.generate(pts.length, (i) {
      double h = 1.0; // self-contribution
      for (final other in densityPts) {
        final dx = pts[i].dx - other.dx;
        final dy = pts[i].dy - other.dy;
        final d2 = dx * dx + dy * dy;
        if (d2 > 0 && d2 < ir2) {
          h += math.exp(-d2 / (ir2 * 0.4));
        }
      }
      if (h > maxHeat) maxHeat = h;
      return h;
    });

    // Normalise: isolated point (heat ≈ 1) → violet; dense cluster → pink.
    final normMax = math.max(maxHeat, _heatCap);
    final bands = List<int>.generate(
      pts.length,
      (i) => _bandIndex((heat[i] / normMax).clamp(0.0, 1.0)),
    );

    // Stacked contour rendering (the Google Photos look): for each band,
    // union the circles of every point at least that hot into ONE path and
    // fill it once — overlapping circles merge into amoeba-shaped contours
    // with no alpha seams, and hotter bands nest inside cooler ones as
    // progressively smaller rings. A soft blur feathers each contour edge.
    for (int b = 0; b < _kBandColors.length; b++) {
      final radius = _blobRadius * _kBandRadiusFactor[b];
      final path = ui.Path();
      var any = false;
      for (int i = 0; i < pts.length; i++) {
        if (bands[i] < b) continue;
        path.addOval(Rect.fromCircle(center: pts[i], radius: radius));
        any = true;
      }
      if (!any) break; // no point reaches this band → none reaches hotter ones
      canvas.drawPath(
        path,
        Paint()
          ..color = _kBandColors[b]
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.camera.zoom != camera.zoom ||
      old.camera.center != camera.center ||
      !identical(old.locations, locations);
}
