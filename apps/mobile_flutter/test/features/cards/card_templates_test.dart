import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/cards/card_branding_footer.dart';
import 'package:mobile_flutter/features/cards/card_templates.dart';
import 'package:mobile_flutter/features/cards/timeline_card.dart';
import 'package:shared_models/shared_models.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 200, child: child)));

void main() {
  group('GridFlagsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const GridFlagsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your card'), findsOneWidget);
    });

    testWidgets('renders flags with 5 countries', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
      ));
      // Branding footer shows "{N} countries" (ADR-101)
      expect(find.text('5 countries'), findsOneWidget);
      expect(find.byType(CardBrandingFooter), findsOneWidget);
    });

    testWidgets('shows ROAVVY wordmark in branding footer', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(countryCodes: ['GB', 'FR']),
      ));
      expect(find.text('ROAVVY'), findsOneWidget);
    });

    testWidgets('shows dateLabel in footer when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(
            countryCodes: ['GB', 'FR'],
            dateLabel: '2018\u20132024'),
      ));
      expect(find.text('2018\u20132024'), findsOneWidget);
    });

    testWidgets('shows titleOverride in header when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(
          countryCodes: ['GB', 'FR'],
          titleOverride: 'My Adventures',
        ),
      ));
      expect(find.text('MY ADVENTURES'), findsOneWidget);
    });

    testWidgets('shows default title (country count) when titleOverride is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(countryCodes: ['GB', 'FR']),
      ));
      expect(find.text('2 COUNTRIES'), findsOneWidget);
    });

    testWidgets('uses CustomPaint for non-empty state', (tester) async {
      await tester.pumpWidget(_wrap(
        const GridFlagsCard(countryCodes: ['GB', 'FR', 'JP']),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
    });

  });

  group('HeartFlagsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const HeartFlagsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your card'), findsOneWidget);
    });

    testWidgets('renders without exception with 5 countries', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
      ));
      expect(find.byType(HeartFlagsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash with 50+ countries', (tester) async {
      final codes = List.generate(50, (i) => String.fromCharCode(65 + i % 26) +
          String.fromCharCode(65 + (i + 1) % 26));
      await tester.pumpWidget(_wrap(HeartFlagsCard(countryCodes: codes)));
      expect(find.byType(HeartFlagsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aspect ratio is 3:2', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(countryCodes: ['GB', 'US']),
      ));
      final aspectRatio = tester.widget<AspectRatio>(
        find.byType(AspectRatio).first,
      );
      expect(aspectRatio.aspectRatio, closeTo(1.5, 0.01));
    });

    testWidgets('uses CustomPaint for non-empty state', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(countryCodes: ['GB']),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows CardBrandingFooter with country count', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(countryCodes: ['GB', 'FR', 'DE']),
      ));
      expect(find.byType(CardBrandingFooter), findsOneWidget);
      expect(find.text('3 countries'), findsOneWidget);
    });

    testWidgets('renders without exception when titleOverride is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(
          countryCodes: ['GB', 'FR'],
          titleOverride: 'My Heart Card',
        ),
      ));
      expect(find.byType(HeartFlagsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without exception when titleOverride is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const HeartFlagsCard(countryCodes: ['GB', 'FR']),
      ));
      expect(find.byType(HeartFlagsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PassportStampsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(
          _wrap(const PassportStampsCard(countryCodes: [], trips: [])));
      expect(find.text('Scan your photos\nto fill your passport'), findsOneWidget);
    });

    testWidgets('renders with 5 countries and no trips', (tester) async {
      await tester.pumpWidget(_wrap(
        const PassportStampsCard(
          countryCodes: ['FR', 'DE', 'JP', 'US', 'GB'],
          trips: [],
        ),
      ));
      expect(find.byType(PassportStampsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash with 50+ countries', (tester) async {
      final codes = List.generate(50, (i) =>
          String.fromCharCode(65 + i % 26) +
          String.fromCharCode(65 + (i + 1) % 26));
      await tester.pumpWidget(
          _wrap(PassportStampsCard(countryCodes: codes, trips: const [])));
      expect(find.byType(PassportStampsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trips parameter defaults to empty list', (tester) async {
      await tester.pumpWidget(_wrap(
        const PassportStampsCard(countryCodes: ['GB', 'US']),
      ));
      expect(find.byType(PassportStampsCard), findsOneWidget);
    });

  });

  group('TimelineCard', () {
    testWidgets('renders with TRAVEL LOG header', (tester) async {
      await tester.pumpWidget(_wrap(
        TimelineCard(
          trips: [
            TripRecord(
              id: 't1',
              countryCode: 'GB',
              startedOn: DateTime(2023, 3, 1),
              endedOn: DateTime(2023, 5, 28),
              photoCount: 1,
              isManual: false,
            ),
          ],
          countryCodes: const ['GB'],
        ),
      ));
      expect(find.byType(TimelineCard), findsOneWidget);
      expect(find.text('TRAVEL LOG'), findsOneWidget);
    });

    testWidgets('shows CardBrandingFooter', (tester) async {
      await tester.pumpWidget(_wrap(
        const TimelineCard(trips: [], countryCodes: ['GB', 'FR']),
      ));
      expect(find.byType(CardBrandingFooter), findsOneWidget);
    });

    testWidgets('shows empty state when no trips', (tester) async {
      await tester.pumpWidget(_wrap(
        const TimelineCard(trips: [], countryCodes: ['US']),
      ));
      expect(find.text('No trips in this date range'), findsOneWidget);
    });
  });
}
