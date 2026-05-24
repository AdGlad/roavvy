import 'dart:convert';

/// A UNESCO World Heritage Site from the bundled `whs_sites.json` dataset.
///
/// Immutable; equality and hash are based on [siteId] alone.
/// Transboundary sites share a [siteId] but appear once per [countryCode]
/// in the lookup index so they are discoverable from any member country.
class WorldHeritageSite {
  const WorldHeritageSite({
    required this.siteId,
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.region,
    required this.inscriptionYear,
  });

  /// UNESCO `id_no` as a string — stable identifier across dataset updates.
  final String siteId;

  /// English name of the site.
  final String name;

  /// ISO 3166-1 alpha-2 country code. For transboundary sites this is the
  /// member country under whose entry this record was indexed.
  final String countryCode;

  final double latitude;
  final double longitude;

  /// One of `"cultural"`, `"natural"`, or `"mixed"`.
  final String category;

  /// UNESCO region string, e.g. `"Asia and the Pacific"`.
  final String region;

  final int inscriptionYear;

  factory WorldHeritageSite.fromJson(Map<String, dynamic> json) {
    return WorldHeritageSite(
      siteId: json['siteId'] as String,
      name: json['name'] as String,
      countryCode: json['countryCode'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String,
      region: json['region'] as String,
      inscriptionYear: (json['inscriptionYear'] as num).toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorldHeritageSite && other.siteId == siteId;

  @override
  int get hashCode => siteId.hashCode;

  @override
  String toString() => 'WorldHeritageSite($siteId, $name)';
}

/// A candidate WHS match returned by [WorldHeritageLookupService].
///
/// Never persisted — used transiently in the scan pipeline to accumulate
/// [VisitedHeritageSite] records.
class WhsMatch {
  const WhsMatch({
    required this.site,
    required this.distanceKm,
    required this.confidence,
  });

  final WorldHeritageSite site;

  /// Distance from the photo GPS coordinate to the site centroid, in km.
  final double distanceKm;

  /// `"strong"` (≤ 2 km) or `"nearby"` (≤ 10 km). (ADR-165)
  final String confidence;
}

/// A World Heritage Site that the user has visited, as recorded by the
/// scan pipeline and persisted in the `VisitedHeritageSites` Drift table.
class VisitedHeritageSite {
  const VisitedHeritageSite({
    required this.siteId,
    required this.name,
    required this.countryCode,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.inscriptionYear,
    required this.firstSeen,
    required this.lastSeen,
    required this.photoCount,
    required this.confidence,
    required this.nearestDistanceKm,
  });

  final String siteId;
  final String name;
  final String countryCode;

  /// One of `"cultural"`, `"natural"`, or `"mixed"`.
  final String category;

  /// Site centroid latitude from the UNESCO dataset.
  final double latitude;

  /// Site centroid longitude from the UNESCO dataset.
  final double longitude;

  /// Year the site was inscribed on the UNESCO World Heritage List.
  final int inscriptionYear;

  /// UTC timestamp of the earliest matching photo.
  final DateTime firstSeen;

  /// UTC timestamp of the most recent matching photo.
  final DateTime lastSeen;

  /// Total number of photos matched to this site across all scans.
  final int photoCount;

  /// Strongest confidence ever observed for this site. (ADR-165)
  final String confidence;

  /// Closest distance (km) from any matched photo to this site's centroid.
  final double nearestDistanceKm;

  VisitedHeritageSite copyWith({
    DateTime? firstSeen,
    DateTime? lastSeen,
    int? photoCount,
    String? confidence,
    double? nearestDistanceKm,
  }) {
    return VisitedHeritageSite(
      siteId: siteId,
      name: name,
      countryCode: countryCode,
      category: category,
      latitude: latitude,
      longitude: longitude,
      inscriptionYear: inscriptionYear,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      photoCount: photoCount ?? this.photoCount,
      confidence: confidence ?? this.confidence,
      nearestDistanceKm: nearestDistanceKm ?? this.nearestDistanceKm,
    );
  }
}

/// Parses the bundled `whs_sites.json` asset into a list of [WorldHeritageSite].
List<WorldHeritageSite> parseWhsSitesJson(String jsonString) {
  final list = jsonDecode(jsonString) as List<dynamic>;
  return list
      .map((e) => WorldHeritageSite.fromJson(e as Map<String, dynamic>))
      .toList();
}
