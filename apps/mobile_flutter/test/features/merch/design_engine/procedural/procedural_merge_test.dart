import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';
import 'package:mobile_flutter/features/merch/design_engine/rendering/merged_flag_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const gen = ProceduralDesignGenerator();

  final twoCountry = DesignContext.of(
    scope: DesignScope.multiCountry,
    countryCodes: const ['au', 'jp'],
    garmentIsDark: true,
  );

  test('duoBlend family is eligible only for two-country sets', () {
    final fams2 = eligibleFamilies(twoCountry).map((f) => f.family).toSet();
    expect(fams2, contains(CompositionFamily.duoBlend));

    final single = DesignContext.of(
        scope: DesignScope.singleCountry, countryCodes: const ['jp']);
    final many = DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: List.generate(6, (i) => 'a$i'.padRight(2, 'x')));
    expect(eligibleFamilies(single).map((f) => f.family),
        isNot(contains(CompositionFamily.duoBlend)));
    expect(eligibleFamilies(many).map((f) => f.family),
        isNot(contains(CompositionFamily.duoBlend)));
  });

  test('generator produces merged two-flag recipes for a duo context', () {
    ProceduralDesignRecipe? merged;
    for (var seed = 0; seed < 40 && merged == null; seed++) {
      for (final d in gen.generate(twoCountry, seed: seed, count: 12).designs) {
        if (d.recipe.isMerged) {
          merged = d.recipe;
          break;
        }
      }
    }
    expect(merged, isNotNull, reason: 'expected at least one duoBlend design');
    expect(merged!.combination, isNot(FlagCombination.none));
    expect(merged.countryCount, 2);
    // Genes are captured in the identity + JSON (reproducible).
    expect(merged.recipeId, contains(merged.combination.name));
    expect(merged.toJson()['combination'], merged.combination.name);
  });

  test('recipe identity changes with the blend gene', () {
    // Same design, different combination ⇒ different recipeId.
    ProceduralDesignRecipe? m;
    for (var s = 0; s < 40 && m == null; s++) {
      for (final d in gen.generate(twoCountry, seed: s).designs) {
        if (d.recipe.isMerged) m = d.recipe;
      }
    }
    expect(m, isNotNull);
    // Non-merged mapping stays printable.
    expect(m!.toDesignParams().isValid, isTrue);
  });

  test('MergedFlagRenderer returns null for a non-merged recipe', () async {
    final renderer = await MergedFlagRenderer.load();
    final single = DesignContext.of(
        scope: DesignScope.singleCountry, countryCodes: const ['jp']);
    final recipe = gen.generate(single, seed: 1).designs.first.recipe;
    expect(recipe.isMerged, isFalse);
    expect(await renderer.renderPng(recipe), isNull);
  });
}
