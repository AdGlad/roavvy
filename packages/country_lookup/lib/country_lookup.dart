/// Offline GPS coordinate to ISO 3166-1 alpha-2 country code resolution.
///
/// Usage:
/// ```dart
/// // Once at app startup (caller loads the asset):
/// final bytes = await rootBundle.load('assets/geodata/ne_countries.bin');
/// initCountryLookup(bytes.buffer.asUint8List());
///
/// // Then anywhere in the app:
/// final code = resolveCountry(51.5, -0.12); // → "GB"
/// ```
library country_lookup;

import 'dart:typed_data';

import 'src/binary_format.dart' show CountryPolygon;
import 'src/lookup_engine.dart';

export 'src/binary_format.dart' show CountryPolygon;

LookupEngine? _engine;

/// Initialises the lookup engine from the bundled geodata bytes.
///
/// Must be called once before any [resolveCountry] call. The [geodataBytes]
/// must be the raw content of `assets/geodata/ne_countries.bin`, loaded by
/// the caller. Calling this multiple times replaces the previous engine.
void initCountryLookup(Uint8List geodataBytes) {
  _engine = LookupEngine.fromBytes(geodataBytes);
}

/// Returns all country polygons parsed from the binary loaded by
/// [initCountryLookup].
///
/// Multi-ring countries (e.g. US, RU, archipelagos) produce multiple entries
/// sharing the same [CountryPolygon.isoCode]. The returned list is unmodifiable
/// and in binary file order.
///
/// Asserts in debug mode that [initCountryLookup] has been called first.
List<CountryPolygon> loadPolygons() {
  assert(
    _engine != null,
    'initCountryLookup() must be called before loadPolygons()',
  );
  return _engine?.polygons ?? const [];
}

/// Returns the ISO 3166-1 alpha-2 country code for ([latitude], [longitude]).
///
/// Returns null if the coordinate is over international waters, at the poles,
/// or otherwise unresolvable.
///
/// Coordinates outside the valid range (lat ±90, lng ±180) return null.
///
/// Asserts in debug mode that [initCountryLookup] has been called first.
String? resolveCountry(double latitude, double longitude) {
  assert(
    _engine != null,
    'initCountryLookup() must be called before resolveCountry()',
  );
  return _engine?.resolve(latitude, longitude);
}
