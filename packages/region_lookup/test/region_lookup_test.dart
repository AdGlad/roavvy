import 'dart:typed_data';

import 'package:region_lookup/region_lookup.dart';
import 'package:test/test.dart';

import 'test_geodata_builder.dart';

/// Test polygons — simple rectangles so expected results are unambiguous.
///
/// US-CA: California approx   32–42 °N, −124–−114 °E
/// US-NY: New York approx     40–45 °N,  −80–−71 °E
/// GB-ENG: England approx     50–55 °N,   −5–2 °E
/// FR-IDF: Île-de-France appr 48–49 °N,    2–3 °E
/// AU-NSW: New South Wales ap −38–−28 °N, 141–154 °E
/// DE-BY:  Bavaria approx     47–50 °N,   11–14 °E
///
/// Rectangles are chosen so that representative capitals fall clearly
/// inside exactly one region and open-ocean points fall in none.
Uint8List _buildTestData() {
  final b = TestGeodataBuilder()
    ..addRect('US-CA', 32.0, 42.0, -124.0, -114.0)
    ..addRect('US-NY', 40.0, 45.0, -80.0, -71.0)
    ..addRect('GB-ENG', 50.0, 55.0, -5.0, 2.0)
    ..addRect('FR-IDF', 48.0, 49.0, 2.0, 3.0)
    ..addRect('AU-NSW', -38.0, -28.0, 141.0, 154.0)
    ..addRect('DE-BY', 47.0, 50.0, 11.0, 14.0);
  return b.build();
}

