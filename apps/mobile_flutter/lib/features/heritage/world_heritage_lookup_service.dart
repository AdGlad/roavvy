import 'dart:math';

import 'package:shared_models/shared_models.dart';

/// Offline UNESCO World Heritage Site lookup service. (M119, ADR-163, ADR-164)
///
/// Must be initialised once at app startup via [init] before any lookup calls.
/// All lookups are synchronous, in-memory, and make zero network calls.
///
/// **Matching strategy (ADR-163):**
/// 1. Filter candidates by country code — O(1) map lookup, ~5–30 candidates.
/// 2. Compute haversine distance to each candidate.
/// 3. Return the nearest site ≤ 10 km, or null if none qualify.
///
/// Transboundary sites appear under multiple country keys in the index, so
/// [findNearest] can discover them from any member country.
class WorldHeritageLookupService {
  WorldHeritageLookupService._();

  /// Country code → list of sites in that country.
  static Map<String, List<WorldHeritageSite>> _index = {};

  static bool _initialised = false;

  /// Strong match threshold: ≤ 2 km. (ADR-165)
  static const double _strongKm = 2.0;

  /// Outer match threshold: ≤ 10 km. Beyond this distance the photo is
  /// considered unrelated to the site.
  static const double _nearbyKm = 10.0;

  /// Total number of UNESCO World Heritage Sites in the dataset.
  ///
  /// Returns 0 before [init] is called. Safe to call at any time.
  static int get totalSiteCount =>
      _index.values.fold(0, (sum, list) => sum + list.length);

  /// All indexed sites as a flat iterable (M129).
  /// Transboundary sites appear once per member country.
  static Iterable<WorldHeritageSite> get allSites =>
      _index.values.expand((list) => list);

  /// Returns the first [WorldHeritageSite] with the given [siteId], or null.
  ///
  /// For transboundary sites (same siteId across multiple countries) this
  /// returns the first matching record which carries the enriched data
  /// (shortDescription, imageUrl) shared by all country entries.
  static WorldHeritageSite? findBySiteId(String siteId) {
    for (final sites in _index.values) {
      for (final site in sites) {
        if (site.siteId == siteId) return site;
      }
    }
    return null;
  }

  /// Initialises the service from the bundled JSON string.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  static void init(String jsonString) {
    if (_initialised) return;
    final sites = parseWhsSitesJson(jsonString);
    final index = <String, List<WorldHeritageSite>>{};
    for (final site in sites) {
      index.putIfAbsent(site.countryCode, () => []).add(site);
    }
    _index = index;
    _initialised = true;
  }

  /// Finds the nearest WHS to [lat]/[lng] within the given [countryCode].
  ///
  /// Returns null if no site is within [_nearbyKm] km, or if [countryCode]
  /// has no registered sites.
  static WhsMatch? findNearest(double lat, double lng, String countryCode) {
    final candidates = _index[countryCode];
    if (candidates == null || candidates.isEmpty) return null;

    WorldHeritageSite? bestSite;
    double bestDist = double.infinity;

    for (final site in candidates) {
      final d = _haversineKm(lat, lng, site.latitude, site.longitude);
      if (d < bestDist) {
        bestDist = d;
        bestSite = site;
      }
    }

    if (bestSite == null || bestDist > _nearbyKm) return null;

    return WhsMatch(
      site: bestSite,
      distanceKm: bestDist,
      confidence: bestDist <= _strongKm ? 'strong' : 'nearby',
    );
  }

  /// Bulk lookup for a list of `(lat, lng, countryCode)` records.
  ///
  /// Returns a list of the same length; each element is the nearest [WhsMatch]
  /// for the corresponding input record, or null if no site was within
  /// [_nearbyKm] km.
  ///
  /// Using Dart 3 record tuples keeps this service free of dependencies on
  /// scan-layer types (no import of [PhotoGpsRecord]).
  static List<WhsMatch?> findBatch(
      List<(double lat, double lng, String countryCode)> records) {
    return records
        .map((r) => findNearest(r.$1, r.$2, r.$3))
        .toList();
  }

  /// Haversine great-circle distance in kilometres.
  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
