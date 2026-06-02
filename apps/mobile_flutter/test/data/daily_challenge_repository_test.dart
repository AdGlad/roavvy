import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/daily_challenge_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:shared_models/shared_models.dart';

DailyChallengeRepository _makeRepo() =>
    DailyChallengeRepository(RoavvyDatabase(NativeDatabase.memory()));

void main() {
  group('DailyChallengeRepository', () {
    test('loadToday returns null when no row exists', () async {
      final repo = _makeRepo();
      final result = await repo.loadToday('2026-05-27');
      expect(result, isNull);
    });

    test('save then loadToday round-trips all fields', () async {
      final repo = _makeRepo();
      const progress = DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '86',
        cluesRevealed: 3,
        guesses: ['Taj Mahal', 'Giza'],
        solved: false,
      );
      await repo.save(progress);

      final loaded = await repo.loadToday('2026-05-27');
      expect(loaded, isNotNull);
      expect(loaded!.date, '2026-05-27');
      expect(loaded.siteId, '86');
      expect(loaded.cluesRevealed, 3);
      expect(loaded.guesses, ['Taj Mahal', 'Giza']);
      expect(loaded.solved, false);
      expect(loaded.solvedAtClue, isNull);
    });

    test('save solved progress round-trips solvedAtClue', () async {
      final repo = _makeRepo();
      const progress = DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '86',
        cluesRevealed: 2,
        guesses: ['Wrong guess'],
        solved: true,
        solvedAtClue: 2,
      );
      await repo.save(progress);

      final loaded = await repo.loadToday('2026-05-27');
      expect(loaded!.solved, true);
      expect(loaded.solvedAtClue, 2);
    });

    test('loadToday returns null for a different date', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '86',
        cluesRevealed: 1,
        guesses: [],
        solved: false,
      ));

      final other = await repo.loadToday('2026-05-26');
      expect(other, isNull);
    });

    test('save overwrites existing row for same date', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '86',
        cluesRevealed: 1,
        guesses: [],
        solved: false,
      ));
      await repo.save(const DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '86',
        cluesRevealed: 4,
        guesses: ['Wrong'],
        solved: true,
        solvedAtClue: 4,
      ));

      final loaded = await repo.loadToday('2026-05-27');
      expect(loaded!.cluesRevealed, 4);
      expect(loaded.solved, true);
    });

    test('guesses JSON round-trips with special characters', () async {
      final repo = _makeRepo();
      final guesses = ['Café de Flore', "d'Orbigny", 'Angkor\nWat'];
      await repo.save(DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '200',
        cluesRevealed: 5,
        guesses: guesses,
        solved: false,
      ));
      final loaded = await repo.loadToday('2026-05-27');
      expect(loaded!.guesses, guesses);
    });
  });

  // T3.6 — Daily challenge repository additional coverage ───────────────────

  group('DailyChallengeRepository.deleteProgress', () {
    test('deleteProgress removes the row; loadToday returns null', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-06-01',
        siteId: '42',
        cluesRevealed: 1,
        guesses: [],
        solved: false,
      ));
      await repo.deleteProgress('2026-06-01');
      expect(await repo.loadToday('2026-06-01'), isNull);
    });

    test('deleteProgress for non-existent date is a no-op', () async {
      final repo = _makeRepo();
      await expectLater(repo.deleteProgress('2099-01-01'), completes);
    });

    test('deleteProgress only removes the specified date', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-06-01',
        siteId: '42',
        cluesRevealed: 1,
        guesses: [],
        solved: false,
      ));
      await repo.save(const DailyChallengeProgress(
        date: '2026-06-02',
        siteId: '43',
        cluesRevealed: 2,
        guesses: ['Wrong'],
        solved: false,
      ));
      await repo.deleteProgress('2026-06-01');
      expect(await repo.loadToday('2026-06-01'), isNull);
      expect(await repo.loadToday('2026-06-02'), isNotNull);
    });
  });

  group('DailyChallengeRepository — failed flag', () {
    test('failed flag round-trips correctly', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-06-03',
        siteId: '99',
        cluesRevealed: 5,
        guesses: ['Wrong 1', 'Wrong 2'],
        solved: false,
        failed: true,
      ));
      final loaded = await repo.loadToday('2026-06-03');
      expect(loaded!.failed, isTrue);
    });

    test('failed defaults to false when not set', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-06-04',
        siteId: '100',
        cluesRevealed: 1,
        guesses: [],
        solved: false,
      ));
      final loaded = await repo.loadToday('2026-06-04');
      expect(loaded!.failed, isFalse);
    });
  });

  group('DailyChallengeRepository — multiple dates', () {
    test('progress for multiple dates coexist without conflict', () async {
      final repo = _makeRepo();
      const dates = ['2026-06-01', '2026-06-02', '2026-06-03'];
      for (var i = 0; i < dates.length; i++) {
        await repo.save(DailyChallengeProgress(
          date: dates[i],
          siteId: '${i + 1}',
          cluesRevealed: i,
          guesses: [],
          solved: false,
        ));
      }
      for (var i = 0; i < dates.length; i++) {
        final loaded = await repo.loadToday(dates[i]);
        expect(loaded, isNotNull);
        expect(loaded!.siteId, '${i + 1}');
      }
    });

    test('loading progress for a date not saved returns null', () async {
      final repo = _makeRepo();
      await repo.save(const DailyChallengeProgress(
        date: '2026-06-01',
        siteId: '1',
        cluesRevealed: 0,
        guesses: [],
        solved: false,
      ));
      expect(await repo.loadToday('2026-06-02'), isNull);
    });
  });
}
