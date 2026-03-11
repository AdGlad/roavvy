import 'package:shared_models/shared_models.dart';

import '../../photo_scan_channel.dart';

/// Maps spike-layer [DetectedCountry] results into domain [CountryVisit] objects.
///
/// [DetectedCountry] is the raw channel contract: it carries what CLGeocoder
/// returned (country code, display name, photo count within the scan window).
/// [CountryVisit] is the persistent domain model that the rest of the app works with.
///
/// Limitations of the current spike:
/// - [firstSeen] and [lastSeen] are null because the channel does not yet return
///   photo capture dates. That extension belongs in a follow-up task that adds
///   date streaming to the Swift PhotoKit bridge.
/// - [CountryVisit.source] is always [VisitSource.auto] — scan results are inferred,
///   never user-initiated.
List<CountryVisit> toCountryVisits(
  List<DetectedCountry> detected, {
  required DateTime now,
}) {
  return detected
      .map(
        (d) => CountryVisit(
          countryCode: d.code,
          source: VisitSource.auto,
          updatedAt: now,
        ),
      )
      .toList();
}

/// Maps [DetectedCountry] results into [InferredCountryVisit] objects for
/// persistence in the Drift [inferred_country_visits] table.
///
/// [firstSeen] and [lastSeen] are null — the current Swift bridge returns only
/// country-level aggregates, not per-photo timestamps. These fields will become
/// non-nullable once the bridge is extended in Task 3+4.
List<InferredCountryVisit> toInferredVisits(
  List<DetectedCountry> detected, {
  required DateTime now,
}) {
  return detected
      .map(
        (d) => InferredCountryVisit(
          countryCode: d.code,
          inferredAt: now,
          photoCount: d.photoCount,
        ),
      )
      .toList();
}
