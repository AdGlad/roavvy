import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/passport_layout_engine.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String code, DateTime start) => TripRecord(
      id: '${code}_${start.toIso8601String()}',
      countryCode: code,
      startedOn: start,
      endedOn: start.add(const Duration(days: 7)),
      photoCount: 5,
      isManual: false,
    );

const _size = Size(400, 267);
const _codes5 = ['FR', 'DE', 'JP', 'US', 'GB'];

void main() {
  group('PassportLayoutEngine.layout', () {
    test('returns empty list when countryCodes is empty', () {
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: [],
        canvasSize: _size,
      );
      expect(result, isEmpty);
    });

    test('codes-only path works without trips', () {
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
      );
      expect(result.length, _codes5.length);
      for (final stamp in result) {
        expect(stamp.dateLabel, isNull);
      }
    });

    test('deterministic: same seed → same positions', () {
      final a = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
        seed: 0,
      );
      final b = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
        seed: 0,
      );
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].center, b[i].center);
      }
    });

    test('all stamp centres within canvas margins (8%)', () {
      final marginX = _size.width * 0.08;
      final marginY = _size.height * 0.08;
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
        seed: 0,
      );
      for (final stamp in result) {
        expect(stamp.center.dx, greaterThanOrEqualTo(marginX));
        expect(stamp.center.dy, greaterThanOrEqualTo(marginY));
        expect(stamp.center.dx, lessThanOrEqualTo(_size.width - marginX));
        expect(stamp.center.dy, lessThanOrEqualTo(_size.height - marginY));
      }
    });

    test('no two stamps have identical centres', () {
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
        seed: 0,
      );
      final centres = result.map((s) => s.center).toSet();
      expect(centres.length, result.length);
    });

    test('caps at 20 stamps for large input', () {
      final codes = List.generate(30, (i) {
        final c = String.fromCharCode(65 + i % 26);
        return '$c${String.fromCharCode(65 + (i + 1) % 26)}';
      });
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: codes,
        canvasSize: _size,
      );
      expect(result.length, lessThanOrEqualTo(20));
    });

    test('trip stamps include date labels; bare code stamps do not', () {
      final trips = [_trip('FR', DateTime(2022, 6, 1))];
      final result = PassportLayoutEngine.layout(
        trips: trips,
        countryCodes: ['FR', 'DE'],
        canvasSize: _size,
        seed: 42,
      );
      final frStamp = result.firstWhere((s) => s.countryCode == 'FR');
      final deStamp = result.firstWhere((s) => s.countryCode == 'DE');
      expect(frStamp.dateLabel, isNotNull);
      expect(deStamp.dateLabel, isNull);
    });

    test('alternates ENTRY/EXIT labels', () {
      final trips = [
        _trip('FR', DateTime(2021, 1, 1)),
        _trip('DE', DateTime(2021, 6, 1)),
        _trip('JP', DateTime(2022, 1, 1)),
      ];
      final result = PassportLayoutEngine.layout(
        trips: trips,
        countryCodes: ['FR', 'DE', 'JP'],
        canvasSize: _size,
        seed: 0,
      );
      // Even index → ENTRY, odd → EXIT
      for (var i = 0; i < result.length; i++) {
        expect(result[i].entryLabel, i % 2 == 0 ? 'ENTRY' : 'EXIT');
      }
    });
  });
}
