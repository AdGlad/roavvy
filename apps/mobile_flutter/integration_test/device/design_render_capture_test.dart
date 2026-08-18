// C-00 Lane A2 — ON-DEVICE rendered-evidence capture (pixel-truth path).
//
// Renders representative procedural designs through the REAL CardImageRenderer on
// a booted simulator/device, where fonts, SVG flag/outline assets and GPU shaders
// all work (unlike the flaky headless host harness, render_capture.dart / Lane A1).
// The rendered PNGs are base64-packed into `binding.reportData` and written to the
// repo by the host driver (test_driver/design_render_capture_driver.dart).
//
// Run (see design_studio/tools/README or C-00 doc):
//   flutter drive \
//     --driver=test_driver/design_render_capture_driver.dart \
//     --target=integration_test/device/design_render_capture_test.dart \
//     -d <booted-simulator-id>
// Then: design_studio/tools/decode_device_capture.sh

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/card_render_thumbnailer.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const gen = ProceduralDesignGenerator();

  // Inlined representative contexts (integration_test can't import test/ fixtures).
  // Focused on the render-dependent + type-led families that Lane A1 couldn't judge.
  final contexts = <String, DesignContext>{
    'one-country-light': DesignContext.of(
        scope: DesignScope.singleCountry,
        countryCodes: const ['jp'],
        garmentIsDark: false),
    'two-countries': DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['fr', 'jp'],
        garmentIsDark: true),
    'several-countries': DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['fr', 'jp', 'us', 'ke', 'br'],
        garmentIsDark: true),
    'lifetime': DesignContext.of(
        scope: DesignScope.lifetime,
        countryCodes: const [
          'fr', 'jp', 'us', 'ke', 'br', 'it', 'es', 'de', 'gr', 'pt',
          'th', 'vn', 'au', 'nz', 'mx', 'ca', 'gb', 'ie', 'nl', 'be',
          'ch', 'at', 'se', 'no', 'fi', 'dk', 'pl', 'cz',
        ],
        garmentIsDark: true),
    // one-country-dark: same JP set on a dark garment (E-006/statement contrast).
    'one-country-dark': DesignContext.of(
        scope: DesignScope.singleCountry,
        countryCodes: const ['jp'],
        garmentIsDark: true),
  };
  const seed = 1;
  // Keep the payload small enough that reportData transfers reliably over the VM
  // service (a larger 8-context×2 set failed to write report.json). 5 contexts × 2
  // covers every target family (typographicIntegration/negativeSpaceCutout/
  // dominantAccent/statementCount/duoBlend) in ~10 designs.
  const perContext = 2;

  testWidgets('device render capture', (tester) async {
    // A live context with an Overlay for the renderer.
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      ),
    ));
    await tester.pumpAndSettle();

    final thumb = CardRenderThumbnailer.forContext(
      // ignore: use_build_context_synchronously — tree stays mounted for the test
      ctx,
      pixelRatio: 3.0,
      assetsTimeout: const Duration(seconds: 12), // real assets load on device
    );

    final out = <Map<String, dynamic>>[];
    await tester.runAsync(() async {
      for (final entry in contexts.entries) {
        final designs =
            gen.generate(entry.value, seed: seed, count: perContext).designs;
        for (var i = 0; i < designs.length; i++) {
          final d = designs[i];
          try {
            final b = await _drive(tester, thumb.renderThumbnail(d.params, const []));
            if (b.isNotEmpty) {
              out.add({
                'stem': '${entry.key}_${d.recipe.family.name}_$i',
                'context': entry.key,
                'family': d.recipe.family.name,
                'quality': d.quality.total,
                'seed': seed,
                'recipe': d.recipe.toJson(),
                'pngBase64': base64Encode(b),
              });
            }
          } catch (_) {
            // best-effort; skip a failed render
          }
        }
      }
    });

    binding.reportData = <String, dynamic>{
      'capture': {
        'engineVersion': kProceduralEngineVersion,
        'grammarVersion': kProceduralGrammarVersion,
        'count': out.length,
        'designs': out,
      }
    };
    expect(out, isNotEmpty, reason: 'no designs rendered on device');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Drive one queued render to completion, pumping real frames so the render
/// queue + post-frame raster capture progress. On device, assets actually load.
Future<Uint8List> _drive(WidgetTester tester, Future<Uint8List> future) async {
  Uint8List? bytes;
  Object? error;
  var done = false;
  // ignore: unawaited_futures
  future.then<void>((b) {
    bytes = b;
    done = true;
  }, onError: (Object e) {
    error = e;
    done = true;
  });
  for (var i = 0; i < 240 && !done; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
  if (error != null) throw error!;
  return bytes ?? Uint8List(0);
}
