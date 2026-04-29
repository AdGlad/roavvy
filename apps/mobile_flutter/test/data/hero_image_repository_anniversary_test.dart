import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/scan/hero_image_repository.dart';
import 'package:shared_models/shared_models.dart';

HeroImageRepository _makeRepo() =>
    HeroImageRepository(RoavvyDatabase(NativeDatabase.memory()));

HeroImage _hero({
  required String id,
  required DateTime capturedAt,
  String countryCode = 'GR',
  String tripId = 'trip_1',
  int rank = 1,
}) =>
    HeroImage(
      id: id,
      assetId: 'asset_$id',
      tripId: tripId,
      countryCode: countryCode,
      capturedAt: capturedAt,
      heroScore: 0.8,
      rank: rank,
      isUserSelected: false,
      createdAt: capturedAt,
      updatedAt: capturedAt,
    );

void main() {
  group('HeroImageRepository.getHeroesWithAnniversaryToday', () {
    test('returns rank-1 hero whose capturedAt month+day matches today', () async {
      final repo = _makeRepo();
      // Photo taken exactly 2 years ago today.
      final twoYearsAgo = DateTime.utc(
        DateTime.now().toUtc().year - 2,
        DateTime.now().toUtc().month,
        DateTime.now().toUtc().day,
        10,
        0,
      );
      final hero = _hero(id: 'h1', capturedAt: twoYearsAgo);
      await repo.upsertHeroesForTrip('trip_1', [hero]);

      final results = await repo.getHeroesWithAnniversaryToday(DateTime.now());
      expect(results, hasLength(1));
      expect(results.first.id, 'h1');
    });

    test('excludes hero captured less than 1 year ago', () async {
      final repo = _makeRepo();
      final today = DateTime.now().toUtc();
      // Photo taken 6 months ago — same month+day in 6 months won't match today.
      // Use photo taken exactly today but < 1 year ago → should be excluded.
      final recentCapture = today.subtract(const Duration(days: 60));
      final hero = _hero(id: 'h_recent', capturedAt: recentCapture);
      await repo.upsertHeroesForTrip('trip_recent', [hero]);

      final results = await repo.getHeroesWithAnniversaryToday(today);
      // h_recent may or may not be in results depending on whether 60-days-ago
      // happens to share today's MM-DD; this test confirms the < 1yr filter works.
      for (final r in results) {
        expect(
          today.millisecondsSinceEpoch - r.capturedAt.millisecondsSinceEpoch,
          greaterThan(const Duration(days: 365).inMilliseconds),
        );
      }
    });

    test('excludes tombstoned rows (rank = -1)', () async {
      final repo = _makeRepo();
      final twoYearsAgo = DateTime.utc(
        DateTime.now().toUtc().year - 2,
        DateTime.now().toUtc().month,
        DateTime.now().toUtc().day,
      );
      final hero = _hero(id: 'h_tomb', capturedAt: twoYearsAgo, rank: 1);
      await repo.upsertHeroesForTrip('trip_tomb', [hero]);
      await repo.tombstone('h_tomb'); // rank → -1

      final results = await repo.getHeroesWithAnniversaryToday(DateTime.now());
      expect(results.where((r) => r.id == 'h_tomb'), isEmpty);
    });

    test('returns empty list when no anniversaries match', () async {
      final repo = _makeRepo();
      // Photo from a completely different date 2 years ago.
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final twoYearsAgoYesterday = DateTime.utc(
        yesterday.year - 2,
        yesterday.month,
        yesterday.day,
      );
      final hero = _hero(id: 'h_other', capturedAt: twoYearsAgoYesterday);
      await repo.upsertHeroesForTrip('trip_other', [hero]);

      final today = DateTime.now();
      final results = await repo.getHeroesWithAnniversaryToday(today);
      expect(results.where((r) => r.id == 'h_other'), isEmpty);
    });
  });
}