void main() {
  setUp(() => initRegionLookup(_buildTestData()));

  // ── Known capitals / cities ───────────────────────────────────────────────

  group('known city coordinates resolve to correct ISO 3166-2 codes', () {
    test('Sacramento (CA capital) → US-CA', () {
      // Sacramento: 38.58 °N, −121.49 °E — well inside US-CA rect
      expect(resolveRegion(38.58, -121.49), equals('US-CA'));
    });

    test('Los Angeles → US-CA', () {
      expect(resolveRegion(34.05, -118.24), equals('US-CA'));
    });

    test('Albany (NY capital) → US-NY', () {
      // Albany: 42.65 °N, −73.76 °E
      expect(resolveRegion(42.65, -73.76), equals('US-NY'));
    });

    test('New York City → US-NY', () {
      expect(resolveRegion(40.71, -74.01), equals('US-NY'));
    });

    test('London → GB-ENG', () {
      // London: 51.5 °N, −0.12 °E
      expect(resolveRegion(51.5, -0.12), equals('GB-ENG'));
    });

    test('Manchester → GB-ENG', () {
      expect(resolveRegion(53.48, -2.24), equals('GB-ENG'));
    });

    test('Paris (FR-IDF capital) → FR-IDF', () {
      // Paris: 48.85 °N, 2.35 °E — inside FR-IDF rect
      expect(resolveRegion(48.85, 2.35), equals('FR-IDF'));
    });

    test('Sydney (AU-NSW) → AU-NSW', () {
      // Sydney: −33.87 °S, 151.21 °E
      expect(resolveRegion(-33.87, 151.21), equals('AU-NSW'));
    });

    test('Munich (DE-BY capital) → DE-BY', () {
      // Munich: 48.14 °N, 11.58 °E
      expect(resolveRegion(48.14, 11.58), equals('DE-BY'));
    });
  });

  // ── Open water / unresolvable → null ─────────────────────────────────────

  group('coordinates with no matching polygon return null', () {
    test('open Atlantic ocean', () {
      expect(resolveRegion(0.0, -30.0), isNull);
    });

    test('Null Island (0 °N, 0 °E)', () {
      expect(resolveRegion(0.0, 0.0), isNull);
    });

    test('North Pole (90 °N)', () {
      expect(resolveRegion(90.0, 0.0), isNull);
    });

    test('South Pole (−90 °N)', () {
      expect(resolveRegion(-90.0, 0.0), isNull);
    });

    test('open Pacific ocean', () {
      expect(resolveRegion(20.0, -150.0), isNull);
    });

    test('open Indian ocean', () {
      expect(resolveRegion(-20.0, 80.0), isNull);
    });
  });

  // ── Out-of-range coordinates ──────────────────────────────────────────────

  group('out-of-range coordinates return null without throwing', () {
    test('latitude > 90', () {
      expect(resolveRegion(91.0, 0.0), isNull);
    });

    test('latitude < −90', () {
      expect(resolveRegion(-91.0, 0.0), isNull);
    });

    test('longitude > 180', () {
      expect(resolveRegion(0.0, 181.0), isNull);
    });

    test('longitude < −180', () {
      expect(resolveRegion(0.0, -181.0), isNull);
    });
  });

  // ── ISO 3166-2 code format ────────────────────────────────────────────────

  group('returned codes are valid ISO 3166-2 format (CC-XXX)', () {
    const testCoords = [
      (38.58, -121.49), // US-CA
      (42.65, -73.76),  // US-NY
      (51.5,  -0.12),   // GB-ENG
      (48.85,  2.35),   // FR-IDF
      (-33.87, 151.21), // AU-NSW
      (48.14,  11.58),  // DE-BY
    ];

    for (final (lat, lng) in testCoords) {
      test('code at ($lat, $lng) matches CC-XXX pattern', () {
        final code = resolveRegion(lat, lng);
        expect(code, isNotNull);
        // ISO 3166-2: 2-letter country prefix, dash, 1–3 alphanumeric suffix.
        expect(code, matches(RegExp(r'^[A-Z]{2}-[A-Z0-9]{1,3}$')));
      });
    }
  });

  // ── Binary format validation ──────────────────────────────────────────────

  group('binary format validation', () {
    test('bad magic bytes throw FormatException', () {
      final bad = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(
        () => initRegionLookup(bad),
        throwsA(isA<FormatException>()),
      );
    });

    test('wrong version throws FormatException', () {
      final valid = _buildTestData();
      final corrupted = Uint8List.fromList(valid);
      corrupted[4] = 99; // unsupported version byte
      expect(
        () => initRegionLookup(corrupted),
        throwsA(isA<FormatException>()),
      );
    });

    test('magic must be RLRG not RLKP (country_lookup magic)', () {
      // country_lookup binary should be rejected.
      final wrongMagic = Uint8List.fromList([
        0x52, 0x4C, 0x4B, 0x50, // "RLKP" — country_lookup magic
      ]);
      expect(
        () => initRegionLookup(wrongMagic),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ── Multi-polygon regions ─────────────────────────────────────────────────

  group('multi-polygon regions', () {
    test('same region code across two separate polygons both resolve', () {
      // US-HI (Hawaii) as a second polygon for US-CA test code stand-in.
      final b = TestGeodataBuilder()
        ..addRect('US-CA', 32.0, 42.0, -124.0, -114.0)
        ..addRect('US-CA', 18.5, 22.5, -160.0, -154.5); // Hawaii-ish
      initRegionLookup(b.build());

      // Mainland California point.
      expect(resolveRegion(36.0, -119.0), equals('US-CA'));
      // Hawaii point.
      expect(resolveRegion(20.0, -157.0), equals('US-CA'));
    });
  });

  // ── Variable-length code round-trip ──────────────────────────────────────

  group('variable-length region codes survive binary round-trip', () {
    test('short code (2-char suffix: US-CA) round-trips correctly', () {
      final b = TestGeodataBuilder()
        ..addRect('US-CA', 32.0, 42.0, -124.0, -114.0);
      initRegionLookup(b.build());
      expect(resolveRegion(36.0, -119.0), equals('US-CA'));
    });

    test('long code (3-char suffix: GB-ENG) round-trips correctly', () {
      final b = TestGeodataBuilder()
        ..addRect('GB-ENG', 50.0, 55.0, -5.0, 2.0);
      initRegionLookup(b.build());
      expect(resolveRegion(51.5, -0.12), equals('GB-ENG'));
    });

    test('numeric suffix (AU-2) round-trips correctly', () {
      // Some Natural Earth admin1 records use numeric suffixes.
      final b = TestGeodataBuilder()
        ..addRect('AU-2', -38.0, -28.0, 141.0, 154.0);
      initRegionLookup(b.build());
      expect(resolveRegion(-33.87, 151.21), equals('AU-2'));
    });
  });

  // ── Border / boundary cases ───────────────────────────────────────────────

  group('border-adjacent coordinates do not throw', () {
    test('point on northern boundary of US-CA rect', () {
      expect(() => resolveRegion(42.0, -119.0), returnsNormally);
    });

    test('point between US-CA and US-NY (open gap) returns null', () {
      // −113 °E is east of US-CA and west of US-NY: no polygon covers it.
      expect(resolveRegion(41.0, -113.0), isNull);
    });
  });

  // ── Coastal fallback ──────────────────────────────────────────────────────

  group('coastal fallback — point just outside polygon resolves via neighbour',
      () {
    // US-CA rect: lat [32, 42], lng [−124, −114].
    // A point 0.1° south of the southern boundary is outside the rect, but
    // the coastal fallback should find it by nudging 0.25° north.
    test('point 0.1° south of US-CA southern edge resolves to US-CA', () {
      // 31.9 °N is outside [32, 42] N, but nudging +0.25° puts it at 32.15 °N
      // which is inside the rect.
      expect(resolveRegion(31.9, -119.0), equals('US-CA'));
    });

    test('point 0.1° north of US-CA northern edge resolves to US-CA', () {
      // 42.1 °N is outside [32, 42] N, but nudging −0.25° puts it at 41.85 °N.
      expect(resolveRegion(42.1, -119.0), equals('US-CA'));
    });

    test('point 0.1° west of US-CA western edge resolves to US-CA', () {
      // −124.1 °E is outside [−124, −114] E, nudging +0.25° puts it at −123.85.
      expect(resolveRegion(37.0, -124.1), equals('US-CA'));
    });

    test('open gap > 0.25° away from any polygon still returns null', () {
      // −113 °E is > 0.25° from US-CA (boundary at −114) and from US-NY.
      // The fallback cannot bridge a 1° gap.
      expect(resolveRegion(41.0, -113.0), isNull);
    });
  });
}
