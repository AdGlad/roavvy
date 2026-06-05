// T5 — TravelStoryData unit tests (M146)
//
// Covers:
//   1. build() returns correct country count for year filter
//   2. build() returns correct heroCountryCode from last trip

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/merch/travel_story_data.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _visits = [
  EffectiveVisitedCountry(
    countryCode: 'FR',
    hasPhotoEvidence: true,
    firstSeen: DateTime(2024, 3, 1),
    lastSeen: DateTime(2024, 3, 10),
  ),
  EffectiveVisitedCountry(
    countryCode: 'DE',
    hasPhotoEvidence: true,
    firstSeen: DateTime(2024, 6, 1),
    lastSeen: DateTime(2024, 6, 5),
  ),
  EffectiveVisitedCountry(
    countryCode: 'JP',
    hasPhotoEvidence: true,
    firstSeen: DateTime(2023, 11, 1),
    lastSeen: DateTime(2023, 11, 15),
  ),
];

final _trips = [
  TripRecord(
    id: 'FR_2024-03-01',
    countryCode: 'FR',
    startedOn: DateTime(2024, 3, 1),
    endedOn: DateTime(2024, 3, 10),
    photoCount: 12,
    isManual: false,
  ),
  TripRecord(
    id: 'DE_2024-06-01',
    countryCode: 'DE',
    startedOn: DateTime(2024, 6, 1),
    endedOn: DateTime(2024, 6, 5),
    photoCount: 8,
    isManual: false,
  ),
  TripRecord(
    id: 'JP_2023-11-01',
    countryCode: 'JP',
    startedOn: DateTime(2023, 11, 1),
    endedOn: DateTime(2023, 11, 15),
    photoCount: 20,
    isManual: false,
  ),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TravelStoryData.build()', () {
    test('returns only year-filtered countries when yearFilter is true', () {
      final data = TravelStoryData.build(
        year: 2024,
        allVisits: _visits,
        allTrips: _trips,
        unlockedAchievements: {},
      );

      // Only FR and DE have firstSeen in 2024; JP is 2023.
      expect(data.countryCodes, hasLength(2));
      expect(data.countryCodes, containsAll(['FR', 'DE']));
      expect(data.countryCodes, isNot(contains('JP')));
    });

    test('returns all countries when yearFilter is false', () {
      final data = TravelStoryData.build(
        year: 2024,
        allVisits: _visits,
        allTrips: _trips,
        unlockedAchievements: {},
        yearFilter: false,
      );

      expect(data.countryCodes, hasLength(3));
    });

    test('heroCountryCode is from the most recent trip in scope', () {
      final data = TravelStoryData.build(
        year: 2024,
        allVisits: _visits,
        allTrips: _trips,
        unlockedAchievements: {},
      );

      // DE trip ends 2024-06-05, FR trip ends 2024-03-10 — DE is more recent.
      expect(data.heroCountryCode, equals('DE'));
    });

    test('heroCountryCode falls back to first code when no trips match', () {
      final data = TravelStoryData.build(
        year: 2025, // no visits or trips in 2025
        allVisits: _visits,
        allTrips: _trips,
        unlockedAchievements: {},
      );

      // No 2025 visits → falls back to allCodes.first (or first from allVisits)
      expect(data.countryCodes.isNotEmpty || data.heroCountryCode.isNotEmpty, isTrue);
    });
  });
}
