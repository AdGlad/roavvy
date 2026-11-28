import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

SignatureRecipe _wallPack() => SignaturePackCodec.decode(
    File('../design_studio/assets/signature/heart_wall.pack.json')
        .readAsStringSync());

void main() {
  group('SignatureList', () {
    test('parses, keeps order, lowercases', () {
      final l = SignatureList.parse('US, fr ,JP');
      expect(l.codes, ['us', 'fr', 'jp']);
      expect(l.key, 'us,fr,jp');
      expect(SignatureList.parse('gr').length, 1);
    });

    test('refuses empty, repeated, pair-shaped and over-long lists', () {
      expect(() => SignatureList([]), throwsFormatException);
      expect(() => SignatureList.parse('us,fr,us'), throwsFormatException);
      expect(() => SignatureList.parse('us+fr'), throwsFormatException);
      expect(
          () => SignatureList([
                for (var i = 0; i <= SignatureList.maxLength; i++) 'c$i',
              ]),
          throwsFormatException);
    });

    test('sample lists are the first 3, 6, 12, 24, 48 of a fixed order', () {
      expect([for (final l in SignatureList.samples) l.length],
          SignatureList.sampleSizes);
      expect(SignatureList.samples.last.codes,
          SignatureList.sampleOrder.take(48).toList());
    });
  });

  group('list packs (countries: "n")', () {
    final pack = _wallPack();

    test('the bundled Heart Wall is a list pack, written as "n"', () {
      expect(pack.isList, isTrue);
      expect(pack.isPair || pack.isSingle, isFalse);
      final text = SignaturePackCodec.encode(pack);
      expect(text, contains('"countries": "n"'));
      expect(SignaturePackCodec.encode(SignaturePackCodec.decode(text)), text);
      expect(SignatureResolver.driftedLocks(pack), isEmpty);
    });

    test('{{countries}} becomes one flag per country, in order', () {
      final r = SignatureResolver.heroList(pack, ['jp', 'fr', 'br']);
      expect([for (final f in r.content.flags) f.code], ['jp', 'fr', 'br']);
      expect(r.heartWall, isNotNull);
    });

    test('variations are deterministic and keyed by the ordered list', () {
      final a = SignatureResolver.variationList(pack, ['us', 'fr', 'jp'], 3);
      final b = SignatureResolver.variationFor(pack, 'us,fr,jp', 3);
      final swapped =
          SignatureResolver.variationList(pack, ['fr', 'us', 'jp'], 3);
      expect(a.recipeId, b.recipeId);
      expect(swapped.recipeId == a.recipeId, isFalse);
    });

    test('single and pair entry points refuse a list pack', () {
      expect(() => SignatureResolver.hero(pack, 'us'), throwsStateError);
      expect(
          () => SignatureResolver.heroPair(pack, 'us', 'fr'), throwsStateError);
    });

    test('a list pack must use {{countries}} and nothing per-country', () {
      final base = pack.base;
      SignatureRecipe withBase(Map<String, Object?> b) => SignatureRecipe(
            id: 'x',
            title: 'x',
            version: 1,
            status: SignatureStatus.draft,
            countries: SignatureRecipe.anyCount,
            base: b,
          );
      final noList = deepCopyJson(base) as Map<String, Object?>
        ..['content'] = {
          'flags': [
            {'code': '{{country}}', 'weight': 1.0},
          ],
        };
      expect(() => withBase(noList), throwsFormatException);
      // And a single pack may not use {{countries}}.
      expect(
          () => SignatureRecipe(
                id: 'y',
                title: 'y',
                version: 1,
                status: SignatureStatus.draft,
                base: base,
              ),
          throwsFormatException);
    });

    test('codec refuses a numeric 0', () {
      final text = SignaturePackCodec.encode(pack)
          .replaceFirst('"countries": "n"', '"countries": 0');
      expect(() => SignaturePackCodec.decode(text), throwsFormatException);
    });
  });

  group('HeartWall', () {
    test('round-trips and validates', () {
      const w = HeartWall(maxColumns: 5, fill: 0.8, frayed: false);
      expect(HeartWall.fromJson(w.toJson()).toJson(), w.toJson());
      expect(
          () => HeartWall.fromJson({'maxColumns': 0}), throwsFormatException);
      expect(() => HeartWall.fromJson({'fill': 0.1}), throwsFormatException);
    });
  });

  group('HeartWallLayout', () {
    const p = HeartWall();

    test('rows of at most 6 on portrait, last row centred, inside the canvas',
        () {
      for (final n in SignatureList.sampleSizes) {
        final codes = SignatureList.sampleOrder.take(n).toList();
        final l =
            HeartWallLayout.compute(p, width: 800, height: 1000, codes: codes);
        expect(l.slots, hasLength(n));
        expect(l.columns, lessThanOrEqualTo(6));
        expect(l.columns * l.rows, greaterThanOrEqualTo(n));
        // Order is the input order, row by row.
        expect([for (final s in l.slots) s.code], codes);
        for (final s in l.slots) {
          expect(s.heartBox.left, greaterThanOrEqualTo(0));
          expect(s.heartBox.right, lessThanOrEqualTo(800));
          expect(s.heartBox.top, greaterThanOrEqualTo(0));
          expect(s.heartBox.bottom, lessThanOrEqualTo(1000));
        }
        // The last row is centred on the canvas.
        final lastRow = l.slots.skip((l.rows - 1) * l.columns).toList();
        final mid =
            (lastRow.first.heartBox.left + lastRow.last.heartBox.right) / 2;
        expect(mid, closeTo(400, 1e-6), reason: 'n=$n');
        // Uniform size.
        expect(l.slots.map((s) => s.heartBox.width.toStringAsFixed(6)).toSet(),
            hasLength(1));
      }
    });

    test('48 countries: 6 per row', () {
      final l = HeartWallLayout.compute(p,
          width: 800, height: 1000, codes: SignatureList.samples.last.codes);
      expect(l.columns, 6);
      expect(l.rows, 8);
    });

    test('every flag keeps its emblem in view', () {
      final codes = FlagFocus.knownCodes.toList();
      for (var i = 0; i < codes.length; i += 48) {
        final chunk = codes.skip(i).take(48).toList();
        final l =
            HeartWallLayout.compute(p, width: 800, height: 1000, codes: chunk);
        for (final s in l.slots) {
          expect(s.crop().emblemVisible, greaterThanOrEqualTo(0.75),
              reason: s.code);
        }
      }
    });

    test('tilts are seeded per heart and bounded', () {
      final codes = SignatureList.samples[3].codes;
      HeartWallLayout l() => HeartWallLayout.compute(p,
          width: 800, height: 1000, codes: codes, seed: 7);
      expect([for (final s in l().slots) s.rotationDeg],
          [for (final s in l().slots) s.rotationDeg]);
      for (final s in l().slots) {
        expect(s.rotationDeg.abs(), lessThanOrEqualTo(p.tiltJitter));
      }
    });
  });
}
