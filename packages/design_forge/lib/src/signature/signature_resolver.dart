import '../determinism/deterministic_rng.dart';
import '../recipe/design_recipe.dart';
import 'recipe_path.dart';
import 'signature_recipe.dart';

/// Turns a [SignatureRecipe] into concrete [DesignRecipe]s (ADR-181 §3).
///
/// Pure and deterministic: the same `(signature id, version, country, index)`
/// gives the same recipe on every device and isolate, so a feed position, a
/// liked design or an order can always be re-rendered exactly.
///
/// Order of application:
///   base → fill country tokens → country override → (hero values | sampled
///   envelope values) → [DesignRecipe].
/// Envelope paths pinned by the country's override are not sampled.
class SignatureResolver {
  const SignatureResolver._();

  /// The best default design for [country]: index 0 of the feed.
  static DesignRecipe hero(SignatureRecipe s, String country,
          {Map<String, String> tokens = const {}}) =>
      _build(s, country, tokens, (json, overridden) {
        final hero = s.heroes[country.toLowerCase()];
        if (hero == null) return;
        for (final e in hero.entries) {
          if (overridden.contains(e.key)) continue;
          RecipePath(e.key).write(json, e.value);
        }
      });

  /// Variation [index] for [country]. Index 0 is the [hero]; index ≥ 1
  /// samples every envelope parameter inside its approved range.
  static DesignRecipe variation(SignatureRecipe s, String country, int index,
      {Map<String, String> tokens = const {}}) {
    if (index < 0) throw RangeError.value(index, 'index', 'must be >= 0');
    if (index == 0) return hero(s, country, tokens: tokens);
    final cc = country.toLowerCase();
    final seed =
        DeterministicRng.hashString('${s.id}|${s.version}|$cc|$index');
    return _build(s, country, tokens, (json, overridden) {
      for (final e in s.envelope.ranges.entries) {
        if (overridden.contains(e.key)) continue;
        final rng = DeterministicRng.stream(seed, e.key);
        RecipePath(e.key).write(json, e.value.sample(rng));
      }
    });
  }

  /// Countries whose hero no longer matches its locked `recipeId` — i.e. an
  /// engine change has altered an approved design. Empty when all is well.
  static List<String> driftedLocks(SignatureRecipe s) => [
        for (final e in s.locks.entries)
          if (hero(s, e.key).recipeId != e.value) e.key,
      ]..sort();

  /// Fresh locks for [countries], from the current heroes.
  static Map<String, String> lockFor(
          SignatureRecipe s, Iterable<String> countries) =>
      {
        for (final c in countries) c.toLowerCase(): hero(s, c).recipeId,
      };

  static DesignRecipe _build(
    SignatureRecipe s,
    String country,
    Map<String, String> tokens,
    void Function(Map<String, Object?> json, Set<String> overridden) vary,
  ) {
    final json = s.instantiate(country, tokens: tokens);
    final override = s.overrides[country.toLowerCase()];
    final overridden = <String>{};
    if (override != null) {
      for (final e in override.params.entries) {
        RecipePath(e.key).write(json, e.value);
        overridden.add(e.key);
      }
    }
    vary(json, overridden);
    return DesignRecipe.fromJson(json);
  }
}
