import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

Trip _t(String cc, String start, String end) =>
    Trip(countryCode: cc, startedOn: DateTime.parse(start), endedOn: DateTime.parse(end));

void main() {
  group('Trip', () {
    test('duration is inclusive and json round-trips', () {
      final t = _t('SC', '2024-03-12', '2024-03-18');
      expect(t.cc, 'sc');
      expect(t.durationDays, 7);
      expect(Trip.fromJson(t.toJson()).toJson(), t.toJson());
    });
  });

  group('DateRange', () {
    test('years() overlaps trips inside the window', () {
      final r = DateRange.years(2023, 2024);
      expect(r.overlaps(_t('sc', '2024-01-05', '2024-01-10')), isTrue);
      expect(r.overlaps(_t('sc', '2022-06-01', '2022-06-10')), isFalse);
      // A trip straddling the boundary still overlaps.
      expect(r.overlaps(_t('sc', '2022-12-28', '2023-01-03')), isTrue);
    });
    test('all is open and matches everything', () {
      expect(DateRange.all.isOpen, isTrue);
      expect(DateRange.all.overlaps(_t('sc', '1999-01-01', '1999-01-02')), isTrue);
    });
  });

  group('TravelHistory', () {
    final h = TravelHistory([
      _t('au', '2021-05-01', '2021-05-10'),
      _t('sc', '2024-03-12', '2024-03-18'),
      _t('sc', '2022-07-02', '2022-07-09'),
      _t('gb', '2023-09-01', '2023-09-14'),
    ]);

    test('countryCodes are distinct in first-visited order', () {
      expect(h.countryCodes, ['au', 'sc', 'gb']);
    });
    test('visitCounts reflect frequency', () {
      expect(h.visitCounts['sc'], 2);
      expect(h.visitCounts['au'], 1);
    });
    test('mostRecentFor picks the latest trip', () {
      expect(h.mostRecentFor('sc')!.startedOn, DateTime.parse('2024-03-12'));
    });
    test('inRange filters trips', () {
      final r = h.inRange(DateRange.years(2023, 2024));
      expect(r.trips.length, 2); // sc 2024 + gb 2023
      expect(r.countryCodes.toSet(), {'sc', 'gb'});
    });
  });

  group('DesignContext', () {
    test('fromTrips derives flag codes and applies the range', () {
      final ctx = DesignContext.fromTrips([
        _t('au', '2021-05-01', '2021-05-10'),
        _t('sc', '2024-03-12', '2024-03-18'),
      ], dateRange: DateRange.years(2024, 2024));
      expect(ctx.hasTrips, isTrue);
      expect(ctx.flagCodes, ['sc']);
      expect(ctx.trips.single.cc, 'sc');
    });

    test('default context has no trips (backward compatible)', () {
      const ctx = DesignContext(flagCodes: ['us']);
      expect(ctx.hasTrips, isFalse);
      expect(ctx.dateRange.isOpen, isTrue);
    });

    test('fromTrips with a range that excludes all trips yields no countries', () {
      // Drives the Lab "Only countries visited in range" → empty result.
      final ctx = DesignContext.fromTrips([
        _t('au', '2021-05-01', '2021-05-10'),
        _t('sc', '2024-03-12', '2024-03-18'),
      ], dateRange: DateRange.years(2019, 2019));
      expect(ctx.flagCodes, isEmpty);
      expect(ctx.hasTrips, isFalse);
    });
  });
}
