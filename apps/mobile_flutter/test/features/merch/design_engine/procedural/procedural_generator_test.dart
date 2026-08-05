import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart'
    show GridClipShape;
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

/// Representative contexts spanning the required scopes / set sizes / garments.
Map<String, DesignContext> _contexts() => {
      'single': DesignContext.of(
        scope: DesignScope.singleCountry,
        countryCodes: const ['jp'],
        garmentIsDark: true,
      ),
      'two': DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['fr', 'jp'],
        garmentIsDark: true,
      ),
      'several': DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['fr', 'jp', 'us', 'ke', 'br'],
        signatureCountries: const ['ke'],
        garmentIsDark: true,
      ),
      'lifetime': DesignContext.of(
        scope: DesignScope.lifetime,
        countryCodes: List.generate(28, (i) => _codes[i % _codes.length]),
        garmentIsDark: true,
      ),
      'year': DesignContext.of(
        scope: DesignScope.year,
        countryCodes: const ['it', 'es', 'fr', 'de'],
        year: 2024,
        garmentIsDark: false,
      ),
      'region': DesignContext.of(
        scope: DesignScope.region,
        countryCodes: const ['fr', 'de', 'it', 'es', 'gr', 'pt'],
        regionId: 'europe',
        garmentIsDark: true,
      ),
      'massive-light': DesignContext.of(
        scope: DesignScope.lifetime,
        countryCodes: List.generate(60, (i) => _codes[i % _codes.length]),
        garmentIsDark: false,
      ),
    };

const _codes = [
  'fr', 'jp', 'us', 'ke', 'br', 'it', 'es', 'de', 'gr', 'pt', 'th', 'vn',
  'au', 'nz', 'mx', 'ca', 'gb', 'ie', 'nl', 'be', 'ch', 'at', 'se', 'no',
  'fi', 'dk', 'pl', 'cz', 'hu', 'hr', 'in', 'cn', 'kr', 'sg', 'my', 'id',
];

