import 'package:shared_models/shared_models.dart';

/// Replay mode for the cinematic globe replay (M108).
enum TravelReplayMode {
  /// Every trip ever recorded, sorted chronologically.
  allTime,

  /// Only trips from the current calendar year.
  year,

  /// Only trips from a specific [TripRecord.tripId] group (reserved; UI
  /// currently shows allTime and year only).
  trip,
}

/// A single travel leg between two countries.
class TravelLeg {
  const TravelLeg({
    required this.fromCode,
    required this.toCode,
    required this.date,
  });

  /// ISO 3166-1 alpha-2 departure country.
  final String fromCode;

  /// ISO 3166-1 alpha-2 arrival country.
  final String toCode;

  /// Date of travel (used for year-filter and display).
  final DateTime date;

  @override
  String toString() => 'TravelLeg($fromCode→$toCode, ${date.year})';
}

/// An ordered list of [TravelLeg]s ready to replay on the globe.
class TravelReplayScript {
  const TravelReplayScript({
    required this.legs,
    required this.mode,
    required this.label,
  });

  final List<TravelLeg> legs;
  final TravelReplayMode mode;

  /// Human-readable label shown in the replay UI (e.g. "All-Time Travels").
  final String label;

  bool get isEmpty => legs.isEmpty;
}

/// Converts a list of [TripRecord]s into a [TravelReplayScript].
///
/// Strategy: trips sorted by [TripRecord.startedOn]; consecutive records with
/// different [countryCode] form one leg. Duplicate `fromCode == toCode` legs
/// are dropped.
class TravelReplayScriptBuilder {
  const TravelReplayScriptBuilder._();

  static TravelReplayScript build({
    required List<TripRecord> trips,
    required TravelReplayMode mode,
    int? year,
  }) {
    final targetYear = year ?? DateTime.now().year;

    // Filter by mode.
    final filtered = switch (mode) {
      TravelReplayMode.allTime => trips,
      TravelReplayMode.year =>
        trips.where((t) => t.startedOn.year == targetYear).toList(),
      TravelReplayMode.trip => trips, // caller narrows by tripId if needed
    };

    // Sort chronologically.
    final sorted = filtered.toList()
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    // Build legs from consecutive country changes.
    final legs = <TravelLeg>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final from = sorted[i];
      final to = sorted[i + 1];
      if (from.countryCode == to.countryCode) continue;
      legs.add(TravelLeg(
        fromCode: from.countryCode,
        toCode: to.countryCode,
        date: to.startedOn,
      ));
    }

    final label = switch (mode) {
      TravelReplayMode.allTime => 'All-Time Travels',
      TravelReplayMode.year => '$targetYear Travels',
      TravelReplayMode.trip => 'Trip Replay',
    };

    return TravelReplayScript(legs: legs, mode: mode, label: label);
  }

  /// Per-leg duration in milliseconds, compressed for large scripts.
  static int legDurationMs(int legCount) {
    if (legCount <= 10) return 3500;
    if (legCount <= 30) return 2000;
    if (legCount <= 80) return 1200;
    return 700;
  }
}
