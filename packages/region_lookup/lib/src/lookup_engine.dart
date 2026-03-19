import 'dart:typed_data';

import 'binary_format.dart';
import 'point_in_polygon.dart';

/// Parses the admin1 geodata binary and resolves coordinates to region codes.
class RegionLookupEngine {
  final RegionGeodataIndex _index;

  RegionLookupEngine._(this._index);

  factory RegionLookupEngine.fromBytes(Uint8List bytes) {
    return RegionLookupEngine._(RegionGeodataIndex.parse(bytes));
  }

  /// Returns the ISO 3166-2 region code for ([latitude], [longitude]),
  /// or null if the coordinate is over open water, in a country with no
  /// admin1 coverage in Natural Earth data, or otherwise unresolvable.
  ///
  /// Countries with no admin1 coverage (always returns null):
  /// micro-states (Monaco, Vatican, San Marino, Liechtenstein, Andorra),
  /// city-states (Singapore), and many small island nations (Maldives, Nauru,
  /// Tuvalu, Palau, Marshall Islands, Kiribati, FSM, Malta, Bahrain, etc.).
  ///
  /// Includes a coastal fallback: callers bucket GPS coordinates to a 0.5°
  /// grid (ADR-051), which can shift a coastal photo up to 0.25° offshore.
  /// After a primary miss, four cardinal neighbours at ±[_kCoastalEpsilon]°
  /// are tried so that near-shore photos resolve to the correct region.
  String? resolve(double latitude, double longitude) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    // Primary lookup.
    final primary = _resolveAt(latitude, longitude);
    if (primary != null) return primary;

    // Coastal fallback: try cardinal neighbours at ±0.25° (the maximum shift
    // introduced by 0.5° bucketing) to recover the correct region for photos
    // taken right at the waterline or a political boundary.
    for (final (jLat, jLng) in [
      (latitude + _kCoastalEpsilon, longitude),
      (latitude - _kCoastalEpsilon, longitude),
      (latitude, longitude + _kCoastalEpsilon),
      (latitude, longitude - _kCoastalEpsilon),
    ]) {
      final result = _resolveAt(jLat, jLng);
      if (result != null) return result;
    }
    return null;
  }

  /// The maximum coordinate shift introduced by 0.5° bucketing. Equal to
  /// half the grid step — about 27 km at the equator.
  static const double _kCoastalEpsilon = 0.25;

  String? _resolveAt(double lat, double lng) {
    for (final polygon in _index.candidatesAt(lat, lng)) {
      if (pointInPolygon(lat, lng, polygon.vertices)) {
        return polygon.regionCode;
      }
    }
    return null;
  }
}