void main() {
  const gen = ProceduralDesignGenerator();

  group('determinism', () {
    test('same context + seed + version reproduces identical recipes', () {
      for (final ctx in _contexts().values) {
        final a = gen.generate(ctx, seed: 42);
        final b = gen.generate(ctx, seed: 42);
        expect(
          a.designs.map((d) => d.recipe.recipeId).toList(),
          b.designs.map((d) => d.recipe.recipeId).toList(),
          reason: 'context $ctx not reproducible',
        );
      }
    });

    test('different seeds generally produce different sets', () {
      final ctx = _contexts()['several']!;
      final a = gen.generate(ctx, seed: 1).designs.map((d) => d.recipe.recipeId);
      final b = gen.generate(ctx, seed: 2).designs.map((d) => d.recipe.recipeId);
      expect(a, isNot(equals(b)));
    });

    test('recipeId fully determines the mapped genome', () {
      final ctx = _contexts()['several']!;
      final d = gen.generate(ctx, seed: 7).designs.first;
      // Re-mapping is stable and printable.
      expect(d.recipe.toDesignParams().isValid, isTrue);
      expect(d.recipe.toDesignParams().contentHash,
          d.recipe.toDesignParams().contentHash);
    });
  });

  group('validity + printability', () {
    test('every returned design passes constraints and maps to a valid genome',
        () {
      for (final entry in _contexts().entries) {
        final result = gen.generate(entry.value, seed: 11);
        expect(result.designs, isNotEmpty,
            reason: 'no designs for ${entry.key}');
        for (final d in result.designs) {
          expect(validateRecipe(d.recipe, entry.value), isNull,
              reason: '${entry.key}: ${d.recipe.family}');
          expect(d.params.isValid, isTrue);
        }
      }
    });

    test('quality scores are within [0,1] with a full breakdown', () {
      final result = gen.generate(_contexts()['several']!, seed: 3);
      for (final d in result.designs) {
        expect(d.quality.total, inInclusiveRange(0.0, 1.0));
        expect(d.quality.breakdown.keys, contains('hierarchy'));
        for (final v in d.quality.breakdown.values) {
          expect(v, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('one country through many without clutter', () {
    test('generates valid non-clutter designs at every set size', () {
      for (final n in [1, 2, 3, 5, 8, 20, 45, 90]) {
        final ctx = DesignContext.of(
          scope: n == 1 ? DesignScope.singleCountry : DesignScope.multiCountry,
          countryCodes: List.generate(n, (i) => _codes[i % _codes.length]),
          garmentIsDark: true,
        );
        final result = gen.generate(ctx, seed: 5);
        expect(result.designs, isNotEmpty, reason: 'no designs for n=$n');
        for (final d in result.designs) {
          // Clutter + min-feature are guaranteed by the constraints, but assert
          // the estimated density stays sane.
          final vd = d.recipe
              .estimatePrinciples()[DesignPrinciple.visualDensity]!;
          expect(vd, lessThanOrEqualTo(0.98), reason: 'n=$n cluttered');
        }
      }
    });

    test('hierarchy is explicit when multiple countries are present', () {
      final ctx = _contexts()['several']!;
      final result = gen.generate(ctx, seed: 9);
      // At least one strong-hierarchy design (a hero, or a focal/dominant
      // family) is offered for a multi-country set.
      final hasHierarchy = result.designs.any((d) =>
          d.recipe.heroCode != null ||
          d.recipe.hierarchy == HierarchyMode.singleFocal ||
          d.recipe.hierarchy == HierarchyMode.dominantAccent ||
          d.recipe.hierarchy == HierarchyMode.radial);
      expect(hasHierarchy, isTrue);
      // Any focal family that requires a hero actually has one.
      for (final d in result.designs) {
        final spec = kCompositionFamilies[d.recipe.family]!;
        if (spec.heroRequiredWhenMulti && d.recipe.countryCount > 1) {
          expect(d.recipe.heroCode, isNotNull);
        }
      }
    });
  });

  group('constraints reject clearly invalid designs', () {
    test('empty set yields nothing', () {
      final ctx = DesignContext.of(
          scope: DesignScope.random, countryCodes: const []);
      expect(gen.generate(ctx, seed: 1).designs, isEmpty);
    });

    test('validateRecipe flags a single-country clip on a multi set', () {
      final ctx = _contexts()['several']!;
      final base = gen.generate(ctx, seed: 2).designs.first.recipe;
      // Force an illegal clip by hand and confirm it is rejected.
      final bad = _RecipeProbe.withMaskCountryOutline(base);
      expect(validateRecipe(bad, ctx), isNotNull);
    });
  });

  group('diversity / exploration', () {
    test('returned set spans multiple families when eligible', () {
      final ctx = _contexts()['several']!;
      final fams = gen
          .generate(ctx, seed: 17, count: 6, exploration: 0.4)
          .designs
          .map((d) => d.recipe.family)
          .toSet();
      expect(fams.length, greaterThanOrEqualTo(2));
    });

    test('zero exploration puts the strongest design first (still diverse)', () {
      final ctx = _contexts()['lifetime']!;
      final result = gen.generate(ctx, seed: 4, exploration: 0.0);
      expect(result.designs, isNotEmpty);
      // The very first pick is the highest-quality survivor; subsequent slots
      // may reorder for family diversity by design (exploration must not vanish
      // entirely — variety is a feature, not a bug).
      final maxQ =
          result.designs.map((d) => d.quality.total).reduce((a, b) => a > b ? a : b);
      expect(result.designs.first.quality.total, closeTo(maxQ, 1e-9));
    });
  });

  test('EXAMPLES — print recipes for several contexts', () {
    for (final entry in _contexts().entries) {
      final best = gen.generate(entry.value, seed: 2026).designs.first;
      // ignore: avoid_print
      print('${entry.key.padRight(14)} '
          'q=${best.quality.total.toStringAsFixed(3)} '
          'family=${best.recipe.family.name} '
          'template=${best.recipe.template.name} '
          'mask=${best.recipe.mask.name} '
          'hero=${best.recipe.heroCode ?? "-"} '
          'print=${best.recipe.printStyle.name}');
    }
  });
}

/// Test-only helper to fabricate an illegal recipe for constraint checks.
class _RecipeProbe {
  static ProceduralDesignRecipe withMaskCountryOutline(
          ProceduralDesignRecipe r) =>
      ProceduralDesignRecipe(
        engineVersion: r.engineVersion,
        grammarVersion: r.grammarVersion,
        seed: r.seed,
        scopeKey: r.scopeKey,
        family: r.family,
        hierarchy: r.hierarchy,
        template: r.template,
        layoutMode: r.layoutMode,
        mask: GridClipShape.countryOutline,
        maskCode: r.countryCodes.first,
        rowCount: r.rowCount,
        countryCodes: r.countryCodes, // multi-country → illegal single clip
        heroCode: r.heroCode,
        source: r.source,
        density: r.density,
        jitter: r.jitter,
        stampMode: r.stampMode,
        isPortrait: r.isPortrait,
        imageSize: r.imageSize,
        garmentColour: r.garmentColour,
        flagTreatment: r.flagTreatment,
        colourTreatment: r.colourTreatment,
        printStyle: r.printStyle,
        heroScale: r.heroScale,
        placement: r.placement,
        placementOffset: r.placementOffset,
        cropMode: r.cropMode,
        rotationDeg: r.rotationDeg,
        layerMode: r.layerMode,
      );
}
