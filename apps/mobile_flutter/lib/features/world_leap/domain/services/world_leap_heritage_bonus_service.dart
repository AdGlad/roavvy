// lib/features/world_leap/domain/services/world_leap_heritage_bonus_service.dart

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../world_leap_config.dart';
import 'world_leap_geo_service.dart';

/// A single UNESCO World Heritage Site with a name and coordinates.
class WhsSite {
  final String name;
  final double lat;
  final double lon;

  const WhsSite({required this.name, required this.lat, required this.lon});

  factory WhsSite.fromJson(Map<String, dynamic> json) => WhsSite(
        name: json['name'] as String,
        lat: (json['latitude'] as num).toDouble(),
        lon: (json['longitude'] as num).toDouble(),
      );
}

/// Result of a heritage bonus lookup.
typedef HeritageBonusResult = ({int bonus, String? siteName});

/// Computes the UNESCO World Heritage Site bonus for a landing position.
///
/// Inject [sites] directly for tests; use [WorldLeapHeritageBonusService.load]
/// in production to read from the bundled asset.
class WorldLeapHeritageBonusService {
  final List<WhsSite> _sites;
  final WorldLeapGeoService _geo;

  WorldLeapHeritageBonusService(this._sites, this._geo);

  /// Loads [WorldLeapConfig.unescoAsset] and returns a ready service.
  static Future<WorldLeapHeritageBonusService> load(
      WorldLeapGeoService geo) async {
    final raw = await rootBundle.loadString(WorldLeapConfig.unescoAsset);
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => WhsSite.fromJson(e as Map<String, dynamic>))
        .toList();
    return WorldLeapHeritageBonusService(list, geo);
  }

  /// Returns the best-tier heritage bonus (and site name) for the given
  /// landing coordinates, or `(bonus: 0, siteName: null)` if no site is
  /// within [WorldLeapConfig.heritageTier1RadiusKm].
  HeritageBonusResult bonusAt(double lat, double lon) {
    WhsSite? bestSite;
    double bestDist = double.infinity;

    for (final site in _sites) {
      final d = _geo.greatCircleDistanceKm(
          lat1: lat, lon1: lon, lat2: site.lat, lon2: site.lon);
      if (d < bestDist) {
        bestDist = d;
        bestSite = site;
      }
    }

    if (bestSite == null || bestDist > WorldLeapConfig.heritageTier1RadiusKm) {
      return (bonus: 0, siteName: null);
    }

    if (bestDist <= WorldLeapConfig.heritageTier3RadiusKm) {
      return (bonus: WorldLeapConfig.heritageTier3Bonus, siteName: bestSite.name);
    }
    if (bestDist <= WorldLeapConfig.heritageTier2RadiusKm) {
      return (bonus: WorldLeapConfig.heritageTier2Bonus, siteName: bestSite.name);
    }
    return (bonus: WorldLeapConfig.heritageTier1Bonus, siteName: bestSite.name);
  }
}
