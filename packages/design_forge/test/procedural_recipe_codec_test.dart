import 'dart:convert';
import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

Map<String, Object?> _loadAnchor(String name) {
  // package cwd is packages/design_forge during `dart test`.
  final file = File('../../design_studio/recipes/$name');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

void main() {
  group('ProceduralRecipeCodec.fromFlatJson (studio anchor import)', () {
    test('torn_flag_usa anchor maps to the expected DesignRecipe', () {
      final json = _loadAnchor('torn_flag_usa.recipe.json');
      final r = ProceduralRecipeCodec.fromFlatJson(json);

      expect(r.seed, 424242);
      expect(r.content.flags.single.code, 'us');
      expect(r.content.source, 'singleCountry');
      expect(r.composition.family, DesignFamily.singleHero);
      expect(r.composition.orientation, Orientation.landscape); // isPortrait:false
      expect(r.composition.rowCount, 1);

      // mask 'none' => no clip.
      expect(r.clip, isNull);
      // combination 'none' => no flag combination.
      expect(r.flagCombination, isNull);

      // printStyle edgeTear => an EdgeTreatment is synthesised.
      expect(r.edgeTreatment, isNotNull);

      // continuous treatment genes carried into Effects.
      expect(r.effects, isNotNull);
      expect(r.effects!.distress, closeTo(0.45, 1e-9));
      expect(r.effects!.grain, closeTo(0.22, 1e-9));
      expect(r.effects!.fade, closeTo(0.12, 1e-9));

      expect(r.palette?.garmentColour, 'White');

      // Original id preserved for traceability; new id recomputed under schema.
      expect(r.provenance?.parentRecipeIds, ['curated:torn_flag_usa']);
      expect(r.recipeId, isNot('curated:torn_flag_usa'));
    });

    test('imported recipe re-serialises and round-trips under the new schema', () {
      final json = _loadAnchor('torn_flag_usa.recipe.json');
      final r = ProceduralRecipeCodec.fromFlatJson(json);
      final again = DesignRecipe.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect(again.recipeId, r.recipeId);
    });

    test('all three curated anchors import without error', () {
      for (final name in const [
        'torn_flag_usa.recipe.json',
        'torn_flag_mono.recipe.json',
        'ripped_flag.recipe.json',
      ]) {
        final file = File('../../design_studio/recipes/$name');
        if (!file.existsSync()) continue; // tolerate missing optional anchors
        final json =
            (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
        final r = ProceduralRecipeCodec.fromFlatJson(json);
        expect(r.content.flags, isNotEmpty, reason: name);
        expect(r.recipeId, isNotEmpty, reason: name);
      }
    });
  });
}
