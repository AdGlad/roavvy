import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('PreferenceLearner', () {
    const learner = PreferenceLearner();

    DesignRecipe _recipe({
      String generator = 'lab:grunge',
      String? shapeId = 'circle',
    }) {
      return DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us')]),
        composition: const Composition(family: DesignFamily.singleHero),
        clip: shapeId != null ? Clip(shapeId: shapeId) : null,
        provenance: RecipeProvenance(generator: generator),
      );
    }

    test('saved signal increases style weight', () {
      final prefs = DesignPreferences.neutral;
      final r = _recipe(generator: 'lab:grunge');
      final updated = learner.observe(prefs, r, PreferenceSignal.saved);
      expect(updated.weightFor(StyleCluster.bold), greaterThan(1.0));
    });

    test('rejected signal decreases style weight', () {
      final prefs = DesignPreferences.neutral;
      final r = _recipe(generator: 'lab:grunge');
      final updated = learner.observe(prefs, r, PreferenceSignal.rejected);
      expect(updated.weightFor(StyleCluster.bold), lessThan(1.0));
    });

    test('sampleCount increments', () {
      final prefs = DesignPreferences.neutral;
      final r = _recipe();
      final updated = learner.observe(prefs, r, PreferenceSignal.viewed);
      expect(updated.sampleCount, equals(1));
      final again = learner.observe(updated, r, PreferenceSignal.viewed);
      expect(again.sampleCount, equals(2));
    });

    test('weights are clamped', () {
      var prefs = DesignPreferences.neutral;
      final r = _recipe(generator: 'lab:grunge');
      // Apply many strong positive signals.
      for (var i = 0; i < 100; i++) {
        prefs = learner.observe(prefs, r, PreferenceSignal.selectedForMockup);
      }
      expect(prefs.weightFor(StyleCluster.bold),
          lessThanOrEqualTo(DesignPreferences.kClampMax));
    });

    test('shape preference updates from clip', () {
      final prefs = DesignPreferences.neutral;
      final r = _recipe(shapeId: 'circle');
      final updated = learner.observe(prefs, r, PreferenceSignal.saved);
      expect(updated.shapeWeightFor(ShapePreference.geometric),
          greaterThan(1.0));
    });

    test('no-clip recipe updates noClip shape weight', () {
      final prefs = DesignPreferences.neutral;
      final r = _recipe(shapeId: null);
      final updated = learner.observe(prefs, r, PreferenceSignal.saved);
      expect(updated.shapeWeightFor(ShapePreference.noClip),
          greaterThan(1.0));
    });
  });
}
