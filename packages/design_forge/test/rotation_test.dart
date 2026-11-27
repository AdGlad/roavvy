import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _recipe({int rotation = 0}) => DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('us')]),
      composition: Composition(
          family: DesignFamily.portraitTornFlag, rotation: rotation),
      tornStrips: const TornStrips(),
    );

void main() {
  test('rotation 0 is omitted, so existing recipeIds do not move', () {
    final r = _recipe();
    expect(r.composition.toJson().containsKey('rotation'), isFalse);
    final withExplicitZero = r.toJson()..remove('recipeId');
    (withExplicitZero['composition'] as Map)['rotation'] = 0;
    expect(DesignRecipe.fromJson(withExplicitZero).recipeId, r.recipeId);
  });

  test('quarter turns round-trip and change the recipeId', () {
    final ids = <String>{};
    for (final deg in Composition.rotations) {
      final r = _recipe(rotation: deg);
      final back = DesignRecipe.fromJson(r.toJson());
      expect(back.composition.rotation, deg);
      ids.add(r.recipeId);
    }
    expect(ids, hasLength(4));
  });

  test('anything but a quarter turn is refused', () {
    final json = _recipe().toJson();
    (json['composition'] as Map)['rotation'] = 45;
    expect(() => DesignRecipe.fromJson(json), throwsFormatException);
  });

  group('signature packs', () {
    final pack = SignaturePackCodec.draftFromRecipe(
        id: 'torn_flag', title: 'Torn Flag', recipe: _recipe());

    test('drafts list rotation so the Lab can edit it', () {
      expect(RecipePath('composition.rotation').read(pack.base), 0);
      expect(SignatureResolver.driftedLocks(pack), isEmpty);
    });

    test('a rotation range can vary between allowed turns', () {
      final p = pack.copyWith(
          envelope: VariationEnvelope({
        'composition.rotation': const ValueSet([0, 90]),
      }));
      final seen = {
        for (var i = 1; i <= 40; i++)
          SignatureResolver.variation(p, 'fr', i).composition.rotation,
      };
      expect(seen, {0, 90});
    });

    test('a range that allows a non-quarter turn is refused', () {
      expect(
        () => pack.copyWith(
            envelope: VariationEnvelope({
          'composition.rotation': const NumRange(0, 10, integer: true),
        })),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('rotation'))),
      );
    });
  });
}
