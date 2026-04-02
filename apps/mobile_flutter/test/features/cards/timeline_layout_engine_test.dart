import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/timeline_layout_engine.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code, int year, int startMonth, int endMonth) =>
    TripRecord(
      id: '$code-$year-$startMonth',
      countryCode: code,
      startedOn: DateTime(year, startMonth, 1),
      endedOn: DateTime(year, endMonth, 28),
      photoCount: 1,
      isManual: false,
    );

void main() {
  const landscape = Size(600, 400);
  const portrait = Size(400, 600);

  group('TimelineLayoutEngine.layout', () {
    test('0 trips → empty result', () {
      final result = TimelineLayoutEngine.layout(
        trips: [],
        countryCodes: ['GB'],
        canvasSize: landscape,
      );
      expect(result.entries, isEmpty);
      expect(result.truncatedCount, 0);
    });

    test('1 trip → 1 entry, 0 truncated', () {
      final result = TimelineLayoutEngine.layout(
        trips: [_trip('GB', 2023, 3, 3)],
        countryCodes: ['GB'],
        canvasSize: landscape,
      );
      expect(result.entries.length, 1);
      expect(result.truncatedCount, 0);
    });

    test('5 same-year trips fit on standard landscape canvas without truncation',
        () {
      // 5 trips in the same year → 1 year divider + 5 rows, which comfortably
      // fits the 292px usable height at row height ≈33px.
      final trips = List.generate(
        5,
        (i) => _trip('FR', 2023, i + 1, i + 1),
      );
      final result = TimelineLayoutEngine.layout(
        trips: trips,
        countryCodes: ['FR'],
        canvasSize: landscape,
      );
      expect(result.entries.length + result.truncatedCount, 5);
      expect(result.truncatedCount, 0);
    });

    test('30 trips on landscape canvas → some truncated; invariant holds', () {
      final trips = List.generate(
        30,
        (i) => _trip('DE', 2000 + i, 6, 7),
      );
      final result = TimelineLayoutEngine.layout(
        trips: trips,
        countryCodes: ['DE'],
        canvasSize: landscape,
      );
      expect(result.entries.length + result.truncatedCount, 30);
      expect(result.truncatedCount, greaterThan(0));
    });

    test('60 trips → truncated; invariant holds', () {
      final trips = List.generate(
        60,
        (i) => _trip('JP', 1960 + i, 4, 5),
      );
      final result = TimelineLayoutEngine.layout(
        trips: trips,
        countryCodes: ['JP'],
        canvasSize: landscape,
      );
      expect(result.entries.length + result.truncatedCount, 60);
      expect(result.truncatedCount, greaterThan(0));
    });

    test('entries are sorted most-recent first', () {
      final trips = [
        _trip('GB', 2018, 1, 2),
        _trip('FR', 2022, 5, 6),
        _trip('DE', 2020, 3, 4),
      ];
      final result = TimelineLayoutEngine.layout(
        trips: trips,
        countryCodes: ['GB', 'FR', 'DE'],
        canvasSize: landscape,
      );
      final years = result.entries.map((e) => e.entryDate.year).toList();
      expect(years, [2022, 2020, 2018]);
    });

    test('portrait canvas also works without error', () {
      final trips = List.generate(5, (i) => _trip('US', 2020 + i, 7, 8));
      final result = TimelineLayoutEngine.layout(
        trips: trips,
        countryCodes: ['US'],
        canvasSize: portrait,
      );
      expect(result.entries.length + result.truncatedCount, 5);
    });
  });

  group('formatTimelineDate', () {
    test('same month + year → "Mar 2023"', () {
      expect(
        formatTimelineDate(DateTime(2023, 3, 1), DateTime(2023, 3, 28)),
        'Mar 2023',
      );
    });

    test('same year, different month → "Mar–Jun 2023"', () {
      expect(
        formatTimelineDate(DateTime(2023, 3, 1), DateTime(2023, 6, 30)),
        'Mar–Jun 2023',
      );
    });

    test('different year → "Mar 2023–Jan 2024"', () {
      expect(
        formatTimelineDate(DateTime(2023, 3, 1), DateTime(2024, 1, 15)),
        'Mar 2023–Jan 2024',
      );
    });

    test('same day → "Jun 2024"', () {
      expect(
        formatTimelineDate(DateTime(2024, 6, 10), DateTime(2024, 6, 10)),
        'Jun 2024',
      );
    });

    test('December entry, January exit → cross-year', () {
      expect(
        formatTimelineDate(DateTime(2022, 12, 20), DateTime(2023, 1, 5)),
        'Dec 2022–Jan 2023',
      );
    });

    test('all 12 month abbreviations correct', () {
      const expected = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      for (int m = 1; m <= 12; m++) {
        final result = formatTimelineDate(
          DateTime(2024, m, 1),
          DateTime(2024, m, 1),
        );
        expect(result, '${expected[m - 1]} 2024',
            reason: 'Month $m should be ${expected[m - 1]}');
      }
    });
  });
}
