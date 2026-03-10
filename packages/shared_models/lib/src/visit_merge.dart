import 'country_visit.dart';
import 'visit_source.dart';

/// Returns the effective visited-country set from [all].
///
/// Applies the canonical Roavvy merge precedence rules (see offline_strategy.md):
///
///   1. [VisitSource.manual] beats [VisitSource.auto] for the same country code,
///      regardless of [CountryVisit.updatedAt].
///   2. Among same-source duplicates, the record with the later [updatedAt] wins.
///   3. [CountryVisit.isDeleted] tombstones are excluded from the result, but
///      their precedence still applies — a manual tombstone prevents an auto
///      record from surfacing.
///
/// The result is an unordered list of at most one record per country code.
/// Sorting (e.g. by name or count) is the caller's responsibility.
List<CountryVisit> effectiveVisits(List<CountryVisit> all) {
  final map = <String, CountryVisit>{};

  for (final visit in all) {
    final existing = map[visit.countryCode];
    if (existing == null) {
      map[visit.countryCode] = visit;
      continue;
    }
    // manual always beats auto
    if (visit.source == VisitSource.manual && existing.source == VisitSource.auto) {
      map[visit.countryCode] = visit;
      continue;
    }
    if (visit.source == VisitSource.auto && existing.source == VisitSource.manual) {
      continue; // existing manual wins — do not replace
    }
    // same source: later updatedAt wins
    if (visit.updatedAt.isAfter(existing.updatedAt)) {
      map[visit.countryCode] = visit;
    }
  }

  return map.values.where((v) => v.isActive).toList();
}
