// Verifies two fixes to the map's full-screen photo viewer:
//   1. computeMapGalleryPhotos: once a sort anchor is set (a heat-tap), the
//      gallery spans the WHOLE library by distance, not just the current
//      viewport — and the viewport-filtered/newest-first default still
//      applies when no anchor is set.
//   2. MapPhotoViewer's image fills the screen (explicit width/height +
//      BoxFit.contain) instead of rendering at its native decoded pixel
//      size, and requests the FULL-RESOLUTION image (size: 0), not a fixed
//      800px thumbnail.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/data/photo_gps_repository.dart';
import 'package:mobile_flutter/features/map/map_photo_viewer.dart';

// Minimal valid 1×1 RGB PNG (69 bytes) — same fixture used by
// artwork_confirmation_screen_test.dart.
final _kFakePng = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
  0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 120,
  156, 99, 72, 153, 153, 118, 2, 0, 3, 36, 1, 195, 32, 85, 100, 163, 0, 0, 0,
  0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  group('computeMapGalleryPhotos', () {
    final locations = [
      const PhotoLocation('near', 10.0, 10.0),
      const PhotoLocation('far', -10.0, -10.0),
      const PhotoLocation('outside-viewport', 50.0, 50.0),
    ];

    test('no anchor: viewport-filters and orders newest-first', () {
      final result = computeMapGalleryPhotos(
        locations: locations,
        sortAnchor: null,
        viewport: (north: 20.0, south: -20.0, east: 20.0, west: -20.0),
      );
      // "outside-viewport" excluded; newest-first reverses input order.
      expect(
        result.photos.map((p) => p.assetId),
        ['far', 'near'],
      );
      expect(result.totalCount, 2);
    });

    test('anchor set: sorts the WHOLE library by distance, ignoring viewport',
        () {
      final result = computeMapGalleryPhotos(
        locations: locations,
        sortAnchor: const PhotoLocation('anchor', 9.0, 9.0),
        // A viewport that would normally exclude 'outside-viewport'.
        viewport: (north: 20.0, south: -20.0, east: 20.0, west: -20.0),
      );
      // Nearest-to-anchor first (near, then far, then the far-flung
      // outside-viewport point) — crucially 'outside-viewport' is NOT
      // excluded at all, proving the sort spans the full library rather
      // than being pre-filtered to the viewport subset.
      expect(
        result.photos.map((p) => p.assetId),
        ['near', 'far', 'outside-viewport'],
      );
      expect(result.totalCount, locations.length);
    });

    test('empty locations returns empty result', () {
      final result = computeMapGalleryPhotos(
        locations: const [],
        sortAnchor: null,
        viewport: null,
      );
      expect(result.photos, isEmpty);
      expect(result.totalCount, 0);
    });
  });

  group('MapPhotoViewer', () {
    const channel = MethodChannel('roavvy/thumbnail');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return _kFakePng;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('image fills the screen and requests full resolution',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapPhotoViewer(
            assetIds: ['asset-1'],
            initialIndex: 0,
          ),
        ),
      );
      // Let the async getFullResolutionImage() call resolve.
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, double.infinity);
      expect(image.height, double.infinity);
      expect(image.fit, BoxFit.contain);

      // getFullResolutionImage() calls getThumbnail(assetId, size: 0) —
      // confirms the viewer no longer requests the old fixed 800px image.
      final sizes = calls
          .where((c) => c.method == 'getThumbnail')
          .map((c) => (c.arguments as Map)['size']);
      expect(sizes, contains(0));
    });
  });
}
