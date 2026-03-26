import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_image_renderer.dart';
import 'package:shared_models/shared_models.dart';

/// Renders [template] for [codes] inside a widget test environment.
///
/// Uses a [MaterialApp] + [Scaffold] to provide the [Overlay] that
/// [CardImageRenderer.render] requires.
Future<Uint8List> _render(
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

  late Uint8List result;
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
    testWidgets('render(grid, [GB, FR]) returns non-empty Uint8List',
        (tester) async {
      final bytes =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      expect(bytes, isNotEmpty);
    });

    testWidgets('returned bytes start with PNG magic bytes (0x89 0x50)',
        (tester) async {
      final bytes =
          await _render(tester, CardTemplateType.grid, codes: ['GB', 'FR']);
      expect(bytes.length, greaterThanOrEqualTo(2));
      expect(bytes[0], equals(0x89), reason: 'First PNG magic byte mismatch');
      expect(bytes[1], equals(0x50), reason: 'Second PNG magic byte mismatch');
    });

    testWidgets('render completes for every CardTemplateType without throwing',
        (tester) async {
      for (final template in CardTemplateType.values) {
        final bytes = await _render(tester, template, codes: ['GB', 'FR']);
        expect(bytes, isNotEmpty,
            reason: 'render(${template.name}) returned empty bytes');
      }
    });
  });
}
