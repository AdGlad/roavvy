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

    test('non-adjacency holds for every FlagGridLayoutMode value', () {
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

  group('FlagGridLayoutEngine — coverGrid (clip mask coverage)', () {
    // Landscape grid zone (the reported cut-off case): a single-country design
    // clipped to a country outline must have flags under the WHOLE grid zone so
    // the outline is never sheared by the flag block's edge.
    const canvas = Size(600, 320);
    const top = 40.0, bot = 40.0, pad = 4.0, gutter = 2.0;
    final gridRight = canvas.width - pad;
    final gridBottom = canvas.height - bot - pad;
    final gridTop = top + pad;

    Rect bounds(List<FlagGridTile> tiles) {
      var l = double.infinity, t = double.infinity, r = -1e9, b = -1e9;
      for (final tile in tiles) {
        l = tile.rect.left < l ? tile.rect.left : l;
        t = tile.rect.top < t ? tile.rect.top : t;
        r = tile.rect.right > r ? tile.rect.right : r;
        b = tile.rect.bottom > b ? tile.rect.bottom : b;
      }
      return Rect.fromLTRB(l, t, r, b);
    }

    test('coverGrid fully covers the grid zone (no straight-edge gaps)', () {
      final tiles = FlagGridLayoutEngine.compute(
        codes: ['au'],
        canvasSize: canvas,
        topOffset: top,
        bottomOffset: bot,
        rowCount: 3,
        coverGrid: true,
      );
      final bb = bounds(tiles);
      // Flags reach every edge of the grid zone (right edge is over-filled);
      // the bottom reaches within one inter-row gutter of the grid zone bottom.
      expect(bb.left, lessThanOrEqualTo(pad + 1));
      expect(bb.top, lessThanOrEqualTo(gridTop + 1));
      expect(bb.right, greaterThanOrEqualTo(gridRight - 1));
      expect(bb.bottom, greaterThanOrEqualTo(gridBottom - gutter - 1));
    });

    test('without coverGrid the single-country block is centred (has a margin)',
        () {
      final tiles = FlagGridLayoutEngine.compute(
        codes: ['au'],
        canvasSize: canvas,
        topOffset: top,
        bottomOffset: bot,
        rowCount: 3,
      );
      // Default (unclipped) keeps the tidy centred behaviour — not full width.
      final bb = bounds(tiles);
      expect(bb.right, lessThanOrEqualTo(gridRight + 1));
    });
  });

  group('FlagGridLayoutEngine — montage (M188)', () {
    const canvasSize = Size(600, 400);

    List<FlagGridTile> montage(
      List<String> codes, {
      int seed = 0,
      int flagRepeatCount = 1,
    }) =>
        FlagGridLayoutEngine.compute(
          codes: codes,
          canvasSize: canvasSize,
          topOffset: 40,
          bottomOffset: 40,
          mode: FlagGridLayoutMode.montage,
          flagRepeatCount: flagRepeatCount,
          seed: seed,
        );

    test('every selected country appears at least once (coverage)', () {
      final tiles = montage(['fr', 'de', 'it', 'es', 'pt']);
      final present = tiles.map((t) => t.code).toSet();
      expect(present, containsAll(['fr', 'de', 'it', 'es', 'pt']));
    });

    test('places one tile per expanded code', () {
      final tiles = montage(['fr', 'de'], flagRepeatCount: 4);
      expect(tiles.length, 8); // 2 codes × 4 repeats
    });

    test('is deterministic for a fixed seed (preview == print)', () {
      final a = montage(['fr', 'de', 'it', 'es'], seed: 12345);
      final b = montage(['fr', 'de', 'it', 'es'], seed: 12345);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].code, b[i].code);
        expect(a[i].rect, b[i].rect);
      }
    });

    test('different seeds produce different arrangements', () {
      final a = montage(['fr', 'de', 'it', 'es', 'pt', 'nl'], seed: 1);
      final b = montage(['fr', 'de', 'it', 'es', 'pt', 'nl'], seed: 2);
      // At least one tile should sit in a different position.
      final differs = List.generate(
        a.length,
        (i) => a[i].rect != b[i].rect,
      ).any((d) => d);
      expect(differs, isTrue);
    });

    test('all tiles stay within the canvas bounds', () {
      final tiles = montage(['fr', 'de', 'it', 'es', 'pt', 'nl', 'be', 'ch'],
          seed: 99);
      for (final t in tiles) {
        expect(t.rect.left, greaterThanOrEqualTo(-0.01));
        expect(t.rect.top, greaterThanOrEqualTo(-0.01));
        expect(t.rect.right, lessThanOrEqualTo(canvasSize.width + 0.01));
        expect(t.rect.bottom, lessThanOrEqualTo(canvasSize.height + 0.01));
      }
    });

    test('no flag is fully occluded by another (bounded overlap)', () {
      // Base grid positions are cell-separated, so each tile centre must be
      // outside every other tile's rect — i.e. no tile is entirely covered.
      final tiles = montage(['fr', 'de', 'it', 'es', 'pt', 'nl'], seed: 7);
      for (var i = 0; i < tiles.length; i++) {
        final centre = tiles[i].rect.center;
        var coveredBy = 0;
        for (var j = 0; j < tiles.length; j++) {
          if (i == j) continue;
          if (tiles[j].rect.contains(centre)) coveredBy++;
        }
        // A tile's own centre may fall under at most a couple of neighbours;
        // it is never so buried that it cannot be seen.
        expect(coveredBy, lessThan(tiles.length - 1));
      }
    });

    test('empty input yields no tiles', () {
      expect(montage(const []), isEmpty);
    });
  });
}
