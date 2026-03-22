import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/xp/xp_event.dart';
import 'package:mobile_flutter/features/xp/xp_notifier.dart';

RoavvyDatabase _openDb() => RoavvyDatabase(NativeDatabase.memory());

XpEvent _event({int amount = 50, XpReason reason = XpReason.newCountry}) =>
    XpEvent(
      id: 'test-${DateTime.now().microsecondsSinceEpoch}',
      reason: reason,
      amount: amount,
      awardedAt: DateTime.now().toUtc(),
    );

void main() {
  // ── xpStateFromTotal ────────────────────────────────────────────────────────

  group('xpStateFromTotal', () {
    test('level 1 at 0 XP', () {
      final s = xpStateFromTotal(0);
      expect(s.level, 1);
      expect(s.levelLabel, 'Explorer');
      expect(s.progressFraction, 0.0);
      expect(s.xpToNextLevel, 100);
    });

    test('level 1 at 99 XP', () {
      final s = xpStateFromTotal(99);
      expect(s.level, 1);
      expect(s.progressFraction, closeTo(0.99, 0.01));
    });

    test('level 2 at exactly 100 XP', () {
      final s = xpStateFromTotal(100);
      expect(s.level, 2);
      expect(s.levelLabel, 'Adventurer');
      expect(s.progressFraction, 0.0);
      expect(s.xpToNextLevel, 150);
    });

    test('level 3 at exactly 250 XP', () {
      final s = xpStateFromTotal(250);
      expect(s.level, 3);
      expect(s.levelLabel, 'Globetrotter');
    });

    test('level 4 at exactly 500 XP', () => expect(xpStateFromTotal(500).level, 4));
    test('level 5 at exactly 1000 XP', () => expect(xpStateFromTotal(1000).level, 5));
    test('level 6 at exactly 2000 XP', () => expect(xpStateFromTotal(2000).level, 6));
    test('level 7 at exactly 4000 XP', () => expect(xpStateFromTotal(4000).level, 7));

    test('level 8 (max) at exactly 8000 XP', () {
      final s = xpStateFromTotal(8000);
      expect(s.level, 8);
      expect(s.levelLabel, 'Legend');
      expect(s.progressFraction, 1.0);
      expect(s.xpToNextLevel, 0);
    });

    test('level 8 stays capped beyond 8000 XP', () {
      final s = xpStateFromTotal(99999);
      expect(s.level, 8);
      expect(s.progressFraction, 1.0);
    });

    test('mid-level progress fraction is correct', () {
      // L1=0, L2=100 → 50 XP is 50% of the way through level 1
      final s = xpStateFromTotal(50);
      expect(s.progressFraction, closeTo(0.5, 0.001));
    });
  });

  // ── XpRepository ────────────────────────────────────────────────────────────

  group('XpRepository', () {
    late RoavvyDatabase db;
    late XpRepository repo;

    setUp(() {
      db = _openDb();
      repo = XpRepository(db);
    });

    tearDown(() => db.close());

    test('totalXp returns 0 when empty', () async {
      expect(await repo.totalXp(), 0);
    });

    test('award inserts a row and totalXp reflects it', () async {
      await repo.award(_event(amount: 50));
      expect(await repo.totalXp(), 50);
    });

    test('multiple awards accumulate correctly', () async {
      await repo.award(_event(amount: 50));
      await repo.award(_event(amount: 25));
      await repo.award(_event(amount: 150));
      expect(await repo.totalXp(), 225);
    });

    test('loadAll returns events in awardedAt order', () async {
      final e1 = XpEvent(
        id: 'a',
        reason: XpReason.scanCompleted,
        amount: 25,
        awardedAt: DateTime(2024, 1, 1).toUtc(),
      );
      final e2 = XpEvent(
        id: 'b',
        reason: XpReason.newCountry,
        amount: 50,
        awardedAt: DateTime(2024, 1, 2).toUtc(),
      );
      await repo.award(e2);
      await repo.award(e1);
      final all = await repo.loadAll();
      expect(all.first.id, 'a');
      expect(all.last.id, 'b');
    });

    test('clearAll removes all rows', () async {
      await repo.award(_event(amount: 100));
      await repo.clearAll();
      expect(await repo.totalXp(), 0);
      expect(await repo.loadAll(), isEmpty);
    });
  });

  // ── XpNotifier ──────────────────────────────────────────────────────────────

  group('XpNotifier', () {
    late RoavvyDatabase db;
    late XpRepository repo;
    late XpNotifier notifier;

    setUp(() {
      db = _openDb();
      repo = XpRepository(db);
      notifier = XpNotifier(repo);
    });

    tearDown(() {
      notifier.dispose();
      db.close();
    });

    test('initial state is level 1 with zero XP', () async {
      // Give notifier time to load from empty DB.
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.totalXp, 0);
      expect(notifier.state.level, 1);
    });

    test('award updates state and emits on xpEarned stream', () async {
      final earned = <int>[];
      notifier.xpEarned.listen(earned.add);

      await notifier.award(_event(amount: 50));

      expect(notifier.state.totalXp, 50);
      expect(earned, [50]);
    });

    test('reaching level 2 threshold updates level in state', () async {
      await notifier.award(_event(amount: 100));
      expect(notifier.state.level, 2);
    });

    test('award does not throw when called with unawaited pattern', () async {
      // ignore: unawaited_futures
      expect(() => notifier.award(_event(amount: 25)), returnsNormally);
      await Future<void>.delayed(Duration.zero);
    });
  });
}
