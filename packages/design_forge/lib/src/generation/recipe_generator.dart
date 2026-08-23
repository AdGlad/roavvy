import '../determinism/deterministic_rng.dart';
import '../recipe/design_recipe.dart';
import '../travel/trip.dart';

/// The travel/filter input to generation — "what is this design about?".
///
/// Carries the resolved set of [flagCodes] plus, optionally, the real
/// **travel history** ([trips]) and a [dateRange] filter selected in the studio
/// design options. Timeline / journey / passport / word-cloud designs read the
/// trips (dates, visit frequency); simpler designs use just the flag codes. On
/// mobile this is produced from the user's `TripRecord`s; the engine never needs
/// to know how it was derived.
class DesignContext {
  const DesignContext({
    required this.flagCodes,
    this.scopeKey,
    this.trips = const [],
    this.dateRange = DateRange.all,
  });

  /// Build a context straight from a travel history, applying [dateRange] and
  /// deriving [flagCodes] from the (filtered) trips.
  factory DesignContext.fromTrips(
    List<Trip> trips, {
    DateRange dateRange = DateRange.all,
    String? scopeKey,
  }) {
    final history = TravelHistory(trips).inRange(dateRange);
    return DesignContext(
      flagCodes: history.countryCodes,
      trips: history.trips,
      dateRange: dateRange,
      scopeKey: scopeKey,
    );
  }

  final List<String> flagCodes;
  final String? scopeKey;

  /// Real travel history (already filtered to [dateRange] when non-empty).
  final List<Trip> trips;

  /// The date-range filter the trips were resolved under (for provenance/seed).
  final DateRange dateRange;

  bool get hasTrips => trips.isNotEmpty;

  /// Convenience view over [trips].
  TravelHistory get history => TravelHistory(trips);
}

/// Produces [DesignRecipe]s. The engine renders whatever a generator emits, so
/// generators can be deterministic rules today and preference-learned or
/// on-device-model driven later — **AI proposes recipes, the deterministic
/// engine renders them**. Rendering never depends on a generator.
abstract class RecipeGenerator {
  List<DesignRecipe> generate(
    DesignContext context, {
    required int seed,
    int count = 1,
  });
}

/// A tiny deterministic rule generator that proves the interface end-to-end:
/// picks a family from a seeded sub-stream and maps the resolved flags 1:1.
/// Real grammar/priors arrive in Phase 1.
class DeterministicRuleGenerator implements RecipeGenerator {
  const DeterministicRuleGenerator();

  @override
  List<DesignRecipe> generate(
    DesignContext context, {
    required int seed,
    int count = 1,
  }) {
    final flags = [
      for (final code in context.flagCodes) FlagRef(code.toLowerCase()),
    ];
    return [
      for (var i = 0; i < count; i++)
        _one(context, seed: seed + i, flags: flags),
    ];
  }

  DesignRecipe _one(
    DesignContext context, {
    required int seed,
    required List<FlagRef> flags,
  }) {
    final rng = DeterministicRng(seed);
    final family = flags.length <= 1
        ? DesignFamily.singleHero
        : rng.stream('family').pick(const [
            DesignFamily.grid,
            DesignFamily.duoBlend,
          ]);
    return DesignRecipe(
      seed: seed,
      content: RecipeContent(flags: flags, source: context.scopeKey),
      composition: Composition(family: family),
      provenance: const RecipeProvenance(generator: 'deterministicRule'),
    );
  }
}
