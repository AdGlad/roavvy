import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

void main() {
  const gen = ProceduralDesignGenerator();
  const learner = PreferenceLearner();
  const scorer = PreferenceScorer();

  final ctx = DesignContext.of(
    scope: DesignScope.multiCountry,
    countryCodes: const ['fr', 'jp', 'us', 'br', 'ke'],
    garmentIsDark: true,
  );
  final designs = gen.generate(ctx, seed: 100).designs;
  final liked = designs.first.recipe;

  test('neutral profile is exactly neutral (0.5) for any recipe', () {
    for (final d in designs) {
      expect(scorer.score(d.recipe, UserDesignPreferenceProfile.neutral),
          closeTo(0.5, 1e-9));
    }
  });

  test('a positive signal raises preference for that recipe', () {
    final before = scorer.score(liked, UserDesignPreferenceProfile.neutral);
    final p = learner.observe(
        UserDesignPreferenceProfile.neutral, liked, PreferenceSignal.saved);
    final after = scorer.score(liked, p);
    expect(after, greaterThan(before));
  });

  test('a rejection lowers preference for that recipe', () {
    final p = learner.observe(UserDesignPreferenceProfile.neutral, liked,
        PreferenceSignal.rejected);
    expect(scorer.score(liked, p), lessThan(0.5));
  });

  test('styleChosen moves only the treatment, not the composition', () {
    final p = learner.observe(UserDesignPreferenceProfile.neutral, liked,
        PreferenceSignal.styleChosen);
    // print style weight changed…
    expect(p.printStyle[liked.printStyle.name], isNot(1.0));
    // …but family weight stayed neutral.
    expect(p.family[liked.family.name] ?? 1.0, 1.0);
  });

  test('quality and preference are independent scores', () {
    // Quality does not depend on the profile at all.
    final q1 = designs.first.quality.total;
    final p = learner.observe(UserDesignPreferenceProfile.neutral, liked,
        PreferenceSignal.selectedForMockup);
    final q2 = gen.generate(ctx, seed: 100).designs.first.quality.total;
    expect(q1, q2); // unchanged by any preference learning
    // Combined ranking blends them but keeps them retrievable.
    final pref = scorer.score(liked, p);
    final combined = scorer.combined(q1, pref, prefBlend: 0.35);
    expect(combined, isNot(q1));
  });

  test('exploration rate decays as evidence accrues', () {
    var p = UserDesignPreferenceProfile.neutral;
    final start = p.explorationRate;
    for (var i = 0; i < 60; i++) {
      p = learner.observe(p, liked, PreferenceSignal.viewed);
    }
    expect(p.explorationRate, lessThan(start));
    expect(p.explorationRate, greaterThanOrEqualTo(0.05));
    expect(p.sampleCount, 60);
  });

  test('profile serialises round-trip', () {
    var p = UserDesignPreferenceProfile.neutral;
    p = learner.observe(p, liked, PreferenceSignal.saved);
    final restored =
        UserDesignPreferenceProfile.fromJson(p.toJson());
    expect(scorer.score(liked, restored), closeTo(scorer.score(liked, p), 1e-9));
  });
}
