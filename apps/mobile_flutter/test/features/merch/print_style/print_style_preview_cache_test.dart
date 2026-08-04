import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style_preview_cache.dart';

void main() {
  group('PrintStylePreviewCache', () {
    test('hit returns stored bytes; miss returns null', () {
      final cache = PrintStylePreviewCache();
      final k = PrintStylePreviewCache.keyFor(
        artworkHash: 'abc',
        styleId: 'vintage',
        seed: 1,
      );
      expect(cache.get(k), isNull);
      final bytes = Uint8List.fromList([1, 2, 3]);
      cache.put(k, bytes);
      expect(cache.get(k), same(bytes));
    });

    test('key distinguishes style and seed', () {
      final a = PrintStylePreviewCache.keyFor(
          artworkHash: 'h', styleId: 'vintage', seed: 1);
      final b = PrintStylePreviewCache.keyFor(
          artworkHash: 'h', styleId: 'retro', seed: 1);
      final c = PrintStylePreviewCache.keyFor(
          artworkHash: 'h', styleId: 'vintage', seed: 2);
      expect(a, isNot(b));
      expect(a, isNot(c));
    });

    test('evicts the oldest entry beyond capacity (LRU)', () {
      final cache = PrintStylePreviewCache(maxEntries: 2);
      cache.put('k1', Uint8List.fromList([1]));
      cache.put('k2', Uint8List.fromList([2]));
      // Touch k1 so k2 becomes the oldest.
      expect(cache.get('k1'), isNotNull);
      cache.put('k3', Uint8List.fromList([3]));
      expect(cache.length, 2);
      expect(cache.get('k2'), isNull); // evicted
      expect(cache.get('k1'), isNotNull);
      expect(cache.get('k3'), isNotNull);
    });
  });
}
