// T4 — MerchOptionAlternativesStrip widget tests (M139)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_option_list_widgets.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/merch/pulse_merch_option.dart';

PulseMerchOption _opt(CardTemplateType t) => PulseMerchOption(
  id: t.name,
  title: 'Test ${t.name}',
  description: 'desc',
  scope: PulseMerchScope.pulseTrip,
  template: t,
  codes: const ['GB'],
  trips: const [],
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MerchOptionAlternativesStrip', () {
    testWidgets('renders nothing when options list is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MerchOptionAlternativesStrip(
            options: [],
            allCodes: ['GB'],
          ),
        ),
      );
      await tester.pump();

      // Empty → SizedBox.shrink, no ListView
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders a scrollable row for non-empty options', (tester) async {
      final opts = [
        _opt(CardTemplateType.passport),
        _opt(CardTemplateType.grid),
      ];
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrap(
            MerchOptionAlternativesStrip(
              options: opts,
              allCodes: const ['GB'],
            ),
          ),
        );
        await tester.pump();
      });

      // Strip should be present even before images load
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows template label text for each thumb', (tester) async {
      final opts = [
        _opt(CardTemplateType.passport),
        _opt(CardTemplateType.grid),
      ];
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrap(
            MerchOptionAlternativesStrip(
              options: opts,
              allCodes: const ['GB'],
            ),
          ),
        );
        await tester.pump();
      });

      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Flags'), findsOneWidget);
    });
  });
}
