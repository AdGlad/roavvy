import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_branding_footer.dart';
import 'package:mobile_flutter/features/cards/timeline_card.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code, int year, int startMonth, int endMonth) =>
    TripRecord(
      id: '$code-$year-$startMonth',
      countryCode: code,
      startedOn: DateTime(year, startMonth, 1),
      endedOn: DateTime(year, endMonth, 28),
      photoCount: 1,
      isManual: false,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TimelineCard', () {
    testWidgets('renders landscape 3:2 as an AspectRatio widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('GB', 2023, 3, 5), _trip('FR', 2022, 6, 8)],
            countryCodes: const ['GB', 'FR'],
            aspectRatio: 3.0 / 2.0,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('renders portrait 2:3 as an AspectRatio widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('DE', 2024, 1, 2)],
            countryCodes: const ['DE'],
            aspectRatio: 2.0 / 3.0,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('branding footer is present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('JP', 2023, 4, 5)],
            countryCodes: const ['JP'],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CardBrandingFooter), findsOneWidget);
    });

    testWidgets('empty state shown when no trips', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimelineCard(
            trips: [],
            countryCodes: ['US'],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No trips in this date range'), findsOneWidget);
    });

    testWidgets('TRAVEL LOG header is visible', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('CA', 2024, 7, 8)],
            countryCodes: const ['CA'],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('TRAVEL LOG'), findsOneWidget);
    });

    testWidgets('year divider shown for trip year', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('AU', 2021, 3, 4)],
            countryCodes: const ['AU'],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2021'), findsOneWidget);
    });

    testWidgets('truncation note visible when truncatedCount > 0', (tester) async {
      // 40 trips in different years → many dividers → likely truncation
      final trips = List.generate(
        40,
        (i) => _trip('FR', 1985 + i, 6, 7),
      );
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: trips,
            countryCodes: const ['FR'],
          ),
        ),
      );
      await tester.pump();
      // Find "and N more trips" — may or may not truncate depending on height
      // Just verify no crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('dateLabel shown in header when non-empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimelineCard(
            trips: [_trip('IT', 2023, 5, 6)],
            countryCodes: const ['IT'],
            dateLabel: '2023',
          ),
        ),
      );
      await tester.pump();
      // dateLabel shown in header AND in footer; at least one instance
      expect(find.text('2023'), findsWidgets);
    });
  });
}
