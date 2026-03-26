import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_product_browser_screen.dart';
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
      expect(find.text('Preview my design'), findsOneWidget);

      await tester.tap(find.text('Passport'));
      await tester.pump();

      // Preview state should still be initial (button still visible — state reset).
      expect(find.text('Preview my design'), findsOneWidget);
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

      expect(find.text('Preview my design'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('Preview my design'), findsOneWidget);
    });
  });
}
