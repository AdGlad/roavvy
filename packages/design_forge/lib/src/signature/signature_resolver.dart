import '../determinism/deterministic_rng.dart';
import '../recipe/design_recipe.dart';
import 'recipe_path.dart';
import 'signature_recipe.dart';

/// Turns a [SignatureRecipe] into concrete [DesignRecipe]s (ADR-181 §3,
/// pairs ADR-185).
///
/// Pure and deterministic: the same `(signature id, version, country, index)`
/// gives the same recipe on every device and isolate, so a feed position, a
/// liked design or an order can always be re-rendered exactly.
///
/// Order of application:
///   base → fill country tokens → country override(s) → pair override →
///   (hero values | sampled envelope values) → [DesignRecipe].
/// Envelope paths pinned by an override are not sampled.
///
/// Single-country packs use [hero]/[variation]; pair packs ([SignatureRecipe.
/// isPair]) use [heroPair]/[variationPair]. [heroFor]/[variationFor] take a
/// pack key (a country code, or `"a+b"`) and work for both.
class SignatureResolver {
  const SignatureResolver._();

  /// The best default design for [country]: index 0 of the feed.
  static DesignRecipe hero(SignatureRecipe s, String country,
      {Map<String, String> tokens = const {}}) {
    _single(s);
    return _hero(s, country.toLowerCase(), tokens);
  }

  /// Variation [index] for [country]. Index 0 is the [hero]; index ≥ 1
  /// samples every envelope parameter inside its approved range.
  static DesignRecipe variation(SignatureRecipe s, String country, int index,
      {Map<String, String> tokens = const {}}) {
    _single(s);
    return _variation(s, country.toLowerCase(), index, tokens);
  }

  /// The hero of a pair pack for countries [a] (left/top) and [b].
  static DesignRecipe heroPair(SignatureRecipe s, String a, String b,
      {Map<String, String> tokens = const {}}) {
    _pair(s);
    return _hero(s, SignaturePair(a, b).key, tokens);
  }

  /// Variation [index] of a pair pack for [a] and [b]. The seed key is
  /// `id|version|a+b|index`, so swapping the countries gives a different
  /// (equally deterministic) feed.
  static DesignRecipe variationPair(
      SignatureRecipe s, String a, String b, int index,
      {Map<String, String> tokens = const {}}) {
    _pair(s);
    return _variation(s, SignaturePair(a, b).key, index, tokens);
  }

  /// [hero] or [heroPair] for a pack key (`"jp"` or `"fr+jp"`).
  static DesignRecipe heroFor(SignatureRecipe s, String key,
          {Map<String, String> tokens = const {}}) =>
      _hero(s, _key(s, key), tokens);

  /// [variation] or [variationPair] for a pack key.
  static DesignRecipe variationFor(SignatureRecipe s, String key, int index,
          {Map<String, String> tokens = const {}}) =>
      _variation(s, _key(s, key), index, tokens);

  /// Keys (countries, or pairs) whose hero no longer matches its locked
  /// `recipeId` — i.e. an engine change has altered an approved design.
  /// Empty when all is well.
  static List<String> driftedLocks(SignatureRecipe s) => [
        for (final e in s.locks.entries)
          if (heroFor(s, e.key).recipeId != e.value) e.key,
      ]..sort();

  /// Fresh locks for [keys] (countries, or `"a+b"` pairs), from the current
  /// heroes.
  static Map<String, String> lockFor(
          SignatureRecipe s, Iterable<String> keys) =>
      {
        for (final k in keys) _key(s, k): heroFor(s, k).recipeId,
      };

  static DesignRecipe _hero(
          SignatureRecipe s, String key, Map<String, String> tokens) =>
      _build(s, key, tokens, (json, overridden) {
        final hero = s.heroes[key];
        if (hero == null) return;
        for (final e in hero.entries) {
          if (overridden.contains(e.key)) continue;
          RecipePath(e.key).write(json, e.value);
        }
      });

  static DesignRecipe _variation(
      SignatureRecipe s, String key, int index, Map<String, String> tokens) {
    if (index < 0) throw RangeError.value(index, 'index', 'must be >= 0');
    if (index == 0) return _hero(s, key, tokens);
    final seed =
        DeterministicRng.hashString('${s.id}|${s.version}|$key|$index');
    return _build(s, key, tokens, (json, overridden) {
      for (final e in s.envelope.ranges.entries) {
        if (overridden.contains(e.key)) continue;
        final rng = DeterministicRng.stream(seed, e.key);
        RecipePath(e.key).write(json, e.value.sample(rng));
      }
    });
  }

  static DesignRecipe _build(
    SignatureRecipe s,
    String key,
    Map<String, String> tokens,
    void Function(Map<String, Object?> json, Set<String> overridden) vary,
  ) {
    final json = s.instantiateKey(key, tokens: tokens);
    final overridden = <String>{};
    void apply(CountryOverride? o, {int? slot}) {
      if (o == null) return;
      for (final e in o.params.entries) {
        final path =
            slot == null ? e.key : SignatureRecipe.slotPath(e.key, slot);
        RecipePath(path).write(json, e.value);
        overridden.add(path);
      }
    }

    if (s.isPair) {
      final p = SignaturePair.parse(key);
      apply(s.overrides[p.a], slot: 0);
      apply(s.overrides[p.b], slot: 1);
      apply(s.overrides[p.key]);
    } else {
      apply(s.overrides[key]);
    }
    vary(json, overridden);
    return DesignRecipe.fromJson(json);
  }

  static String _key(SignatureRecipe s, String key) =>
      s.isPair ? SignaturePair.parse(key).key : key.toLowerCase();

  static void _single(SignatureRecipe s) {
    if (s.isPair) {
      throw StateError('${s.id} is a pair pack: use heroPair/variationPair');
    }
  }

  static void _pair(SignatureRecipe s) {
    if (!s.isPair) {
      throw StateError('${s.id} is a single-country pack: use hero/variation');
    }
  }
}
