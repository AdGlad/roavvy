// Verifies the continent-outline fitting fix: far-flung outlier polygons are
// dropped so the main landmass fills the target at its true aspect (no tiny,
// skewed sliver). Country outlines (single polygon) are unaffected.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/country_path_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<double?> aspectOf(String code) async {
    // Square target → fit-inside means the path bounds equal the shape aspect.
    final p = await CountryPathService.pathFor(code, const Size(1000, 1000));
    if (p == null) return null;
    final b = p.getBounds();
    return b.height == 0 ? null : b.width / b.height;
  }

  test('country outline (au) is unchanged by outlier filtering', () async {
    final ar = await aspectOf('au');
    expect(ar, isNotNull);
    expect(ar!, closeTo(1.41, 0.15));
  });

  test('oceania outline no longer skewed by antimeridian outliers', () async {
    // Was AR ~4.78 (polys wrapped to x=-7292); after dropping outliers it is
    // Australia-dominated (~1.3).
    final ar = await aspectOf('oceania');
    expect(ar, isNotNull);
    expect(ar!, lessThan(2.0));
    expect(ar, greaterThan(0.8));
  });

  test('africa outline is roughly square (not an inflated sliver)', () async {
    final ar = await aspectOf('africa');
    expect(ar, isNotNull);
    expect(ar!, lessThan(1.5));
    expect(ar, greaterThan(0.6));
  });

  test('europe outline has recognizable proportions (regenerated data)',
      () async {
    // Was ~2.5–4.5 (mis-projected flat sliver); the regenerated Mercator
    // outline is ~1.1, so it fills the print area like a country outline.
    final ar = await aspectOf('europe');
    expect(ar, isNotNull);
    expect(ar!, lessThan(1.5));
    expect(ar, greaterThan(0.8));
  });
}
