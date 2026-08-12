import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart'
    show GridClipShape;
import 'package:mobile_flutter/features/merch/print_style/print_style.dart'
    show PrintStyleId;
import 'package:mobile_flutter/features/merch/design_engine/procedural/curated_recipes.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

void main() {
  const gen = ProceduralDesignGenerator();

  test('curated exemplars are valid, printable single-country torn flags', () {
    final ctx = DesignContext.of(
        scope: DesignScope.singleCountry, countryCodes: const ['us']);
    final ex =
        curatedExemplars(ctx, 1, engineVersion: 'x', grammarVersion: 'x');
    expect(ex, isNotEmpty);
    for (final r in ex) {
      expect(r.countryCount, 1);
      expect(r.mask, GridClipShape.none);
      expect(
          const [PrintStyleId.edgeTear, PrintStyleId.grunge], contains(r.printStyle));
      expect(r.generator, 'curated');
      expect(validateRecipe(r, ctx), isNull);
      expect(r.toDesignParams().isValid, isTrue);
    }
  });

  test('no curated exemplars for multi-country contexts', () {
    final ctx = DesignContext.of(
        scope: DesignScope.multiCountry, countryCodes: const ['au', 'jp']);
    expect(curatedExemplars(ctx, 1, engineVersion: 'x', grammarVersion: 'x'),
        isEmpty);
  });

  test('the generator surfaces a curated exemplar for single-country', () {
    final ctx = DesignContext.of(
        scope: DesignScope.singleCountry, countryCodes: const ['us']);
    var found = false;
    for (var s = 0; s < 30 && !found; s++) {
      for (final d in gen.generate(ctx, seed: s, count: 8).designs) {
        if (d.recipe.generator == 'curated') found = true;
      }
    }
    expect(found, isTrue);
  });
}
