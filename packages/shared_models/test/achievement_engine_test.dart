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
    test('catalogue contains at least 8 entries', () {
      expect(kAchievements.length, greaterThanOrEqualTo(8));
    });

    test('all engine IDs are present in catalogue', () {
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
        expect(catalogueIds, contains(id));
      }
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
  });

  // ── continent achievements ────────────────────────────────────────────────

  group('continent achievements', () {
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
