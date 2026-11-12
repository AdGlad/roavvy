// Visual validation for the torn-slash recipe using the REAL Roavvy renderer.
//
// Renders the Seychelles flag through CardImageRenderer, then applies the actual
// PrintStylePipeline parameters carried by the generated rippedFlag recipe.
// The PNG is returned through reportData for the existing host capture driver.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/card_render_thumbnailer.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style_pipeline.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render Seychelles torn slash recipe', (tester) async {
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

    final context = DesignContext.of(
      scope: DesignScope.singleCountry,
      countryCodes: const ['sc'],
      garmentIsDark: true,
    );

    // Generate a broad pool so the curated rippedFlag exemplar is present.
    const generator = ProceduralDesignGenerator();
    final result =
        generator.generate(context, seed: 260918, count: 60, poolSize: 120);
    final design = result.designs.firstWhere(
      (d) => d.recipe.printStyle == PrintStyleId.rippedFlag,
      orElse: () => throw StateError('rippedFlag curated recipe not generated'),
    );

    final thumbnailer = CardRenderThumbnailer.forContext(
      ctx,
      pixelRatio: 4.0,
      assetsTimeout: const Duration(seconds: 15),
      suppressText: true,
    );

    // CardImageRenderer completes from post-frame callbacks. Keep pumping the
    // simulator while the queued render is outstanding, matching the proven
    // device render-capture harness.
    final Uint8List base = await tester.runAsync(
          () => _drive(
            tester,
            thumbnailer.renderThumbnail(
              design.recipe.toDesignParams(),
              const [],
            ),
          ),
        ) ??
        Uint8List(0);
    expect(base, isNotEmpty);

    // This is the production treatment path: recipe -> PrintStyleParams ->
    // PrintStylePipeline. It exercises the branch's generateGashBytes code.
    final styled = await tester.runAsync(
          () => PrintStylePipeline.instance.applyToBytes(
            base,
            design.recipe.toPrintStyleParams(),
          ),
        ) ??
        Uint8List(0);
    expect(styled, isNotEmpty);

    binding.reportData = <String, dynamic>{
      'capture': {
        'count': 1,
        'designs': [
          {
            'stem': 'seychelles_torn_slash',
            'country': 'SC',
            'recipe': design.recipe.toJson(),
            'pngBase64': base64Encode(styled),
          }
        ],
      }
    };
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Pump real frames while CardImageRenderer's queued/post-frame work completes.
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
