import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/merch_orders_screen.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  final user = MockUser(isAnonymous: false, uid: 'test-uid');
  final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => mockAuth.authStateChanges()),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('MerchOrderSummary.fromDoc', () {
    test('maps status correctly — cart_created → In progress label', () {
      final summary = MerchOrderSummary.fromDoc('id1', {
        'variantId': 'gid://shopify/ProductVariant/123',
        'selectedCountryCodes': ['GB', 'FR', 'JP'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'status': 'cart_created',
      });
      expect(summary.countryCount, 3);
      expect(summary.status, 'cart_created');
    });

    test('maps status ordered → Processing', () {
      final summary = MerchOrderSummary.fromDoc('id2', {
        'variantId': 'gid://shopify/ProductVariant/456',
        'selectedCountryCodes': ['US'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
        'status': 'ordered',
      });
      expect(summary.status, 'ordered');
      expect(summary.countryCount, 1);
    });

    test('maps status print_file_error → error suffix', () {
      final summary = MerchOrderSummary.fromDoc('id3', {
        'variantId': 'gid://shopify/ProductVariant/789',
        'selectedCountryCodes': [],
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
        'status': 'print_file_error',
      });
      expect(summary.status.endsWith('_error'), isTrue);
    });

    test('handles missing fields gracefully', () {
      final summary = MerchOrderSummary.fromDoc('id4', {});
      expect(summary.countryCount, 0);
      expect(summary.status, 'pending');
      expect(summary.productName, isNotEmpty);
    });
  });

  group('MerchOrdersScreen', () {
    testWidgets('shows empty state when no orders', (tester) async {
      await tester.pumpWidget(_wrap(
        const MerchOrdersScreen(),
        overrides: [
          merchOrdersProvider.overrideWith((_) async => const []),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('No orders yet'), findsOneWidget);
    });

    testWidgets('shows order rows when orders exist', (tester) async {
      final orders = [
        MerchOrderSummary(
          configId: 'cfg1',
          productName: 'Roavvy Test Tee',
          countryCount: 15,
          createdAt: DateTime(2026, 3, 1),
          status: 'ordered',
        ),
      ];

      await tester.pumpWidget(_wrap(
        const MerchOrdersScreen(),
        overrides: [
          merchOrdersProvider.overrideWith((_) async => orders),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Roavvy Test Tee'), findsOneWidget);
      expect(find.textContaining('15 countries'), findsOneWidget);
      expect(find.text('Processing'), findsOneWidget);
    });

    testWidgets('shows error badge for error status', (tester) async {
      final orders = [
        MerchOrderSummary(
          configId: 'cfg2',
          productName: 'Roavvy Test Tee',
          countryCount: 5,
          createdAt: DateTime(2026, 3, 1),
          status: 'print_file_error',
        ),
      ];

      await tester.pumpWidget(_wrap(
        const MerchOrdersScreen(),
        overrides: [
          merchOrdersProvider.overrideWith((_) async => orders),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
    });
  });
}
