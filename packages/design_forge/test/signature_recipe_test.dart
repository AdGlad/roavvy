import 'dart:isolate';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _tornRecipe(String cc) => DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef(cc)]),
      composition: const Composition(
        family: DesignFamily.portraitTornFlag,
        orientation: Orientation.portrait,
      ),
      tornStrips: const TornStrips(),
    );

SignatureRecipe _draft() => SignaturePackCodec.draftFromRecipe(
      id: 'torn_flag',
      title: 'Torn Flag',
      recipe: _tornRecipe('us'),
    );

SignatureRecipe _withEnvelope() => _draft().copyWith(
      envelope: VariationEnvelope({
        'seed': const NumRange(1, 1000000, integer: true),
        'tornStrips.distress': const NumRange(0.55, 0.85),
        'tornStrips.mirror': const ValueSet([true, false]),
      }),
    );

void main() {
  group('RecipePath', () {
    final json = {
      'seed': 3,
      'content': {
        'flags': [
          {'code': 'us'},
        ],
      },
    };

    test('reads and writes leaves, including list indices', () {
      final copy = deepCopyJson(json) as Map<String, Object?>;
      expect(RecipePath('content.flags.0.code').read(copy), 'us');
      RecipePath('content.flags.0.code').write(copy, 'jp');
      expect(RecipePath('content.flags.0.code').read(copy), 'jp');
      expect(RecipePath('content.flags.0.code').read(json), 'us',
          reason: 'deepCopyJson must not share structure');
    });

    test('rejects missing fields, bad indices and non-leaves', () {
      expect(() => RecipePath('sed').read(json), throwsA(isA<RecipePathError>()));
      expect(() => RecipePath('content.flags.1.code').read(json),
          throwsA(isA<RecipePathError>()));
      expect(() => RecipePath('content.flags').read(json),
          throwsA(isA<RecipePathError>()));
      expect(() => RecipePath('seed.x').read(json),
          throwsA(isA<RecipePathError>()));
      expect(() => RecipePath('a..b'), throwsFormatException);
    });
  });

  group('SignaturePackCodec', () {
    test('draftFromRecipe reproduces the source recipe for its country', () {
      final source = _tornRecipe('us');
      final draft = _draft();
      expect(draft.status, SignatureStatus.draft);
      expect(draft.locks, {'us': source.recipeId});
      expect(SignatureResolver.hero(draft, 'us').recipeId, source.recipeId);
      expect(SignatureResolver.driftedLocks(draft), isEmpty);
    });

    test('round-trips byte for byte', () {
      final s = _withEnvelope().copyWith(
        overrides: {
          'jp': CountryOverride(
            params: {'tornStrips.distress': 0.6},
            reason: 'Red disc vanishes under heavy distress',
          ),
        },
        heroes: {
          'fr': {'seed': 42, 'tornStrips.mirror': true},
        },
      );
      final text = SignaturePackCodec.encode(s);
      final back = SignaturePackCodec.decode(text);
      expect(SignaturePackCodec.encode(back), text);
      expect(back.envelope, s.envelope);
      expect(back.overrides, s.overrides);
      expect(text.endsWith('\n'), isTrue);
    });

    test('rejects unknown fields and future format versions', () {
      final text = SignaturePackCodec.encode(_draft());
      expect(
        () => SignaturePackCodec.decode(
            text.replaceFirst('"base"', '"colour": 1, "base"')),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('colour'))),
      );
      expect(
        () => SignaturePackCodec.decode(
            text.replaceFirst('"formatVersion": 1', '"formatVersion": 2')),
        throwsFormatException,
      );
    });

    test('rejects an envelope path that is not in the recipe', () {
      final text = SignaturePackCodec.encode(_withEnvelope());
      expect(
        () => SignaturePackCodec.decode(
            text.replaceFirst('"tornStrips.distress"', '"tornStrips.distres"')),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('distres'))),
      );
    });
  });

  group('SignatureRecipe validation', () {
    test('base must be templated on the country', () {
      final json = _tornRecipe('us').toJson()..remove('recipeId');
      expect(
        () => SignatureRecipe(
          id: 'x',
          title: 'X',
          version: 1,
          status: SignatureStatus.draft,
          base: json,
        ),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('{{country}}'))),
      );
    });

    test('approved needs approvedAt; overrides need a reason', () {
      expect(() => _draft().copyWith(status: SignatureStatus.approved),
          throwsFormatException);
      expect(
          () => CountryOverride(params: {'seed': 2}, reason: ' '),
          throwsFormatException);
    });

    test('overrides and heroes cannot leave the envelope', () {
      expect(
        () => _withEnvelope().copyWith(overrides: {
          'jp': CountryOverride(
              params: {'tornStrips.distress': 0.95}, reason: 'too much'),
        }),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('outside'))),
      );
      expect(
        () => _withEnvelope().copyWith(heroes: {
          'jp': {'tornStrips.gap': 0.1},
        }),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('not in the envelope'))),
      );
    });
  });

  group('SignatureResolver', () {
    test('fills the country into the recipe', () {
      final r = SignatureResolver.hero(_draft(), 'JP');
      expect(r.content.flags.single.code, 'jp');
    });

    test('variations are deterministic and differ by index', () {
      final s = _withEnvelope();
      final a = SignatureResolver.variation(s, 'br', 7);
      final b = SignatureResolver.variation(s, 'br', 7);
      expect(a.recipeId, b.recipeId);
      final ids = {
        for (var i = 1; i <= 50; i++)
          SignatureResolver.variation(s, 'br', i).recipeId,
      };
      expect(ids.length, 50);
      expect(SignatureResolver.variation(s, 'br', 0).recipeId,
          SignatureResolver.hero(s, 'br').recipeId);
    });

    test('variations match across isolates', () async {
      final s = _withEnvelope();
      final here = [
        for (var i = 0; i < 10; i++) SignatureResolver.variation(s, 'za', i).recipeId,
      ];
      final there = await Isolate.run(() => [
            for (var i = 0; i < 10; i++)
              SignatureResolver.variation(_withEnvelope(), 'za', i).recipeId,
          ]);
      expect(there, here);
    });

    test('variation values stay inside the envelope', () {
      final s = _withEnvelope();
      for (var i = 1; i <= 200; i++) {
        final json = SignatureResolver.variation(s, 'de', i).toJson();
        for (final e in s.envelope.ranges.entries) {
          expect(e.value.contains(RecipePath(e.key).read(json)), isTrue,
              reason: '${e.key} at $i');
        }
      }
    });

    test('a new version reshuffles variations', () {
      final s = _withEnvelope();
      final v2 = s.copyWith(version: 2);
      expect(SignatureResolver.variation(s, 'de', 3).recipeId,
          isNot(SignatureResolver.variation(v2, 'de', 3).recipeId));
    });

    test('an override applies to its country only and pins the path', () {
      final s = _withEnvelope().copyWith(overrides: {
        'jp': CountryOverride(
            params: {'tornStrips.distress': 0.6}, reason: 'keep the disc'),
      });
      for (var i = 0; i < 20; i++) {
        expect(
            SignatureResolver.variation(s, 'jp', i).tornStrips!.distress, 0.6);
      }
      final others = {
        for (var i = 1; i < 20; i++)
          SignatureResolver.variation(s, 'fr', i).tornStrips!.distress,
      };
      expect(others.length, greaterThan(1));
    });

    test('heroes apply curated values', () {
      final s = _withEnvelope().copyWith(heroes: {
        'fr': {'seed': 42},
      });
      expect(SignatureResolver.hero(s, 'fr').seed, 42);
      expect(SignatureResolver.hero(s, 'de').seed, 1);
    });

    test('driftedLocks reports a changed design', () {
      final s = _draft().copyWith(locks: {'us': 'deadbeefdeadbeef'});
      expect(SignatureResolver.driftedLocks(s), ['us']);
      final fresh = s.copyWith(locks: SignatureResolver.lockFor(s, ['us', 'jp']));
      expect(SignatureResolver.driftedLocks(fresh), isEmpty);
    });
  });
}
