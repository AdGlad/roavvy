import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/map/country_centroids.dart';

void main() {
  test('kCountryCentroids contains key countries', () {
    for (final code in ['JP', 'FR', 'BR', 'AU', 'US', 'GB']) {
      expect(kCountryCentroids, contains(code),
          reason: 'Missing centroid for $code');
    }
  });

  test('kCountryCentroids JP returns expected approximate centroid', () {
    final (lat, lng) = kCountryCentroids['JP']!;
    expect(lat, closeTo(36.2, 1.0));
    expect(lng, closeTo(138.3, 1.0));
  });

  test('kCountryCentroids has at least 150 entries', () {
    expect(kCountryCentroids.length, greaterThanOrEqualTo(150));
  });

  test('kCountryCentroids all latitudes are in valid range', () {
    for (final entry in kCountryCentroids.entries) {
      final (lat, lng) = entry.value;
      expect(lat, inInclusiveRange(-90.0, 90.0),
          reason: '${entry.key} lat out of range');
      expect(lng, inInclusiveRange(-180.0, 180.0),
          reason: '${entry.key} lng out of range');
    }
  });
}
