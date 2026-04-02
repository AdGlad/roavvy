import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_image_renderer.dart';
import 'package:shared_models/shared_models.dart';

/// Renders [template] for [codes] inside a widget test environment.
///
/// Uses a [MaterialApp] + [Scaffold] to provide the [Overlay] that
/// [CardImageRenderer.render] requires.
Future<CardRenderResult> _render(
  WidgetTester tester,
  CardTemplateType template, {
  List<String> codes = const ['GB', 'FR'],
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
    final future = CardImageRenderer.render(ctx!, template, codes: codes);
    // Pump two frames: one to build the OverlayEntry, one to fire the
    // post-frame callback that captures the RepaintBoundary.
    await tester.pump();
    await tester.pump();
    result = await future;
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
  });
}
