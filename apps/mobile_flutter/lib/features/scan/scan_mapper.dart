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
