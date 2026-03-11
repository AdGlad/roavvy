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

  /// Returns the ISO 3166-1 alpha-2 code for ([latitude], [longitude]),
  /// or null if the coordinate is over open water or otherwise unresolvable.
  String? resolve(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    for (final polygon in _index.candidatesAt(latitude, longitude)) {
      if (pointInPolygon(latitude, longitude, polygon.vertices)) {
        return polygon.isoCode;
      }
    }
    return null;
  }
}
