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

  test('torn + ripped flag-hero exemplars default to text OFF', () {
    final ex = _ex(single('us')).cast<ProceduralDesignRecipe>();
    // Every torn/ripped flag-hero (edgeTear / rippedFlag) has no title/footer —
    // the reference torn tees carry no text.
    final tornOrRipped = ex.where((r) =>
        r.printStyle.name == 'edgeTear' || r.printStyle.name == 'rippedFlag');
    expect(tornOrRipped, isNotEmpty);
    for (final r in tornOrRipped) {
      expect(r.showTitle, isFalse, reason: '${r.printStyle.name} title');
      expect(r.showFooter, isFalse, reason: '${r.printStyle.name} footer');
    }
    // The souvenir country-outline design keeps its label.
    final outline =
        ex.firstWhere((r) => r.mask == GridClipShape.countryOutline);
    expect(outline.showTitle, isTrue);
    expect(outline.showFooter, isTrue);
  });

  test('title/footer toggles survive copyWith, JSON and recipe identity', () {
    final ex = _ex(single('us')).cast<ProceduralDesignRecipe>();
    final torn = ex.firstWhere((r) => r.printStyle.name == 'edgeTear');
    expect(torn.toJson()['showTitle'], false);
    expect(torn.toJson()['showFooter'], false);
    final shown = torn.copyWith(showTitle: true, showFooter: true);
    expect(shown.showTitle, isTrue);
    expect(shown.showFooter, isTrue);
    // Visibility is part of the recipe identity (distinct rendered result).
    expect(shown.recipeId, isNot(torn.recipeId));
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
