import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _sample() => DesignRecipe(
      seed: 123,
      content: const RecipeContent(
        flags: [FlagRef('jp', weight: 2.0), FlagRef('fr')],
        source: 'thisYear',
      ),
      composition: const Composition(family: DesignFamily.duoBlend),
      provenance: const RecipeProvenance(generator: 'studioManual'),
    );

void main() {
  group('DesignRecipe serialisation', () {
    test('JSON round-trips losslessly', () {
      final r = _sample();
      final decoded = DesignRecipe.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect(decoded.seed, r.seed);
      expect(decoded.content.flags, r.content.flags);
      expect(decoded.content.source, 'thisYear');
      expect(decoded.composition.family, DesignFamily.duoBlend);
      expect(decoded.recipeId, r.recipeId);
    });

    test('unknown family decodes to unknown (forward compatible)', () {
      final json = _sample().toJson();
      (json['composition'] as Map)['family'] = 'someFutureFamily';
      final decoded = DesignRecipe.fromJson(json);
      expect(decoded.composition.family, DesignFamily.unknown);
    });
  });

  group('recipeId content hash', () {
    test('is stable across identical recipes', () {
      expect(_sample().recipeId, _sample().recipeId);
    });

    test('ignores provenance (bookkeeping does not change the artwork)', () {
      final a = _sample();
      final b = a.copyWith(
          provenance: const RecipeProvenance(generator: 'mutation'));
      expect(b.recipeId, a.recipeId);
    });

    test('changes when a design-affecting field changes', () {
      final a = _sample();
      final b = a.copyWith(seed: 124);
      expect(b.recipeId, isNot(a.recipeId));
    });

    test('is independent of flag insertion order metadata but sensitive to it',
        () {
      // Order of flags is meaningful (flag A vs B), so a reversed list differs.
      final a = _sample();
      final b = a.copyWith(
        content: RecipeContent(
          flags: a.content.flags.reversed.toList(),
          source: a.content.source,
        ),
      );
      expect(b.recipeId, isNot(a.recipeId));
    });
  });

  group('DeterministicRuleGenerator', () {
    test('same (context, seed) yields identical recipes', () {
      const gen = DeterministicRuleGenerator();
      const ctx = DesignContext(flagCodes: ['jp', 'fr'], scopeKey: 'trip:1');
      final a = gen.generate(ctx, seed: 10, count: 5);
      final b = gen.generate(ctx, seed: 10, count: 5);
      expect([for (final r in a) r.recipeId], [for (final r in b) r.recipeId]);
    });

    test('single flag => singleHero; multi flag => grid/duoBlend', () {
      const gen = DeterministicRuleGenerator();
      final single =
          gen.generate(const DesignContext(flagCodes: ['jp']), seed: 1).single;
      expect(single.composition.family, DesignFamily.singleHero);

      final multi = gen
          .generate(const DesignContext(flagCodes: ['jp', 'fr']), seed: 1)
          .single;
      expect(multi.composition.family,
          anyOf(DesignFamily.grid, DesignFamily.duoBlend));
    });

    test('count produces distinct seeds', () {
      const gen = DeterministicRuleGenerator();
      final recipes =
          gen.generate(const DesignContext(flagCodes: ['jp']), seed: 0, count: 3);
      expect(recipes.map((r) => r.seed).toList(), [0, 1, 2]);
    });
  });
}
