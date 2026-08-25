import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _base({Map<String, int> axisSeeds = const {}}) => DesignRecipe(
      seed: 100,
      axisSeeds: axisSeeds,
      content: const RecipeContent(flags: [FlagRef('sc')], source: 'lab:sc'),
      composition: const Composition(family: DesignFamily.singleHero),
    );

void main() {
  group('DesignAxis', () {
    test('key is the stable enum name and round-trips via fromKey', () {
      for (final a in DesignAxis.values) {
        expect(a.key, a.name);
        expect(DesignAxis.fromKey(a.key), a);
      }
      expect(DesignAxis.fromKey('nope'), isNull);
      expect(DesignAxis.fromKey(null), isNull);
    });
  });

  group('DesignRecipe.axisSeeds', () {
    test('seedForAxis falls back to seed, else the per-axis override', () {
      final r = _base(axisSeeds: {DesignAxis.vibe.key: 777});
      expect(r.seedForAxis(DesignAxis.vibe), 777);
      // Unset axes fall back to the master seed.
      expect(r.seedForAxis(DesignAxis.direction), 100);
      expect(r.seedForAxis(DesignAxis.focus), 100);
    });

    test('empty axisSeeds does not change the recipeId (pre-M2 recipes stable)',
        () {
      // A recipe with an explicit empty map must hash identically to one that
      // never set axisSeeds at all.
      expect(_base(axisSeeds: const {}).recipeId, _base().recipeId);
    });

    test('a non-empty axisSeeds map is part of the content hash', () {
      final a = _base();
      final b = _base(axisSeeds: {DesignAxis.vibe.key: 1});
      expect(b.recipeId, isNot(a.recipeId));
      // Different per-axis seeds → different ids.
      final c = _base(axisSeeds: {DesignAxis.vibe.key: 2});
      expect(c.recipeId, isNot(b.recipeId));
    });

    test('axisSeeds survives a JSON round-trip', () {
      final r = _base(axisSeeds: {
        DesignAxis.vibe.key: 11,
        DesignAxis.focus.key: 22,
      });
      final decoded = DesignRecipe.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect(decoded.axisSeeds, r.axisSeeds);
      expect(decoded.recipeId, r.recipeId);
    });

    test('copyWith can set axisSeeds and preserves it otherwise', () {
      final r = _base(axisSeeds: {DesignAxis.vibe.key: 5});
      expect(r.copyWith(seed: 101).axisSeeds, {DesignAxis.vibe.key: 5});
      expect(r.copyWith(axisSeeds: {DesignAxis.focus.key: 9}).axisSeeds,
          {DesignAxis.focus.key: 9});
    });
  });
}
