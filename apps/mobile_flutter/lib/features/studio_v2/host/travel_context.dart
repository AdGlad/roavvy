import 'package:design_forge/design_forge.dart';
import 'package:shared_models/shared_models.dart';

/// Bridges real Roavvy travel data into the shared `design_forge` travel model —
/// the single conversion seam for Studio V2. No new trip model is introduced:
/// the app's [TripRecord] maps 1:1 onto [Trip], and the effective visited-country
/// list is the flat fallback when no dated trips exist.
///
/// Kept as pure functions (no Riverpod, no widgets) so it is unit-testable and
/// reusable by both the real V2 app and tests.
class StudioV2TravelContext {
  const StudioV2TravelContext._();

  /// One [Trip] per [TripRecord] (repeat visits stay distinct → "Trips" mode can
  /// repeat a country).
  static Trip tripFromRecord(TripRecord r) => Trip(
        countryCode: r.countryCode,
        startedOn: r.startedOn,
        endedOn: r.endedOn,
        photoCount: r.photoCount,
      );

  /// Build the Studio's [DesignContext] from the best available real data:
  ///  * dated [trips] when present (enables Countries/Trips + year range), else
  ///  * the flat [visitedCodes] (Countries only), else
  ///  * [fallbackCodes] so a dev build still renders something.
  static DesignContext build({
    required List<TripRecord> trips,
    required List<String> visitedCodes,
    List<String> fallbackCodes = const ['us', 'fr', 'jp', 'br', 'au', 'it'],
    String scopeKey = 'studio_v2',
  }) {
    if (trips.isNotEmpty) {
      return DesignContext.fromTrips(
        [for (final r in trips) tripFromRecord(r)],
        scopeKey: scopeKey,
      );
    }
    final codes = visitedCodes.isNotEmpty ? visitedCodes : fallbackCodes;
    return DesignContext(
      flagCodes: [for (final c in codes) c.toLowerCase()],
      scopeKey: scopeKey,
    );
  }
}
