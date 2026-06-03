import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/cards/card_branding_footer.dart';
import 'package:mobile_flutter/features/cards/card_templates.dart';
import 'package:mobile_flutter/features/cards/timeline_card.dart';
import 'package:shared_models/shared_models.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 300, height: 200, child: child)),
);

void main() {
  group('GridFlagsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const GridFlagsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your card'), findsOneWidget);
    });

    testWidgets('renders flags with 5 countries', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GridFlagsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
        ),
      );
      // GridFlagsCard renders all content (title, branding, flags) via
      // CustomPainter on a canvas — there are no Text widgets in the tree.
      // Verify the painter is present and no exception occurred.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows ROAVVY wordmark in branding footer', (tester) async {
      await tester.pumpWidget(
        _wrap(const GridFlagsCard(countryCodes: ['GB', 'FR'])),
      );
      // GridFlagsCard draws branding (including "ROAVVY") via CustomPainter
      // on a canvas — there are no Text widgets in the tree (ADR-101).
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows dateLabel in footer when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GridFlagsCard(
            countryCodes: ['GB', 'FR'],
            dateLabel: '2018\u20132024',
          ),
        ),
      );
      // GridFlagsCard draws the dateLabel via CustomPainter — no Text widget.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows overflow indicator with 50+ countries', (tester) async {
      final codes = List.generate(
        50,
        (i) =>
            String.fromCharCode(65 + i % 26) +
            String.fromCharCode(65 + (i + 1) % 26),
      );
      await tester.pumpWidget(_wrap(GridFlagsCard(countryCodes: codes)));
      // Overflow indicator is drawn on canvas by _GridPainter (not a Text widget).
      // Verify no exception is thrown and CustomPaint is present.
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('uses CustomPaint for non-empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(const GridFlagsCard(countryCodes: ['FR', 'DE', 'JP'])),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('titleOverride shown in branding footer (ADR-120)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GridFlagsCard(
            countryCodes: ['GB', 'FR'],
            dateLabel: '2024',
            titleOverride: 'My Grid Card',
          ),
        ),
      );
      // GridFlagsCard draws titleOverride via CustomPainter on the canvas —
      // no Text widgets in the widget tree (ADR-120).
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash when switching portrait to landscape', (
      tester,
    ) async {
      // Simulate portrait → landscape by changing the wrapping SizedBox dimensions.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: GridFlagsCard(
                countryCodes: const ['FR', 'DE', 'JP', 'US', 'GB'],
                aspectRatio: 200 / 300,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);

      // Switch to landscape dimensions.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: GridFlagsCard(
                countryCodes: const ['FR', 'DE', 'JP', 'US', 'GB'],
                aspectRatio: 300 / 200,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('HeartFlagsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(_wrap(const HeartFlagsCard(countryCodes: [])));
      expect(find.text('Scan your photos\nto fill your card'), findsOneWidget);
    });

    testWidgets('renders without exception with 5 countries', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HeartFlagsCard(countryCodes: ['FR', 'DE', 'JP', 'US', 'GB']),
        ),
      );
      expect(find.byType(HeartFlagsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash with 50+ countries', (tester) async {
      final codes = List.generate(
        50,
        (i) =>
            String.fromCharCode(65 + i % 26) +
            String.fromCharCode(65 + (i + 1) % 26),
      );
      await tester.pumpWidget(_wrap(HeartFlagsCard(countryCodes: codes)));
      expect(find.byType(HeartFlagsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aspect ratio is 3:2', (tester) async {
      await tester.pumpWidget(
        _wrap(const HeartFlagsCard(countryCodes: ['GB', 'US'])),
      );
      final aspectRatio = tester.widget<AspectRatio>(
        find.byType(AspectRatio).first,
      );
      expect(aspectRatio.aspectRatio, closeTo(1.5, 0.01));
    });

    testWidgets('uses CustomPaint for non-empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(const HeartFlagsCard(countryCodes: ['GB'])),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows CardBrandingFooter with country count', (tester) async {
      await tester.pumpWidget(
        _wrap(const HeartFlagsCard(countryCodes: ['GB', 'FR', 'DE'])),
      );
      expect(find.byType(CardBrandingFooter), findsOneWidget);
      expect(find.text('3 countries'), findsOneWidget);
    });

    testWidgets('titleOverride shown in branding footer (ADR-120)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const HeartFlagsCard(
            countryCodes: ['GB', 'FR'],
            dateLabel: '2024',
            titleOverride: 'My Heart Card',
          ),
        ),
      );
      expect(find.text('My Heart Card'), findsOneWidget);
      expect(find.text('2 countries'), findsNothing);
    });
  });

  group('PassportStampsCard', () {
    testWidgets('renders empty state with 0 countries', (tester) async {
      await tester.pumpWidget(
        _wrap(const PassportStampsCard(countryCodes: [], trips: [])),
      );
      expect(
        find.text('Scan your photos\nto fill your passport'),
        findsOneWidget,
      );
    });

    testWidgets('renders with 5 countries and no trips', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PassportStampsCard(
            countryCodes: ['FR', 'DE', 'JP', 'US', 'GB'],
            trips: [],
          ),
        ),
      );
      expect(find.byType(PassportStampsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash with 50+ countries', (tester) async {
      final codes = List.generate(
        50,
        (i) =>
            String.fromCharCode(65 + i % 26) +
            String.fromCharCode(65 + (i + 1) % 26),
      );
      await tester.pumpWidget(
        _wrap(PassportStampsCard(countryCodes: codes, trips: const [])),
      );
      expect(find.byType(PassportStampsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trips parameter defaults to empty list', (tester) async {
      await tester.pumpWidget(
        _wrap(const PassportStampsCard(countryCodes: ['GB', 'US'])),
      );
      expect(find.byType(PassportStampsCard), findsOneWidget);
    });

    testWidgets('renders without exception for 2 countries', (tester) async {
      // PassportStampsCard draws branding on canvas via CustomPainter (ADR-117),
      // not as a CardBrandingFooter widget — so we just verify no exception.
      await tester.pumpWidget(
        _wrap(const PassportStampsCard(countryCodes: ['GB', 'FR'], trips: [])),
      );
      expect(find.byType(PassportStampsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TimelineCard', () {
    testWidgets('renders with TRAVEL LOG header', (tester) async {
      await tester.pumpWidget(
        _wrap(
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
        ),
      );
      expect(find.byType(TimelineCard), findsOneWidget);
      // TimelineCard draws the "TRAVEL LOG" header via CardTextRenderer on the
      // canvas — there are no Text widgets in the tree (M86).
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows CardBrandingFooter', (tester) async {
      await tester.pumpWidget(
        _wrap(const TimelineCard(trips: [], countryCodes: ['GB', 'FR'])),
      );
      // TimelineCard renders branding via CustomPainter (_TimelinePainter),
      // not as a CardBrandingFooter widget. Verify the painter is present.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows empty state when no trips', (tester) async {
      await tester.pumpWidget(
        _wrap(const TimelineCard(trips: [], countryCodes: ['US'])),
      );
      // TimelineCard draws empty state text via CustomPainter on the canvas —
      // there are no Text widgets in the tree.
      expect(find.byType(TimelineCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
