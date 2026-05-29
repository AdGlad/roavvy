import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/challenge/daily_challenge_stats.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());
ChallengeStatsService _makeService([RoavvyDatabase? db]) =>
    ChallengeStatsService(db ?? _makeDb());

String _date(int daysAgo) {
  final d = DateTime.now().toUtc().subtract(Duration(days: daysAgo));
  return DateFormat('yyyy-MM-dd').format(d);
}

Future<void> _record(
  ChallengeStatsService svc, {
  required int daysAgo,
  required bool solved,
  int guesses = 0,
  int clues = 1,
}) =>
    svc.record(
      date: _date(daysAgo),
      siteId: 'test-$daysAgo',
      solved: solved,
      guessesUsed: guesses,
      cluesUsed: clues,
    );

void main() {
  group('ChallengeStatsService.last30Days', () {
    test('returns empty list when no rows', () async {
      final svc = _makeService();
      final result = await svc.last30Days();
      expect(result, isEmpty);
    });

    test('returns at most 30 rows even with more data', () async {
      final db = _makeDb();
      final svc = _makeService(db);
      for (var i = 0; i < 40; i++) {
        await _record(svc, daysAgo: i, solved: true);
      }
      final result = await svc.last30Days();
      expect(result.length, lessThanOrEqualTo(30));
    });

    test('rows are in descending date order', () async {
      final db = _makeDb();
      final svc = _makeService(db);
      await _record(svc, daysAgo: 2, solved: true);
      await _record(svc, daysAgo: 0, solved: false);
      await _record(svc, daysAgo: 1, solved: true);

      final result = await svc.last30Days();
      expect(result.length, equals(3));
      // First row should be most recent (daysAgo=0)
      expect(result[0].date, equals(_date(0)));
      expect(result[1].date, equals(_date(1)));
      expect(result[2].date, equals(_date(2)));
    });

    test('solved flag and guessesUsed are preserved correctly', () async {
      final db = _makeDb();
      final svc = _makeService(db);
      await _record(svc, daysAgo: 0, solved: true, guesses: 3);
      await _record(svc, daysAgo: 1, solved: false, guesses: 5);

      final result = await svc.last30Days();
      expect(result[0].solved, isTrue);
      expect(result[0].guessesUsed, equals(3));
      expect(result[1].solved, isFalse);
      expect(result[1].guessesUsed, equals(5));
    });
  });

  group('ChallengeStatsService.loadAggregate', () {
    test('streak is 0 when nothing recorded', () async {
      final agg = await _makeService().loadAggregate();
      expect(agg.currentStreak, equals(0));
      expect(agg.bestStreak, equals(0));
    });

    test('streak counts consecutive solved days from today', () async {
      final db = _makeDb();
      final svc = _makeService(db);
      // Today + previous 2 days solved
      await _record(svc, daysAgo: 0, solved: true);
      await _record(svc, daysAgo: 1, solved: true);
      await _record(svc, daysAgo: 2, solved: true);
      // Gap at day 3, then solved at day 4 — does not extend streak
      await _record(svc, daysAgo: 4, solved: true);

      final agg = await svc.loadAggregate();
      expect(agg.currentStreak, equals(3));
      // Gap at day 3 means days 0,1,2 form a run of 3; day 4 alone is 1. Best = 3.
      expect(agg.bestStreak, equals(3));
    });

    test('failed day breaks current streak', () async {
      final db = _makeDb();
      final svc = _makeService(db);
      await _record(svc, daysAgo: 0, solved: true);
      await _record(svc, daysAgo: 1, solved: false); // failed breaks streak
      await _record(svc, daysAgo: 2, solved: true);

      final agg = await svc.loadAggregate();
      expect(agg.currentStreak, equals(1)); // only today
    });
  });
}
