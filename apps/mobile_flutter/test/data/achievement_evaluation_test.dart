/// Tests that verify the evaluate-and-upsert pattern used at each write site
/// (scan and review). These are repository-level unit tests that mirror the
/// logic in [_ScanScreenState._scan] and [_ReviewScreenState._save].
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── Scan site ─────────────────────────────────────────────────────────────

  group('evaluate-and-upsert at scan site', () {
    test('newly resolved countries unlock matching achievements', () async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);
      final now = DateTime.utc(2025, 6, 1);

      // Simulate what _scan() does: save inferred visits, load effective,
      // evaluate engine, upsert newly unlocked IDs.
      await visitRepo.saveAllInferred([
        InferredCountryVisit(countryCode: 'GB', inferredAt: now, photoCount: 2),
        InferredCountryVisit(countryCode: 'FR', inferredAt: now, photoCount: 1),
        InferredCountryVisit(countryCode: 'DE', inferredAt: now, photoCount: 3),
        InferredCountryVisit(countryCode: 'ES', inferredAt: now, photoCount: 1),
        InferredCountryVisit(countryCode: 'IT', inferredAt: now, photoCount: 1),
      ]);

      final effective = await visitRepo.loadEffective();
      final priorIds = (await achievementRepo.loadAll()).toSet();
      final unlockedIds = AchievementEngine.evaluate(effective);
      final newlyUnlockedIds = unlockedIds.difference(priorIds);
      if (newlyUnlockedIds.isNotEmpty) {
        await achievementRepo.upsertAll(newlyUnlockedIds, now);
      }

      final stored = await achievementRepo.loadAll();
      expect(stored, containsAll(['countries_1', 'countries_5']));
      expect(stored, isNot(contains('countries_10')));
    });

    test('second scan does not re-dirty already-unlocked achievements', () async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);
      final now = DateTime.utc(2025, 6, 1);

      // First scan — unlock countries_1 and mark it clean (simulating a sync).
      await visitRepo.saveAllInferred([
        InferredCountryVisit(countryCode: 'GB', inferredAt: now, photoCount: 1),
      ]);
      await achievementRepo.upsertAll({'countries_1'}, now);
      await achievementRepo.markClean('countries_1', now);
      expect(await achievementRepo.loadDirty(), isEmpty);

      // Second scan — same single country, no new achievements.
      final effective = await visitRepo.loadEffective();
      final priorIds = (await achievementRepo.loadAll()).toSet();
      final unlockedIds = AchievementEngine.evaluate(effective);
      final newlyUnlockedIds = unlockedIds.difference(priorIds);
      if (newlyUnlockedIds.isNotEmpty) {
        await achievementRepo.upsertAll(newlyUnlockedIds, now);
      }

      // countries_1 was already known — not re-dirtied.
      expect(await achievementRepo.loadDirty(), isEmpty);
    });
  });
}
