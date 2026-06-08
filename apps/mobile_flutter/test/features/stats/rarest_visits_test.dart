import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  group('rarestVisited', () {
    test('empty visited list returns empty', () {
      expect(rarestVisited([]), isEmpty);
    });

    test('only common countries (not in map) returns empty', () {
      // FR, DE, US are not in kCountryRarity (common, default 0.5)
      expect(rarestVisited(['FR', 'DE', 'US']), isEmpty);
    });

    test('Tuvalu (ultra rare) appears, France (common) does not', () {
      final results = rarestVisited(['FR', 'TV']);
      expect(results, hasLength(1));
      expect(results.first.countryCode, equals('TV'));
      expect(results.first.tier, equals(RarityTier.ultraRare));
    });

    test('returns countries sorted by ascending rarity score (rarest first)', () {
      // TV = 0.001, NR = 0.002, KI = 0.003
      final results = rarestVisited(['KI', 'TV', 'NR'], limit: 3);
      expect(results.map((r) => r.countryCode).toList(),
          equals(['TV', 'NR', 'KI']));
    });

    test('cap at limit=3 by default, taking rarest', () {
      // Pass 5 rare countries; only top 3 rarest returned
      final results = rarestVisited(['KI', 'TV', 'NR', 'MH', 'FM']);
      expect(results, hasLength(3));
      expect(results.map((r) => r.countryCode).toList(),
          equals(['TV', 'NR', 'KI']));
    });

    test('limit parameter is respected', () {
      final results = rarestVisited(['TV', 'NR', 'KI', 'MH'], limit: 2);
      expect(results, hasLength(2));
      expect(results.first.countryCode, equals('TV'));
    });

    test('uncommon tier boundary: score 0.20–0.45', () {
      // LA = 0.218 → uncommon
      final results = rarestVisited(['LA']);
      expect(results, hasLength(1));
      expect(results.first.tier, equals(RarityTier.uncommon));
    });

    test('rare tier boundary: score 0.05–0.20', () {
      // MR = 0.055 → rare
      final results = rarestVisited(['MR']);
      expect(results, hasLength(1));
      expect(results.first.tier, equals(RarityTier.rare));
    });

    test('score at/above 0.45 is excluded (common threshold)', () {
      // AL = 0.445 → still uncommon (< 0.45)
      expect(rarestVisited(['AL']), hasLength(1));
    });

    test('unknown country codes are excluded', () {
      expect(rarestVisited(['XX', 'ZZ', '??']), isEmpty);
    });
  });

  group('RarityTier', () {
    test('fromScore: < 0.05 is ultraRare', () {
      expect(RarityTier.fromScore(0.001), equals(RarityTier.ultraRare));
      expect(RarityTier.fromScore(0.049), equals(RarityTier.ultraRare));
    });

    test('fromScore: 0.05–0.20 is rare', () {
      expect(RarityTier.fromScore(0.05), equals(RarityTier.rare));
      expect(RarityTier.fromScore(0.199), equals(RarityTier.rare));
    });

    test('fromScore: 0.20–0.45 is uncommon', () {
      expect(RarityTier.fromScore(0.20), equals(RarityTier.uncommon));
      expect(RarityTier.fromScore(0.449), equals(RarityTier.uncommon));
    });

    test('fromScore: >= 0.45 returns null (common)', () {
      expect(RarityTier.fromScore(0.45), isNull);
      expect(RarityTier.fromScore(1.0), isNull);
    });

    test('labels are correct', () {
      expect(RarityTier.ultraRare.label, equals('Ultra Rare'));
      expect(RarityTier.rare.label, equals('Rare'));
      expect(RarityTier.uncommon.label, equals('Uncommon'));
    });
  });
}
