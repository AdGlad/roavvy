import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import 'country_visual_state.dart';

/// ISO codes suppressed from the map (mirrors [MapScreen]).
const _kSuppressedCodes = {'AQ'};

// ── Colour definitions (ADR-066) ──────────────────────────────────────────────

const _kUnvisitedFill = Color(0xFFE5E7EB);     // grey-200
const _kUnvisitedBorder = Color(0xFF9CA3AF);   // grey-400

const _kVisitedFill = Color(0xFFFFB300);       // amber-700
const _kVisitedBorder = Color(0xFFFF8F00);     // amber-900

const _kReviewedFill = Color(0xFFFFCA28);      // amber-400
const _kReviewedBorder = Color(0xFFFFB300);    // amber-700

const _kNewFill = Color(0xFFFFD54F);           // amber-300
const _kNewBorder = Color(0xFFFFCA28);         // amber-400

// Depth colouring tiers — more trips → richer amber (ADR-066).
const _kDepth1Fill = Color(0xFFFFE082); // 1 trip:  amber-200 (lightest)
const _kDepth2Fill = Color(0xFFFFCA28); // 2-3:     amber-400 (mid)
const _kDepth3Fill = Color(0xFFFFB300); // 4-5:     amber-600 (dark)
const _kDepth4Fill = Color(0xFFFF8F00); // 6+:      amber-800 (deepest)

/// Returns the fill [Color] for a visited country based on [tripCount].
///
/// Tier boundaries:  0 → fallback visited colour, 1 → lightest,
/// 2-3 → mid, 4-5 → dark, 6+ → deepest.
// ignore: public_member_api_docs — exposed for unit testing
Color depthFillColor(int tripCount) {
  if (tripCount <= 0) return _kVisitedFill;
  if (tripCount == 1) return _kDepth1Fill;
  if (tripCount <= 3) return _kDepth2Fill;
  if (tripCount <= 5) return _kDepth3Fill;
  return _kDepth4Fill;
}

// ── CountryPolygonLayer ───────────────────────────────────────────────────────

/// Renders all country polygons on the flutter_map canvas with per-state
/// colours and animation (ADR-066).
///
/// Polygons are split into two [PolygonLayer] instances:
///   1. **Static** (`unvisited`, `visited`, `reviewed`, `target`) — rebuilt
///      only when providers change.
///   2. **Animated** (`newlyDiscovered`) — driven by a repeating
///      [AnimationController]; only this layer rebuilds on each tick.
class CountryPolygonLayer extends ConsumerStatefulWidget {
  const CountryPolygonLayer({super.key});

  @override
  ConsumerState<CountryPolygonLayer> createState() => _CountryPolygonLayerState();
}

class _CountryPolygonLayerState extends ConsumerState<CountryPolygonLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polygonData = ref.watch(polygonsProvider);
    final visualStates = ref.watch(countryVisualStatesProvider);
    final tripCounts =
        ref.watch(countryTripCountsProvider).valueOrNull ?? const {};

    // Partition polygons into static and animated groups.
    final staticPolygons = <Polygon>[];
    final newlyDiscoveredPolygons = <_PolygonSpec>[];

    for (final p in polygonData) {
      if (_kSuppressedCodes.contains(p.isoCode)) continue;

      final state = visualStates[p.isoCode] ?? CountryVisualState.unvisited;
      final points = [for (final (lat, lng) in p.vertices) LatLng(lat, lng)];

      if (state == CountryVisualState.newlyDiscovered) {
        newlyDiscoveredPolygons.add(_PolygonSpec(points: points));
      } else {
        final tripCount = tripCounts[p.isoCode] ?? 0;
        staticPolygons.add(_staticPolygon(points, state, tripCount));
      }
    }

    // Only animate when there are newly-discovered polygons and animations are
    // enabled. Stopping when the list is empty prevents pumpAndSettle timeouts
    // in tests (ADR-055).
    final shouldAnimate = newlyDiscoveredPolygons.isNotEmpty &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldAnimate && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    return Stack(
      children: [
        // Static layer — rebuilt only when polygonData or visualStates change.
        PolygonLayer(
          polygonCulling: true,
          polygons: staticPolygons,
        ),
        // Animated layer — rebuilds on every animation tick.
        // Respects MediaQuery.disableAnimations (ADR-055): static opacity in
        // reduced-motion / test environments so pumpAndSettle can settle.
        if (newlyDiscoveredPolygons.isNotEmpty)
          MediaQuery.disableAnimationsOf(context)
              ? PolygonLayer(
                  polygonCulling: true,
                  polygons: [
                    for (final spec in newlyDiscoveredPolygons)
                      Polygon(
                        points: spec.points,
                        color: _kNewFill.withValues(alpha: 0.7),
                        borderColor: _kNewBorder,
                        borderStrokeWidth: 0.8,
                      ),
                  ],
                )
              : AnimatedBuilder(
                  animation: _pulseOpacity,
                  builder: (context, _) {
                    return PolygonLayer(
                      polygonCulling: true,
                      polygons: [
                        for (final spec in newlyDiscoveredPolygons)
                          Polygon(
                            points: spec.points,
                            color: _kNewFill.withValues(alpha: _pulseOpacity.value),
                            borderColor: _kNewBorder,
                            borderStrokeWidth: 0.8,
                          ),
                      ],
                    );
                  },
                ),
      ],
    );
  }

  Polygon _staticPolygon(
      List<LatLng> points, CountryVisualState state, int tripCount) {
    return switch (state) {
      CountryVisualState.visited => Polygon(
          points: points,
          color: depthFillColor(tripCount).withValues(alpha: 0.75),
          borderColor: _kVisitedBorder,
          borderStrokeWidth: 0.5,
        ),
      CountryVisualState.target => Polygon(
          points: points,
          color: _kVisitedFill.withValues(alpha: 0.75),
          borderColor: _kVisitedBorder,
          borderStrokeWidth: 0.5,
        ),
      CountryVisualState.reviewed => Polygon(
          points: points,
          color: _kReviewedFill.withValues(alpha: 0.75),
          borderColor: _kReviewedBorder,
          borderStrokeWidth: 0.5,
        ),
      _ => Polygon(
          points: points,
          color: _kUnvisitedFill.withValues(alpha: 0.6),
          borderColor: _kUnvisitedBorder,
          borderStrokeWidth: 0.5,
        ),
    };
  }
}

// ── Internal data class ───────────────────────────────────────────────────────

class _PolygonSpec {
  const _PolygonSpec({required this.points});
  final List<LatLng> points;
}
