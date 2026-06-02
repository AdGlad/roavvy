import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_image_renderer.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/cards/heart_layout_engine.dart';

/// Renders [template] for [codes] inside a widget test environment.
///
/// Uses a [MaterialApp] + [Scaffold] to provide the [Overlay] that
/// [CardImageRenderer.render] requires.
Future<CardRenderResult> _render(
  WidgetTester tester,
  CardTemplateType template, {
  List<String> codes = const ['GB', 'FR'],
  bool entryOnly = false,
  double cardAspectRatio = 3.0 / 2.0,
  HeartFlagOrder heartOrder = HeartFlagOrder.alphabetical,
  String dateLabel = '',
}) async {
  BuildContext? ctx;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        }),
      ),
    ),
  );

  // Ensure the Builder has run and ctx is captured.
  await tester.pump();
  expect(ctx, isNotNull, reason: 'BuildContext not captured — test setup error');

  late CardRenderResult result;
  await tester.runAsync(() async {
    final future = CardImageRenderer.render(
      ctx!,
      template,
      codes: codes,
      entryOnly: entryOnly,
      cardAspectRatio: cardAspectRatio,
      heartOrder: heartOrder,
      dateLabel: dateLabel,
      // Skip the SVG asset-load wait so the capture fires immediately with
      // emoji fallbacks. Avoids hanging on picture.toImage() in test env.
      assetsTimeout: Duration.zero,
    );
    // In runAsync (real-time event loop), tester.pump() completes via
    // microtasks — so the Duration.zero macrotask timer that fires
    // doCapture() never gets a turn before the pumps complete.
    // await Future.delayed(Duration.zero) explicitly gives the macrotask
    // queue one turn so the timer fires and registers the postFrameCallback
    // BEFORE we pump the frame that builds the OverlayEntry.
    await Future.delayed(Duration.zero);
    await tester.pump(); // build OverlayEntry + fire postFrameCallback
    result = await future; // wait for boundary.toImage() to complete
  });

  return result;
}

void main() {
  group('CardImageRenderer', () {
    testWidgets('render(grid, [GB, FR]) returns non-empty bytes',
        (tester) async {
      final result =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      expect(result.bytes, isNotEmpty);
    });

    testWidgets('returned bytes start with PNG magic bytes (0x89 0x50)',
        (tester) async {
      final result =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      expect(result.bytes.length, greaterThanOrEqualTo(2));
      expect(result.bytes[0], equals(0x89),
          reason: 'First PNG magic byte mismatch');
      expect(result.bytes[1], equals(0x50),
          reason: 'Second PNG magic byte mismatch');
    });

    testWidgets('render completes for every CardTemplateType without throwing',
        (tester) async {
      for (final template in CardTemplateType.values) {
        // wordCloud uses the word_cloud package which computes a negative font
        // size in the headless test environment (test TextScaler + no system
        // fonts), triggering a 'fontSize >= 0' assertion in TextPainter.
        // The same limitation is absorbed with takeException() in
        // card_type_picker_screen_test.dart. Skip here — covered by QA.
        if (template == CardTemplateType.wordCloud) continue;
        final result = await _render(tester, template, codes: ['GB', 'FR']);
        expect(result.bytes, isNotEmpty,
            reason: 'render(${template.name}) returned empty bytes');
      }
    });

    testWidgets('imageHash is 64 lowercase hex characters', (tester) async {
      final result =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      expect(result.imageHash, hasLength(64));
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(result.imageHash),
        isTrue,
        reason: 'imageHash must be 64 lowercase hex chars',
      );
    });

    testWidgets('identical inputs produce identical hash within same test run',
        (tester) async {
      final result1 =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      final result2 =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      expect(result1.imageHash, equals(result2.imageHash),
          reason: 'Hash must be deterministic for identical inputs');
    });

    // ADR-112: new params are forwarded to template widgets.
    testWidgets('render completes with entryOnly=true for passport template',
        (tester) async {
      final result = await _render(
        tester,
        CardTemplateType.passport,
        codes: ['GB', 'FR'],
        entryOnly: true,
      );
      expect(result.bytes, isNotEmpty);
    });

    testWidgets('render completes with portrait cardAspectRatio for grid',
        (tester) async {
      final result = await _render(
        tester,
        CardTemplateType.grid,
        codes: ['GB', 'FR'],
        cardAspectRatio: 2.0 / 3.0,
      );
      expect(result.bytes, isNotEmpty);
    });

    testWidgets(
        'render completes with heartOrder=alphabetical for heart template',
        (tester) async {
      final result = await _render(
        tester,
        CardTemplateType.heart,
        codes: ['GB', 'FR', 'DE'],
        heartOrder: HeartFlagOrder.alphabetical,
      );
      expect(result.bytes, isNotEmpty);
    });

    testWidgets('render with dateLabel produces non-empty bytes',
        (tester) async {
      final result = await _render(
        tester,
        CardTemplateType.grid,
        codes: ['GB', 'FR'],
        dateLabel: '2018\u20132024',
      );
      expect(result.bytes, isNotEmpty);
    });
  });
}
