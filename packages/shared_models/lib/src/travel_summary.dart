import 'country_visit.dart';

/// A point-in-time snapshot of a user's effective travel history.
///
/// Constructed from the output of [effectiveVisits] — i.e. the already-merged,
/// non-deleted visit set. The caller is responsible for the merge step.
///
/// [continentCount] is intentionally absent: continent assignment requires
/// the country→continent mapping that lives in apps or country_lookup.
/// If needed, pass it in at construction time.
class TravelSummary {
  const TravelSummary({
    required this.visitedCodes,
    required this.computedAt,
    this.earliestVisit,
    this.latestVisit,
  });

  /// Build a [TravelSummary] from a list of active (non-deleted) visits.
  ///
  /// [activeVisits] must already be the effective set (call [effectiveVisits]
  /// first if starting from raw visit records).
  ///
  /// [now] overrides the [computedAt] timestamp — useful in tests.
  factory TravelSummary.fromVisits(
    List<CountryVisit> activeVisits, {
    DateTime? now,
  }) {
    final codes = activeVisits.map((v) => v.countryCode).toList()..sort();
    final dates = activeVisits
        .expand((v) => [v.firstSeen, v.lastSeen].whereType<DateTime>())
        .toList();

    return TravelSummary(
      visitedCodes: codes,
      computedAt: now ?? DateTime.now().toUtc(),
      earliestVisit: dates.isEmpty
          ? null
          : dates.reduce((a, b) => a.isBefore(b) ? a : b),
      latestVisit: dates.isEmpty
          ? null
          : dates.reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// ISO 3166-1 alpha-2 codes, sorted alphabetically, non-deleted only.
  final List<String> visitedCodes;

  /// UTC timestamp of when this summary was computed.
  final DateTime computedAt;

  /// Earliest [CountryVisit.firstSeen] across all active visits.
  /// Null when no visit has date metadata (e.g. all visits are manually added
  /// without photo evidence).
  final DateTime? earliestVisit;

  /// Latest [CountryVisit.lastSeen] across all active visits.
  final DateTime? latestVisit;

  int get countryCount => visitedCodes.length;
}
