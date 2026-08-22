import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('DiversitySelector', () {
    const selector = DiversitySelector();

    DesignRecipe _recipe(int seed, {
      String generator = 'lab:showcase',
      String? shapeId,
      DesignFamily family = DesignFamily.singleHero,
    }) {
      return DesignRecipe(
        seed: seed,
        content: const RecipeContent(flags: [FlagRef('us')]),
        composition: Composition(family: family),
        clip: shapeId != null ? Clip(shapeId: shapeId) : null,
        provenance: RecipeProvenance(generator: generator),
      );
    }

    test('returns at most count designs', () {
      final scored = [
        for (var i = 0; i < 20; i++)
          (_recipe(i, generator: 'lab:${['minimalist', 'grunge', 'vintage', 'beachwear'][i % 4]}',
              shapeId: ['circle', 'heart', 'diamond', 'animalSilhouette'][i % 4],
              family: DesignFamily.values[i % DesignFamily.values.length]),
           1.0 - i * 0.01),
      ];
      final result = selector.select(scored, count: 8);
      expect(result.length, lessThanOrEqualTo(8));
    });

    test('enforces max per composition family', () {
      // All same family → should still cap at maxPerComposition.
      final scored = [
        for (var i = 0; i < 10; i++)
          (_recipe(i,
              generator: 'lab:${['minimalist', 'grunge', 'vintage', 'beachwear', 'surf'][i % 5]}',
              shapeId: ['circle', 'heart', 'diamond', 'text', 'compass'][i % 5],
              family: DesignFamily.singleHero),
           1.0 - i * 0.05),
      ];
      final result = selector.select(scored, count: 8, maxPerComposition: 1);
      // Only 1 per composition family, and there's only 1 family → max 1.
      expect(result.length, equals(1));
    });

    test('returns all if pool smaller than count', () {
      final scored = [
        (_recipe(1, generator: 'lab:minimalist', shapeId: 'circle'), 0.9),
        (_recipe(2, generator: 'lab:grunge', shapeId: 'heart'), 0.8),
      ];
      final result = selector.select(scored, count: 8);
      expect(result.length, equals(2));
    });

    test('empty pool returns empty', () {
      final result = selector.select([], count: 8);
      expect(result, isEmpty);
    });

    test('includes exploration pick from non-top clusters', () {
      // Build a pool with mostly one cluster, using varied compositions
      // and shapes so diversity constraints don't block selection entirely.
      final families = DesignFamily.values;
      final shapes = ['circle', 'heart', 'diamond', 'text', 'compass',
          'hexagon', 'star', 'triangle', 'animalSilhouette', 'countryOutline'];
      final scored = <(DesignRecipe, double)>[];
      // 10 "bold" (grunge) recipes scored highest.
      for (var i = 0; i < 10; i++) {
        scored.add((_recipe(i,
            generator: 'lab:grunge',
            shapeId: shapes[i % shapes.length],
            family: families[i % families.length]),
            1.0 - i * 0.01));
      }
      // 2 "vintage" recipes scored lower, with unique families/shapes.
      scored.add((_recipe(100,
          generator: 'lab:vintage', shapeId: 'badge',
          family: DesignFamily.grid), 0.5));
      scored.add((_recipe(101,
          generator: 'lab:retro', shapeId: 'luggageTag',
          family: DesignFamily.duoBlend), 0.4));

      final result = selector.select(scored, count: 6);
      // Should have at least one non-bold (exploration) pick.
      final hasExploration = result.any((r) {
        final gen = r.provenance?.generator;
        return gen != null && !gen.contains('grunge') &&
            !gen.contains('streetwear') && !gen.contains('extreme');
      });
      expect(hasExploration, isTrue);
    });
  });
}
