import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import 'country_visual_state.dart';

/// ISO codes suppressed from the map (mirrors [MapScreen]).
const _kSuppressedCodes = {'AQ'};

// ── Colour definitions (ADR-066, updated ADR-080) ─────────────────────────────

// Dark navy ocean theme (ADR-080).
const _kUnvisitedFill = Color(0xFF1E3A5F);     // dark blue-grey land
const _kUnvisitedBorder = Color(0xFF2A4F7A);   // slightly lighter border, 0.4 stroke

const _kVisitedFill = Color(0xFFD4A017);       // rich gold tier-0 fallback
const _kVisitedBorder = Color(0xFFFFD700);     // bright gold border

const _kReviewedFill = Color(0xFFC8860A);      // reviewed — gold tier-2
const _kReviewedBorder = Color(0xFFFFD700);    // bright gold border

const _kNewFill = Color(0xFFFFD700);           // newly discovered — bright gold
const _kNewBorder = Color(0xFFFFFFFF);         // white border for pop

// Depth colouring tiers — more trips → richer/darker gold (ADR-066, ADR-080).
const _kDepth1Fill = Color(0xFFD4A017); // 1 trip:  gold (light)
const _kDepth2Fill = Color(0xFFC8860A); // 2-3:     deeper gold
const _kDepth3Fill = Color(0xFFB86A00); // 4-5:     amber-brown
const _kDepth4Fill = Color(0xFF8B4500); // 6+:      deep burnt amber

/// Returns the fill [Color] for a visited country based on [tripCount].
///
/// Tier boundaries:  0 → fallback visited colour, 1 → lightest gold,
/// 2-3 → deeper gold, 4-5 → amber-brown, 6+ → deep burnt amber. (ADR-080)
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
        staticPolygons.add(_buildStaticPolygon(points, state, tripCount));
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
                        color: _kNewFill.withValues(alpha: 0.75),
                        borderColor: _kNewBorder,
                        borderStrokeWidth: 1.5,
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
                            borderStrokeWidth: 1.5,
                          ),
                      ],
                    );
                  },
                ),
      ],
    );
  }

  Polygon _buildStaticPolygon(
      List<LatLng> points, CountryVisualState state, int tripCount) {
    return switch (state) {
      CountryVisualState.visited => Polygon(
          points: points,
          color: depthFillColor(tripCount).withValues(alpha: 0.85),
          borderColor: _kVisitedBorder,
          borderStrokeWidth: 0.8,
        ),
      CountryVisualState.target => Polygon(
          points: points,
          color: _kVisitedFill.withValues(alpha: 0.6),
          borderColor: const Color(0xFFFF8C00),
          borderStrokeWidth: 1.2,
        ),
      CountryVisualState.reviewed => Polygon(
          points: points,
          color: _kReviewedFill.withValues(alpha: 0.85),
          borderColor: _kReviewedBorder,
          borderStrokeWidth: 0.8,
        ),
      _ => Polygon(
          points: points,
          color: _kUnvisitedFill.withValues(alpha: 0.9),
          borderColor: _kUnvisitedBorder,
          borderStrokeWidth: 0.4,
        ),
    };
  }
}

// ── Internal data class ───────────────────────────────────────────────────────

class _PolygonSpec {
  const _PolygonSpec({required this.points});
  final List<LatLng> points;
}
