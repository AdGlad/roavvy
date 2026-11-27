import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  test('3-letter codes for countries, home nations and fallbacks', () {
    expect(countryAlpha3('us'), 'USA');
    expect(countryAlpha3('GB'), 'GBR');
    expect(countryAlpha3('jp'), 'JPN');
    expect(countryAlpha3('gb-sct'), 'SCO');
    expect(countryAlpha3('xk'), 'KOS');
    expect(countryAlpha3('zz'), 'ZZ');
  });

  test('{{country3}} is a built-in token every pack gets', () {
    final json = const DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef('us')]),
      composition: Composition(family: DesignFamily.singleHero),
      clip: Clip(shapeId: 'text', text: 'x'),
    ).toJson()
      ..remove('recipeId');
    (json['content'] as Map)['flags'] = [
      {'code': '{{country}}', 'weight': 1.0},
    ];
    (json['clip'] as Map)['text'] = '{{country3}}';
    final pack = SignatureRecipe(
        id: 'v', title: 'V', version: 1, status: SignatureStatus.draft, base: json);
    expect(SignatureResolver.hero(pack, 'de').clip!.text, 'DEU');
  });

  test('clip font / flagFit and outline rings round-trip and validate', () {
    const clip = Clip(shapeId: 'text', text: 'USA', font: 'varsity', flagFit: 'stretch');
    final back = Clip.fromJson(clip.toJson());
    expect(back.font, 'varsity');
    expect(back.flagFit, 'stretch');
    expect(const Clip(shapeId: 'text').toJson().containsKey('font'), isFalse);

    const comp = Composition(family: DesignFamily.singleHero, outlineRings: [
      OutlineRing(width: 0.3, colour: '#111111'),
      OutlineRing(width: 0.9),
    ]);
    final c2 = Composition.fromJson(comp.toJson());
    expect(c2.outlineRings.map((r) => r.toJson()), comp.outlineRings.map((r) => r.toJson()));
    expect(const Composition(family: DesignFamily.singleHero).toJson().containsKey('outlineRings'),
        isFalse);
    expect(
        () => Composition.fromJson({
              ...comp.toJson(),
              'outlineRings': [
                {'width': 1, 'colour': 'red'},
              ],
            }),
        throwsFormatException);
  });
}
