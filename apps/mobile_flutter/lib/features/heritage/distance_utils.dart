import 'dart:math' as math;

/// Pure distance and navigation utility functions for the UNESCO Nearby feature.
///
/// All functions are stateless and make zero network or platform calls.
class DistanceUtils {
  DistanceUtils._();

  static const double _earthRadiusKm = 6371.0;

  // ── Distance ──────────────────────────────────────────────────────────────

  /// Haversine great-circle distance in kilometres between two WGS-84 points.
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  // ── Bearing ───────────────────────────────────────────────────────────────

  /// Forward azimuth bearing in degrees (0–360, clockwise from north) from
  /// point 1 to point 2.
  static double bearingDeg(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final lat1r = _toRad(lat1);
    final lat2r = _toRad(lat2);
    final dLng = _toRad(lng2 - lng1);
    final x = math.sin(dLng) * math.cos(lat2r);
    final y = math.cos(lat1r) * math.sin(lat2r) -
        math.sin(lat1r) * math.cos(lat2r) * math.cos(dLng);
    return (_toDeg(math.atan2(x, y)) + 360) % 360;
  }

  /// 8-point compass label for a bearing in degrees.
  ///
  /// Returns one of: "North", "North-East", "East", "South-East",
  /// "South", "South-West", "West", "North-West".
  static String bearingLabel(double deg) {
    const labels = [
      'North',
      'North-East',
      'East',
      'South-East',
      'South',
      'South-West',
      'West',
      'North-West',
    ];
    final index = ((deg + 22.5) / 45).floor() % 8;
    return labels[index];
  }

  // ── Travel time estimates ─────────────────────────────────────────────────

  /// Walking speed in km/h used for travel time estimates.
  static const double walkingKmh = 5.0;

  /// Cycling speed in km/h used for travel time estimates.
  static const double cyclingKmh = 15.0;

  /// Driving speed in km/h used for travel time estimates.
  static const double drivingKmh = 50.0;

  /// Approximate travel time string for [distanceKm] at [speedKmh].
  ///
  /// Returns `"42 min"` for durations under one hour, or `"3 h 12 min"`
  /// for one hour or more. Prefixing with "~" to signal estimates is the
  /// caller's responsibility.
  static String travelTime(double distanceKm, double speedKmh) {
    if (speedKmh <= 0) return '—';
    final totalMinutes = (distanceKm / speedKmh * 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;
}
