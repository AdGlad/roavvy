import 'dart:typed_data';

import 'binary_format.dart';
import 'point_in_polygon.dart';

/// Parses the geodata binary and resolves coordinates to country codes.
class LookupEngine {
  final GeodataIndex _index;

  LookupEngine._(this._index);

  factory LookupEngine.fromBytes(Uint8List bytes) {
    return LookupEngine._(GeodataIndex.parse(bytes));
  }

  // Maps legacy or non-standard codes that appear in some Natural Earth
  // releases to their current ISO 3166-1 alpha-2 equivalents.
  // Applied after polygon lookup so that binaries built from older shapefiles
  // still produce correct codes without requiring a rebuild.
  static const Map<String, String> _kCodeNormalisations = {
    'FX': 'FR', // Metropolitan France — deprecated code in some NE releases
  };

  /// All country polygons from the loaded binary. See [GeodataIndex.polygons].
  List<CountryPolygon> get polygons => _index.polygons;

  /// Returns the ISO 3166-1 alpha-2 code for ([latitude], [longitude]),
  /// or null if the coordinate is over open water or otherwise unresolvable.
  ///
  /// When the direct lookup returns null (e.g. a GPS point falls in a gap in
  /// the 50 m polygon — narrow coastal strips like Bandar Abbas, Iran, or lake
  /// shores like Bodensee), a nearest-neighbour fallback samples 8 surrounding
  /// points at ±0.15 ° and returns the most frequent non-null result. This
  /// recovers the large majority of coastal/border misses without affecting
  /// normal inland lookups (which return on the first pass).
  String? resolve(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    final primary = _resolveOnce(latitude, longitude);
    if (primary != null) return primary;

    // Nearest-neighbour fallback for coastal / border gaps in the 50 m data.
    const kStep = 0.15;
    final counts = <String, int>{};
    for (final dLat in [-kStep, 0.0, kStep]) {
      for (final dLng in [-kStep, 0.0, kStep]) {
        if (dLat == 0.0 && dLng == 0.0) continue; // already tried above
        final code = _resolveOnce(latitude + dLat, longitude + dLng);
        if (code != null) counts[code] = (counts[code] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String? _resolveOnce(double latitude, double longitude) {
    for (final polygon in _index.candidatesAt(latitude, longitude)) {
      if (pointInPolygon(latitude, longitude, polygon.vertices)) {
        final code = polygon.isoCode;
        return _kCodeNormalisations[code] ?? code;
      }
    }
    return null;
  }
}
