import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2020, 3, 15);
  final t1 = DateTime.utc(2022, 8, 1);
  final t2 = DateTime.utc(2024, 12, 25);
  final now = DateTime.utc(2025, 1, 1);

  EffectiveVisitedCountry visit(
    String code, {
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) =>
      EffectiveVisitedCountry(
        countryCode: code,
        hasPhotoEvidence: firstSeen != null || lastSeen != null,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
        photoCount: firstSeen != null ? 1 : 0,
      );

  group('TravelSummary.fromVisits', () {
    test('empty visit list produces zero counts and null dates', () {
      final s = TravelSummary.fromVisits([], now: now);
      expect(s.countryCount, 0);
      expect(s.visitedCodes, isEmpty);
      expect(s.earliestVisit, isNull);
      expect(s.latestVisit, isNull);
      expect(s.computedAt, now);
    });

    test('country codes are sorted alphabetically', () {
      final s = TravelSummary.fromVisits(
        [visit('US'), visit('GB'), visit('JP')],
        now: now,
      );
      expect(s.visitedCodes, ['GB', 'JP', 'US']);
    });

    test('countryCount matches visitedCodes length', () {
      final s = TravelSummary.fromVisits(
        [visit('GB'), visit('JP'), visit('FR')],
        now: now,
      );
      expect(s.countryCount, 3);
    });

    test('earliestVisit is the minimum firstSeen across all visits', () {
      final s = TravelSummary.fromVisits([
        visit('GB', firstSeen: t1, lastSeen: t2),
        visit('JP', firstSeen: t0, lastSeen: t1),
      ], now: now);
      expect(s.earliestVisit, t0);
    });

    test('latestVisit is the maximum lastSeen across all visits', () {
      final s = TravelSummary.fromVisits([
        visit('GB', firstSeen: t0, lastSeen: t1),
        visit('JP', firstSeen: t1, lastSeen: t2),
      ], now: now);
      expect(s.latestVisit, t2);
    });

    test('visits without date metadata do not affect date range', () {
      final s = TravelSummary.fromVisits([
        visit('GB', firstSeen: t0, lastSeen: t1),
        visit('FR'), // manually added — no photo evidence, null dates
      ], now: now);
      expect(s.earliestVisit, t0);
      expect(s.latestVisit, t1);
      expect(s.countryCount, 2);
    });

    test('all visits without dates yield null date range', () {
      final s = TravelSummary.fromVisits(
        [visit('GB'), visit('JP')],
        now: now,
      );
      expect(s.earliestVisit, isNull);
      expect(s.latestVisit, isNull);
    });

    test('single visit with only firstSeen', () {
      final s = TravelSummary.fromVisits(
        [visit('GB', firstSeen: t0)],
        now: now,
      );
      expect(s.earliestVisit, t0);
      expect(s.latestVisit, t0); // only one date in pool
    });
  });
}
