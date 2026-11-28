import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

/// A minimal two-flag pack (test only; real pair packs arrive in M209).
Map<String, Object?> _pairBase() {
  final r = DesignRecipe(
    seed: 1,
    content: RecipeContent(flags: [FlagRef('us'), FlagRef('co')]),
    composition: const Composition(
      family: DesignFamily.duoBlend,
      orientation: Orientation.portrait,
    ),
  );
  final json = r.toJson()
    ..remove('recipeId')
    ..remove('provenance');
  RecipePath('content.flags.0.code').write(json, '{{countryA}}');
  RecipePath('content.flags.1.code').write(json, '{{countryB}}');
  return json;
}

SignatureRecipe _pair({
  Map<String, CountryOverride> overrides = const {},
  Map<String, Map<String, Object?>> heroes = const {},
  Map<String, String> locks = const {},
  List<String> samplePairs = const ['us+co', 'fr+it'],
}) =>
    SignatureRecipe(
      id: 'test_pair',
      title: 'Test Pair',
      version: 1,
      status: SignatureStatus.draft,
      base: _pairBase(),
      countries: 2,
      samplePairs: samplePairs,
      envelope: VariationEnvelope({
        'seed': const NumRange(1, 1000000, integer: true),
        'content.flags.0.weight': const NumRange(0.5, 1.0),
        'content.flags.1.weight': const NumRange(0.5, 1.0),
      }),
      overrides: overrides,
      heroes: heroes,
      locks: locks,
    );

