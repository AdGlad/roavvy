import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'region_progress_notifier.dart';

// ── TargetCountryLayer ────────────────────────────────────────────────────────

/// Renders a breathing amber highlight over countries in regions that are
/// exactly 1 visit away from completion (ADR-070).
///
/// Uses a native [PolygonLayer] with a solid amber border
/// (`borderColor: Color(0xFFFFB300)`, `borderStrokeWidth: 2.5`) and a
/// breathing fill opacity (0.10 → 0.25 → 0.10, 2400 ms).
///
/// In reduced-motion mode ([MediaQuery.disableAnimationsOf]) a static opacity
/// of 0.175 (midpoint of the range) is used instead.
class TargetCountryLayer extends ConsumerStatefulWidget {
  const TargetCountryLayer({super.key});

  @override
  ConsumerState<TargetCountryLayer> createState() => _TargetCountryLayerState();
}

class _TargetCountryLayerState extends ConsumerState<TargetCountryLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheOpacity;

  static const _amber = Color(0xFFFFB300);
  static const _staticOpacity = 0.175; // midpoint of 0.10–0.25

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _breatheOpacity = Tween<double>(begin: 0.10, end: 0.25).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polygonData = ref.watch(polygonsProvider);
    final regionProgress = ref.watch(regionProgressProvider);

    // Regions that are exactly 1 country away from completion.
    final targetRegions = regionProgress
        .where((r) => r.remaining == 1 && r.visitedCount > 0)
        .map((r) => r.region)
        .toSet();

    if (targetRegions.isEmpty) {
      if (_breatheController.isAnimating) _breatheController.stop();
      return const SizedBox.shrink();
    }

    // ISO codes in target regions.
    final targetCodes = <String>{};
    for (final entry in kCountryContinent.entries) {
      final region = Region.fromContinentString(entry.value);
      if (region != null && targetRegions.contains(region)) {
        targetCodes.add(entry.key);
      }
    }

    // Build polygon point lists.
    final targetPoints = <List<LatLng>>[];
    for (final p in polygonData) {
      if (targetCodes.contains(p.isoCode)) {
        targetPoints.add([for (final (lat, lng) in p.vertices) LatLng(lat, lng)]);
      }
    }

    if (targetPoints.isEmpty) {
      if (_breatheController.isAnimating) _breatheController.stop();
      return const SizedBox.shrink();
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (!reduceMotion && !_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    } else if (reduceMotion && _breatheController.isAnimating) {
      _breatheController.stop();
    }

    if (reduceMotion) {
      return PolygonLayer(
        polygonCulling: true,
        polygons: [
          for (final pts in targetPoints)
            Polygon(
              points: pts,
              color: _amber.withValues(alpha: _staticOpacity),
              borderColor: _amber,
              borderStrokeWidth: 2.5,
            ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _breatheOpacity,
      builder: (context, _) {
        return PolygonLayer(
          polygonCulling: true,
          polygons: [
            for (final pts in targetPoints)
              Polygon(
                points: pts,
                color: _amber.withValues(alpha: _breatheOpacity.value),
                borderColor: _amber,
                borderStrokeWidth: 2.5,
              ),
          ],
        );
      },
    );
  }
}
