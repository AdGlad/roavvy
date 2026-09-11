import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:shared_models/shared_models.dart';

/// The ONE place Roavvy's travel models are turned into something the Studio
/// can read.
///
/// Above this line: [TripRecord], [EffectiveVisitedCountry] — the app's own
/// records, owned by the scan and the travel database. Below it: a
/// [StudioContext], which is derived travel and nothing else. No photo, no
/// asset id, no coordinate and no database handle crosses, because none of
/// them can be expressed on the far side.
///
/// Pure functions (no Riverpod, no widgets) so both the real app and the tests
/// map the same way.
class StudioV2TravelContext {
  const StudioV2TravelContext._();

  /// One [Trip] per [TripRecord] — repeat visits stay distinct, so "Trips" mode
  /// can genuinely repeat a country.
  static Trip tripFromRecord(TripRecord r) => Trip(
    countryCode: r.countryCode.toLowerCase(),
    startedOn: r.startedOn,
    endedOn: r.endedOn,
    photoCount: r.photoCount,
  );

  /// A visited country as a single trip, when Roavvy knows when it happened.
  ///
  /// Visits restored from the cloud arrive without trip records but keep their
  /// first/last dates, and that is enough to date a history — which is the
  /// difference between the Studio offering a year range and silently dropping
  /// half its Travels step.
  static Trip? tripFromVisit(EffectiveVisitedCountry v) {
    final first = v.firstSeen;
    if (first == null) return null;
    return Trip(
      countryCode: v.countryCode.toLowerCase(),
      startedOn: first,
      endedOn: v.lastSeen ?? first,
      photoCount: v.photoCount,
    );
  }

  /// Roavvy's travel, as the Studio sees it.
  ///
  /// Dated trip records are the best source. Failing those, dated visits are
  /// promoted to one trip each — but only when EVERY visit is dated, because a
  /// dated history is derived from its trips alone and a half-dated one would
  /// quietly drop the countries added by hand. Otherwise the flat country list
  /// carries the whole history, undated.
  ///
  /// Nothing is invented: a traveller with no discovered travel gets a context
  /// that says so ([StudioContext.hasTravel]), never a stand-in country.
  static StudioContext fromRoavvy({
    required List<TripRecord> trips,
    required List<EffectiveVisitedCountry> visits,
    List<String> initialSelection = const [],
    String scopeKey = 'studio_v2',
  }) {
    final codes = [
      for (final v in visits) v.countryCode,
      // A trip for a country no visit row mentions still counts as travel.
      for (final t in trips) t.countryCode,
    ];

    if (trips.isNotEmpty) {
      return StudioContext(
        trips: [for (final r in trips) tripFromRecord(r)],
        countryCodes: codes,
        initialSelection: initialSelection,
        scopeKey: scopeKey,
      );
    }

    final dated = [for (final v in visits) tripFromVisit(v)];
    if (visits.isNotEmpty && !dated.contains(null)) {
      return StudioContext(
        trips: dated.whereType<Trip>().toList(),
        countryCodes: codes,
        initialSelection: initialSelection,
        scopeKey: scopeKey,
      );
    }

    return StudioContext(
      countryCodes: codes,
      initialSelection: initialSelection,
      scopeKey: scopeKey,
    );
  }
}