void main() {
  group('SignaturePair', () {
    test('parses, lower-cases and keeps order', () {
      final p = SignaturePair.parse('US+Co');
      expect(p.a, 'us');
      expect(p.b, 'co');
      expect(p.key, 'us+co');
      expect(p.swapped.key, 'co+us');
      expect(p, SignaturePair('us', 'co'));
      expect(p == p.swapped, isFalse);
    });

    test('rejects malformed and same-country pairs', () {
      expect(() => SignaturePair.parse('us'), throwsFormatException);
      expect(() => SignaturePair.parse('us+co+fr'), throwsFormatException);
      expect(() => SignaturePair('us', 'US'), throwsFormatException);
    });
  });

  group('pair pack', () {
    test('fills A/B tokens (code, alpha-3, name)', () {
      final base = _pairBase();
      (base['content'] as Map<String, Object?>)['source'] =
          '{{countryAName}}|{{countryA3}}|{{countryBName}}|{{countryB3}}';
      final s = SignatureRecipe(
          id: 'x',
          title: 'x',
          version: 1,
          status: SignatureStatus.draft,
          base: base,
          countries: 2);
      final json = s.instantiatePair('gr', 'cr');
      expect(
          RecipePath('content.source').read(json), 'Greece|GRC|Costa Rica|CRI');
      expect(RecipePath('content.flags.0.code').read(json), 'gr');
      expect(RecipePath('content.flags.1.code').read(json), 'cr');
      expect(s.isPair, isTrue);
      expect(s.firstPair.key, 'us+co');
    });

    test('must use both countries and never {{country}}', () {
      final onlyA = _pairBase();
      RecipePath('content.flags.1.code').write(onlyA, 'jp');
      expect(
          () => SignatureRecipe(
              id: 'x',
              title: 'x',
              version: 1,
              status: SignatureStatus.draft,
              base: onlyA,
              countries: 2),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('{{countryB}}'))));

      final mixed = _pairBase();
      RecipePath('content.flags.1.code').write(mixed, '{{country}}');
      expect(
          () => SignatureRecipe(
              id: 'x',
              title: 'x',
              version: 1,
              status: SignatureStatus.draft,
              base: mixed,
              countries: 2),
          throwsFormatException);
    });

    test('a single pack may not use pair tokens, pair keys or samplePairs', () {
      expect(
          () => SignatureRecipe(
              id: 'x',
              title: 'x',
              version: 1,
              status: SignatureStatus.draft,
              base: _pairBase()),
          throwsFormatException);
      final single = _pairBase();
      RecipePath('content.flags.0.code').write(single, '{{country}}');
      RecipePath('content.flags.1.code').write(single, 'jp');
      SignatureRecipe make({
        Map<String, String> locks = const {},
        List<String> samplePairs = const [],
      }) =>
          SignatureRecipe(
              id: 'x',
              title: 'x',
              version: 1,
              status: SignatureStatus.draft,
              base: single,
              locks: locks,
              samplePairs: samplePairs);
      expect(make, returnsNormally);
      expect(() => make(locks: {'us+co': 'abc'}), throwsFormatException);
      expect(() => make(samplePairs: ['us+co']), throwsFormatException);
    });

    test('heroes and locks must be keyed by pair', () {
      expect(() => _pair(locks: {'us': 'abc'}), throwsFormatException);
      expect(
          () => _pair(heroes: {
                'us': {'seed': 3}
              }),
          throwsFormatException);
      expect(
          () => _pair(heroes: {
                'us+co': {'seed': 3}
              }),
          returnsNormally);
    });

    test('countries must be 1 or 2', () {
      expect(
          () => SignatureRecipe(
              id: 'x',
              title: 'x',
              version: 1,
              status: SignatureStatus.draft,
              base: _pairBase(),
              countries: 3),
          throwsFormatException);
    });
  });

  group('resolver', () {
    test('hero/variation are deterministic and order matters', () {
      final s = _pair();
      final ab = SignatureResolver.variationPair(s, 'fr', 'jp', 3);
      expect(SignatureResolver.variationPair(s, 'fr', 'jp', 3).recipeId,
          ab.recipeId);
      final ba = SignatureResolver.variationPair(s, 'jp', 'fr', 3);
      expect(ba.recipeId, isNot(ab.recipeId));
      expect(ab.content.flags.map((f) => f.code), ['fr', 'jp']);
      expect(ba.content.flags.map((f) => f.code), ['jp', 'fr']);
      expect(SignatureResolver.heroPair(s, 'fr', 'jp').recipeId,
          SignatureResolver.variationPair(s, 'fr', 'jp', 0).recipeId);
      expect(SignatureResolver.heroFor(s, 'FR+JP').recipeId,
          SignatureResolver.heroPair(s, 'fr', 'jp').recipeId);
    });

    test('seed key is id|version|a+b|i', () {
      final s = _pair();
      final v = SignatureResolver.variationPair(s, 'fr', 'jp', 2);
      final seed = DeterministicRng.hashString('test_pair|1|fr+jp|2');
      final expected = (s.envelope.ranges['seed']!)
          .sample(DeterministicRng.stream(seed, 'seed'));
      expect(v.seed, expected);
    });

    test('single-country entry points refuse a pair pack and vice versa', () {
      expect(() => SignatureResolver.hero(_pair(), 'us'), throwsStateError);
      final single = SignaturePackCodec.draftFromRecipe(
        id: 'one',
        title: 'One',
        recipe: DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(
              family: DesignFamily.singleHero,
              orientation: Orientation.portrait),
        ),
      );
      expect(() => SignatureResolver.heroPair(single, 'us', 'co'),
          throwsStateError);
      expect(SignatureResolver.heroFor(single, 'us').recipeId,
          SignatureResolver.hero(single, 'us').recipeId);
    });

    test('a country override applies to the slot that country is in', () {
      final s = _pair(overrides: {
        'jp': CountryOverride(
            params: {'content.flags.{slot}.weight': 0.6},
            reason: 'Red disc vanishes'),
      });
      final a = SignatureResolver.variationPair(s, 'jp', 'fr', 5);
      expect(a.content.flags[0].weight, 0.6);
      final b = SignatureResolver.variationPair(s, 'fr', 'jp', 5);
      expect(b.content.flags[1].weight, 0.6);
      expect(b.content.flags[0].weight, isNot(0.6),
          reason: 'the other half still varies');
    });

    test('a pair override applies on top of country overrides', () {
      final s = _pair(overrides: {
        'jp': CountryOverride(
            params: {'content.flags.{slot}.weight': 0.6}, reason: 'disc'),
        'fr+jp': CountryOverride(
            params: {'content.flags.1.weight': 0.9}, reason: 'clash'),
      });
      expect(SignatureResolver.heroPair(s, 'fr', 'jp').content.flags[1].weight,
          0.9);
      expect(SignatureResolver.heroPair(s, 'jp', 'fr').content.flags[0].weight,
          0.6);
    });

    test('{slot} is refused outside a country override of a pair pack', () {
      expect(
          () => _pair(overrides: {
                'fr+jp': CountryOverride(
                    params: {'content.flags.{slot}.weight': 0.9}, reason: 'x'),
              }),
          throwsFormatException);
    });

    test('locks are keyed by pair and catch drift', () {
      final s = _pair();
      final locked =
          s.copyWith(locks: SignatureResolver.lockFor(s, ['US+CO', 'fr+it']));
      expect(locked.locks.keys, unorderedEquals(['us+co', 'fr+it']));
      expect(SignatureResolver.driftedLocks(locked), isEmpty);
      final drifted = locked.copyWith(locks: {...locked.locks, 'us+co': 'x'});
      expect(SignatureResolver.driftedLocks(drifted), ['us+co']);
    });
  });

  group('codec', () {
    test('round-trips countries and samplePairs', () {
      final s = _pair(locks: {'us+co': 'abc'});
      final text = SignaturePackCodec.encode(s);
      expect(text, contains('"countries": 2'));
      expect(text, contains('"samplePairs"'));
      final back = SignaturePackCodec.decode(text);
      expect(back.countries, 2);
      expect(back.samplePairs, ['us+co', 'fr+it']);
      expect(SignaturePackCodec.encode(back), text);
    });

    test('single packs do not gain the new fields', () {
      final single = SignaturePackCodec.draftFromRecipe(
        id: 'one',
        title: 'One',
        recipe: DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(
              family: DesignFamily.singleHero,
              orientation: Orientation.portrait),
        ),
      );
      final text = SignaturePackCodec.encode(single);
      expect(text, isNot(contains('countries')));
      expect(text, isNot(contains('samplePairs')));
    });

    test('every bundled pack is byte-identical and keeps its locks', () {
      final dir = Directory('../design_studio/assets/signature');
      final packs = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pack.json'))
          .toList();
      expect(packs, isNotEmpty);
      for (final f in packs) {
        final text = f.readAsStringSync();
        final s = SignaturePackCodec.decode(text);
        // (Pair packs ship from M210 on; they are held to the same rule.)
        expect(SignaturePackCodec.encode(s), text, reason: f.path);
        expect(SignatureResolver.driftedLocks(s), isEmpty, reason: f.path);
      }
    });
  });

  group('FlagFocus', () {
    test('covers every known flag with sane values', () {
      for (final code in FlagFocus.knownCodes) {
        final f = FlagFocus.of(code);
        expect(f.focusX, inInclusiveRange(0, 1), reason: code);
        expect(f.focusY, inInclusiveRange(0, 1), reason: code);
        final e = f.emblem;
        if (e != null) {
          expect(e.left, greaterThanOrEqualTo(0), reason: code);
          expect(e.top, greaterThanOrEqualTo(0), reason: code);
          expect(e.right, lessThanOrEqualTo(1.0001), reason: code);
          expect(e.bottom, lessThanOrEqualTo(1.0001), reason: code);
          expect(e.area, greaterThan(0), reason: code);
          expect(e.contains(f.focusX, f.focusY), isTrue, reason: code);
        }
      }
    });

    test('only known codes are tuned', () {
      final known = FlagFocus.knownCodes.toSet();
      for (final c in FlagFocus.tunedCodes) {
        expect(known, contains(c));
      }
    });

    test('cantons, hoist emblems and central emblems', () {
      expect(FlagFocus.of('US').kind, FlagFocusKind.canton);
      expect(FlagFocus.of('us').focusX, lessThan(0.3));
      expect(FlagFocus.of('pt').kind, FlagFocusKind.hoist);
      expect(FlagFocus.of('mx').kind, FlagFocusKind.emblem);
      expect(FlagFocus.of('fr'), FlagFocus.plain);
      expect(FlagFocus.of('zz'), FlagFocus.plain);
    });

    test('half windows keep the focus; visible fraction', () {
      final us = FlagFocus.of('us');
      expect(us.windowLeft(0.5), 0, reason: 'canton crop stays at the hoist');
      expect(FlagFocus.plain.windowLeft(0.5), 0.25);
      expect(FlagFocus.of('pk').windowLeft(0.5), greaterThan(0.25));
      expect(us.visibleFraction(FlagBox.full), 1);
      expect(us.visibleFraction(const FlagBox(0.5, 0, 0.5, 1)), 0);
      expect(us.visibleFraction(const FlagBox(0.2, 0, 0.8, 1)),
          closeTo(0.5, 1e-9));
      expect(FlagFocus.plain.visibleFraction(const FlagBox(0, 0, 0.1, 0.1)), 1);
    });
  });

  group('PairGeometry', () {
    test('crop emblem visibility with box and polygon', () {
      const mxFull = FlagCrop(slot: 0, code: 'mx', visible: FlagBox.full);
      expect(mxFull.emblemVisible, 1);
      const mxHalf =
          FlagCrop(slot: 0, code: 'mx', visible: FlagBox(0, 0, 0.5, 1));
      expect(mxHalf.emblemVisible, closeTo(0.5, 1e-9));
      // Lower-left triangle of the flag: keeps under half the emblem.
      const tri = FlagCrop(
          slot: 1,
          code: 'mx',
          visible: FlagBox.full,
          polygon: [(0, 0), (0, 1), (1, 1)]);
      expect(tri.emblemVisible, inExclusiveRange(0.3, 0.7));
      const fr = FlagCrop(slot: 1, code: 'fr', visible: FlagBox(0, 0, 0.1, 1));
      expect(fr.emblemVisible, 1);
    });

    test('seam xAt interpolates', () {
      const s = PairSeam([(0.4, 0), (0.6, 1)]);
      expect(s.xAt(0.5), closeTo(0.5, 1e-9));
      expect(PairSeam.vertical(0.5).xAt(0.3), 0.5);
    });

    test('no current composition reports geometry', () {
      final r = SignatureResolver.heroPair(_pair(), 'us', 'co');
      expect(PairGeometry.of(r), isNull);
    });
  });
}
