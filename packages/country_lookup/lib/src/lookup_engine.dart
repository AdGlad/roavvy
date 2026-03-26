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
  String? resolve(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    for (final polygon in _index.candidatesAt(latitude, longitude)) {
      if (pointInPolygon(latitude, longitude, polygon.vertices)) {
        final code = polygon.isoCode;
        return _kCodeNormalisations[code] ?? code;
      }
    }
    return null;
  }
}
