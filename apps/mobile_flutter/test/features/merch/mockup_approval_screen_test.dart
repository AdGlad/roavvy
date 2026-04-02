import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/mockup_approval_screen.dart';
import 'package:shared_models/shared_models.dart';

Widget _wrap(Widget child, {String? uid = 'test-uid'}) {
  return ProviderScope(
    overrides: [currentUidProvider.overrideWith((ref) => uid)],
    child: MaterialApp(home: child),
  );
}

const _kDefaultScreen = MockupApprovalScreen(
  templateType: CardTemplateType.grid,
  variantId: 'gid://shopify/ProductVariant/1',
  placementType: 'front',
);

void main() {
  group('MockupApprovalScreen', () {
    testWidgets('CTA disabled when no checkboxes checked', (tester) async {
      await tester.pumpWidget(_wrap(_kDefaultScreen));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Approve and buy'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('CTA disabled when only 1 of 3 checkboxes checked',
        (tester) async {
      await tester.pumpWidget(_wrap(_kDefaultScreen));
      await tester.pump();

      // Check only the design checkbox
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'My card design looks exactly right'),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Approve and buy'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('CTA enabled when all 3 checkboxes checked', (tester) async {
      await tester.pumpWidget(_wrap(_kDefaultScreen));
      await tester.pump();

      await tester.tap(find.widgetWithText(
          CheckboxListTile, 'My card design looks exactly right'));
      await tester.tap(find.widgetWithText(
          CheckboxListTile, 'The colour and style I\'ve chosen is correct'));
      await tester.tap(
          find.widgetWithText(CheckboxListTile, 'The placement looks right'));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Approve and buy'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('only 2 checkboxes shown when placementType is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MockupApprovalScreen(
            templateType: CardTemplateType.passport,
            variantId: 'gid://shopify/ProductVariant/2',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(
        find.widgetWithText(CheckboxListTile, 'The placement looks right'),
        findsNothing,
      );
    });

    testWidgets('CTA enabled after 2 checkboxes when placement hidden',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MockupApprovalScreen(
            templateType: CardTemplateType.passport,
            variantId: 'gid://shopify/ProductVariant/2',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(
          CheckboxListTile, 'My card design looks exactly right'));
      await tester.tap(find.widgetWithText(
          CheckboxListTile, 'The colour and style I\'ve chosen is correct'));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Approve and buy'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows preview unavailable placeholder when bytes null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MockupApprovalScreen(
            templateType: CardTemplateType.grid,
            variantId: 'gid://shopify/ProductVariant/1',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Preview unavailable'), findsOneWidget);
    });

    testWidgets('hides preview unavailable text when bytes provided',
        (tester) async {
      // Non-empty byte list — enough to pass the null/empty guard.
      // Image.memory will fail to decode the fake bytes, but the widget tree
      // should still render without the placeholder text.
      final fakeBytes = Uint8List.fromList(List.filled(16, 0));
      await tester.pumpWidget(
        _wrap(
          MockupApprovalScreen(
            artworkImageBytes: fakeBytes,
            templateType: CardTemplateType.grid,
            variantId: 'gid://shopify/ProductVariant/1',
          ),
        ),
      );
      await tester.pump();

      // Absorb the image-decode exception thrown by the fake bytes.
      tester.takeException();

      // The "Preview unavailable" placeholder must not be visible — it is only
      // shown when bytes is null. The Image widget is present even if decoding fails.
      expect(find.text('Preview unavailable'), findsNothing);
    });
  });

  group('MockupApprovalScreen — M54-G3 null-UID guard', () {
    testWidgets(
        'shows SnackBar and resets loading state when UID is null on approve',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWith((ref) => null), // UID is null
          ],
          child: const MaterialApp(
            home: MockupApprovalScreen(
              templateType: CardTemplateType.grid,
              variantId: 'gid://shopify/ProductVariant/1',
              placementType: 'front',
            ),
          ),
        ),
      );
      await tester.pump();

      // Check all three boxes so the CTA is enabled.
      await tester.tap(find.widgetWithText(
          CheckboxListTile, 'My card design looks exactly right'));
      await tester.tap(find.widgetWithText(
          CheckboxListTile, 'The colour and style I\'ve chosen is correct'));
      await tester.tap(
          find.widgetWithText(CheckboxListTile, 'The placement looks right'));
      await tester.pump();

      // CTA is now enabled — tap it.
      await tester.tap(find.widgetWithText(FilledButton, 'Approve and buy'));
      await tester.pump();

      // SnackBar with sign-in message must appear.
      expect(find.text('Please sign in to continue'), findsOneWidget);

      // Screen must remain (not popped) and CTA must be re-enabled
      // (loading state reset).
      expect(find.byType(MockupApprovalScreen), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Approve and buy'),
      );
      expect(button.onPressed, isNotNull,
          reason: '_approving should be reset to false after UID-null path');
    });
  });
}
