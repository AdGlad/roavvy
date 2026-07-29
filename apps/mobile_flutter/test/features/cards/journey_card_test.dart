import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/journey_card.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code, int year) => TripRecord(
      id: '${code}_$year',
      countryCode: code,
      startedOn: DateTime(year, 6, 1),
      endedOn: DateTime(year, 6, 8),
      photoCount: 3,
      isManual: false,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
    );

void main() {
  group('JourneyCard.tripYears', () {
    test('returns distinct years, ascending', () {
      final trips = [
        _trip('FR', 2022),
        _trip('JP', 2020),
        _trip('KE', 2022),
        _trip('AU', 2018),
      ];
      expect(JourneyCard.tripYears(trips), [2018, 2020, 2022]);
    });

    test('empty for no trips', () {
      expect(JourneyCard.tripYears(const []), isEmpty);
    });
  });

  group('JourneyCard rendering', () {
    testWidgets('renders flags style without exception', (tester) async {
      await tester.pumpWidget(
        _wrap(const JourneyCard(countryCodes: ['US', 'FR', 'KE', 'AU'])),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders trips style without exception', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            countryCodes: const ['US', 'FR'],
            trips: [_trip('US', 2019), _trip('FR', 2021), _trip('JP', 2023)],
            style: JourneyStyle.trips,
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trips style with a year filter renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            countryCodes: const ['US', 'FR'],
            trips: [_trip('US', 2019), _trip('FR', 2021), _trip('JP', 2023)],
            style: JourneyStyle.trips,
            yearRange: (2020, 2023),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scales to fit a large trip history without exception',
        (tester) async {
      // 80 trips spanning 2010–2026 — previously truncated at 30 (oldest first).
      final many = [
        for (var i = 0; i < 80; i++)
          _trip(['US', 'FR', 'JP', 'KE', 'AU', 'BR'][i % 6], 2010 + i % 17),
      ];
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            countryCodes: const ['US', 'FR'],
            trips: many,
            style: JourneyStyle.trips,
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caps an extreme trip history (150) without exception',
        (tester) async {
      final huge = [
        for (var i = 0; i < 150; i++)
          _trip(['US', 'FR', 'JP'][i % 3], 2005 + i % 22),
      ];
      await tester.pumpWidget(
        _wrap(JourneyCard(
          countryCodes: const ['US'],
          trips: huge,
          style: JourneyStyle.trips,
        )),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with a single stop', (tester) async {
      await tester.pumpWidget(_wrap(const JourneyCard(countryCodes: ['JP'])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with no countries/trips', (tester) async {
      await tester.pumpWidget(_wrap(const JourneyCard(countryCodes: [])));
      expect(tester.takeException(), isNull);
    });
  });
}
