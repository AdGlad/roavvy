import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('VariationGenerator', () {
    const varGen = VariationGenerator();

    final anchor = DesignRecipe(
      seed: 42,
      content: const RecipeContent(flags: [FlagRef('jp')]),
      composition: const Composition(family: DesignFamily.singleHero),
      clip: const Clip(shapeId: 'circle', scale: 0.85),
      palette: const Palette(
        garmentColour: '#FFFFFF',
        vintageGrade: 0.4,
      ),
      effects: const Effects(distress: 0.3, grain: 0.2),
      edgeTreatment: const EdgeTreatment(
        style: TearStyle.lightlyWorn,
        edgeDamage: 0.3,
        maxDepth: 0.1,
      ),
    );

    test('produces requested number of variations', () {
      final vars = varGen.variate(anchor, count: 12);
      expect(vars.length, equals(12));
    });

    test('covers all variation axes', () {
      final vars = varGen.variate(anchor, count: 12);
      final axes = vars.map((v) => v.axis).toSet();
      expect(axes, containsAll(VariationAxis.values));
    });

    test('each variation differs from anchor', () {
      final vars = varGen.variate(anchor, count: 12);
      for (final v in vars) {
        expect(v.recipe.recipeId, isNot(equals(anchor.recipeId)),
            reason: 'Variation on ${v.axis} should differ from anchor');
      }
    });

    test('deterministic: same seed produces same variations', () {
      final a = varGen.variate(anchor, count: 6, seed: 99);
      final b = varGen.variate(anchor, count: 6, seed: 99);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].recipe.recipeId, equals(b[i].recipe.recipeId));
        expect(a[i].axis, equals(b[i].axis));
      }
    });

    test('shape variations change the clip shape', () {
      final vars = varGen.variate(anchor, count: 12);
      final shapeVars = vars.where((v) => v.axis == VariationAxis.shapeSwap);
      for (final v in shapeVars) {
        expect(v.recipe.clip?.shapeId, isNot(equals('circle')));
      }
    });

    test('effect variations keep same shape', () {
      final vars = varGen.variate(anchor, count: 12);
      final fxVars =
          vars.where((v) => v.axis == VariationAxis.effectIntensity);
      for (final v in fxVars) {
        expect(v.recipe.clip?.shapeId, equals('circle'));
      }
    });

    test('edge removal variation has no edge treatment', () {
      final vars = varGen.variate(anchor, count: 12);
      final edgeVars =
          vars.where((v) => v.axis == VariationAxis.edgeTreatment).toList();
      // First edge variation should be the "remove edge" one.
      expect(edgeVars.first.recipe.edgeTreatment, isNull);
    });
  });
}
