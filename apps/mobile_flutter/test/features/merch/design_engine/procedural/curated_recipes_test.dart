import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import 'package:mobile_flutter/features/merch/design_engine/procedural/curated_recipes.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

List<dynamic> _ex(DesignContext ctx) =>
    curatedExemplars(ctx, 1, engineVersion: 'x', grammarVersion: 'x');

void main() {
  const gen = ProceduralDesignGenerator();

  DesignContext single(String cc) => DesignContext.of(
      scope: DesignScope.singleCountry, countryCodes: [cc]);
  DesignContext multi(List<String> cs) => DesignContext.of(
      scope: DesignScope.multiCountry, countryCodes: cs);

  test('every curated exemplar is valid + printable in its context', () {
    final contexts = <DesignContext>[
      single('us'),
      multi(const ['au', 'jp']),
      multi(const ['fr', 'de', 'it', 'es', 'gr', 'pt']),
      multi(const ['fr', 'de', 'it', 'es', 'gr', 'pt', 'th', 'vn', 'au', 'nz', 'mx', 'ca', 'gb', 'ie', 'nl', 'be']),
    ];
    for (final ctx in contexts) {
      final ex = _ex(ctx);
      expect(ex, isNotEmpty, reason: 'no exemplars for $ctx');
      for (final r in ex.cast<ProceduralDesignRecipe>()) {
        expect(r.generator, 'curated');
        expect(validateRecipe(r, ctx), isNull, reason: '${r.family}');
        expect(r.toDesignParams().isValid, isTrue);
      }
    }
  });

  test('single-country offers torn + country-outline exemplars', () {
    final ex = _ex(single('us')).cast<ProceduralDesignRecipe>();
    expect(ex.any((r) => r.printStyle.name == 'edgeTear'), isTrue); // torn
    expect(ex.any((r) => r.mask == GridClipShape.countryOutline), isTrue);
  });

  test('two-country offers a merged dual-heritage exemplar', () {
    final ex = _ex(multi(const ['au', 'jp'])).cast<ProceduralDesignRecipe>();
    expect(ex.any((r) => r.isMerged && r.countryCount == 2), isTrue);
  });

  test('several/large offer heart + mosaic exemplars', () {
    final heart = _ex(multi(const ['fr', 'de', 'it', 'es', 'gr', 'pt']))
        .cast<ProceduralDesignRecipe>();
    expect(heart.any((r) => r.mask == GridClipShape.heart), isTrue);

    final mosaic = _ex(multi(const ['fr', 'de', 'it', 'es', 'gr', 'pt', 'th', 'vn', 'au', 'nz', 'mx', 'ca', 'gb', 'ie', 'nl', 'be']))
        .cast<ProceduralDesignRecipe>();
    expect(mosaic.any((r) => r.layoutMode == FlagGridLayoutMode.treemap),
        isTrue);
  });

  test('the generator surfaces curated exemplars', () {
    for (final ctx in [single('us'), multi(const ['au', 'jp'])]) {
      var found = false;
      for (var s = 0; s < 30 && !found; s++) {
        for (final d in gen.generate(ctx, seed: s, count: 8).designs) {
          if (d.recipe.generator == 'curated') found = true;
        }
      }
      expect(found, isTrue, reason: 'no curated exemplar surfaced for $ctx');
    }
  });
}
