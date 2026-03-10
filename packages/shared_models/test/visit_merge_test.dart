import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2023, 1, 1);
  final t1 = DateTime.utc(2024, 1, 1);

  CountryVisit auto(String code, {bool isDeleted = false, DateTime? updatedAt}) =>
      CountryVisit(
        countryCode: code,
        source: VisitSource.auto,
        updatedAt: updatedAt ?? t0,
        isDeleted: isDeleted,
      );

  CountryVisit manual(String code, {bool isDeleted = false, DateTime? updatedAt}) =>
      CountryVisit(
        countryCode: code,
        source: VisitSource.manual,
        updatedAt: updatedAt ?? t1,
        isDeleted: isDeleted,
      );

  group('effectiveVisits — basic cases', () {
    test('empty list returns empty', () {
      expect(effectiveVisits([]), isEmpty);
    });

    test('single active auto visit is included', () {
      final result = effectiveVisits([auto('GB')]);
      expect(result.length, 1);
      expect(result.first.countryCode, 'GB');
    });

    test('single deleted auto visit is excluded', () {
      expect(effectiveVisits([auto('GB', isDeleted: true)]), isEmpty);
    });

    test('multiple distinct active countries are all included', () {
      final result = effectiveVisits([auto('GB'), auto('JP'), auto('US')]);
      final codes = result.map((v) => v.countryCode).toSet();
      expect(codes, {'GB', 'JP', 'US'});
    });
  });

  group('effectiveVisits — manual beats auto', () {
    test('active manual wins over active auto for same code', () {
      final result = effectiveVisits([auto('GB'), manual('GB')]);
      expect(result.length, 1);
      expect(result.first.source, VisitSource.manual);
    });

    test('manual tombstone suppresses auto — country is excluded', () {
      final result = effectiveVisits([auto('GB'), manual('GB', isDeleted: true)]);
      expect(result, isEmpty);
    });

    test('auto does not suppress manual tombstone', () {
      // auto cannot un-delete a manual tombstone
      final result = effectiveVisits([manual('GB', isDeleted: true), auto('GB')]);
      expect(result, isEmpty);
    });

    test('user-added manual (no auto) is included', () {
      final result = effectiveVisits([manual('FR')]);
      expect(result.length, 1);
      expect(result.first.source, VisitSource.manual);
    });
  });

  group('effectiveVisits — same-source conflict: later updatedAt wins', () {
    test('later auto wins over earlier auto for same code', () {
      final older = auto('GB', updatedAt: t0);
      final newer = auto('GB', updatedAt: t1);
      final result = effectiveVisits([older, newer]);
      expect(result.length, 1);
      expect(result.first.updatedAt, t1);
    });

    test('order in input list does not matter', () {
      final older = auto('GB', updatedAt: t0);
      final newer = auto('GB', updatedAt: t1);
      final resultA = effectiveVisits([older, newer]);
      final resultB = effectiveVisits([newer, older]);
      expect(resultA.first.updatedAt, resultB.first.updatedAt);
    });

    test('later manual tombstone wins over earlier active manual', () {
      final active = manual('GB', isDeleted: false, updatedAt: t0);
      final tombstone = manual('GB', isDeleted: true, updatedAt: t1);
      final result = effectiveVisits([active, tombstone]);
      // tombstone wins — country is excluded
      expect(result, isEmpty);
    });

    test('earlier active manual wins over later manual tombstone when timestamp reversed', () {
      // If user un-deletes (active manual with later timestamp) — country included
      final tombstone = manual('GB', isDeleted: true, updatedAt: t0);
      final undeleted = manual('GB', isDeleted: false, updatedAt: t1);
      final result = effectiveVisits([tombstone, undeleted]);
      expect(result.length, 1);
    });
  });

  group('effectiveVisits — mixed scenarios', () {
    test('auto visits for other countries are unaffected by a tombstone for one', () {
      final result = effectiveVisits([
        auto('GB'),
        auto('JP'),
        manual('GB', isDeleted: true), // removes GB only
      ]);
      final codes = result.map((v) => v.countryCode).toSet();
      expect(codes, {'JP'});
    });

    test('mix of inferred and user-added countries returns all active', () {
      final result = effectiveVisits([
        auto('GB'),          // inferred
        auto('JP'),          // inferred
        manual('FR'),        // user-added, no photo evidence
        manual('DE', isDeleted: true), // user-removed
      ]);
      final codes = result.map((v) => v.countryCode).toSet();
      expect(codes, {'GB', 'JP', 'FR'});
      expect(codes.contains('DE'), isFalse);
    });
  });
}
