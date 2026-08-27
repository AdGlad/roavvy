import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:design_lab/lab_styles.dart';
import 'package:flutter_test/flutter_test.dart';

// Canonical string views used to compare a single axis's fields for identity.
String _comp(DesignRecipe r) => jsonEncode(r.composition.toJson());
String _clip(DesignRecipe r) => jsonEncode(r.clip?.toJson());
String _combo(DesignRecipe r) => jsonEncode(r.flagCombination?.toJson());
String _content(DesignRecipe r) => jsonEncode(r.content.toJson());
String _vibe(DesignRecipe r) => jsonEncode([
      r.edgeTreatment?.toJson(),
      r.effects?.toJson(),
      r.palette?.toJson(),
    ]);

// Wave-2 axis views: palette (colour axis) and title+typography (words axis).
String _pal(DesignRecipe r) => jsonEncode(r.palette?.toJson());
String _fx(DesignRecipe r) => jsonEncode(r.effects?.toJson());
String _typo(DesignRecipe r) => jsonEncode(r.typography?.toJson());
Object? _title(DesignRecipe r) => r.content.meta['title'];

void main() {
  const gen = LabShowcaseGenerator();
  const sc = DesignContext(flagCodes: ['sc'], scopeKey: 'lab:sc');
  const grid =
      DesignContext(flagCodes: ['us', 'gb', 'jp', 'br'], scopeKey: 'lab:grid');
  final base = gen.generate(sc, seed: 7).single;
  final gridBase = gen.generate(grid, seed: 3).single;

  group('determinism preserved (task 3)', () {
    // Golden recipeIds for the current (wave-2) generator with an empty axisSeeds
    // map. Wave-2 moved the palette onto the colour axis and added garment colour
    // + titles/typography, which deliberately changed these ids from the pre-M2
    // values; the test's INTENT is unchanged: an untouched recipe reproduces the
    // current generation byte-for-byte across runs.
    test('empty axisSeeds reproduces the current generation deterministically',
        () {
      const duo = DesignContext(flagCodes: ['jp', 'fr'], scopeKey: 'lab:duo');
      const golden = {
        'SINGLE 1': '09802314fe0c4436',
        'SINGLE 2': '4cd3811931e0be04',
        'SINGLE 3': '42c4748f7e05fd7c',
        'SINGLE 7': '757488141b8045f0',
        'SINGLE 42': '4d179c70068ef894',
        'DUO 1': '6f9db780a6ee7557',
        'DUO 2': '51c5f330e7a4600b',
        'DUO 5': '77cfba584cf0bb7d',
        'GRID 1': '2b6b248f242916d2',
        'GRID 4': '145f31a1b4850630',
      };
      String id(DesignContext c, int s) => gen.generate(c, seed: s).single.recipeId;
      final actual = {
        'SINGLE 1': id(sc, 1),
        'SINGLE 2': id(sc, 2),
        'SINGLE 3': id(sc, 3),
        'SINGLE 7': id(sc, 7),
        'SINGLE 42': id(sc, 42),
        'DUO 1': id(duo, 1),
        'DUO 2': id(duo, 2),
        'DUO 5': id(duo, 5),
        'GRID 1': id(grid, 1),
        'GRID 4': id(grid, 4),
      };
      // One map comparison reports every mismatch at once (easy re-baselining).
      expect(actual, golden);
      // Generated recipes carry no per-axis seeds.
      expect(base.axisSeeds, isEmpty);
    });
  });

  group('single-axis reroll (task 5a)', () {
    test('re-rolling vibe leaves every non-vibe field byte-identical', () {
      final r = gen.reroll(base, DesignAxis.vibe, newSeed: 999);
      expect(_comp(r), _comp(base));
      expect(_clip(r), _clip(base));
      expect(_combo(r), _combo(base));
      expect(_content(r), _content(base));
      expect(r.seed, base.seed);
      expect(r.axisSeeds[DesignAxis.vibe.key], 999);
    });

    test('re-rolling direction leaves every non-direction field byte-identical',
        () {
      final r = gen.reroll(base, DesignAxis.direction, newSeed: 12345);
      // Vibe + composition-orientation belong to other axes → unchanged.
      expect(_vibe(r), _vibe(base));
      expect(r.composition.orientation, base.composition.orientation);
      expect(_combo(r), _combo(base));
      expect(_content(r), _content(base));
    });

    test('re-rolling focus leaves every non-focus field byte-identical', () {
      final r = gen.reroll(gridBase, DesignAxis.focus, newSeed: 4242);
      expect(_clip(r), _clip(gridBase));
      expect(_vibe(r), _vibe(gridBase));
      expect(_content(r), _content(gridBase));
    });
  });

  group('re-roll actually varies the target axis (task 5b)', () {
    test('vibe re-rolls vary the finish while non-vibe stays identical', () {
      final variants = [
        for (final s in [1, 2, 3, 4, 5, 6, 7, 8])
          gen.reroll(base, DesignAxis.vibe, newSeed: s),
      ];
      // The vibe finish takes more than one distinct value across seeds…
      expect(variants.map(_vibe).toSet().length, greaterThan(1));
      // …while direction + composition stay pinned to the base.
      for (final v in variants) {
        expect(_clip(v), _clip(base));
        expect(_comp(v), _comp(base));
      }
    });

    test('direction re-rolls vary the subject while other axes stay identical',
        () {
      final variants = [
        for (final s in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
          gen.reroll(base, DesignAxis.direction, newSeed: s),
      ];
      expect(variants.map(_clip).toSet().length, greaterThan(1));
      for (final v in variants) {
        expect(_vibe(v), _vibe(base));
        expect(v.composition.orientation, base.composition.orientation);
      }
    });

    test('focus re-rolls vary the composition while other axes stay identical',
        () {
      final variants = [
        for (final s in [1, 2, 3, 4, 5, 6, 7, 8])
          gen.reroll(gridBase, DesignAxis.focus, newSeed: s),
      ];
      expect(variants.map(_comp).toSet().length, greaterThan(1));
      for (final v in variants) {
        expect(_clip(v), _clip(gridBase));
        expect(_vibe(v), _vibe(gridBase));
      }
    });

    test('default (seedless) re-roll is reproducible for a given axis', () {
      expect(gen.reroll(base, DesignAxis.vibe).recipeId,
          gen.reroll(base, DesignAxis.vibe).recipeId);
    });
  });

  group('wave-2 colour axis (M5)', () {
    test('re-rolling colour changes ONLY the palette', () {
      final r = gen.reroll(base, DesignAxis.colour, newSeed: 999);
      // Everything except the palette is byte-identical.
      expect(_clip(r), _clip(base));
      expect(_comp(r), _comp(base));
      expect(_combo(r), _combo(base));
      expect(_content(r), _content(base)); // title lives here → unchanged
      expect(jsonEncode(r.edgeTreatment?.toJson()),
          jsonEncode(base.edgeTreatment?.toJson()));
      expect(_fx(r), _fx(base));
      expect(_typo(r), _typo(base));
      expect(r.axisSeeds[DesignAxis.colour.key], 999);
    });

    test('colour re-rolls vary the palette while other axes stay identical', () {
      final variants = [
        for (final s in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
          gen.reroll(base, DesignAxis.colour, newSeed: s),
      ];
      // The palette takes more than one distinct value across colour seeds…
      expect(variants.map(_pal).toSet().length, greaterThan(1));
      // …while clip / composition / effects / typography stay pinned to base.
      for (final v in variants) {
        expect(_clip(v), _clip(base));
        expect(_comp(v), _comp(base));
        expect(_fx(v), _fx(base));
        expect(_typo(v), _typo(base));
      }
    });

    test('a flag/shape design keeps a semantic (non-garmentAware) palette', () {
      // base is a single-flag (sc) design → flag-filled, not adaptive ink.
      expect(base.palette, isNotNull);
      expect(base.palette!.strategy, isNot(ColourStrategy.garmentAware));
    });
  });

  group('wave-2 words axis (M6)', () {
    final typoGen = LabShowcaseGenerator(
      genre: LabGenre.typography,
      countryNames: const {'sc': 'Seychelles'},
    );
    final typoBase = typoGen.generate(sc, seed: 7).single;

    test('a generated typographic design has a non-empty title + typography', () {
      expect(typoBase.clip?.shapeId, 'text');
      final title = typoBase.content.meta['title'];
      expect(title, isA<String>());
      expect((title! as String).isNotEmpty, isTrue);
      expect(typoBase.typography, isNotNull);
      expect(typoBase.typography!.placement, isNot(TextPlacement.none));
      // Text heroes are adaptive-ink → garmentAware so M5 re-inks them.
      expect(typoBase.palette?.strategy, ColourStrategy.garmentAware);
    });

    test('re-rolling words changes ONLY the title/typography', () {
      final r = typoGen.reroll(typoBase, DesignAxis.words, newSeed: 999);
      expect(_pal(r), _pal(typoBase));
      expect(_clip(r), _clip(typoBase));
      expect(r.composition.family, typoBase.composition.family);
      expect(_fx(r), _fx(typoBase));
      expect(r.axisSeeds[DesignAxis.words.key], 999);
    });

    test('words re-rolls vary the title/typography while other axes stay pinned',
        () {
      final variants = [
        for (final s in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
          typoGen.reroll(typoBase, DesignAxis.words, newSeed: s),
      ];
      // The title + typography take more than one distinct value across seeds…
      expect(
          variants.map((v) => '${_title(v)}|${_typo(v)}').toSet().length,
          greaterThan(1));
      // …while palette / clip / family stay pinned to base.
      for (final v in variants) {
        expect(_pal(v), _pal(typoBase));
        expect(_clip(v), _clip(typoBase));
        expect(v.composition.family, typoBase.composition.family);
      }
    });

    test('a multi-country design never uses a single country name as its title',
        () {
      // Titles must not name one country on a multi-country design (title rules).
      final multiGen = LabShowcaseGenerator(
        genre: LabGenre.typography,
        countryNames: const {'jp': 'Japan', 'fr': 'France'},
      );
      const duo = DesignContext(flagCodes: ['jp', 'fr'], scopeKey: 'lab:duo');
      for (var s = 1; s <= 30; s++) {
        final t = multiGen.generate(duo, seed: s).single.content.meta['title'];
        expect(t, isNot('JAPAN'));
        expect(t, isNot('FRANCE'));
      }
    });
  });

  group('lock semantics', () {
    test('locking the target axis makes reroll a no-op', () {
      final r = gen.reroll(base, DesignAxis.vibe,
          newSeed: 5, locked: {DesignAxis.vibe});
      expect(identical(r, base), isTrue);
    });

    test('rerollUnlocked holds locked axes byte-identical', () {
      final r = gen.rerollUnlocked(base,
          locked: {DesignAxis.direction, DesignAxis.focus});
      expect(_clip(r), _clip(base)); // direction locked
      expect(_comp(r), _comp(base)); // focus locked
      // At least one unlocked axis was re-rolled → new identity.
      expect(r.recipeId, isNot(base.recipeId));
    });
  });
}
