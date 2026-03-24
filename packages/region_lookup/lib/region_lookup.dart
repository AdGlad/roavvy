/// Offline GPS coordinate to ISO 3166-2 region code resolution.
///
/// Usage:
/// ```dart
/// // Once at app startup (caller loads the asset):
/// final bytes = await rootBundle.load('assets/geodata/ne_admin1.bin');
/// initRegionLookup(bytes.buffer.asUint8List());
///
/// // Then anywhere in the app:
/// final code = resolveRegion(51.5, -0.12); // → "GB-ENG"
/// ```
///
/// IMPORTANT (ADR-051): pass the same 0.5° bucketed coordinates used by
/// `resolveCountry` in `packages/country_lookup`. Do not pass raw GPS.
library region_lookup;

import 'dart:typed_data';

import 'src/binary_format.dart';
import 'src/lookup_engine.dart';

export 'src/binary_format.dart' show RegionPolygon;

RegionLookupEngine? _engine;

/// Initialises the lookup engine from the bundled geodata bytes.
///
/// Must be called once before any [resolveRegion] call. The [geodataBytes]
/// must be the raw content of `assets/geodata/ne_admin1.bin`, loaded by
/// the caller. Calling this multiple times replaces the previous engine.
void initRegionLookup(Uint8List geodataBytes) {
  _engine = RegionLookupEngine.fromBytes(geodataBytes);
}

/// Returns the ISO 3166-2 region code for ([latitude], [longitude]).
///
/// Returns null if the coordinate is over international waters, in a
/// micro-state with no admin1 divisions, or otherwise unresolvable.
///
/// Coordinates outside the valid range (lat ±90, lng ±180) return null.
///
/// Per ADR-051, callers must pass 0.5° bucketed coordinates — the same
/// values passed to `resolveCountry`.
///
/// Asserts in debug mode that [initRegionLookup] has been called first.
String? resolveRegion(double latitude, double longitude) {
  assert(
    _engine != null,
    'initRegionLookup() must be called before resolveRegion()',
  );
  return _engine?.resolve(latitude, longitude);
}

/// Returns all admin1 region polygons for the given ISO 3166-1 alpha-2
/// [countryCode] (e.g. `'GB'`, `'US'`).
///
/// Each [RegionPolygon] carries its ISO 3166-2 [RegionPolygon.regionCode]
/// (e.g. `'GB-ENG'`) and polygon [RegionPolygon.vertices] as (lat, lng) pairs.
///
/// Returns an empty list when the country has no admin1 divisions in the
/// bundled dataset (micro-states, small island nations).
///
/// Asserts in debug mode that [initRegionLookup] has been called first.
List<RegionPolygon> regionPolygonsForCountry(String countryCode) {
  assert(
    _engine != null,
    'initRegionLookup() must be called before regionPolygonsForCountry()',
  );
  return _engine?.polygonsForCountry(countryCode) ?? const [];
}
