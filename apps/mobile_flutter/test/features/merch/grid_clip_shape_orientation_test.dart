// isPortraitForClipShape — fallback-to-null contract.
//
// Shapes with no country-specific image (none/heart/circle) and a missing
// clip code should always resolve to null so callers fall back to their
// template default, without needing any asset/network access. The
// shape-specific branches (animal/plant/landmark silhouette, country/
// continent outline) hit Firebase Storage / bundled assets via
// AnimalSilhouetteService / CountryPathService and aren't covered here —
// see flag_shape_customise_screen_test.dart for the row-count default that
// consumes this same module.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';
import 'package:mobile_flutter/features/merch/grid_clip_shape_orientation.dart';

void main() {
  group('isPortraitForClipShape — no natural orientation', () {
    test('returns null for GridClipShape.none regardless of code', () async {
      expect(
        await isPortraitForClipShape(GridClipShape.none, 'AU'),
        isNull,
      );
    });

    test('returns null for GridClipShape.heart regardless of code', () async {
      expect(
        await isPortraitForClipShape(GridClipShape.heart, 'AU'),
        isNull,
      );
    });

    test('returns null for GridClipShape.circle regardless of code', () async {
      expect(
        await isPortraitForClipShape(GridClipShape.circle, 'AU'),
        isNull,
      );
    });

    test('returns null when clipCode is null, for any shape', () async {
      expect(
        await isPortraitForClipShape(GridClipShape.animalSilhouette, null),
        isNull,
      );
      expect(
        await isPortraitForClipShape(GridClipShape.countryOutline, null),
        isNull,
      );
    });
  });

  group('kPortraitCardAspectRatio / kLandscapeCardAspectRatio', () {
    test('portrait is narrower than landscape', () {
      expect(kPortraitCardAspectRatio, lessThan(1.0));
      expect(kLandscapeCardAspectRatio, greaterThan(1.0));
    });

    test('the two ratios are reciprocals (2:3 vs 3:2)', () {
      expect(
        kPortraitCardAspectRatio * kLandscapeCardAspectRatio,
        closeTo(1.0, 0.0001),
      );
    });
  });
}
