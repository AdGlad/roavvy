// RegionMapService unit tests (M203/M204).
//
// These load the REAL bundled continent assets (no mock), like
// continent_outline_bounds_test.dart, verifying the per-country region map is
// parsed into aligned raw-frame paths.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/region_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegionMapService.mapFor', () {
    test('europe returns a populated RegionMap in frame bounds', () async {
      final map = await RegionMapService.mapFor('europe');
      expect(map, isNotNull);

      // Frame is the shared [0, w] × [0, h] window (w is 1000 in the data).
      expect(map!.w, greaterThan(0));
      expect(map.h, greaterThan(0));

      // Many countries, including well-known members.
      expect(map.countries.length, greaterThan(20));
      // NOTE: the bundled Europe dataset does not include 'FR' (France is not
      // present in the source polygons); assert on codes that are bundled.
      for (final iso in ['DE', 'GB', 'ES', 'IT']) {
        expect(map.countries.containsKey(iso), isTrue, reason: '$iso missing');
      }

      // Outline path is present and non-empty.
      expect(map.outline.getBounds().isEmpty, isFalse);

      // Every country path lies within the frame bounds (raw coords, no fit).
      final frame = Rect.fromLTWH(-1, -1, map.w + 2, map.h + 2);
      for (final entry in map.countries.entries) {
        final b = entry.value.getBounds();
        expect(frame.contains(b.topLeft), isTrue, reason: '${entry.key} TL');
        expect(frame.contains(b.bottomRight), isTrue,
            reason: '${entry.key} BR');
      }
      // Outline within the frame too (shared transform).
      final ob = map.outline.getBounds();
      expect(frame.contains(ob.topLeft), isTrue);
      expect(frame.contains(ob.bottomRight), isTrue);
    });

    test('returns null for a non-continent key', () async {
      expect(await RegionMapService.mapFor('atlantis'), isNull);
      expect(await RegionMapService.mapFor('fr'), isNull);
      expect(await RegionMapService.mapFor(''), isNull);
    });

    test('caches and returns the same instance on second call', () async {
      final a = await RegionMapService.mapFor('africa');
      final b = await RegionMapService.mapFor('africa');
      expect(a, isNotNull);
      expect(identical(a, b), isTrue);
    });
  });
}
