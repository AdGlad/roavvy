import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips, validates rim colour, changes the recipe id', () {
    const g = Globe(bulge: 0.5, sparkles: 0, rimColour: '#000000');
    expect(Globe.fromJson(g.toJson()).toJson(), g.toJson());
    expect(() => Globe.fromJson({'rimColour': 'white'}), throwsFormatException);
    const base = DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef('us')]),
      composition: Composition(family: DesignFamily.singleHero),
      clip: Clip(shapeId: 'circle'),
    );
    expect(base.toJson().containsKey('globe'), isFalse);
    final ball = base.copyWith(globe: g);
    expect(ball.recipeId, isNot(base.recipeId));
    expect(DesignRecipe.fromJson(ball.toJson()).recipeId, ball.recipeId);
  });
}
