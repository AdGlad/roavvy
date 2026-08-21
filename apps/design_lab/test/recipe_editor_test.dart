import 'package:design_forge/design_forge.dart';
import 'package:design_lab/lab_styles.dart';
import 'package:design_lab/recipe_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DesignRecipe seed() => DesignRecipe(
        seed: 5,
        content: const RecipeContent(flags: [FlagRef('us'), FlagRef('gb')]),
        composition: const Composition(family: DesignFamily.duoBlend),
        flagCombination:
            const FlagCombination(mode: FlagCombineMode.diagonalSplit),
      );

  test('draft round-trips a recipe unchanged', () {
    final r = seed();
    expect(RecipeDraft(r).toRecipe().recipeId, r.recipeId);
  });

  test('a blend recipe reads back as the blend pattern', () {
    expect(RecipeDraft(seed()).pattern, LabPattern.blend);
  });

  test('multi repeats each country by copies-per-country', () {
    // seed() has 2 distinct countries (us, gb).
    final draft = RecipeDraft(seed())
      ..pattern = LabPattern.multi
      ..algorithm = FillAlgorithm.voronoi
      ..perCountry = 4;
    final r = draft.toRecipe();
    expect(r.composition.family, DesignFamily.grid);
    expect(r.composition.fillAlgorithm, FillAlgorithm.voronoi);
    expect(r.content.flags.length, 8); // 4 copies × 2 countries
    expect(r.content.flags.where((f) => f.code == 'us').length, 4);
    expect(r.content.flags.where((f) => f.code == 'gb').length, 4);
    expect(r.flagCombination, isNull); // multi never blends
  });

  test('single-country multi = N copies of that flag', () {
    final draft = RecipeDraft(DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('au')]),
      composition: const Composition(family: DesignFamily.singleHero),
    ))
      ..pattern = LabPattern.multi
      ..perCountry = 4;
    final r = draft.toRecipe();
    expect(r.content.flags.length, 4);
    expect(r.content.flags.every((f) => f.code == 'au'), isTrue);
  });

  test('toggling a group changes the rendered recipe', () {
    final draft = RecipeDraft(seed());
    final before = draft.toRecipe().recipeId;
    draft
      ..edgeOn = true
      ..edgeDamage = 0.8;
    final after = draft.toRecipe();
    expect(after.recipeId, isNot(before));
    expect(after.edgeTreatment, isNotNull);
    expect(after.edgeTreatment!.edgeDamage, 0.8);
  });

  test('editing a parameter changes recipeId (drives live re-render)', () {
    final draft = RecipeDraft(seed())..fxOn = true;
    final a = draft.toRecipe().recipeId;
    draft.distress = 0.5;
    expect(draft.toRecipe().recipeId, isNot(a));
  });

  test('switching to single pattern drops the combination', () {
    final draft = RecipeDraft(seed())..pattern = LabPattern.single;
    final r = draft.toRecipe();
    expect(r.flagCombination, isNull);
    expect(r.content.flags.length, 1);
  });

  test('style round-trips through provenance', () {
    for (final style in LabStyle.values) {
      expect(labStyleFromProvenance('lab:${style.name}'), style);
    }
    expect(labStyleFromProvenance('labEdit'), isNull);
    expect(labStyleFromProvenance(null), isNull);
    expect(labStyleFromProvenance('lab:nope'), isNull);
  });
}
