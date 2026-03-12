import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:test/test.dart';

import 'test_geodata_builder.dart';

/// Rectangular test polygons — deliberately simple so tests are predictable.
///
/// GB:  49–61 °N,  −8–2 °E   (covers London 51.5, −0.12)
/// JP: 30–46 °N, 130–146 °E  (covers Tokyo  35.68, 139.69)
/// US: 24–49 °N, −125–−66 °E (covers New York 40.71, −74.01)
/// FR: 42–51 °N,  −5–8 °E   (covers Paris  48.85, 2.35)
///
/// Paris longitude (2.35 °E) is east of GB's eastern edge (2 °E), so Paris
/// falls only inside FR. London (51.5 °N) is north of FR's northern edge
/// (51 °N), so London falls only inside GB. No ambiguity for the key cases.
Uint8List _buildTestData() {
  final b = TestGeodataBuilder()
    ..addRect('GB', 49.0, 61.0, -8.0, 2.0)
    ..addRect('JP', 30.0, 46.0, 130.0, 146.0)
    ..addRect('US', 24.0, 49.0, -125.0, -66.0)
    ..addRect('FR', 42.0, 51.0, -5.0, 8.0);
  return b.build();
}

void main() {
  setUp(() => initCountryLookup(_buildTestData()));

  // ── Known cities ──────────────────────────────────────────────────────────

  group('known cities resolve to the correct country', () {
    test('London → GB', () {
      expect(resolveCountry(51.5, -0.12), equals('GB'));
    });

    test('Tokyo → JP', () {
      expect(resolveCountry(35.68, 139.69), equals('JP'));
    });

    test('New York → US', () {
      expect(resolveCountry(40.71, -74.01), equals('US'));
    });

    test('Paris → FR', () {
      expect(resolveCountry(48.85, 2.35), equals('FR'));
    });
  });

  // ── Null returns ──────────────────────────────────────────────────────────

  group('coordinates with no matching polygon return null', () {
    test('open Atlantic ocean', () {
      expect(resolveCountry(0.0, -30.0), isNull);
    });

    test('Null Island (0 °N, 0 °E)', () {
      expect(resolveCountry(0.0, 0.0), isNull);
    });

    test('North Pole (90 °N)', () {
      expect(resolveCountry(90.0, 0.0), isNull);
    });

    test('South Pole (−90 °N)', () {
      expect(resolveCountry(-90.0, 0.0), isNull);
    });
  });

  // ── Out-of-range coordinates ──────────────────────────────────────────────

  group('out-of-range coordinates return null without throwing', () {
    test('latitude > 90', () {
      expect(resolveCountry(91.0, 0.0), isNull);
    });

    test('latitude < −90', () {
      expect(resolveCountry(-91.0, 0.0), isNull);
    });

    test('longitude > 180', () {
      expect(resolveCountry(0.0, 181.0), isNull);
    });

    test('longitude < −180', () {
      expect(resolveCountry(0.0, -181.0), isNull);
    });
  });

  // ── Border cases ──────────────────────────────────────────────────────────

  group('border-adjacent coordinates do not throw', () {
    test('point exactly on northern boundary of GB rect', () {
      // Must not throw; either GB or null is acceptable for exact-boundary coords.
      expect(() => resolveCountry(61.0, 0.0), returnsNormally);
    });

    test('point at lat shared by GB and FR (49 °N, 0 °E)', () {
      // Lat 49 is GB southern boundary and within FR range.
      // Result is implementation-defined for exact-boundary coords; must not throw.
      expect(() => resolveCountry(49.0, 0.0), returnsNormally);
      final result = resolveCountry(49.0, 0.0);
      expect(result, anyOf(isNull, equals('GB'), equals('FR')));
    });
  });

  // ── Return value validity ─────────────────────────────────────────────────

  group('returned country codes are valid ISO 3166-1 alpha-2', () {
    const testCoords = [
      (51.5, -0.12),    // GB
      (35.68, 139.69),  // JP
      (40.71, -74.01),  // US
      (48.85, 2.35),    // FR
    ];

    for (final (lat, lng) in testCoords) {
      test('code at ($lat, $lng) is exactly 2 uppercase ASCII letters', () {
        final code = resolveCountry(lat, lng);
        expect(code, isNotNull);
        expect(code!.length, equals(2));
        expect(code, matches(RegExp(r'^[A-Z]{2}$')));
      });
    }
  });

  // ── loadPolygons ──────────────────────────────────────────────────────────

  group('loadPolygons', () {
    test('returns one entry per polygon in the test data', () {
      // Test data has 4 single-ring polygons: GB, JP, US, FR.
      expect(loadPolygons(), hasLength(4));
    });

    test('all returned isoCode values are 2 uppercase ASCII letters', () {
      for (final p in loadPolygons()) {
        expect(p.isoCode, matches(RegExp(r'^[A-Z]{2}$')));
      }
    });

    test('expected country codes are present', () {
      final codes = loadPolygons().map((p) => p.isoCode).toSet();
      expect(codes, containsAll({'GB', 'JP', 'US', 'FR'}));
    });

    test('every polygon has at least 3 vertices', () {
      for (final p in loadPolygons()) {
        expect(
          p.vertices.length,
          greaterThanOrEqualTo(3),
          reason: '${p.isoCode} polygon must have ≥ 3 vertices',
        );
      }
    });

    test('all vertices are within valid coordinate ranges', () {
      for (final p in loadPolygons()) {
        for (final (lat, lng) in p.vertices) {
          expect(
            lat, inInclusiveRange(-90.0, 90.0),
            reason: '${p.isoCode} lat $lat out of range',
          );
          expect(
            lng, inInclusiveRange(-180.0, 180.0),
            reason: '${p.isoCode} lng $lng out of range',
          );
        }
      }
    });

    test('multi-ring country produces multiple entries sharing the same code', () {
      final b = TestGeodataBuilder()
        ..addRect('US', 24.0, 49.0, -125.0, -66.0) // mainland
        ..addRect('US', 18.0, 23.0, -161.0, -154.0); // Hawaii approx
      initCountryLookup(b.build());

      final usPolygons =
          loadPolygons().where((p) => p.isoCode == 'US').toList();
      expect(usPolygons, hasLength(2));
    });

    test('returned list is unmodifiable', () {
      expect(
        () => loadPolygons().add(loadPolygons().first),
        throwsUnsupportedError,
      );
    });
  });

  // ── Binary format ─────────────────────────────────────────────────────────

  group('binary format validation', () {
    test('bad magic bytes throw FormatException', () {
      final bad = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(
        () => initCountryLookup(bad),
        throwsA(isA<FormatException>()),
      );
    });

    test('wrong version throws FormatException', () {
      // Build a valid file and corrupt the version byte (offset 4).
      final valid = _buildTestData();
      final corrupted = Uint8List.fromList(valid);
      corrupted[4] = 99; // unsupported version
      expect(
        () => initCountryLookup(corrupted),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
