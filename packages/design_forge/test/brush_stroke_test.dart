import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips, validates, changes the recipe id', () {
    const b = BrushStroke(dryness: 0.4, liftFray: 0.7, skew: -2);
    expect(BrushStroke.fromJson(b.toJson()).toJson(), b.toJson());
    expect(
        BrushStroke.fromJson(const {}).toJson(), const BrushStroke().toJson());
    expect(() => BrushStroke.fromJson({'bristles': 2}), throwsFormatException);
    expect(() => BrushStroke.fromJson({'minAspect': 2.0, 'maxAspect': 1.0}),
        throwsFormatException);

    const base = DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef('gr')]),
      composition: Composition(family: DesignFamily.singleHero),
    );
    expect(base.toJson().containsKey('brushStroke'), isFalse,
        reason: 'absent group leaves existing recipe ids alone');
    final brushed = base.copyWith(brushStroke: b);
    expect(brushed.recipeId, isNot(base.recipeId));
    final back = DesignRecipe.fromJson(brushed.toJson());
    expect(back.recipeId, brushed.recipeId);
    expect(back.brushStroke!.skew, -2);
  });

  test('handwritten captions font id round-trips', () {
    const c =
        Captions(top: '{{countryName}}', font: 'handwritten', colour: 'auto');
    expect(Captions.fromJson(c.toJson()).font, 'handwritten');
  });
}
