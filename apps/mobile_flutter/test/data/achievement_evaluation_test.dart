/// Tests that verify the evaluate-and-upsert pattern used at each write site
/// (scan and review). These are repository-level unit tests that mirror the
/// logic in [_ScanScreenState._scan] and [_ReviewScreenState._save].
///
/// T2.9 — AchievementEngine.evaluate() boundary conditions are also tested
/// here as pure unit tests (no DB required).
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

// ── T2.9 helpers ────────────────────────────────────────────────────────────

EffectiveVisitedCountry _visit(String code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
    );

List<EffectiveVisitedCountry> _visits(List<String> codes) =>
    codes.map(_visit).toList();

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── T2.9 — AchievementEngine.evaluate() boundary conditions ──────────────

  group('AchievementEngine.evaluate — country count boundaries', () {
    test('0 countries → no country achievements', () {
      final unlocked = AchievementEngine.evaluate([]);
      expect(unlocked, isNot(contains('countries_1')));
    });

    test('1 country → countries_1 only (not countries_3)', () {
      final unlocked = AchievementEngine.evaluate(_visits(['GB']));
      expect(unlocked, contains('countries_1'));
      expect(unlocked, isNot(contains('countries_3')));
    });

    test('2 countries → countries_1 but not countries_3', () {
      final unlocked = AchievementEngine.evaluate(_visits(['GB', 'FR']));
      expect(unlocked, contains('countries_1'));
      expect(unlocked, isNot(contains('countries_3')));
    });

    test('3 countries → countries_1 and countries_3 (exact threshold)', () {
      final unlocked = AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE']));
      expect(unlocked, containsAll(['countries_1', 'countries_3']));
      expect(unlocked, isNot(contains('countries_5')));
    });

    test('4 countries → countries_3 but not countries_5', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE', 'ES']));
      expect(unlocked, contains('countries_3'));
      expect(unlocked, isNot(contains('countries_5')));
    });

    test('5 countries → countries_5 (exact threshold)', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE', 'ES', 'IT']));
      expect(unlocked, containsAll(['countries_1', 'countries_3', 'countries_5']));
      expect(unlocked, isNot(contains('countries_10')));
    });

    test('10 countries → countries_10 (exact threshold)', () {
      final codes = ['GB', 'FR', 'DE', 'ES', 'IT', 'PT', 'NL', 'BE', 'CH', 'AT'];
      final unlocked = AchievementEngine.evaluate(_visits(codes));
      expect(unlocked, contains('countries_10'));
      expect(unlocked, isNot(contains('countries_15')));
    });

    test('50 countries → countries_50 (exact threshold)', () {
      final codes = List.generate(50, (i) => 'C${i.toString().padLeft(2, '0')}');
      final unlocked = AchievementEngine.evaluate(_visits(codes));
      expect(unlocked, contains('countries_50'));
      expect(unlocked, isNot(contains('countries_75')));
    });

    test('49 countries → not countries_50', () {
      final codes = List.generate(49, (i) => 'C${i.toString().padLeft(2, '0')}');
      final unlocked = AchievementEngine.evaluate(_visits(codes));
      expect(unlocked, isNot(contains('countries_50')));
    });
  });

  group('AchievementEngine.evaluate — continent count boundaries', () {
    // GB=Europe, JP=Asia, ZA=Africa, US=North America, BR=South America
    test('1 continent → no continent count achievement', () {
      final unlocked = AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE']));
      expect(unlocked, isNot(contains('continents_2')));
    });

    test('2 continents → continents_2 (exact threshold)', () {
      final unlocked = AchievementEngine.evaluate(_visits(['GB', 'JP']));
      expect(unlocked, contains('continents_2'));
      expect(unlocked, isNot(contains('continents_3')));
    });

    test('6 continents → continents_all', () {
      final unlocked = AchievementEngine.evaluate(
          _visits(['GB', 'JP', 'ZA', 'US', 'BR', 'AU']));
      expect(unlocked,
          containsAll(['continents_2', 'continents_3', 'continents_4', 'continents_5', 'continents_all']));
    });

    test('5 continents → continents_5 but not continents_all', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['GB', 'JP', 'ZA', 'US', 'BR']));
      expect(unlocked, contains('continents_5'));
      expect(unlocked, isNot(contains('continents_all')));
    });
  });

  group('AchievementEngine.evaluate — trip count boundaries', () {
    test('0 trips → no trip achievements', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 0);
      expect(unlocked, isNot(contains('trips_1')));
    });

    test('1 trip → trips_1 only', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 1);
      expect(unlocked, contains('trips_1'));
      expect(unlocked, isNot(contains('trips_3')));
    });

    test('3 trips → trips_3 (exact threshold)', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 3);
      expect(unlocked, containsAll(['trips_1', 'trips_3']));
      expect(unlocked, isNot(contains('trips_5')));
    });

    test('10 trips → trips_10 (exact threshold)', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 10);
      expect(unlocked, contains('trips_10'));
      expect(unlocked, isNot(contains('trips_25')));
    });

    test('9 trips → not trips_10', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 9);
      expect(unlocked, isNot(contains('trips_10')));
    });

    // Passport stamps = tripCount × 2
    test('5 trips → 10 stamps → passport_10', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 5);
      expect(unlocked, contains('passport_10'));
      expect(unlocked, isNot(contains('passport_25')));
    });

    test('4 trips → 8 stamps → not passport_10', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 4);
      expect(unlocked, isNot(contains('passport_10')));
    });

    test('13 trips → 26 stamps → passport_25', () {
      final unlocked = AchievementEngine.evaluate([], tripCount: 13);
      expect(unlocked, contains('passport_25'));
      expect(unlocked, isNot(contains('passport_50')));
    });
  });

  group('AchievementEngine.evaluate — this-year country count boundaries', () {
    test('2 this-year countries → no year achievement', () {
      final unlocked =
          AchievementEngine.evaluate([], thisYearCountryCount: 2);
      expect(unlocked, isNot(contains('year_countries_3')));
    });

    test('3 this-year countries → year_countries_3 (exact threshold)', () {
      final unlocked =
          AchievementEngine.evaluate([], thisYearCountryCount: 3);
      expect(unlocked, contains('year_countries_3'));
      expect(unlocked, isNot(contains('year_countries_5')));
    });

    test('10 this-year countries → all three year achievements', () {
      final unlocked =
          AchievementEngine.evaluate([], thisYearCountryCount: 10);
      expect(unlocked, containsAll(
          ['year_countries_3', 'year_countries_5', 'year_countries_10']));
    });
  });

  group('AchievementEngine.evaluate — continent explorer boundaries', () {
    // European countries in kCountryContinent
    final europeCodes = ['GB', 'FR', 'DE', 'ES', 'IT', 'PT', 'NL', 'BE', 'CH', 'AT'];

    test('2 Europe countries → no continent_europe_3', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(europeCodes.take(2).toList()));
      expect(unlocked, isNot(contains('continent_europe_3')));
    });

    test('3 Europe countries → continent_europe_3 (exact threshold)', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(europeCodes.take(3).toList()));
      expect(unlocked, contains('continent_europe_3'));
      expect(unlocked, isNot(contains('continent_europe_5')));
    });

    test('5 Europe countries → continent_europe_5', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(europeCodes.take(5).toList()));
      expect(unlocked, containsAll(['continent_europe_3', 'continent_europe_5']));
      expect(unlocked, isNot(contains('continent_europe_10')));
    });

    test('10 Europe countries → continent_europe_10', () {
      final unlocked = AchievementEngine.evaluate(_visits(europeCodes));
      expect(unlocked, contains('continent_europe_10'));
    });
  });

  group('AchievementEngine.evaluate — region explorer boundaries', () {
    // Mediterranean: FR, IT, GR, ES, PT, HR, MT, CY (from subregion map)
    // SoutheastAsia: TH, VN, KH, LA, MM, MY
    test('4 Mediterranean countries → not region_mediterranean', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['FR', 'IT', 'GR', 'ES']));
      expect(unlocked, isNot(contains('region_mediterranean')));
    });

    test('5 Mediterranean countries → region_mediterranean (exact threshold)', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['FR', 'IT', 'GR', 'ES', 'HR']));
      expect(unlocked, contains('region_mediterranean'));
    });

    test('4 SoutheastAsia countries → not region_southeast_asia', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['TH', 'VN', 'KH', 'LA']));
      expect(unlocked, isNot(contains('region_southeast_asia')));
    });

    test('5 SoutheastAsia countries → region_southeast_asia (exact threshold)', () {
      final unlocked =
          AchievementEngine.evaluate(_visits(['TH', 'VN', 'KH', 'LA', 'MM']));
      expect(unlocked, contains('region_southeast_asia'));
    });
  });

  group('AchievementEngine.evaluate — heritage site boundaries', () {
    test('0 heritage sites → no WHS achievements', () {
      final unlocked = AchievementEngine.evaluate([], heritageCount: 0);
      expect(unlocked, isNot(contains('whs_1')));
    });

    test('1 heritage site → whs_1 only', () {
      final unlocked = AchievementEngine.evaluate([], heritageCount: 1);
      expect(unlocked, contains('whs_1'));
      expect(unlocked, isNot(contains('whs_5')));
    });

    test('5 heritage sites → whs_5 (exact threshold)', () {
      final unlocked = AchievementEngine.evaluate([], heritageCount: 5);
      expect(unlocked, containsAll(['whs_1', 'whs_5']));
      expect(unlocked, isNot(contains('whs_10')));
    });

    test('category achievements unlock independently of total count', () {
      final unlocked = AchievementEngine.evaluate(
        [],
        heritageCount: 1,
        heritageByCategory: {'cultural': 1, 'natural': 1, 'mixed': 1},
      );
      expect(unlocked,
          containsAll(['whs_1', 'whs_cultural_1', 'whs_natural_1', 'whs_mixed_1']));
    });

    test('0 cultural heritage → no whs_cultural_1', () {
      final unlocked = AchievementEngine.evaluate(
        [],
        heritageCount: 1,
        heritageByCategory: {'natural': 1},
      );
      expect(unlocked, contains('whs_natural_1'));
      expect(unlocked, isNot(contains('whs_cultural_1')));
    });
  });

  group('AchievementEngine.evaluate — no double-counting across categories', () {
    test('unknown country codes do not contribute to continent count', () {
      // Codes not in kCountryContinent are silently ignored for continents.
      final unlocked = AchievementEngine.evaluate(
          _visits(['XX', 'YY'])); // fake codes
      expect(unlocked, contains('countries_1'));
      expect(unlocked, isNot(contains('continents_2')));
    });

    test('returned set contains only IDs for satisfied thresholds', () {
      final unlocked = AchievementEngine.evaluate(_visits(['GB']), tripCount: 1);
      // countries_1, trips_1 are unlocked; countries_3, trips_3 are not.
      expect(unlocked, containsAll(['countries_1', 'trips_1']));
      expect(unlocked, isNot(contains('countries_3')));
      expect(unlocked, isNot(contains('trips_3')));
    });
  });

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
