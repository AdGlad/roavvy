// lib/features/world_leap/domain/services/world_leap_country_service.dart

import 'package:country_lookup/country_lookup.dart';
import 'package:mobile_flutter/core/country_names.dart';

/// Provides World Leap country and water detection via [resolveCountry].
///
/// country_lookup is initialised at app startup — no setup is needed here.
class WorldLeapCountryService {
  const WorldLeapCountryService();

  /// Returns the ISO 3166-1 alpha-2 country code and English name at
  /// [lat]/[lon], or `null` if the point is over open water or outside any
  /// recognised territory.
  ({String code, String name})? countryAt(double lat, double lon) {
    final code = resolveCountry(lat, lon);
    if (code == null) return null;
    final name = kCountryNames[code] ?? code;
    return (code: code, name: name);
  }

  /// Returns `true` when [lat]/[lon] is over open water (no country polygon).
  bool isWater(double lat, double lon) => resolveCountry(lat, lon) == null;
}
