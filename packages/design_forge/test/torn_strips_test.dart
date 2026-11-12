import 'dart:convert';
import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('TornStrips', () {
    test('JSON round-trips every field', () {
      const p = TornStrips(
        rotateClockwise: false,
        mirror: true,
        margin: 0.1,
        flagAspect: 1.9,
        cutMode: TornStrips.cutsFringe,
        stripCount: 9,
        fringeCount: 5,
        fringeDepth: 0.5,
        spacingJitter: 0.4,
        gap: 0.3,
        widthWobble: 0.2,
        curvature: 0.7,
        waviness: 0.1,
        tearLength: 0.5,
        tearPoint: 0.2,
        tearJag: 0.9,
        topVariation: 0.3,
        blockWidth: 0.4,
        blockHeight: 0.3,
        blockTear: 0.8,
        edgeRoughness: 0.1,
        distress: 0.9,
        distressScale: 0.7,
        saturation: 1.2,
        vintage: 0.6,
        knockoutWhite: true,
      );
      final back = TornStrips.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
    });

    test('missing fields decode to the defaults', () {
      expect(TornStrips.fromJson(const {}).toJson(), const TornStrips().toJson());
    });
  });

  group('portrait_torn_flag recipe', () {
    test('survives a JSON round trip with the same recipeId', () {
      final r = portraitTornFlagRecipe(
          flagCode: 'US', seed: 42, params: const TornStrips(gap: 0.3));
      final back = DesignRecipe.fromJson(
          (jsonDecode(jsonEncode(r.toJson())) as Map).cast<String, Object?>());
      expect(back.recipeId, r.recipeId);
      expect(back.composition.family, DesignFamily.portraitTornFlag);
      expect(back.content.flags.single.code, 'us');
      expect(back.tornStrips!.gap, 0.3);
    });

    test('seed, flag and every parameter change the recipeId', () {
      final base = portraitTornFlagRecipe(flagCode: 'us', seed: 1);
      final ids = {
        base.recipeId,
        portraitTornFlagRecipe(flagCode: 'us', seed: 2).recipeId,
        portraitTornFlagRecipe(flagCode: 'sc', seed: 1).recipeId,
        portraitTornFlagRecipe(
                flagCode: 'us', seed: 1, params: const TornStrips(distress: 0.1))
            .recipeId,
      };
      expect(ids, hasLength(4));
    });

    test('adding the tornStrips group leaves other recipes\' ids untouched', () {
      // A recipe without the group hashes exactly as it did before the group
      // existed (the key is omitted when null).
      const r = DesignRecipe(
        seed: 1,
        content: RecipeContent(flags: [FlagRef('jp')]),
        composition: Composition(family: DesignFamily.singleHero),
      );
      expect(r.toJson().containsKey('tornStrips'), isFalse);
    });
  });

  group('TornFlagPreset', () {
    test('wrapper round-trips and reports a matching recipeId', () {
      final p = TornFlagPreset(
          name: 'Test',
          notes: 'n',
          recipe: portraitTornFlagRecipe(flagCode: 'us', seed: 7));
      final back = TornFlagPreset.fromJson(
          (jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
      expect(back.name, 'Test');
      expect(back.notes, 'n');
      expect(back.recipe.recipeId, p.recipe.recipeId);
      expect(back.recipeIdMatchesFile, isTrue);
    });

    test('accepts a bare recipe JSON', () {
      final r = portraitTornFlagRecipe(flagCode: 'sc', seed: 3);
      final p = TornFlagPreset.fromJson(r.toJson(), fallbackName: 'bare');
      expect(p.name, 'bare');
      expect(p.recipe.recipeId, r.recipeId);
    });

    test('flags a file whose stored recipeId no longer matches', () {
      final json = TornFlagPreset(
              name: 'x', recipe: portraitTornFlagRecipe(flagCode: 'us', seed: 1))
          .toJson();
      (json['recipe'] as Map)['recipeId'] = 'stale';
      expect(TornFlagPreset.fromJson(json).recipeIdMatchesFile, isFalse);
    });

    test('the committed presets load and match their stored recipeIds', () {
      final dir = Directory('../../design_studio/recipes/portrait_torn_flag');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.preset.json'))
          .toList();
      expect(files, isNotEmpty);
      for (final f in files) {
        final p = TornFlagPreset.fromJson(
            (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>());
        expect(p.recipe.composition.family, DesignFamily.portraitTornFlag,
            reason: f.path);
        expect(p.recipeIdMatchesFile, isTrue,
            reason: '${f.path}: engine defaults or hashing changed since it '
                'was saved — re-approve and re-save it');
      }
    });
  });
}
