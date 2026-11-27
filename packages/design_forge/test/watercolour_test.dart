import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips every field and changes the recipeId', () {
    const wc = Watercolour(wobble: 0.3, streaks: 0.2, paper: '#FFFFFF');
    expect(Watercolour.fromJson(wc.toJson()).toJson(), wc.toJson());
    const base = DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef('us')]),
      composition: Composition(family: DesignFamily.singleHero),
      clip: Clip(shapeId: 'heart'),
    );
    final painted = base.copyWith(watercolour: wc);
    expect(painted.recipeId, isNot(base.recipeId));
    expect(DesignRecipe.fromJson(painted.toJson()).recipeId, painted.recipeId);
    expect(base.toJson().containsKey('watercolour'), isFalse,
        reason: 'recipes without it keep their ids');
  });

  test('paper must be #RRGGBB', () {
    expect(() => Watercolour.fromJson({'paper': 'cream'}), throwsFormatException);
  });

  test('clip flagScale / flagOffsetY: omitted at defaults, round-trip', () {
    const c = Clip(shapeId: 'heart');
    expect(c.toJson().containsKey('flagScale'), isFalse);
    expect(c.toJson().containsKey('flagOffsetY'), isFalse);
    final d = c.copyWith(flagScale: 0.8, flagOffsetY: -0.03);
    final back = Clip.fromJson(d.toJson());
    expect(back.flagScale, 0.8);
    expect(back.flagOffsetY, -0.03);
  });
}
