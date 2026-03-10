import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2023, 1, 1);
  final t1 = DateTime.utc(2024, 6, 15);

  CountryVisit autoVisit({
    String code = 'GB',
    bool isDeleted = false,
    DateTime? updatedAt,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) =>
      CountryVisit(
        countryCode: code,
        source: VisitSource.auto,
        updatedAt: updatedAt ?? t0,
        isDeleted: isDeleted,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
      );

  CountryVisit manualVisit({
    String code = 'GB',
    bool isDeleted = false,
    DateTime? updatedAt,
  }) =>
      CountryVisit(
        countryCode: code,
        source: VisitSource.manual,
        updatedAt: updatedAt ?? t1,
        isDeleted: isDeleted,
      );

  group('CountryVisit — construction', () {
    test('isActive reflects isDeleted', () {
      expect(autoVisit().isActive, isTrue);
      expect(autoVisit(isDeleted: true).isActive, isFalse);
    });

    test('isDeleted defaults to false', () {
      expect(autoVisit().isDeleted, isFalse);
    });

    test('firstSeen and lastSeen default to null', () {
      final v = autoVisit();
      expect(v.firstSeen, isNull);
      expect(v.lastSeen, isNull);
    });
  });

  group('CountryVisit — copyWith', () {
    test('returns new instance with updated fields', () {
      final original = autoVisit(code: 'JP', firstSeen: t0);
      final updated = original.copyWith(lastSeen: t1);
      expect(updated.countryCode, 'JP');
      expect(updated.firstSeen, t0);
      expect(updated.lastSeen, t1);
      expect(updated.source, VisitSource.auto);
    });

    test('does not mutate the original', () {
      final original = autoVisit(isDeleted: false);
      original.copyWith(isDeleted: true);
      expect(original.isDeleted, isFalse);
    });

    test('can flip source from auto to manual', () {
      final v = autoVisit().copyWith(source: VisitSource.manual);
      expect(v.source, VisitSource.manual);
    });
  });

  group('CountryVisit — equality', () {
    test('equal when all fields match', () {
      final a = autoVisit(code: 'FR', updatedAt: t0);
      final b = autoVisit(code: 'FR', updatedAt: t0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when country code differs', () {
      expect(autoVisit(code: 'GB'), isNot(equals(autoVisit(code: 'US'))));
    });

    test('not equal when source differs', () {
      expect(autoVisit(), isNot(equals(manualVisit())));
    });

    test('not equal when isDeleted differs', () {
      expect(autoVisit(isDeleted: false), isNot(equals(autoVisit(isDeleted: true))));
    });
  });
}
