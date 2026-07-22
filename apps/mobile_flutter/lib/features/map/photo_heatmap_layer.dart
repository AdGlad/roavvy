import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';

/// Google Photos-style photo density heatmap.
///
/// Uses Gaussian kernel density estimation so nearby points compound into
/// hotspots. The result maps to a spectral gradient (blue=sparse → pink=dense),
/// matching the Google Photos "Your Map" visual design.
///
/// Visible at zoom < 8; fades smoothly from zoom 5→8 as the cluster
/// layer takes over.
class PhotoHeatmapLayer extends ConsumerWidget {
  const PhotoHeatmapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const SizedBox.shrink();
    final locationsAsync = ref.watch(photoLocationsProvider);
    final locations = locationsAsync.valueOrNull;
    if (locations == null || locations.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    if (camera.zoom >= 8) return const SizedBox.shrink();
    return SizedBox.expand(
      child: CustomPaint(
        painter: _HeatmapPainter(locations: locations, camera: camera),
      ),
    );
  }
}

/// Spectral colour at normalised heat t ∈ [0, 1].
///
/// Matches Google Photos' gradient:
///   sparse (0) → blue → cyan → green → amber → deep-orange → pink/red (1)
Color _spectralColor(double t, double opacity) {
  const stops = <double>[0.0, 0.15, 0.35, 0.55, 0.70, 0.85, 1.0];
  const colors = <Color>[
    Color(0x002196F3), // transparent blue  (isolated point)
    Color(0xAA2196F3), // Material Blue 500
    Color(0xAA00BCD4), // Material Cyan 500
    Color(0xAA4CAF50), // Material Green 500
    Color(0xBBFFC107), // Material Amber 500
    Color(0xBBFF5722), // Material Deep Orange 500
    Color(0xCCE91E63), // Material Pink 500  (hotspot)
  ];

  for (int i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1]) {
      final local = (t - stops[i]) / (stops[i + 1] - stops[i]);
      final c = Color.lerp(colors[i], colors[i + 1], local)!;
      return c.withValues(alpha: c.a * opacity);
    }
  }
  final last = colors.last;
  return last.withValues(alpha: last.a * opacity);
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({required this.locations, required this.camera});

  final List<PhotoLocation> locations;
  final MapCamera camera;

  /// Blob radius in screen pixels — constant like Google Photos.
  static const double _blobRadius = 30.0;

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
  /// with an origin-centred shader + canvas.translate the cache stays small
  /// and no shader is ever rebuilt mid-pan.
  static final Map<int, Shader> _blobShaderCache = {};

  double get _layerOpacity {
    if (camera.zoom < 5.0) return 1.0;
    return (1.0 - (camera.zoom - 5.0) / 3.0).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = _layerOpacity;
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

    // Normalise: isolated point (heat ≈ 1) → blue; dense cluster → pink.
    final normMax = math.max(maxHeat, _heatCap);

    for (int i = 0; i < pts.length; i++) {
      final center = pts[i];
      // Quantise heat/opacity so blobs share cached shaders.
      final qT = ((heat[i] / normMax).clamp(0.0, 1.0) * 32).round();
      final qOpacity = (opacity * 16).round();
      if (qT == 0 || qOpacity == 0) continue;
      final shader = _blobShaderCache.putIfAbsent(qT * 100 + qOpacity, () {
        final color = _spectralColor(qT / 32, qOpacity / 16);
        return RadialGradient(
          // Gaussian-like falloff: full at centre, half-alpha mid, gone at edge.
          colors: [
            color,
            color.withValues(alpha: color.a * 0.5),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: _blobRadius),
        );
      });
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawCircle(Offset.zero, _blobRadius, Paint()..shader = shader);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.camera.zoom != camera.zoom ||
      old.camera.center != camera.center ||
      !identical(old.locations, locations);
}
