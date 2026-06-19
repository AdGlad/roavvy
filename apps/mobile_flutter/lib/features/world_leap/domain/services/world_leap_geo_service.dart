// lib/features/world_leap/domain/services/world_leap_geo_service.dart

import 'dart:math' as math;

/// Pure-math geographic calculations for World Leap.
/// All inputs/outputs use decimal degrees; distances in kilometres.
/// Uses the WGS-84 mean spherical Earth radius (6371.0088 km).
class WorldLeapGeoService {
  static const double _earthRadiusKm = 6371.0088;

  /// Computes the destination point given a [startLat]/[startLon], [bearingDeg]
  /// (clockwise from true north, 0–360) and [distanceKm].
  ///
  /// Returns a record `(lat, lon)` in decimal degrees.
  ({double lat, double lon}) destinationPoint({
    required double startLat,
    required double startLon,
    required double bearingDeg,
    required double distanceKm,
  }) {
    final phi1 = _toRad(startLat);
    final lambda1 = _toRad(startLon);
    final theta = _toRad(bearingDeg);
    final delta = distanceKm / _earthRadiusKm; // angular distance in radians

    final phi2 = math.asin(
      math.sin(phi1) * math.cos(delta) +
          math.cos(phi1) * math.sin(delta) * math.cos(theta),
    );

    final lambda2 = lambda1 +
        math.atan2(
          math.sin(theta) * math.sin(delta) * math.cos(phi1),
          math.cos(delta) - math.sin(phi1) * math.sin(phi2),
        );

    return (
      lat: _toDeg(phi2),
      lon: _normaliseLon(_toDeg(lambda2)),
    );
  }

  /// Computes the great-circle distance in kilometres between two points.
  double greatCircleDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaPhi = _toRad(lat2 - lat1);
    final deltaLambda = _toRad(lon2 - lon1);

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Computes the initial bearing (forward azimuth) from point 1 to point 2,
  /// returned in degrees (0–360, clockwise from north).
  double initialBearingDeg({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaLambda = _toRad(lon2 - lon1);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    return (_toDeg(math.atan2(y, x)) + 360) % 360;
  }

  /// Returns [count] evenly-spaced intermediate points along a great-circle
  /// arc from [fromLat]/[fromLon], including the destination but not the
  /// start, suitable for animating the trajectory.
  List<({double lat, double lon})> trajectoryPoints({
    required double fromLat,
    required double fromLon,
    required double bearingDeg,
    required double distanceKm,
    required int count,
  }) {
    final points = <({double lat, double lon})>[];
    for (int i = 1; i <= count; i++) {
      final partial = distanceKm * (i / count);
      points.add(destinationPoint(
        startLat: fromLat,
        startLon: fromLon,
        bearingDeg: bearingDeg,
        distanceKm: partial,
      ));
    }
    return points;
  }

  // ---------- helpers ----------

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;

  /// Wraps longitude into [-180, 180].
  static double _normaliseLon(double lon) {
    if (lon > 180) return lon - 360;
    if (lon < -180) return lon + 360;
    return lon;
  }
}
