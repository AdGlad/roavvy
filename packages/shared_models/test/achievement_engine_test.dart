import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

EffectiveVisitedCountry _visit(String code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
      photoCount: 1,
    );

List<EffectiveVisitedCountry> _visits(List<String> codes) =>
    codes.map(_visit).toList();

void main() {
  // ── kAchievements catalogue ───────────────────────────────────────────────

  group('kAchievements', () {
    test('catalogue contains at least 29 entries', () {
      expect(kAchievements.length, greaterThanOrEqualTo(29));
    });

    test('all original IDs are still present in catalogue', () {
      final catalogueIds = kAchievements.map((a) => a.id).toSet();
      for (final id in [
        'countries_1',
        'countries_5',
        'countries_10',
        'countries_25',
        'countries_50',
        'countries_100',
        'continents_3',
        'continents_all',
      ]) {
        expect(catalogueIds, contains(id), reason: 'existing ID $id must not be removed');
      }
    });

    test('new country IDs are present', () {
      final ids = kAchievements.map((a) => a.id).toSet();
      for (final id in ['countries_3', 'countries_15', 'countries_20',
          'countries_30', 'countries_40', 'countries_75',
          'countries_125', 'countries_150', 'countries_195']) {
        expect(ids, contains(id));
      }
    });

    test('all achievements have a non-empty id, title, description', () {
      for (final a in kAchievements) {
        expect(a.id, isNotEmpty, reason: 'id empty for ${a.title}');
        expect(a.title, isNotEmpty, reason: 'title empty for ${a.id}');
        expect(a.description, isNotEmpty, reason: 'description empty for ${a.id}');
        expect(a.progressTarget, greaterThan(0), reason: 'progressTarget invalid for ${a.id}');
      }
    });

    test('no duplicate IDs in catalogue', () {
      final ids = kAchievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate IDs found');
    });
  });

  // ── empty input ───────────────────────────────────────────────────────────

  group('empty visit list', () {
    test('returns empty set', () {
      expect(AchievementEngine.evaluate([]), isEmpty);
    });
  });

  // ── country count thresholds ──────────────────────────────────────────────

  group('country count achievements', () {
    test('1 country unlocks countries_1', () {
      final result = AchievementEngine.evaluate(_visits(['GB']));
      expect(result, contains('countries_1'));
    });

    test('1 country does not unlock countries_5', () {
      final result = AchievementEngine.evaluate(_visits(['GB']));
      expect(result, isNot(contains('countries_5')));
    });

    test('4 countries (one below threshold) does not unlock countries_5', () {
      final result =
          AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE', 'ES']));
      expect(result, isNot(contains('countries_5')));
    });

    test('5 countries unlocks countries_5', () {
      final result =
          AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE', 'ES', 'IT']));
      expect(result, contains('countries_5'));
    });

    test('5 countries also unlocks countries_1', () {
      final result =
          AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE', 'ES', 'IT']));
      expect(result, contains('countries_1'));
    });

    test('9 countries (one below threshold) does not unlock countries_10', () {
      final result = AchievementEngine.evaluate(
          _visits(['GB', 'FR', 'DE', 'ES', 'IT', 'NL', 'BE', 'CH', 'AT']));
      expect(result, isNot(contains('countries_10')));
    });

    test('10 countries unlocks countries_10', () {
      final result = AchievementEngine.evaluate(_visits(
          ['GB', 'FR', 'DE', 'ES', 'IT', 'NL', 'BE', 'CH', 'AT', 'PT']));
      expect(result, contains('countries_10'));
    });

    test('24 countries does not unlock countries_25', () {
      final real24 = [
        'GB', 'FR', 'DE', 'ES', 'IT', 'NL', 'BE', 'CH', 'AT', 'PT',
        'SE', 'NO', 'DK', 'FI', 'PL', 'CZ', 'HU', 'RO', 'GR', 'HR',
        'SK', 'SI', 'LT', 'LV',
      ];
      expect(real24.length, 24);
      final result = AchievementEngine.evaluate(_visits(real24));
      expect(result, isNot(contains('countries_25')));
    });

    test('25 countries unlocks countries_25', () {
      final real25 = [
        'GB', 'FR', 'DE', 'ES', 'IT', 'NL', 'BE', 'CH', 'AT', 'PT',
        'SE', 'NO', 'DK', 'FI', 'PL', 'CZ', 'HU', 'RO', 'GR', 'HR',
        'SK', 'SI', 'LT', 'LV', 'EE',
      ];
      final result = AchievementEngine.evaluate(_visits(real25));
      expect(result, contains('countries_25'));
    });

    test('49 countries does not unlock countries_50', () {
      final codes = List.generate(49, (i) => 'X${i.toString().padLeft(2, '0')}');
      final result = AchievementEngine.evaluate(_visits(codes));
      expect(result, isNot(contains('countries_50')));
    });

    test('50 countries unlocks countries_50', () {
      final codes = List.generate(50, (i) => 'X${i.toString().padLeft(2, '0')}');
      final result = AchievementEngine.evaluate(_visits(codes));
      expect(result, contains('countries_50'));
    });

    test('99 countries does not unlock countries_100', () {
      final codes = List.generate(99, (i) => 'X${i.toString().padLeft(2, '0')}');
      final result = AchievementEngine.evaluate(_visits(codes));
      expect(result, isNot(contains('countries_100')));
    });

    test('100 countries unlocks countries_100', () {
      final codes =
          List.generate(100, (i) => 'X${i.toString().padLeft(2, '0')}');
      final result = AchievementEngine.evaluate(_visits(codes));
      expect(result, contains('countries_100'));
    });

    test('100 countries also unlocks all lower count achievements', () {
      final codes =
          List.generate(100, (i) => 'X${i.toString().padLeft(2, '0')}');
      final result = AchievementEngine.evaluate(_visits(codes));
      expect(result, containsAll(['countries_1', 'countries_5', 'countries_10',
          'countries_25', 'countries_50', 'countries_100']));
    });

    test('3 countries unlocks countries_3', () {
      final result = AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE']));
      expect(result, contains('countries_3'));
    });

    test('2 countries does not unlock countries_3', () {
      final result = AchievementEngine.evaluate(_visits(['GB', 'FR']));
      expect(result, isNot(contains('countries_3')));
    });
  });

  // ── trip count achievements ───────────────────────────────────────────────

  group('trip count achievements', () {
    test('0 trips unlocks nothing trip-based', () {
      final result = AchievementEngine.evaluate([]);
      expect(result, isNot(contains('trips_1')));
    });

    test('1 trip unlocks trips_1', () {
      final result = AchievementEngine.evaluate([], tripCount: 1);
      expect(result, contains('trips_1'));
    });

    test('4 trips does not unlock trips_5', () {
      final result = AchievementEngine.evaluate([], tripCount: 4);
      expect(result, isNot(contains('trips_5')));
    });

    test('5 trips unlocks trips_5', () {
      final result = AchievementEngine.evaluate([], tripCount: 5);
      expect(result, contains('trips_5'));
    });

    test('10 trips unlocks trips_1, trips_3, trips_5, trips_10', () {
      final result = AchievementEngine.evaluate([], tripCount: 10);
      expect(result, containsAll(['trips_1', 'trips_3', 'trips_5', 'trips_10']));
    });

    test('backward-compatible: no trip params → no trip achievements', () {
      final result = AchievementEngine.evaluate(_visits(['GB', 'FR', 'DE']));
      expect(result, isNot(contains('trips_1')));
    });
  });

  // ── this-year country count ───────────────────────────────────────────────

  group('this-year country count achievements', () {
    test('0 this-year countries unlocks nothing', () {
      final result = AchievementEngine.evaluate([]);
      expect(result, isNot(contains('year_countries_3')));
    });

    test('3 this-year countries unlocks year_countries_3', () {
      final result = AchievementEngine.evaluate([], thisYearCountryCount: 3);
      expect(result, contains('year_countries_3'));
    });

    test('2 this-year countries does not unlock year_countries_3', () {
      final result = AchievementEngine.evaluate([], thisYearCountryCount: 2);
      expect(result, isNot(contains('year_countries_3')));
    });

    test('10 this-year countries unlocks all year achievements', () {
      final result = AchievementEngine.evaluate([], thisYearCountryCount: 10);
      expect(result, containsAll(['year_countries_3', 'year_countries_5', 'year_countries_10']));
    });
  });

  // ── continent achievements ────────────────────────────────────────────────

  group('continent achievements', () {
    test('1 continent does not unlock continents_2', () {
      final result = AchievementEngine.evaluate(_visits(['GB', 'FR']));
      expect(result, isNot(contains('continents_2')));
    });

    test('2 continents unlocks continents_2', () {
      // GB=Europe, JP=Asia
      final result = AchievementEngine.evaluate(_visits(['GB', 'JP']));
      expect(result, contains('continents_2'));
    });

    test('2 continents does not unlock continents_3', () {
      // GB=Europe, JP=Asia
      final result = AchievementEngine.evaluate(_visits(['GB', 'JP']));
      expect(result, isNot(contains('continents_3')));
    });

    test('exactly 3 continents unlocks continents_3', () {
      // GB=Europe, JP=Asia, US=North America
      final result = AchievementEngine.evaluate(_visits(['GB', 'JP', 'US']));
      expect(result, contains('continents_3'));
    });

    test('5 continents unlocks continents_3 but not continents_all', () {
      // Europe, Asia, North America, South America, Africa
      final result = AchievementEngine.evaluate(
          _visits(['GB', 'JP', 'US', 'BR', 'NG']));
      expect(result, contains('continents_3'));
      expect(result, isNot(contains('continents_all')));
    });

    test('all 6 continents unlocks both continents_3 and continents_all', () {
      // Europe=GB, Asia=JP, North America=US, South America=BR,
      // Africa=NG, Oceania=AU
      final result = AchievementEngine.evaluate(
          _visits(['GB', 'JP', 'US', 'BR', 'NG', 'AU']));
      expect(result, contains('continents_3'));
      expect(result, contains('continents_all'));
    });
  });

  // ── unknown country codes ─────────────────────────────────────────────────

  group('missing continent keys', () {
    test('unknown country code does not throw', () {
      expect(
        () => AchievementEngine.evaluate(_visits(['XX', 'ZZ', 'Q9'])),
        returnsNormally,
      );
    });

    test('unknown codes still count toward country total', () {
      final codes = List.generate(5, (i) => 'Q$i');
      final result = AchievementEngine.evaluate(_visits(codes));
      expect(result, contains('countries_5'));
    });

    test('unknown codes do not contribute to continent count', () {
      // Only unknown codes — 0 continents, no continent achievements
      final result =
          AchievementEngine.evaluate(_visits(['XX', 'YY', 'ZZ']));
      expect(result, isNot(contains('continents_3')));
    });

    test('mix of known and unknown codes: continents counted from known only', () {
      // GB=Europe, XX=unknown — only 1 continent
      final result = AchievementEngine.evaluate(_visits(['GB', 'XX']));
      expect(result, isNot(contains('continents_3')));
    });
  });
}
