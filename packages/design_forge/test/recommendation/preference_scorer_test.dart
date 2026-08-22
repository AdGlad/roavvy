import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('PreferenceScorer', () {
    const scorer = PreferenceScorer();

    DesignRecipe _recipe({
      String? generator,
      String? shapeId,
      String? garmentColour,
      double vintageGrade = 0.5,
    }) {
      return DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us')]),
        composition: const Composition(family: DesignFamily.singleHero),
        clip: shapeId != null ? Clip(shapeId: shapeId) : null,
        palette: Palette(
          garmentColour: garmentColour,
          vintageGrade: vintageGrade,
        ),
        provenance: generator != null
            ? RecipeProvenance(generator: generator)
            : null,
      );
    }

    test('neutral preferences → ~0.5 for any recipe', () {
      final r = _recipe(generator: 'lab:minimalist', shapeId: 'circle');
      final score = scorer.score(r, DesignPreferences.neutral);
      expect(score, closeTo(0.5, 0.01));
    });

    test('preferred style cluster scores higher', () {
      final r = _recipe(generator: 'lab:grunge', shapeId: 'circle');
      final prefs = DesignPreferences(
        styleWeights: {StyleCluster.bold: 4.0},
      );
      final score = scorer.score(r, prefs);
      expect(score, greaterThan(0.5));
    });

    test('dis-preferred style cluster scores lower', () {
      final r = _recipe(generator: 'lab:grunge', shapeId: 'circle');
      final prefs = DesignPreferences(
        styleWeights: {StyleCluster.bold: 0.2},
      );
      final score = scorer.score(r, prefs);
      expect(score, lessThan(0.5));
    });

    test('garment tone match boosts score', () {
      final r = _recipe(garmentColour: '#1A1A1A'); // dark
      final darkPrefs = DesignPreferences(
        prefersDarkGarment: true,
      );
      final lightPrefs = DesignPreferences(
        prefersDarkGarment: false,
      );
      final darkScore = scorer.score(r, darkPrefs);
      final lightScore = scorer.score(r, lightPrefs);
      expect(darkScore, greaterThan(lightScore));
    });

    test('combined blends quality and preference', () {
      final c = scorer.combined(0.8, 0.6, prefBlend: 0.35);
      // 0.8 * 0.65 + 0.6 * 0.35 = 0.52 + 0.21 = 0.73
      expect(c, closeTo(0.73, 0.01));
    });

    test('score is between 0 and 1', () {
      final r = _recipe(
          generator: 'lab:vintage',
          shapeId: 'heart',
          garmentColour: '#000000');
      final extremePrefs = DesignPreferences(
        styleWeights: {StyleCluster.vintage: 6.0},
        shapeWeights: {ShapePreference.geometric: 6.0},
        prefersDarkGarment: true,
        prefersVibrant: true,
      );
      final score = scorer.score(r, extremePrefs);
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(1));
    });
  });
}
