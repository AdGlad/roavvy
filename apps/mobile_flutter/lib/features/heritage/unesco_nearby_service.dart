import 'package:shared_models/shared_models.dart';

import 'distance_utils.dart';
import 'world_heritage_lookup_service.dart';

/// A UNESCO World Heritage Site enriched with proximity data for a given
/// user location.
class NearbySiteResult {
  const NearbySiteResult({
    required this.site,
    required this.distanceKm,
    required this.bearing,
    required this.bearingLabel,
    required this.isVisited,
  });

  final WorldHeritageSite site;

  /// Great-circle distance in km from the user to the site centroid.
  final double distanceKm;

  /// Forward azimuth in degrees (0–360, clockwise from north).
  final double bearing;

  /// 8-point compass label, e.g. "North-East".
  final String bearingLabel;

  /// True when the site's siteId appears in the user's visited set.
  final bool isVisited;

  String get walkTime =>
      '~${DistanceUtils.travelTime(distanceKm, DistanceUtils.walkingKmh)}';
  String get cycleTime =>
      '~${DistanceUtils.travelTime(distanceKm, DistanceUtils.cyclingKmh)}';
  String get driveTime =>
      '~${DistanceUtils.travelTime(distanceKm, DistanceUtils.drivingKmh)}';
}

/// Filters and ranks UNESCO World Heritage Sites by proximity to a given
/// location.
///
/// All computation is synchronous and in-memory using
/// [WorldHeritageLookupService.allSites]. Transboundary sites (same siteId,
/// multiple country entries) are deduplicated: only the nearest instance is
/// kept. (ADR-014)
class UnescoNearbyService {
  const UnescoNearbyService();

  /// Returns sites within [radiusKm] of ([lat], [lng]), sorted nearest first.
  ///
  /// [visitedSiteIds] is the set of siteIds the user has already visited;
  /// used only for badge display — it does not filter results.
  List<NearbySiteResult> sitesWithin(
    double lat,
    double lng,
    double radiusKm,
    Set<String> visitedSiteIds,
  ) {
    // Deduplicate transboundary sites: keep the entry closest to the user.
    final best = <String, NearbySiteResult>{};

    for (final site in WorldHeritageLookupService.allSites) {
      final dist = DistanceUtils.haversineKm(
        lat, lng, site.latitude, site.longitude,
      );
      if (dist > radiusKm) continue;

      final bearing = DistanceUtils.bearingDeg(
        lat, lng, site.latitude, site.longitude,
      );
      final result = NearbySiteResult(
        site: site,
        distanceKm: dist,
        bearing: bearing,
        bearingLabel: DistanceUtils.bearingLabel(bearing),
        isVisited: visitedSiteIds.contains(site.siteId),
      );

      final existing = best[site.siteId];
      if (existing == null || dist < existing.distanceKm) {
        best[site.siteId] = result;
      }
    }

    return best.values.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }
}
