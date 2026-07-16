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
}
