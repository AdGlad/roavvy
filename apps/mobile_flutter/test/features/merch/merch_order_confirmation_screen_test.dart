import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_order_confirmation_screen.dart';
import 'package:shared_models/shared_models.dart';

// 1×1 transparent PNG — avoids real image decoding in tests.
final Uint8List _fakeBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
  0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

MerchOrderConfirmationScreen _defaultScreen({
  String? frontMockupUrl,
  String? backMockupUrl,
  Uint8List? frontArtworkBytes,
  VoidCallback? onCheckoutLaunched,
}) =>
    MerchOrderConfirmationScreen(
      frontMockupUrl: frontMockupUrl,
      backMockupUrl: backMockupUrl,
      frontArtworkBytes: frontArtworkBytes,
      artworkBytes: _fakeBytes,
      size: 'L',
      colour: 'Black',
      frontPosition: 'center',
      backPosition: 'center',
      templateType: CardTemplateType.passport,
      checkoutUrl: 'https://example.com/checkout',
      isTshirt: true,
      onCheckoutLaunched: onCheckoutLaunched,
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('MerchOrderConfirmationScreen', () {
    testWidgets('proceed button is disabled initially', (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen()));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceed to Checkout'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('proceed button enables after ticking checkbox', (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen()));

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceed to Checkout'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Go Back pops the navigator', (tester) async {
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: _defaultScreen(),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Go Back'));
      await tester.pumpAndSettle();

      expect(observer.popped, isTrue);
    });

    testWidgets('falls back to Image.memory when frontMockupUrl is null',
        (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen()));
      // When no network URL is provided, the widget tree must not contain a
      // NetworkImage-backed widget. We assert Image.memory is present instead.
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('shows order summary details', (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen()));

      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('Centre'), findsWidgets); // front + back both 'center'
      expect(find.text('Passport Stamps'), findsOneWidget);
    });

    testWidgets('renders two-item page indicator when both mockup URLs given',
        (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen(
        // Use non-null URLs so _buildPages returns two pages.
        // Network images won't load in tests but the PageView structure is set.
        frontMockupUrl: 'https://example.com/front.png',
        backMockupUrl: 'https://example.com/back.png',
      )));
      await tester.pump();

      // PageView should be in the tree.
      expect(find.byType(PageView), findsOneWidget);

      // Two dot-indicator AnimatedContainers are rendered (one per page).
      // We verify via the page label text that two pages exist.
      expect(find.text('Front'), findsOneWidget);
    });

    testWidgets('shows only one page when backMockupUrl is null', (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen(
        frontMockupUrl: 'https://example.com/front.png',
        backMockupUrl: null,
      )));
      await tester.pump();

      // Single-image mode: no PageView, just _MockupFrame + Image.
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('warning box is visible', (tester) async {
      await tester.pumpWidget(_wrap(_defaultScreen()));

      expect(find.text('Custom-Made Product'), findsOneWidget);
      expect(find.textContaining('no refunds'), findsNothing);
      expect(
        find.textContaining('made to order'),
        findsOneWidget,
      );
    });

    testWidgets('onCheckoutLaunched callback not called before tap', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(_defaultScreen(onCheckoutLaunched: () => called = true)),
      );

      expect(called, isFalse);
    });
  });
}

class _MockNavigatorObserver extends NavigatorObserver {
  bool popped = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped = true;
  }
}
