// M55-B — LocalMockupImageCache unit tests
//
// LocalMockupImageCache.load() uses rootBundle which is unavailable in headless
// unit tests. These tests verify the public API contracts that can be checked
// without a real asset bundle: dispose, maxEntries, and the singleton identity.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/local_mockup_image_cache.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shading source handed to the painter', () {
    testWidgets('is a derived fold map, never the colour photo itself', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // The production merch flow photographs each colourway separately, so
        // the garment image here is a genuinely RED picture. The painter
        // multiplies the shading over the print — returning the photo as its
        // own shading would multiply that red into every design.
        const spec = GarmentMockupSpec(
          assetPath: 'assets/mockups/Red-tshirt-front.jpeg',
          printAreaNorm: Rect.fromLTWH(0.25, 0.22, 0.50, 0.40),
        );
        final (garment, shading) =
            await LocalMockupImageCache.instance.loadWithShading(spec);
        addTearDown(LocalMockupImageCache.instance.dispose);

        expect(
          identical(garment, shading),
          isFalse,
          reason: 'the red photo is being used as its own shading source',
        );

        // Sample the middle of the shirt: the fold map must be neutral there.
        Future<List<int>> mid(ui.Image img) async {
          final d = (await img.toByteData())!.buffer.asUint8List();
          final i = ((img.height ~/ 2) * img.width + img.width ~/ 2) * 4;
          return [d[i], d[i + 1], d[i + 2]];
        }

        final g = await mid(garment);
        expect(
          g[0],
          greaterThan(g[1]),
          reason: 'sanity: the garment photo really is red',
        );

        final sh = await mid(shading);
        expect(sh[0], sh[1], reason: 'red leaked into the fold map');
        expect(sh[1], sh[2], reason: 'blue leaked into the fold map');
      });
    });
  });

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
