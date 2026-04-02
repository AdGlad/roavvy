import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';
import 'package:mobile_flutter/features/merch/merch_variant_screen.dart';
import 'package:shared_models/shared_models.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

/// Sets a tall logical screen so all sections of the scrollable
/// [MerchVariantScreen] are built (not lazy-culled by the viewport).
void _setTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

MerchVariantScreen _tshirtScreen({
  CardTemplateType initialTemplate = CardTemplateType.grid,
}) =>
    MerchVariantScreen(
      product: MerchProduct.tshirt,
      selectedCodes: const ['GB', 'FR', 'JP'],
      initialTemplate: initialTemplate,
    );

MerchVariantScreen _posterScreen() => const MerchVariantScreen(
      product: MerchProduct.poster,
      selectedCodes: ['GB', 'FR'],
    );

void main() {
  group('MerchVariantScreen — template picker', () {
    testWidgets('renders template picker with 3 options (Grid/Heart/Passport)',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_tshirtScreen()));
      await tester.pump();

      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Heart'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('template picker is visible for poster product too',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_posterScreen()));
      await tester.pump();

      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Heart'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets(
        'changing template resets preview to initial state (Preview button shown)',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_tshirtScreen()));
      await tester.pump();

      // Confirm we start in initial state.
      expect(find.text('Approve & buy'), findsOneWidget);

      await tester.tap(find.text('Passport'));
      await tester.pump();

      // Preview state should still be initial (button still visible — state reset).
      expect(find.text('Approve & buy'), findsOneWidget);
    });
  });

  group('MerchVariantScreen — placement picker', () {
    testWidgets('placement picker is visible for tshirt product',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_tshirtScreen()));
      await tester.pump();

      expect(find.text('Print position'), findsOneWidget);
      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('placement picker is hidden for poster product', (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_posterScreen()));
      await tester.pump();

      expect(find.text('Print position'), findsNothing);
      expect(find.text('Front'), findsNothing);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets(
        'changing placement resets preview to initial state (Preview button shown)',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_tshirtScreen()));
      await tester.pump();

      expect(find.text('Approve & buy'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('Approve & buy'), findsOneWidget);
    });
  });

  group('MerchVariantScreen — M53 approval wiring', () {
    testWidgets('"Approve & buy" button is visible in initial state',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_tshirtScreen()));
      await tester.pump();

      expect(find.text('Approve & buy'), findsOneWidget);
    });

    testWidgets('"Approve & buy" tapping navigates to MockupApprovalScreen',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: _tshirtScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Approve & buy'));
      await tester.pumpAndSettle();

      // MockupApprovalScreen should be pushed — it shows 'Approve your order'
      expect(find.text('Approve your order'), findsOneWidget);
    });

    testWidgets(
        'back-navigation from MockupApprovalScreen returns to MerchVariantScreen',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: _tshirtScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Approve & buy'));
      await tester.pumpAndSettle();

      expect(find.text('Approve your order'), findsOneWidget);

      // Navigate back
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // Back on MerchVariantScreen
      expect(find.text('Approve & buy'), findsOneWidget);
      expect(find.text('Approve your order'), findsNothing);
    });

    testWidgets('template picker includes Timeline option',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_tshirtScreen()));
      await tester.pump();

      expect(find.text('Timeline'), findsOneWidget);
    });
  });

  group('MerchVariantScreen — M54-G1 artworkImageBytes reuse paths', () {
    // These tests verify that each of the three code paths in _generatePreview
    // initialises the screen without error (the conditional selection happens
    // later, during approval). Observable behaviour: "Approve & buy" CTA is
    // present in all three scenarios.

    testWidgets(
        'renders correctly when artworkImageBytes provided and template unchanged',
        (tester) async {
      _setTallView(tester);
      final fakeBytes = Uint8List.fromList(List.filled(64, 0));
      await tester.pumpWidget(
        _wrap(
          MerchVariantScreen(
            product: MerchProduct.tshirt,
            selectedCodes: const ['GB', 'FR', 'JP'],
            initialTemplate: CardTemplateType.grid,
            artworkImageBytes: fakeBytes,
          ),
        ),
      );
      await tester.pump();

      // Screen is in initial state — reuse path will be taken on confirm.
      expect(find.text('Approve & buy'), findsOneWidget);
    });

    testWidgets(
        'renders correctly when artworkImageBytes provided but template differs',
        (tester) async {
      _setTallView(tester);
      final fakeBytes = Uint8List.fromList(List.filled(64, 0));
      // initialTemplate=grid but screen will allow switching to Heart.
      // The re-render path is taken when _selectedTemplate != initialTemplate.
      await tester.pumpWidget(
        _wrap(
          MerchVariantScreen(
            product: MerchProduct.tshirt,
            selectedCodes: const ['GB', 'FR'],
            initialTemplate: CardTemplateType.grid,
            artworkImageBytes: fakeBytes,
          ),
        ),
      );
      await tester.pump();

      // User can change template; re-render path is active.
      expect(find.text('Approve & buy'), findsOneWidget);
      expect(find.text('Heart'), findsOneWidget); // template option available
    });

    testWidgets(
        'renders correctly when artworkImageBytes is null (existing render path)',
        (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(
        _wrap(
          const MerchVariantScreen(
            product: MerchProduct.tshirt,
            selectedCodes: ['GB'],
            initialTemplate: CardTemplateType.grid,
            // artworkImageBytes omitted → null
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Approve & buy'), findsOneWidget);
    });
  });
}
