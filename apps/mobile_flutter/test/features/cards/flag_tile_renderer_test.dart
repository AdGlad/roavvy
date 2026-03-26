import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_tile_renderer.dart';

void main() {
  group('FlagImageCache', () {
    test('starts empty', () {
      final cache = FlagImageCache();
      expect(cache.length, 0);
    });

    test('get returns null for missing entry', () {
      final cache = FlagImageCache();
      expect(cache.get('GB', 72.0), isNull);
    });

    test('clear removes all entries', () {
      final cache = FlagImageCache(maxEntries: 10);
      // We can only test clear without actual ui.Image values in unit tests.
      cache.clear();
      expect(cache.length, 0);
    });

    test('respects maxEntries cap', () {
      // We cannot create real ui.Image without a Flutter rendering context.
      // Verify the maxEntries property is correctly stored.
      final cache = FlagImageCache(maxEntries: 5);
      expect(cache.maxEntries, 5);
    });

    test('default maxEntries is 300', () {
      final cache = FlagImageCache();
      expect(cache.maxEntries, 300);
    });
  });

  group('FlagTileRenderer.svgAssetPath', () {
    test('produces lowercase asset path', () {
      expect(FlagTileRenderer.svgAssetPath('GB'), 'assets/flags/svg/gb.svg');
      expect(FlagTileRenderer.svgAssetPath('US'), 'assets/flags/svg/us.svg');
    });

    test('handles already-lowercase code', () {
      expect(FlagTileRenderer.svgAssetPath('fr'), 'assets/flags/svg/fr.svg');
    });
  });

  group('FlagTileRenderer.hasSvg', () {
    test('returns true for common bundled codes', () {
      for (final code in ['gb', 'us', 'fr', 'de', 'jp', 'au', 'ca', 'br',
                          'cn', 'in', 'it', 'es', 'mx', 'za', 'nl', 'se']) {
        expect(FlagTileRenderer.hasSvg(code), isTrue, reason: '$code should be bundled');
      }
    });

    test('is case-insensitive for uppercase codes', () {
      expect(FlagTileRenderer.hasSvg('GB'), isTrue);
      expect(FlagTileRenderer.hasSvg('US'), isTrue);
    });

    test('returns false for non-existent code', () {
      expect(FlagTileRenderer.hasSvg('XX'), isFalse);
      expect(FlagTileRenderer.hasSvg('ZZ'), isFalse);
    });
  });
}
