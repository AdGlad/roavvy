import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  test('country display names, with home nations and fallback', () {
    expect(countryDisplayName('gr'), 'Greece');
    expect(countryDisplayName('US'), 'United States');
    expect(countryDisplayName('gb-sct'), 'Scotland');
    expect(countryDisplayName('zz'), 'ZZ');
  });

  test('captions round-trip and validate colour', () {
    const c = Captions(top: 'I', bottom: '{{countryName}}', grit: 0.2, colour: '#123456');
    expect(Captions.fromJson(c.toJson()).toJson(), c.toJson());
    expect(() => Captions.fromJson({'colour': 'blue'}), throwsFormatException);
  });

  test('{{countryName}} is built in; a gap ring is allowed', () {
    final json = const DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef('us')]),
      composition: Composition(
        family: DesignFamily.singleHero,
        outlineRings: [OutlineRing(width: 1, colour: 'none'), OutlineRing(width: 1, colour: '#D52B1E')],
      ),
      clip: Clip(shapeId: 'heart'),
      captions: Captions(top: 'I', bottom: 'x'),
    ).toJson()
      ..remove('recipeId');
    (json['content'] as Map)['flags'] = [
      {'code': '{{country}}', 'weight': 1.0},
    ];
    (json['captions'] as Map)['bottom'] = '{{countryName}}';
    final pack = SignatureRecipe(
        id: 'i', title: 'I', version: 1, status: SignatureStatus.draft, base: json);
    final r = SignatureResolver.hero(pack, 'gr');
    expect(r.captions!.bottom, 'Greece');
    expect(r.composition.outlineRings.first.colour, OutlineRing.gap);
  });
}
