import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';

// ── Data model ────────────────────────────────────────────────────────────────

/// Per-region travel progress snapshot (M23 / ADR-068).
class RegionProgressData {
  const RegionProgressData({
    required this.region,
    required this.centroid,
    required this.visitedCount,
    required this.totalCount,
  });

  final Region region;

  /// Approximate geographic centre for placing the progress chip on the map.
  final LatLng centroid;

  final int visitedCount;
  final int totalCount;

  /// Completion ratio in [0.0, 1.0]. Returns 0 when [totalCount] is 0.
  double get ratio => totalCount == 0 ? 0.0 : visitedCount / totalCount;

  /// True when all countries in this region have been visited.
  bool get isComplete => totalCount > 0 && visitedCount >= totalCount;

  /// How many more countries are needed to complete this region.
  int get remaining => (totalCount - visitedCount).clamp(0, totalCount);
}

// ── Hardcoded centroids ───────────────────────────────────────────────────────

/// Approximate geographic centroids per region, used for chip placement on the
/// world map.  These are intentional approximations — accuracy is not critical.
const Map<Region, LatLng> kRegionCentroids = {
  Region.europe: LatLng(54.0, 15.0),
  Region.asia: LatLng(34.0, 100.0),
  Region.africa: LatLng(2.0, 21.0),
  Region.northAmerica: LatLng(40.0, -100.0),
  Region.southAmerica: LatLng(-15.0, -60.0),
  Region.oceania: LatLng(-25.0, 134.0),
};

// ── Computation ───────────────────────────────────────────────────────────────

/// Computes [RegionProgressData] for all six regions by reading [kCountryContinent]
/// directly.  Does not require any static country-list files.
List<RegionProgressData> computeRegionProgress(
  List<EffectiveVisitedCountry> visits,
) {
  final visitedCodes = {for (final v in visits) v.countryCode};

  // Count totals and visited per region from kCountryContinent.
  final totals = <Region, int>{};
  final visited = <Region, int>{};

  for (final entry in kCountryContinent.entries) {
    final region = Region.fromContinentString(entry.value);
    if (region == null) continue;
    totals[region] = (totals[region] ?? 0) + 1;
    if (visitedCodes.contains(entry.key)) {
      visited[region] = (visited[region] ?? 0) + 1;
    }
  }

  return Region.values.map((region) {
    return RegionProgressData(
      region: region,
      centroid: kRegionCentroids[region]!,
      visitedCount: visited[region] ?? 0,
      totalCount: totals[region] ?? 0,
    );
  }).toList();
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Derived list of [RegionProgressData] for all six regions.
///
/// Recomputed whenever [effectiveVisitsProvider] changes. Returns an empty list
/// while visits are loading.
final regionProgressProvider = Provider<List<RegionProgressData>>((ref) {
  final visitsAsync = ref.watch(effectiveVisitsProvider);
  final visits = visitsAsync.valueOrNull ?? const <EffectiveVisitedCountry>[];
  return computeRegionProgress(visits);
});
