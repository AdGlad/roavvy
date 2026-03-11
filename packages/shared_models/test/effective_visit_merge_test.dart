import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2023, 1, 1);
  final t1 = DateTime.utc(2024, 6, 15);
  final t2 = DateTime.utc(2025, 3, 10);

  InferredCountryVisit inferred(
    String code, {
    int photoCount = 1,
    DateTime? firstSeen,
    DateTime? lastSeen,
    DateTime? inferredAt,
  }) =>
      InferredCountryVisit(
        countryCode: code,
        inferredAt: inferredAt ?? t0,
        photoCount: photoCount,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
      );

  UserAddedCountry added(String code, {DateTime? addedAt}) =>
      UserAddedCountry(countryCode: code, addedAt: addedAt ?? t1);

  UserRemovedCountry removed(String code, {DateTime? removedAt}) =>
      UserRemovedCountry(countryCode: code, removedAt: removedAt ?? t1);

  List<EffectiveVisitedCountry> merge({
    List<InferredCountryVisit> inferred = const [],
    List<UserAddedCountry> added = const [],
    List<UserRemovedCountry> removed = const [],
  }) =>
      effectiveVisitedCountries(
        inferred: inferred,
        added: added,
        removed: removed,
      );

  // ── Empty / single cases ───────────────────────────────────────────────────

  group('effectiveVisitedCountries — empty inputs', () {
    test('all empty returns empty', () {
      expect(merge(), isEmpty);
    });

    test('single inferred country is included', () {
      final result = merge(inferred: [inferred('GB')]);
      expect(result.length, 1);
      expect(result.first.countryCode, 'GB');
      expect(result.first.hasPhotoEvidence, isTrue);
    });

    test('single user-added country is included', () {
      final result = merge(added: [added('FR')]);
      expect(result.length, 1);
      expect(result.first.countryCode, 'FR');
      expect(result.first.hasPhotoEvidence, isFalse);
    });

    test('single removal with no matching record produces empty result', () {
      expect(merge(removed: [removed('US')]), isEmpty);
    });
  });

  // ── Removals suppress everything ──────────────────────────────────────────

  group('effectiveVisitedCountries — removals', () {
    test('removal suppresses inferred visit', () {
      final result = merge(
        inferred: [inferred('GB')],
        removed: [removed('GB')],
      );
      expect(result, isEmpty);
    });

    test('removal suppresses user-added country', () {
      final result = merge(
        added: [added('GB')],
        removed: [removed('GB')],
      );
      expect(result, isEmpty);
    });

    test('removal suppresses both inferred and user-added for same code', () {
      final result = merge(
        inferred: [inferred('GB')],
        added: [added('GB')],
        removed: [removed('GB')],
      );
      expect(result, isEmpty);
    });

    test('removal for one country does not affect others', () {
      final result = merge(
        inferred: [inferred('GB'), inferred('JP')],
        removed: [removed('GB')],
      );
      expect(result.length, 1);
      expect(result.first.countryCode, 'JP');
    });

    test('removal does not suppress user-added country with different code', () {
      final result = merge(
        added: [added('FR')],
        removed: [removed('DE')],
      );
      expect(result.length, 1);
      expect(result.first.countryCode, 'FR');
    });
  });

  // ── User-added behaviour ───────────────────────────────────────────────────

  group('effectiveVisitedCountries — user additions', () {
    test('user-added country has no photo evidence', () {
      final result = merge(added: [added('JP')]);
      expect(result.first.hasPhotoEvidence, isFalse);
      expect(result.first.firstSeen, isNull);
      expect(result.first.lastSeen, isNull);
      expect(result.first.photoCount, 0);
    });

    test('user-added + inferred for same code: photo evidence is preserved', () {
      final result = merge(
        inferred: [inferred('JP', photoCount: 5, firstSeen: t0, lastSeen: t1)],
        added: [added('JP')],
      );
      expect(result.length, 1);
      final e = result.first;
      expect(e.hasPhotoEvidence, isTrue);
      expect(e.photoCount, 5);
      expect(e.firstSeen, t0);
      expect(e.lastSeen, t1);
    });

    test('multiple user-added countries all appear', () {
      final result = merge(
        added: [added('GB'), added('JP'), added('US')],
      );
      expect(result.map((e) => e.countryCode).toSet(), {'GB', 'JP', 'US'});
    });
  });

  // ── Inferred merge across scan runs ───────────────────────────────────────

  group('effectiveVisitedCountries — multi-scan inferred merge', () {
    test('photo counts are summed across scan runs', () {
      final result = merge(inferred: [
        inferred('GB', photoCount: 10, inferredAt: t0),
        inferred('GB', photoCount: 15, inferredAt: t1),
      ]);
      expect(result.length, 1);
      expect(result.first.photoCount, 25);
    });

    test('firstSeen takes the earliest value across scans', () {
      final result = merge(inferred: [
        inferred('GB', firstSeen: t1, inferredAt: t1),
        inferred('GB', firstSeen: t0, inferredAt: t2),
      ]);
      expect(result.first.firstSeen, t0);
    });

    test('lastSeen takes the latest value across scans', () {
      final result = merge(inferred: [
        inferred('GB', lastSeen: t0, inferredAt: t0),
        inferred('GB', lastSeen: t2, inferredAt: t1),
      ]);
      expect(result.first.lastSeen, t2);
    });

    test('null firstSeen in one scan does not override non-null in another', () {
      final result = merge(inferred: [
        inferred('GB', firstSeen: null, inferredAt: t0),
        inferred('GB', firstSeen: t0, inferredAt: t1),
      ]);
      expect(result.first.firstSeen, t0);
    });

    test('two inferred for different countries are both included', () {
      final result = merge(inferred: [inferred('GB'), inferred('JP')]);
      expect(result.map((e) => e.countryCode).toSet(), {'GB', 'JP'});
    });
  });

  // ── Mixed scenarios ───────────────────────────────────────────────────────

  group('effectiveVisitedCountries — mixed', () {
    test('realistic scenario: inferred + added + removed', () {
      final result = merge(
        inferred: [
          inferred('GB', photoCount: 42),
          inferred('JP', photoCount: 8),
          inferred('US', photoCount: 5), // will be removed
        ],
        added: [added('FR')], // manual, no photos
        removed: [removed('US')],
      );

      final codes = result.map((e) => e.countryCode).toSet();
      expect(codes, {'GB', 'JP', 'FR'});
      expect(codes.contains('US'), isFalse);

      final gb = result.firstWhere((e) => e.countryCode == 'GB');
      expect(gb.hasPhotoEvidence, isTrue);
      expect(gb.photoCount, 42);

      final fr = result.firstWhere((e) => e.countryCode == 'FR');
      expect(fr.hasPhotoEvidence, isFalse);
    });

    test('removal applied before inferred are processed — order independent', () {
      // Same result regardless of list ordering.
      final a = merge(
        inferred: [inferred('GB')],
        removed: [removed('GB')],
      );
      final b = merge(
        removed: [removed('GB')],
        inferred: [inferred('GB')],
      );
      expect(a, equals(b));
    });
  });
}
