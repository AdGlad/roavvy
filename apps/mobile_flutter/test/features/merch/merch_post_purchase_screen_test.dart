import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_post_purchase_screen.dart';
import 'package:mobile_flutter/features/merch/merch_product_browser_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('MerchPostPurchaseScreen', () {
    testWidgets('renders product name and country count (tshirt)', (tester) async {
      await tester.pumpWidget(_wrap(
        const MerchPostPurchaseScreen(
          product: MerchProduct.tshirt,
          countryCount: 23,
        ),
      ));
      await tester.pump();

      expect(find.text('Your order is on its way!'), findsOneWidget);
      expect(find.textContaining('Roavvy Test Tee'), findsOneWidget);
      expect(find.textContaining('23 countries'), findsOneWidget);
    });

    testWidgets('renders product name and country count (poster)', (tester) async {
      await tester.pumpWidget(_wrap(
        const MerchPostPurchaseScreen(
          product: MerchProduct.poster,
          countryCount: 1,
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Roavvy Travel Poster'), findsOneWidget);
      // singular country
      expect(find.textContaining('1 country'), findsOneWidget);
    });

    testWidgets('shows Back to my map and Share my order buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        const MerchPostPurchaseScreen(
          product: MerchProduct.tshirt,
          countryCount: 5,
        ),
      ));
      await tester.pump();

      expect(find.text('Back to my map'), findsOneWidget);
      expect(find.text('Share my order'), findsOneWidget);
    });

    testWidgets('has no back button in AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('root')),
          routes: {
            '/post': (_) => const MerchPostPurchaseScreen(
                  product: MerchProduct.tshirt,
                  countryCount: 3,
                ),
          },
        ),
      );
      await tester.pumpWidget(_wrap(
        const MerchPostPurchaseScreen(
          product: MerchProduct.tshirt,
          countryCount: 3,
        ),
      ));
      await tester.pump();

      // automaticallyImplyLeading: false means no back arrow
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
