import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart'
    show GridClipShape;
import 'package:mobile_flutter/features/merch/bundled_silhouette_manifest.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

void main() {
  const gen = ProceduralDesignGenerator();

  test('a single-country design can emit a bundled animal-silhouette clip', () {
    // Australia has a bundled silhouette (kangaroo).
    final ctx = DesignContext.of(
        scope: DesignScope.singleCountry, countryCodes: const ['au']);
    ProceduralDesignRecipe? sil;
    for (var s = 0; s < 60 && sil == null; s++) {
      for (final d in gen.generate(ctx, seed: s, count: 16).designs) {
        if (d.recipe.mask == GridClipShape.animalSilhouette) sil = d.recipe;
      }
    }
    expect(sil, isNotNull, reason: 'expected an animal-silhouette clip for AU');
    expect(sil!.maskCode, 'AU|${kBundledSilhouetteSlugs['AU']}');
    expect(sil.toDesignParams().isValid, isTrue);
  });

  test('every emitted silhouette clip is backed by the local manifest', () {
    for (final cc in const ['au', 'jp', 'ke', 'br', 'fr', 'us', 'in', 'za']) {
      final ctx = DesignContext.of(
          scope: DesignScope.singleCountry, countryCodes: [cc]);
      for (var s = 0; s < 20; s++) {
        for (final d in gen.generate(ctx, seed: s, count: 16).designs) {
          if (d.recipe.mask == GridClipShape.animalSilhouette) {
            final upper = cc.toUpperCase();
            // Only ever emitted for a manifest-backed country…
            expect(kBundledSilhouetteSlugs.containsKey(upper), isTrue);
            // …with a valid composite "CC|slug" code.
            expect(d.recipe.maskCode, '$upper|${kBundledSilhouetteSlugs[upper]}');
            expect(d.recipe.toDesignParams().isValid, isTrue);
          }
        }
      }
    }
  });

  test('never emits silhouette clips for multi-country sets', () {
    final ctx = DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['au', 'jp', 'fr']);
    for (var s = 0; s < 30; s++) {
      for (final d in gen.generate(ctx, seed: s, count: 16).designs) {
        expect(d.recipe.mask, isNot(GridClipShape.animalSilhouette));
      }
    }
  });
}
