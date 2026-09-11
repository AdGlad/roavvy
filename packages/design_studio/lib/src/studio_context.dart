import 'package:design_forge/design_forge.dart';

/// Where the travel in a [StudioContext] came from.
enum StudioTravelSource {
  /// A real traveller's own discovered history, handed over by the host app.
  live,

  /// Demo travel, for the standalone dev entrypoints and for tests.
  fixture,
}

/// Everything the Studio is allowed to know about a traveller — and nothing
/// else.
///
/// This is the integration boundary:
///
/// ```text
/// Roavvy → StudioContext → StudioController → DesignRecipe
/// ```
///
/// The host maps its own models onto this ONCE, at the moment it opens a
/// session. Everything downstream sees only what is on this object, so the
/// Studio never reaches back into the app for travel data — and never sees a
/// photo, a scan, a database handle or a user record, because none of those
/// can be expressed here.
///
/// Production and standalone builds differ only in how this object is filled
/// in: real trips from the app, or fixtures from a dev entrypoint. There is one
/// Studio behind both.
class StudioContext {
  StudioContext({
    List<Trip> trips = const [],
    List<String> countryCodes = const [],
    List<String> initialSelection = const [],
    this.scopeKey = 'studio',
    this.source = StudioTravelSource.live,
  }) : trips = List.unmodifiable(trips),
       countryCodes = List.unmodifiable(_normalise(countryCodes)),
       initialSelection = List.unmodifiable(_normalise(initialSelection));

  /// Nothing travelled yet. A host that gets this must NOT invent countries to
  /// fill it — see [hasTravel].
  static final StudioContext empty = StudioContext();

  /// Dated travel history, one entry per visit. Empty when the host knows
  /// where someone has been but not when, in which case [countryCodes] carries
  /// the whole of it.
  final List<Trip> trips;

  /// Every country travelled, lowercase and de-duplicated, in the order the
  /// host supplied them. Always populated when anything was travelled — also
  /// when [trips] is, so a host never has to dig dates out to ask a flat
  /// question.
  final List<String> countryCodes;

  /// The countries a session should open on, when the host has an opinion.
  /// Empty means "all of them", which is the Studio's own default.
  final List<String> initialSelection;

  /// Namespaces the deterministic seed, so two different travel sets cannot
  /// collide on the same design. A stable per-traveller reference belongs here
  /// — never an identity the design engine could leak into a recipe.
  final String scopeKey;

  final StudioTravelSource source;

  /// False when the traveller has no discovered travel at all. The honest
  /// answer then is to say so, not to open the Studio on countries nobody has
  /// been to.
  bool get hasTravel => trips.isNotEmpty || countryCodes.isNotEmpty;

  /// True when the history carries real dates, which is what lets the Studio
  /// offer a year range and repeat visits.
  bool get isDated => trips.isNotEmpty;

  /// The first and last year travelled, or null when the history is undated.
  (int, int)? get yearRange {
    if (trips.isEmpty) return null;
    final span = TravelHistory(trips).span;
    final (start, end) = (span?.start, span?.end);
    if (start == null || end == null) return null;
    return (start.year, end.year);
  }

  /// The engine's own view of the same travel. Dated history goes through
  /// [DesignContext.fromTrips] so trips survive; an undated one carries the
  /// flat country list.
  DesignContext toDesignContext() =>
      trips.isNotEmpty
          ? DesignContext.fromTrips(trips, scopeKey: scopeKey)
          : DesignContext(flagCodes: countryCodes, scopeKey: scopeKey);

  static List<String> _normalise(List<String> codes) {
    final seen = <String>{};
    return [
      for (final c in codes)
        if (c.trim().isNotEmpty && seen.add(c.trim().toLowerCase()))
          c.trim().toLowerCase(),
    ];
  }
}
