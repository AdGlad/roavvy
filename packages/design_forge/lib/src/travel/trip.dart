/// Portable travel-data model for the Design Studio — the input real-world
/// travel history that timeline / journey / passport / word-cloud designs are
/// built from. Pure Dart (no platform deps) so it drops onto the iPhone: it
/// mirrors the mobile app's `TripRecord` (`countryCode`, `startedOn`, `endedOn`,
/// `photoCount`) so the app can pass its trips straight in.
class Trip {
  const Trip({
    required this.countryCode,
    required this.startedOn,
    required this.endedOn,
    this.photoCount = 0,
  });

  /// ISO-3166-1 alpha-2, stored lowercase.
  final String countryCode;
  final DateTime startedOn;
  final DateTime endedOn;
  final int photoCount;

  /// Inclusive trip duration in days (≥ 1).
  int get durationDays => endedOn.difference(startedOn).inDays.abs() + 1;

  String get cc => countryCode.toLowerCase();

  Trip copyWith({
    String? countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
    int? photoCount,
  }) =>
      Trip(
        countryCode: countryCode ?? this.countryCode,
        startedOn: startedOn ?? this.startedOn,
        endedOn: endedOn ?? this.endedOn,
        photoCount: photoCount ?? this.photoCount,
      );

  Map<String, Object?> toJson() => {
        'countryCode': cc,
        'startedOn': startedOn.toIso8601String(),
        'endedOn': endedOn.toIso8601String(),
        if (photoCount != 0) 'photoCount': photoCount,
      };

  factory Trip.fromJson(Map<String, Object?> j) => Trip(
        countryCode: (j['countryCode'] as String).toLowerCase(),
        startedOn: DateTime.parse(j['startedOn'] as String),
        endedOn: DateTime.parse(j['endedOn'] as String),
        photoCount: (j['photoCount'] as num?)?.toInt() ?? 0,
      );
}

/// An inclusive date window used to filter [Trip]s in the studio design options
/// ("select a date range"). Either bound may be null (open-ended).
class DateRange {
  const DateRange({this.start, this.end});

  /// All time (no filtering).
  static const all = DateRange();

  final DateTime? start;
  final DateTime? end;

  bool get isOpen => start == null && end == null;

  /// True if [trip] overlaps this window at all.
  bool overlaps(Trip trip) {
    if (start != null && trip.endedOn.isBefore(start!)) return false;
    if (end != null && trip.startedOn.isAfter(end!)) return false;
    return true;
  }

  /// A range covering whole calendar years [fromYear]..[toYear] inclusive.
  factory DateRange.years(int fromYear, int toYear) => DateRange(
        start: DateTime(fromYear, 1, 1),
        end: DateTime(toYear, 12, 31, 23, 59, 59),
      );

  Map<String, Object?> toJson() => {
        if (start != null) 'start': start!.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
      };

  factory DateRange.fromJson(Map<String, Object?> j) => DateRange(
        start: j['start'] == null ? null : DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
      );
}

/// Read-only helpers over a set of [Trip]s — the travel history a design draws
/// from. Deterministic ordering so generation stays reproducible.
class TravelHistory {
  TravelHistory(List<Trip> trips)
      : trips = List.unmodifiable(
          [...trips]..sort((a, b) => a.startedOn.compareTo(b.startedOn)),
        );

  final List<Trip> trips;

  bool get isEmpty => trips.isEmpty;
  bool get isNotEmpty => trips.isNotEmpty;

  /// Distinct country codes, in first-visited order.
  List<String> get countryCodes {
    final seen = <String>{};
    final out = <String>[];
    for (final t in trips) {
      if (seen.add(t.cc)) out.add(t.cc);
    }
    return out;
  }

  /// Trips overlapping [range], chronological.
  TravelHistory inRange(DateRange range) =>
      range.isOpen ? this : TravelHistory([for (final t in trips) if (range.overlaps(t)) t]);

  /// Trips for one country, chronological.
  List<Trip> forCountry(String cc) {
    final c = cc.toLowerCase();
    return [for (final t in trips) if (t.cc == c) t];
  }

  /// Number of trips per country (visit frequency — drives word-cloud sizing).
  Map<String, int> get visitCounts {
    final m = <String, int>{};
    for (final t in trips) {
      m[t.cc] = (m[t.cc] ?? 0) + 1;
    }
    return m;
  }

  /// The most recent trip for [cc] (latest [Trip.startedOn]), or null.
  Trip? mostRecentFor(String cc) {
    Trip? best;
    for (final t in forCountry(cc)) {
      if (best == null || t.startedOn.isAfter(best.startedOn)) best = t;
    }
    return best;
  }

  /// The full span covered by the history, or null when empty.
  DateRange? get span => trips.isEmpty
      ? null
      : DateRange(start: trips.first.startedOn, end: trips.last.endedOn);
}
