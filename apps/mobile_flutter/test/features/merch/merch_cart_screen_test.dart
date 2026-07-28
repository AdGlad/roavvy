// T4.1 — MerchCartScreen widget tests

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item.dart';
import 'package:mobile_flutter/features/merch/merch_cart_item_card.dart';
import 'package:mobile_flutter/features/merch/merch_cart_screen.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

final _now = DateTime.utc(2026, 1, 1);

MerchCartItem _item({
  String id = 'item-1',
  MerchCartItemStatus status = MerchCartItemStatus.mockupReady,
  String productType = 'tshirt',
  String? title,
  String? checkoutUrl,
  List<String> selectedCountryCodes = const ['GB', 'FR'],
}) => MerchCartItem(
  id: id,
  status: status,
  productType: productType,
  variantId: 'gid://shopify/ProductVariant/1',
  templateType: 'grid',
  colour: 'Black',
  size: 'M',
  frontPosition: 'center',
  backPosition: 'none',
  selectedCountryCodes: selectedCountryCodes,
  createdAt: _now,
  updatedAt: _now,
  title: title,
  checkoutUrl: checkoutUrl,
);

// ── Pump helpers ───────────────────────────────────────────────────────────────

Widget _pump({
  String? uid,
  List<MerchCartItem>? items,
  bool loading = false,
  Object? error,
}) {
  final Stream<List<MerchCartItem>> cartStream;
  if (loading) {
    // Never-completing stream keeps the provider in AsyncValue.loading().
    cartStream = StreamController<List<MerchCartItem>>().stream;
  } else if (error != null) {
    cartStream = Stream.error(error);
  } else {
    cartStream = Stream.value(items ?? const []);
  }

  return ProviderScope(
    overrides: [
      currentUidProvider.overrideWithValue(uid),
      merchCartProvider.overrideWith((_) => cartStream),
    ],
    child: const MaterialApp(home: MerchCartScreen()),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('MerchCartScreen — signed-out state', () {
    testWidgets('shows sign-in prompt when uid is null', (tester) async {
      await tester.pumpWidget(_pump(uid: null));
      await tester.pump();

      expect(find.text('Sign in to view your saved designs.'), findsOneWidget);
    });

    testWidgets('does not show cart items when uid is null', (tester) async {
      await tester.pumpWidget(_pump(uid: null));
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('MerchCartScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      await tester.pumpWidget(_pump(uid: 'user-001', loading: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('MerchCartScreen — empty cart', () {
    testWidgets('shows empty state message when cart is empty', (tester) async {
      await tester.pumpWidget(_pump(uid: 'user-001', items: const []));
      await tester.pump();

      expect(find.textContaining('No designs saved yet.'), findsOneWidget);
    });

    testWidgets('no list tiles when cart is empty', (tester) async {
      await tester.pumpWidget(_pump(uid: 'user-001', items: const []));
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('MerchCartScreen — non-empty cart', () {
    testWidgets('renders a ListTile for each cart item', (tester) async {
      await tester.pumpWidget(
        _pump(uid: 'user-001', items: [_item(id: 'a'), _item(id: 'b')]),
      );
      await tester.pump();

      expect(find.byType(MerchCartItemCard), findsNWidgets(2));
    });

    testWidgets('shows custom title when item.title is set', (tester) async {
      await tester.pumpWidget(
        _pump(uid: 'user-001', items: [_item(title: 'My Europe Tour')]),
      );
      await tester.pump();

      expect(find.text('My Europe Tour'), findsWidgets);
    });

    testWidgets(
      'shows default title derived from product/country count when title is null',
      (tester) async {
        await tester.pumpWidget(
          _pump(
            uid: 'user-001',
            items: [
              _item(title: null, selectedCountryCodes: const ['GB', 'FR']),
            ],
          ),
        );
        await tester.pump();

        // Default title: "T-shirt · 2 countries" (appears in placeholder + info area)
        expect(find.textContaining('T-shirt'), findsWidgets);
        expect(find.textContaining('countries'), findsWidgets);
      },
    );

    testWidgets('shows delete button for each item', (tester) async {
      await tester.pumpWidget(_pump(uid: 'user-001', items: [_item()]));
      await tester.pump();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  group('MerchCartScreen — error state', () {
    testWidgets('shows error message on async error', (tester) async {
      await tester.pumpWidget(
        _pump(uid: 'user-001', error: 'connection failed'),
      );
      await tester.pump();

      expect(find.textContaining('Could not load cart'), findsOneWidget);
    });
  });

  // ── CartItemCheckoutScreen — Proceed gating (M194) ──────────────────────────
  group('CartItemCheckoutScreen — Proceed gating (M194)', () {
    // uid is null so initState's Firestore recovery write is skipped (guarded by
    // uid != null); the _confirmed pre-set still runs.
    Widget pumpCheckout(MerchCartItem item) => ProviderScope(
      overrides: [currentUidProvider.overrideWithValue(null)],
      child: MaterialApp(home: CartItemCheckoutScreen(item: item)),
    );

    FilledButton proceedButton(WidgetTester tester) =>
        tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Proceed to Checkout'),
        );

    testWidgets(
      'Proceed is enabled for a returning checkoutStarted item (pre-confirmed)',
      (tester) async {
        await tester.pumpWidget(
          pumpCheckout(
            _item(
              status: MerchCartItemStatus.checkoutStarted,
              checkoutUrl: 'https://shop.example.com/checkout',
            ),
          ),
        );
        await tester.pump();

        expect(proceedButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      'Proceed is disabled for a fresh mockupReady item until confirmed',
      (tester) async {
        await tester.pumpWidget(
          pumpCheckout(
            _item(
              status: MerchCartItemStatus.mockupReady,
              checkoutUrl: 'https://shop.example.com/checkout',
            ),
          ),
        );
        await tester.pump();

        expect(proceedButton(tester).onPressed, isNull);

        // Ticking the confirmation checkbox enables it.
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();

        expect(proceedButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      'Proceed is disabled with a message when checkoutUrl is null',
      (tester) async {
        await tester.pumpWidget(
          pumpCheckout(
            _item(
              status: MerchCartItemStatus.checkoutStarted,
              checkoutUrl: null,
            ),
          ),
        );
        await tester.pump();

        expect(proceedButton(tester).onPressed, isNull);
        expect(find.textContaining("isn't ready for checkout"), findsOneWidget);
      },
    );
  });
}
