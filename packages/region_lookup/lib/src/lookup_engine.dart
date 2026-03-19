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
  /// or null if the coordinate is over open water, in a micro-state with no
  /// admin1 divisions, or otherwise unresolvable.
  String? resolve(double latitude, double longitude) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    for (final polygon in _index.candidatesAt(latitude, longitude)) {
      if (pointInPolygon(latitude, longitude, polygon.vertices)) {
        return polygon.regionCode;
      }
    }
    return null;
  }
}
