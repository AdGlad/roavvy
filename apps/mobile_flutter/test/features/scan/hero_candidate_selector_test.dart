import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/scan/hero_candidate_selector.dart';

PhotoDateRecord _photo(
  String assetId,
  DateTime capturedAt, {
  String countryCode = 'GR',
}) =>
    PhotoDateRecord(
      countryCode: countryCode,
      capturedAt: capturedAt,
      assetId: assetId,
    );

DateTime _t(int hour, {int minute = 0}) =>
    DateTime.utc(2024, 7, 12, hour, minute);

const _selector = HeroCandidateSelector();

void main() {
  group('HeroCandidateSelector', () {
    test('empty input returns empty list', () {
      expect(_selector.select([]), isEmpty);
    });

    test('single photo returns its assetId', () {
      final result = _selector.select([_photo('a1', _t(10))]);
      expect(result, ['a1']);
    });

    test('photos without assetId are skipped', () {
      final photos = [
        PhotoDateRecord(countryCode: 'GR', capturedAt: _t(10)),
        _photo('a2', _t(11)),
      ];
      final result = _selector.select(photos);
      expect(result, ['a2']);
    });

    test('burst dedup removes photos within 60 seconds of each other', () {
      // Three photos within 10 seconds — only the first should survive.
      final photos = [
        _photo('a1', _t(10, minute: 0)),
        _photo('a2', DateTime.utc(2024, 7, 12, 10, 0, 30)),
        _photo('a3', DateTime.utc(2024, 7, 12, 10, 0, 55)),
        _photo('a4', _t(12)), // 2 hours later — should survive
      ];

      final result = _selector.select(photos);
      expect(result, contains('a1'));
      expect(result, contains('a4'));
      expect(result, isNot(contains('a2')));
      expect(result, isNot(contains('a3')));
    });

    test('temporal spacing removes photos within 30 minutes of previous', () {
      // a1 at 10:00, a2 at 10:20 (20 min — too close), a3 at 10:45 (45 min — ok)
      final photos = [
        _photo('a1', _t(10, minute: 0)),
        _photo('a2', _t(10, minute: 20)),
        _photo('a3', _t(10, minute: 45)),
      ];

      final result = _selector.select(photos);
      expect(result, contains('a1'));
      expect(result, contains('a3'));
      expect(result, isNot(contains('a2')));
    });

    test('caps at maxCandidates', () {
      final photos = List.generate(
        10,
        (i) => _photo('a$i', DateTime.utc(2024, 7, 12, i + 1)),
      );
      final result = _selector.select(photos, maxCandidates: 3);
      expect(result.length, lessThanOrEqualTo(3));
    });

    test('default cap is 5', () {
      final photos = List.generate(
        10,
        (i) => _photo('a$i', DateTime.utc(2024, 7, 12, i + 1)),
      );
      final result = _selector.select(photos);
      expect(result.length, lessThanOrEqualTo(5));
    });

    test('fallback returns candidates when all fail temporal spacing', () {
      // Many photos very close together — burst dedup kicks in,
      // only one survives, which is still returned.
      final photos = List.generate(
        5,
        (i) => _photo('a$i', DateTime.utc(2024, 7, 12, 10, 0, i * 5)),
      );
      final result = _selector.select(photos);
      expect(result, isNotEmpty);
    });

    test('preserves ordering by capturedAt ascending', () {
      final photos = [
        _photo('late', _t(12)),
        _photo('early', _t(8)),
        _photo('mid', _t(10)),
      ];
      final result = _selector.select(photos);
      // earliest should be first
      expect(result.first, 'early');
    });
  });
}
