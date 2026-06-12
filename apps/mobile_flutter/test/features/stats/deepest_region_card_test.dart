import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/stats/widgets/deepest_region_card.dart';

void main() {
  group('deepestContinent', () {
    const totals = {
      'Africa': 54,
      'Asia': 48,
      'Europe': 44,
      'North America': 23,
      'South America': 12,
      'Oceania': 14,
    };

    test('returns continent with highest fraction', () {
      // Europe: 22/44 = 50%, Asia: 12/48 = 25%, Africa: 5/54 ~9%
      final counts = {'Europe': 22, 'Asia': 12, 'Africa': 5};
      expect(deepestContinent(counts, totals), 'Europe');
    });

    test('on tie in fraction, prefers continent with more absolute visits', () {
      // Europe: 22/44 = 50%, South America: 6/12 = 50% — SA has fewer → Europe wins
      final counts = {'Europe': 22, 'South America': 6};
      expect(deepestContinent(counts, totals), 'Europe');
    });

    test('returns null when no countries visited', () {
      expect(deepestContinent({}, totals), isNull);
    });

    test('returns null when all counts are zero', () {
      final counts = {'Europe': 0, 'Asia': 0};
      expect(deepestContinent(counts, totals), isNull);
    });

    test('single continent visited returns that continent', () {
      final counts = {'Oceania': 3};
      expect(deepestContinent(counts, totals), 'Oceania');
    });

    test('100% completion is handled', () {
      final counts = {'South America': 12}; // 12/12 = 100%
      expect(deepestContinent(counts, totals), 'South America');
    });
  });
}
