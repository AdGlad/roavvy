import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/daily_challenge_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_notifier.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_stats.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());
DailyChallengeRepository _makeRepo([RoavvyDatabase? db]) =>
    DailyChallengeRepository(db ?? _makeDb());
ChallengeStatsService _makeStats([RoavvyDatabase? db]) =>
    ChallengeStatsService(db ?? _makeDb());

const _challenge = DailyChallenge(
  siteId: '86',
  clues: [
    ChallengeClue(type: 'geography', text: 'clue1'),
    ChallengeClue(type: 'category', text: 'clue2'),
    ChallengeClue(type: 'historical', text: 'clue3'),
    ChallengeClue(type: 'location', text: 'clue4'),
    ChallengeClue(type: 'direct', text: 'clue5'),
  ],
);

const _site = WorldHeritageSite(
  siteId: '86',
  name: 'Petra',
  latitude: 30.3285,
  longitude: 35.4444,
  countryCode: 'JO',
  inscriptionYear: 1985,
  category: 'Cultural',
  region: 'Arab States',
);

DailyChallengeProgress _freshProgress(String date) => DailyChallengeProgress(
      date: date,
      siteId: '86',
      cluesRevealed: 1,
      guesses: const [],
      solved: false,
    );

DailyChallengeNotifier _makeNotifier({
  DailyChallengeProgress? savedProgress,
  DailyChallengeRepository? repo,
  List<WorldHeritageSite> allSites = const [],
}) {
  final db = _makeDb();
  final date = '2026-05-27';
  final progress = savedProgress ?? _freshProgress(date);
  final state = DailyChallengeState(
    challenge: _challenge,
    progress: progress,
    site: _site,
  );
  return DailyChallengeNotifier(
    initial: AsyncValue.data(state),
    repo: repo ?? _makeRepo(db),
    allSites: [...allSites, _site],
    statsService: _makeStats(db),
  );
}

