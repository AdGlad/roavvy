import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/lab_generator.dart';
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

void main() {
  const gen = LabShowcaseGenerator();
  const sc = DesignContext(flagCodes: ['sc'], scopeKey: 'lab:sc');
  const grid =
      DesignContext(flagCodes: ['us', 'gb', 'jp', 'br'], scopeKey: 'lab:grid');
  final base = gen.generate(sc, seed: 7).single;
  final gridBase = gen.generate(grid, seed: 3).single;

  group('determinism preserved (task 3)', () {
    // Golden recipeIds captured from the pre-M2 generator (single shared seed).
    // With an empty axisSeeds map the refactored generator MUST reproduce them.
    test('empty axisSeeds reproduces the exact pre-M2 output', () {
      const duo = DesignContext(flagCodes: ['jp', 'fr'], scopeKey: 'lab:duo');
      const golden = {
        'SINGLE 1': '6f6c433211770c6c',
        'SINGLE 2': '5e7bacaafb6f6132',
        'SINGLE 3': '676a5860978621be',
        'SINGLE 7': '1f0ee50d04abb3a9',
        'SINGLE 42': '394d94da2e2ca4f6',
        'DUO 1': '6e5b904c03ecdb25',
        'DUO 2': '26b585a87b970b1d',
        'DUO 5': '2d2f38c221c77199',
        'GRID 1': '3e0c545ce353bc1c',
        'GRID 4': '321fdb5fc4d149fc',
      };
      String id(DesignContext c, int s) => gen.generate(c, seed: s).single.recipeId;
      expect(id(sc, 1), golden['SINGLE 1']);
      expect(id(sc, 2), golden['SINGLE 2']);
      expect(id(sc, 3), golden['SINGLE 3']);
      expect(id(sc, 7), golden['SINGLE 7']);
      expect(id(sc, 42), golden['SINGLE 42']);
      expect(id(duo, 1), golden['DUO 1']);
      expect(id(duo, 2), golden['DUO 2']);
      expect(id(duo, 5), golden['DUO 5']);
      expect(id(grid, 1), golden['GRID 1']);
      expect(id(grid, 4), golden['GRID 4']);
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
