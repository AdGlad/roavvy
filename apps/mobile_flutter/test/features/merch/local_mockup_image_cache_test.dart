// M55-B — LocalMockupImageCache unit tests
//
// LocalMockupImageCache.load() uses rootBundle which is unavailable in headless
// unit tests. These tests verify the public API contracts that can be checked
// without a real asset bundle: dispose, maxEntries, and the singleton identity.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/local_mockup_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M55-B — LocalMockupImageCache', () {
    test('maxEntries is 6', () {
      expect(LocalMockupImageCache.maxEntries, 6);
    });

    test('instance is a singleton', () {
      final a = LocalMockupImageCache.instance;
      final b = LocalMockupImageCache.instance;
      expect(identical(a, b), isTrue);
    });

    test('dispose() on empty cache does not throw', () {
      final cache = LocalMockupImageCache.instance;
      expect(() => cache.dispose(), returnsNormally);
    });

    test('dispose() can be called multiple times without error', () {
      final cache = LocalMockupImageCache.instance;
      cache.dispose();
      expect(() => cache.dispose(), returnsNormally);
    });

    test('load() with invalid asset path throws FlutterError', () async {
      final cache = LocalMockupImageCache.instance;
      cache.dispose(); // ensure clean state
      await expectLater(
        () async => cache.load('assets/mockups/does_not_exist.png'),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}
