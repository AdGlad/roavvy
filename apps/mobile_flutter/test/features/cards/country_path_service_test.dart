// T3 — CountryPathService unit tests (M171)
//
// These tests use flutter_test's rootBundle mock mechanism to inject test
// asset data without requiring a real build artifact.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/country_path_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _makeAsset({
  double w = 1000,
  double h = 600,
  List<List<List<double>>>? polys,
}) {
  polys ??= [
    [
      [0, 0], [500, 0], [500, 300], [0, 300],
    ]
  ];
  return json.encode({'w': w, 'h': h, 'polys': polys});
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Register fake asset bundle that serves test JSON.
  setUp(() {
    // Provide minimal asset bundle using ServicesBinding test utilities.
    // We inject via AssetBundle.loadString by binding the test bundle.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      // message contains the asset key as a UTF-8 string.
      // Decode key from ByteData.
      final key = utf8.decode(message!.buffer.asUint8List());
      String? content;
      if (key == 'assets/country_paths/jp.json') {
        // Multi-polygon country (two separate contours).
        content = _makeAsset(
          w: 1000,
          h: 900,
          polys: [
            [[0, 0], [200, 0], [200, 200], [0, 200]],
            [[300, 300], [500, 300], [500, 500], [300, 500]],
          ],
        );
      } else if (key == 'assets/country_paths/au.json') {
        content = _makeAsset(w: 1000, h: 600);
      } else if (key == 'assets/continent_paths/europe.json') {
        content = _makeAsset(w: 1000, h: 500);
      }
      if (content == null) return null;
      final bytes = utf8.encode(content);
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  group('CountryPathService', () {
    test('parses single-polygon country and returns non-empty path', () async {
      final path = await CountryPathService.pathFor('au', const ui.Size(400, 300));
      expect(path, isNotNull);
      expect(path!.getBounds(), isNot(ui.Rect.zero));
    });

    test('parses multi-polygon country (JP) as single ui.Path', () async {
      final path = await CountryPathService.pathFor('jp', const ui.Size(400, 360));
      expect(path, isNotNull);
      // Path has bounds — both contours contribute.
      expect(path!.getBounds().width, greaterThan(0));
      expect(path.getBounds().height, greaterThan(0));
    });

    test('scaled path bounds fit within targetSize', () async {
      const target = ui.Size(300, 200);
      final path = await CountryPathService.pathFor('au', target);
      expect(path, isNotNull);
      final bounds = path!.getBounds();
      expect(bounds.width, lessThanOrEqualTo(target.width + 1));
      expect(bounds.height, lessThanOrEqualTo(target.height + 1));
    });

    test('loads continent path from continent_paths directory', () async {
      final path = await CountryPathService.pathFor('europe', const ui.Size(400, 300));
      expect(path, isNotNull);
    });

    test('returns null for unknown country code', () async {
      final path = await CountryPathService.pathFor('xx', const ui.Size(400, 300));
      expect(path, isNull);
    });

    test('caches path and returns same instance on second call', () async {
      final a = await CountryPathService.pathFor('au', const ui.Size(400, 300));
      final b = await CountryPathService.pathFor('au', const ui.Size(400, 300));
      expect(a, isNotNull);
      expect(identical(a, b), isTrue);
    });

    test('preload completes without error for known codes', () async {
      await expectLater(
        CountryPathService.preload(['au', 'jp'], const ui.Size(400, 300)),
        completes,
      );
    });

    test('preload silently ignores unknown codes', () async {
      await expectLater(
        CountryPathService.preload(['xx', 'yy'], const ui.Size(400, 300)),
        completes,
      );
    });
  });
}
