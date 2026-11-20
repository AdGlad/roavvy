import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/commerce/commerce_flag.dart';
import 'package:mobile_flutter/features/commerce_entry/commerce_entry.dart';

/// ADR-180 / M186: the commerce seam hides, never disables.
void main() {
  Widget host(bool commerce, Widget child) => ProviderScope(
    overrides: [
      commerceBuildProvider.overrideWithValue(commerce),
      commerceRemoteSwitchProvider.overrideWithValue(true),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('CommerceGate builds nothing when commerce is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(false, const CommerceGate(child: Text('Buy a tee'))),
    );
    expect(find.text('Buy a tee'), findsNothing);
  });

  testWidgets('CommerceGate builds its child when commerce is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(true, const CommerceGate(child: Text('Buy a tee'))),
    );
    expect(find.text('Buy a tee'), findsOneWidget);
  });

  testWidgets('openers do not navigate when commerce is off', (tester) async {
    await tester.pumpWidget(
      host(
        false,
        Builder(
          builder:
              (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => CommerceEntry.openOrders(context),
                    child: const Text('orders'),
                  ),
                  TextButton(
                    onPressed: () => CommerceEntry.openCountryMerch(context),
                    child: const Text('country'),
                  ),
                ],
              ),
        ),
      ),
    );
    for (final label in ['orders', 'country']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      // Still on the host page: nothing was pushed.
      expect(find.text(label), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    }
  });
}
