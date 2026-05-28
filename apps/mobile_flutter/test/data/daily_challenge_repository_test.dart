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
}
