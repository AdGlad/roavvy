// T9 — FlagGridLayoutEngine: repeat count + non-adjacency algorithm (M170)

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';

void main() {
  group('FlagGridLayoutEngine — flag repeat count', () {
    const canvasSize = Size(600, 400);

    test('repeatCount: 9 with 1 country produces 9 tiles', () {
      final tiles = FlagGridLayoutEngine.compute(
        codes: ['jp'],
        canvasSize: canvasSize,
        topOffset: 40,
        bottomOffset: 40,
        flagRepeatCount: 9,
      );

      expect(tiles.length, 9);
      // Tiles tile the full grid area — individual rects may extend beyond
      // canvas.width because the clip shape crops them at render time.
      for (final tile in tiles) {
        expect(tile.rect.left, greaterThanOrEqualTo(0));
        expect(tile.rect.top, greaterThanOrEqualTo(0));
        expect(tile.rect.bottom, lessThanOrEqualTo(canvasSize.height + 1));
      }
    });

    test('repeatCount: 3 with 2 countries produces 6 tiles', () {
      final tiles = FlagGridLayoutEngine.compute(
        codes: ['fr', 'de'],
        canvasSize: canvasSize,
        topOffset: 40,
        bottomOffset: 40,
        flagRepeatCount: 3,
      );

      expect(tiles.length, 6);
      expect(tiles.where((t) => t.code == 'fr').length, 3);
      expect(tiles.where((t) => t.code == 'de').length, 3);
    });

    test('no two adjacent tiles have the same code (2 countries × 3 repeats)',
        () {
      final tiles = FlagGridLayoutEngine.compute(
        codes: ['au', 'nz'],
        canvasSize: canvasSize,
        topOffset: 40,
        bottomOffset: 40,
        flagRepeatCount: 3,
      );

      // Check that no two consecutive tiles share a code.
      for (int i = 0; i < tiles.length - 1; i++) {
        expect(
          tiles[i].code,
          isNot(equals(tiles[i + 1].code)),
          reason: 'Tiles at positions $i and ${i + 1} have the same code '
              '(${tiles[i].code})',
        );
      }
    });

    test('single country with repeatCount: 1 produces 1 tile', () {
      final tiles = FlagGridLayoutEngine.compute(
        codes: ['gb'],
        canvasSize: canvasSize,
        topOffset: 40,
        bottomOffset: 40,
        flagRepeatCount: 1,
      );
      expect(tiles.length, 1);
      expect(tiles.first.code, 'gb');
    });

    test('non-adjacency holds for all three FlagGridLayoutMode values', () {
      for (final mode in FlagGridLayoutMode.values) {
        final tiles = FlagGridLayoutEngine.compute(
          codes: ['us', 'ca'],
          canvasSize: canvasSize,
          topOffset: 40,
          bottomOffset: 40,
          flagRepeatCount: 4,
          mode: mode,
        );

        expect(tiles.length, 8, reason: 'mode=$mode');
        for (int i = 0; i < tiles.length - 1; i++) {
          expect(
            tiles[i].code,
            isNot(equals(tiles[i + 1].code)),
            reason: 'Adjacent same code at index $i for mode=$mode',
          );
        }
      }
    });

    test('default repeatCount: 1 is backward compatible', () {
      final withDefault = FlagGridLayoutEngine.compute(
        codes: ['fr', 'de', 'es'],
        canvasSize: canvasSize,
        topOffset: 40,
        bottomOffset: 40,
      );
      final explicit1 = FlagGridLayoutEngine.compute(
        codes: ['fr', 'de', 'es'],
        canvasSize: canvasSize,
        topOffset: 40,
        bottomOffset: 40,
        flagRepeatCount: 1,
      );
      expect(withDefault.length, explicit1.length);
    });
  });

  group('FlagGridLayoutEngine — GridClipShape enum', () {
    test('all GridClipShape values are defined', () {
      expect(GridClipShape.values.length, 5);
      expect(GridClipShape.values, contains(GridClipShape.none));
      expect(GridClipShape.values, contains(GridClipShape.heart));
      expect(GridClipShape.values, contains(GridClipShape.circle));
      expect(GridClipShape.values, contains(GridClipShape.countryOutline));
      expect(GridClipShape.values, contains(GridClipShape.continentOutline));
    });
  });
}
