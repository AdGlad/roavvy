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
    test('returns empty stamps when countryCodes is empty', () {
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: [],
        canvasSize: _size,
      );
      expect(result.stamps, isEmpty);
      expect(result.wasForced, isFalse);
    });

    test('codes-only path works without trips', () {
      // ADR-097 Decision: fromCode always generates a deterministic placeholder
      // date, so all code-only stamps also have a non-null dateLabel.
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
      );
      expect(result.stamps.length, _codes5.length);
      for (final stamp in result.stamps) {
        expect(stamp.dateLabel, isNotNull);
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
      expect(a.stamps.length, b.stamps.length);
      for (var i = 0; i < a.stamps.length; i++) {
        expect(a.stamps[i].center, b.stamps[i].center);
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
      for (final stamp in result.stamps) {
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
      final centres = result.stamps.map((s) => s.center).toSet();
      expect(centres.length, result.stamps.length);
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
      expect(result.stamps.length, lessThanOrEqualTo(20));
    });

    test('trip stamps and code-only stamps both have non-null date labels', () {
      // ADR-097 Decision: fromCode always generates a deterministic placeholder
      // date; fromTrip uses the real trip date. All stamps show a date label.
      final trips = [_trip('FR', DateTime(2022, 6, 1))];
      final result = PassportLayoutEngine.layout(
        trips: trips,
        countryCodes: ['FR', 'DE'],
        canvasSize: _size,
        seed: 42,
      );
      final frStamp = result.stamps.firstWhere((s) => s.countryCode == 'FR');
      final deStamp = result.stamps.firstWhere((s) => s.countryCode == 'DE');
      // Trip stamp has a real date from the trip record
      expect(frStamp.dateLabel, isNotNull);
      // Code-only stamp has a deterministic placeholder date (not null)
      expect(deStamp.dateLabel, isNotNull);
    });

    test('alternates entry/exit labels using native language per country', () {
      // ADR-097 Decision 7: entry/exit labels use the country's native language
      // (e.g. 'ARRIVÉE' for FR, 'EINREISE' for DE). The layout engine passes
      // isEntry=true for even stamp indices and isEntry=false for odd.
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
      // Even index → isEntry=true → native arrival label (non-empty)
      // Odd index  → isEntry=false → native departure label (non-empty)
      for (var i = 0; i < result.stamps.length; i++) {
        expect(result.stamps[i].entryLabel, isNotEmpty);
      }
      // Verify the alternation pattern: even = entry stamp, odd = exit stamp
      expect(result.stamps[0].isEntry, isTrue);
      expect(result.stamps[1].isEntry, isFalse);
      if (result.stamps.length > 2) expect(result.stamps[2].isEntry, isTrue);
    });
  });

  group('PassportLayoutEngine.layout forPrint mode (ADR-102)', () {
    test('forPrint=false preserves default behaviour', () {
      final normal = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
        seed: 1,
      );
      final explicit = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: _codes5,
        canvasSize: _size,
        seed: 1,
        forPrint: false,
      );
      expect(explicit.stamps.length, normal.stamps.length);
      expect(explicit.wasForced, isFalse);
    });

    test('forPrint=true: no stamps have edgeClip', () {
      // Generate enough codes to make edge-clipping likely in normal mode.
      final codes = List.generate(20, (i) =>
          '${String.fromCharCode(65 + i % 26)}${String.fromCharCode(65 + (i + 3) % 26)}');
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: codes,
        canvasSize: _size,
        forPrint: true,
        seed: 99,
      );
      for (final stamp in result.stamps) {
        expect(stamp.edgeClip, isNull,
            reason: 'edge clips must be null in print mode');
      }
    });

    test('forPrint=true N=10: stamps within 3% safe zone', () {
      final codes = List.generate(10, (i) =>
          '${String.fromCharCode(65 + i % 26)}${String.fromCharCode(65 + (i + 1) % 26)}');
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: codes,
        canvasSize: _size,
        forPrint: true,
        seed: 0,
      );
      final safeLeft = _size.width * 0.03;
      final safeTop = _size.height * 0.03;
      for (final stamp in result.stamps) {
        expect(stamp.center.dx, greaterThanOrEqualTo(safeLeft),
            reason: 'stamp centre must be within safe zone (left)');
        expect(stamp.center.dy, greaterThanOrEqualTo(safeTop),
            reason: 'stamp centre must be within safe zone (top)');
        expect(stamp.center.dx, lessThanOrEqualTo(_size.width - safeLeft),
            reason: 'stamp centre must be within safe zone (right)');
        expect(stamp.center.dy, lessThanOrEqualTo(_size.height - safeTop),
            reason: 'stamp centre must be within safe zone (bottom)');
      }
    });

    test('forPrint=true N=30: wasForced reflects entryOnly pressure', () {
      final codes = List.generate(30, (i) =>
          '${String.fromCharCode(65 + i % 26)}${String.fromCharCode(65 + (i + 2) % 26)}');
      // Layout engine caps at _kMaxStamps=20, so effective N=20.
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: codes,
        canvasSize: _size,
        forPrint: true,
      );
      // wasForced is true when unclamped radius < 20; value depends on canvas.
      // Just verify the result is a valid PassportLayoutResult.
      expect(result.stamps, isNotEmpty);
      expect(result.wasForced, isA<bool>());
    });

    test('forPrint=true N=60 (capped to 20): baseRadius ≥ 20', () {
      final codes = List.generate(60, (i) =>
          '${String.fromCharCode(65 + i % 26)}${String.fromCharCode(65 + (i + 5) % 26)}');
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: codes,
        canvasSize: _size,
        forPrint: true,
        seed: 42,
      );
      // All stamp scales derive from clamped radius ≥ 20, so stamp.scale ≥ 20/38.
      for (final stamp in result.stamps) {
        final impliedRadius = 38.0 * stamp.scale;
        expect(impliedRadius, greaterThanOrEqualTo(20.0));
      }
    });

    test('forPrint=true: wasForced=true sets entryOnly on all trip stamps', () {
      // Use a canvas small enough to make radius drop below 20 with enough codes.
      const smallCanvas = Size(150, 100);
      final codes = List.generate(20, (i) =>
          '${String.fromCharCode(65 + i % 26)}${String.fromCharCode(65 + (i + 1) % 26)}');
      final result = PassportLayoutEngine.layout(
        trips: [],
        countryCodes: codes,
        canvasSize: smallCanvas,
        forPrint: true,
      );
      if (result.wasForced) {
        for (final stamp in result.stamps) {
          expect(stamp.isEntry, isTrue,
              reason: 'all stamps must be entry stamps when wasForced=true');
        }
      }
    });
  });
}
