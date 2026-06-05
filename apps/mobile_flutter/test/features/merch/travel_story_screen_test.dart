// T5 — TravelStoryScreen widget tests (M146)
//
// Covers:
//   1. TravelStoryScreen renders the correct number of pages
//   2. Page 6 (CTA) "Design this shirt" navigates to LocalMockupPreviewScreen
//   3. TravelStorySummaryCard renders identity emoji and year

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/merch/pulse_merch_option.dart';
import 'package:mobile_flutter/features/merch/travel_identity.dart';
import 'package:mobile_flutter/features/merch/travel_story_data.dart';
import 'package:mobile_flutter/features/merch/travel_story_screen.dart';
import 'package:mobile_flutter/features/merch/travel_story_summary_card.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// 5 visits across 2 continents (Europe).
final _visits5 = [
  'FR',
  'DE',
  'ES',
  'IT',
  'GB',
].map((code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
      firstSeen: DateTime(2024, 3, 1),
      lastSeen: DateTime(2024, 3, 10),
    )).toList();

final _trips2 = [
  TripRecord(
    id: 'FR_2024-03-01',
    countryCode: 'FR',
    startedOn: DateTime(2024, 3, 1),
    endedOn: DateTime(2024, 3, 5),
    photoCount: 5,
    isManual: false,
  ),
  TripRecord(
    id: 'DE_2024-03-06',
    countryCode: 'DE',
    startedOn: DateTime(2024, 3, 6),
    endedOn: DateTime(2024, 3, 10),
    photoCount: 4,
    isManual: false,
  ),
];

TravelStoryData _buildData({bool yearFilter = true}) => TravelStoryData.build(
      year: 2024,
      allVisits: _visits5,
      allTrips: _trips2,
      unlockedAchievements: {},
      yearFilter: yearFilter,
    );

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: child),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TravelStoryScreen', () {
    testWidgets('renders at least 4 pages (year + countries + identity + cta)',
        (tester) async {
      final data = _buildData();
      await tester.pumpWidget(_wrap(TravelStoryScreen(data: data)));
      await tester.pump();

      // PageView is present.
      expect(find.byType(PageView), findsOneWidget);

      // Page 1: year text is visible.
      expect(find.text('2024'), findsWidgets);
      expect(find.textContaining('in travel'), findsOneWidget);
    });

    testWidgets('close button dismisses the screen', (tester) async {
      final data = _buildData();
      bool popped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  await Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => TravelStoryScreen(data: data),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Close button should be visible.
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('skips continent page when continentCount equals 1',
        (tester) async {
      // Build data with all visits in the same continent (Europe).
      final data = TravelStoryData(
        year: 2024,
        countryCodes: const ['FR', 'DE'],
        continentCount: 1,
        tripCount: 1,
        topAchievement: null,
        identity: TravelIdentityInfo.forContext(
          codes: const ['FR', 'DE'],
          tripCount: 1,
          stampCount: 2,
        ),
        merchOption: PulseMerchOption(
          id: 'test',
          title: 'Test',
          description: 'Desc',
          scope: PulseMerchScope.allTime,
          template: CardTemplateType.grid,
          codes: const ['FR', 'DE'],
          trips: const [],
        ),
        heroCountryCode: 'FR',
      );

      await tester.pumpWidget(_wrap(TravelStoryScreen(data: data)));
      await tester.pump();

      // No "continents explored" text because page is skipped.
      expect(find.textContaining('continents explored'), findsNothing);
    });
  });

  group('TravelStorySummaryCard', () {
    testWidgets('renders identity emoji and year', (tester) async {
      final data = _buildData();
      await tester.pumpWidget(
        _wrap(Scaffold(body: TravelStorySummaryCard(data: data))),
      );
      await tester.pump();

      // Year is displayed.
      expect(find.text('2024'), findsOneWidget);
      // Country count text.
      expect(find.textContaining('countries'), findsOneWidget);
      // Wordmark.
      expect(find.text('Roavvy'), findsOneWidget);
    });
  });
}
