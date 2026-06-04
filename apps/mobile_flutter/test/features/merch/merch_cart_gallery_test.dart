// T4 — MerchCartItemCard + MerchCartStatusBadge widget tests (M141)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item_card.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

MerchCartItem _item({
  String id = 'item-1',
  MerchCartItemStatus status = MerchCartItemStatus.mockupGenerating,
  String? title,
  String? frontMockupUrl,
}) => MerchCartItem(
  id: id,
  status: status,
  productType: 'tshirt',
  variantId: 'v1',
  templateType: 'passport',
  colour: 'White',
  size: 'M',
  frontPosition: 'center',
  backPosition: 'center',
  selectedCountryCodes: const ['GB', 'FR'],
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
  title: title,
  frontMockupUrl: frontMockupUrl,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MerchCartItemCard', () {
    testWidgets('renders fallback title when item.title is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(MerchCartItemCard(item: _item(), uid: 'uid-1')),
      );
      // Default title: "T-shirt · 2 countries" — appears in info area + placeholder
      expect(find.textContaining('T-shirt'), findsAtLeastNWidgets(1));
      expect(find.textContaining('2 countries'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders custom title when set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MerchCartItemCard(
            item: _item(title: 'My Europe Tour'),
            uid: 'uid-1',
          ),
        ),
      );
      expect(find.text('My Europe Tour'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Checkout button when status is mockupReady', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          MerchCartItemCard(
            item: _item(status: MerchCartItemStatus.mockupReady),
            uid: 'uid-1',
            onCheckout: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Checkout →'), findsOneWidget);
      await tester.tap(find.text('Checkout →'));
      expect(tapped, isTrue);
    });

    testWidgets('hides Checkout button when status is mockupGenerating', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(MerchCartItemCard(item: _item(), uid: 'uid-1')),
      );
      expect(find.text('Checkout →'), findsNothing);
    });
  });

  group('MerchCartStatusBadge', () {
    for (final (status, label) in [
      (MerchCartItemStatus.mockupGenerating, 'Generating…'),
      (MerchCartItemStatus.mockupReady, 'Ready to checkout'),
      (MerchCartItemStatus.checkoutStarted, 'Checkout started'),
      (MerchCartItemStatus.purchased, 'Purchased'),
      (MerchCartItemStatus.failed, 'Failed'),
    ]) {
      testWidgets('shows "$label" for $status', (tester) async {
        await tester.pumpWidget(
          _wrap(MerchCartStatusBadge(status: status)),
        );
        expect(find.text(label), findsOneWidget);
      });
    }
  });
}