void main() {
  group('buildInitialChallengeState', () {
    test('uses saved progress when available', () {
      const saved = DailyChallengeProgress(
        date: '2026-05-27',
        siteId: '86',
        cluesRevealed: 3,
        guesses: ['Colosseum'],
        solved: false,
      );
      final state = buildInitialChallengeState(
        challenge: _challenge,
        savedProgress: saved,
        allSites: [_site],
      );
      expect(state.progress.cluesRevealed, 3);
      expect(state.progress.guesses, ['Colosseum']);
    });

    test('defaults to cluesRevealed=1 when no saved progress', () {
      final state = buildInitialChallengeState(
        challenge: _challenge,
        savedProgress: null,
        allSites: [_site],
      );
      expect(state.progress.cluesRevealed, 1);
      expect(state.progress.guesses, isEmpty);
    });

    test('throws StateError when site not in allSites', () {
      expect(
        () => buildInitialChallengeState(
          challenge: _challenge,
          savedProgress: null,
          allSites: const [],
        ),
        throwsStateError,
      );
    });
  });

  group('DailyChallengeNotifier.revealNextClue', () {
    test('increments cluesRevealed', () async {
      final notifier = _makeNotifier();
      await notifier.revealNextClue();
      expect(notifier.state.valueOrNull?.progress.cluesRevealed, 2);
    });

    test('does not exceed 5 clues', () async {
      final progress = _freshProgress('2026-05-27').copyWith(cluesRevealed: 5);
      final notifier = _makeNotifier(savedProgress: progress);
      await notifier.revealNextClue();
      expect(notifier.state.valueOrNull?.progress.cluesRevealed, 5);
    });

    test('no-op when already solved', () async {
      final progress =
          _freshProgress('2026-05-27').copyWith(solved: true, solvedAtClue: 1);
      final notifier = _makeNotifier(savedProgress: progress);
      await notifier.revealNextClue();
      expect(notifier.state.valueOrNull?.progress.cluesRevealed, 1);
    });
  });

  group('DailyChallengeNotifier.submitGuess', () {
    test('correct guess sets solved=true and returns true', () async {
      final notifier = _makeNotifier();
      final result = await notifier.submitGuess('petra');
      expect(result, isTrue);
      expect(notifier.state.valueOrNull?.progress.solved, isTrue);
    });

    test('correct guess is case-insensitive', () async {
      final notifier = _makeNotifier();
      final result = await notifier.submitGuess('PETRA');
      expect(result, isTrue);
    });

    test('wrong guess adds to guesses list and returns false', () async {
      final notifier = _makeNotifier();
      final result = await notifier.submitGuess('Colosseum');
      expect(result, isFalse);
      expect(notifier.state.valueOrNull?.progress.guesses, ['Colosseum']);
      expect(notifier.state.valueOrNull?.progress.solved, isFalse);
    });

    test('no-op when already solved', () async {
      final progress =
          _freshProgress('2026-05-27').copyWith(solved: true, solvedAtClue: 1);
      final notifier = _makeNotifier(savedProgress: progress);
      final result = await notifier.submitGuess('petra');
      expect(result, isFalse);
    });

    test('records solvedAtClue correctly', () async {
      final progress = _freshProgress('2026-05-27').copyWith(cluesRevealed: 3);
      final notifier = _makeNotifier(savedProgress: progress);
      await notifier.submitGuess('petra');
      expect(notifier.state.valueOrNull?.progress.solvedAtClue, 3);
    });

    test('5th wrong guess sets failed=true', () async {
      final notifier = _makeNotifier(
        allSites: [
          const WorldHeritageSite(
            siteId: '999', name: 'Wrong Site', countryCode: 'FR',
            latitude: 48.8566, longitude: 2.3522,
            category: 'cultural', region: 'Europe', inscriptionYear: 2000,
          ),
        ],
      );
      for (var i = 0; i < 5; i++) {
        await notifier.submitGuess('Wrong Site');
      }
      expect(notifier.state.valueOrNull?.progress.failed, isTrue);
      expect(notifier.state.valueOrNull?.progress.guesses.length, 5);
    });

    test('no-op after failed', () async {
      final progress = _freshProgress('2026-05-27').copyWith(
        guesses: ['a', 'b', 'c', 'd', 'e'],
        failed: true,
      );
      final notifier = _makeNotifier(savedProgress: progress);
      final result = await notifier.submitGuess('petra');
      expect(result, isFalse);
      expect(notifier.state.valueOrNull?.progress.guesses.length, 5);
    });

    test('wrong guess populates lastGuessResult when guessed site known', () async {
      final notifier = _makeNotifier(
        allSites: [
          const WorldHeritageSite(
            siteId: '200', name: 'Some Other Site', countryCode: 'FR',
            latitude: 48.8566, longitude: 2.3522,
            category: 'cultural', region: 'Europe', inscriptionYear: 2000,
          ),
        ],
      );
      await notifier.submitGuess('Some Other Site');
      final result = notifier.state.valueOrNull?.lastGuessResult;
      expect(result, isNotNull);
      expect(result!.distanceKm, greaterThan(0));
      expect(result.direction, isNotEmpty);
      expect(result.hotColdLabel, isNotEmpty);
    });
  });

  group('DailyChallengeNotifier.update', () {
    test('does not regress from data to loading', () {
      final notifier = _makeNotifier();
      // State is already data — sending loading should be ignored.
      notifier.update(const AsyncValue.loading());
      expect(notifier.state, isA<AsyncData<DailyChallengeState>>());
    });

    test('accepts new data state', () {
      final notifier = _makeNotifier();
      final newProgress =
          _freshProgress('2026-05-27').copyWith(cluesRevealed: 2);
      final newState = DailyChallengeState(
        challenge: _challenge,
        progress: newProgress,
        site: _site,
      );
      notifier.update(AsyncValue.data(newState));
      expect(notifier.state.valueOrNull?.progress.cluesRevealed, 2);
    });
  });
}
