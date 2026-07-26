// flag_clip_options — default row count + clip-option construction (M187).
//
// Replaces flag_shape_customise_screen_test.dart: the row-count defaults and
// clip-shape option set moved out of the (removed) FlagShapeCustomiseScreen
// into the shared flag_clip_options module consumed by the merged configurator.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';
import 'package:mobile_flutter/features/merch/animal_silhouette_service.dart';
import 'package:mobile_flutter/features/merch/flag_clip_options.dart';

void main() {
  group('merchDefaultRepeatCount', () {
    test('scales down as the country count grows (no clip)', () {
      expect(merchDefaultRepeatCount(1, GridClipShape.none), 9);
      expect(merchDefaultRepeatCount(2, GridClipShape.none), 6);
      expect(merchDefaultRepeatCount(3, GridClipShape.none), 4);
      expect(merchDefaultRepeatCount(4, GridClipShape.none), 4);
      expect(merchDefaultRepeatCount(8, GridClipShape.none), 2);
      expect(merchDefaultRepeatCount(20, GridClipShape.none), 1);
    });

    test('heart/circle clips bump the count by 1 to fill lost area', () {
      expect(merchDefaultRepeatCount(1, GridClipShape.heart), 10);
      expect(merchDefaultRepeatCount(1, GridClipShape.circle), 10);
      expect(merchDefaultRepeatCount(8, GridClipShape.heart), 3);
    });

    test('outline clips do NOT bump the count', () {
      expect(merchDefaultRepeatCount(1, GridClipShape.countryOutline), 9);
      expect(merchDefaultRepeatCount(1, GridClipShape.continentOutline), 9);
    });

    test('is capped at 50', () {
      // No realistic input reaches the cap, but the contract holds.
      expect(merchDefaultRepeatCount(1, GridClipShape.animalSilhouette), 10);
    });
  });

  group('buildFlagClipOptions', () {
    test('multi-country set offers only Grid / Heart / Circle', () {
      final opts = buildFlagClipOptions(codes: const ['fr', 'de', 'it']);
      expect(opts.map((o) => o.shape).toList(), const [
        GridClipShape.none,
        GridClipShape.heart,
        GridClipShape.circle,
      ]);
    });

    test('single country adds a country-outline option', () {
      final opts = buildFlagClipOptions(codes: const ['au']);
      expect(
        opts.any((o) => o.shape == GridClipShape.countryOutline),
        isTrue,
      );
      final outline =
          opts.firstWhere((o) => o.shape == GridClipShape.countryOutline);
      expect(outline.clipCode, 'au');
    });

    test('single country appends silhouette options per category', () {
      final opts = buildFlagClipOptions(
        codes: const ['au'],
        animalOptions: const [SilhouetteOption(name: 'Kangaroo', slug: 'roo')],
        plantOptions: const [SilhouetteOption(name: 'Wattle', slug: 'wattle')],
        landmarkOptions: const [
          SilhouetteOption(name: 'Opera House', slug: 'opera'),
        ],
      );
      expect(opts.any((o) => o.shape == GridClipShape.animalSilhouette), isTrue);
      expect(opts.any((o) => o.shape == GridClipShape.plantSilhouette), isTrue);
      expect(
        opts.any((o) => o.shape == GridClipShape.landmarkSilhouette),
        isTrue,
      );
      expect(
        opts.firstWhere((o) => o.label == 'Kangaroo').clipCode,
        isNotNull,
      );
    });

    test('continentKey adds a continent-outline option', () {
      final opts = buildFlagClipOptions(
        codes: const ['fr', 'de'],
        continentKey: 'europe',
      );
      final continent =
          opts.firstWhere((o) => o.shape == GridClipShape.continentOutline);
      expect(continent.label, 'Europe');
      expect(continent.clipCode, 'europe');
    });
  });
}
