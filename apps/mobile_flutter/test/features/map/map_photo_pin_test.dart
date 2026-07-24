// Verifies GlobeHeroPin — the globe's equivalent of the flat map's
// PhotoPinLayer, added so "the hero image feature on the flat map" is also
// available on the globe (same look, same tap-to-view behaviour, just
// projected via GlobeProjection instead of a flutter_map Marker).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/photo_gps_repository.dart';
import 'package:mobile_flutter/features/map/globe_projection.dart';
import 'package:mobile_flutter/features/map/map_photo_pin.dart';
import 'package:mobile_flutter/features/map/map_photo_viewer.dart';

final _kFakePng = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
  0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 120,
  156, 99, 72, 153, 153, 118, 2, 0, 3, 36, 1, 195, 32, 85, 100, 163, 0, 0, 0,
  0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

const _kSize = Size(400, 800);
const _kProjection = GlobeProjection(); // default: centred ~20°N, 0°E

Widget _harness({
  required List<Override> overrides,
  required Widget child,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: Stack(children: [child])),
    ),
  );
}

void main() {
  group('findCenterMostPhoto', () {
    test('returns null for empty locations or zero canvas size', () {
      expect(
        findCenterMostPhoto(
          locations: const [],
          projection: _kProjection,
          canvasSize: _kSize,
        ),
        isNull,
      );
      expect(
        findCenterMostPhoto(
          locations: const [PhotoLocation('a', 0.0, 0.0)],
          projection: _kProjection,
          canvasSize: Size.zero,
        ),
        isNull,
      );
    });

    test('excludes back-facing photos', () {
      // Antipodal to the projection's front-facing centre.
      const backFacing = PhotoLocation('back', -60.0, 180.0);
      expect(
        findCenterMostPhoto(
          locations: const [backFacing],
          projection: _kProjection,
          canvasSize: _kSize,
        ),
        isNull,
      );
    });

    test('excludes front-facing photos that project outside the canvas', () {
      // Orthographic projection guarantees a front-facing point ALWAYS
      // lands within the globe disk — which only exceeds the canvas
      // rectangle once scale pushes the disk radius past the canvas itself
      // (zoomed in). At the default scale (1.0) the disk fits inside the
      // canvas, so a point off dead-centre still lands on-screen...
      const nearCentre = PhotoLocation('centre-ish', 0.0, 0.0);
      expect(
        findCenterMostPhoto(
          locations: const [nearCentre],
          projection: _kProjection,
          canvasSize: _kSize,
        )?.assetId,
        'centre-ish',
      );
      // ...but zoomed in far enough, that same off-centre point's pixel
      // offset (which scales with the radius) is pushed outside the canvas
      // even though it's still front-facing (z > 0) — this is the case
      // findCenterMostPhoto must exclude.
      const zoomedIn = GlobeProjection(scale: 30.0);
      expect(
        findCenterMostPhoto(
          locations: const [nearCentre],
          projection: zoomedIn,
          canvasSize: _kSize,
        ),
        isNull,
      );
    });

    test('picks the candidate nearest the screen centre', () {
      // The default projection's rotLat (0.35 rad) IS its true screen-centre
      // latitude, at lng 0 — so this point projects almost exactly to the
      // canvas centre. (-20, 90) is angularly far from that, still
      // front-facing and on-screen, but nowhere near the centre pixel.
      const centreLatDeg = 0.35 * 180 / math.pi; // ~20.05°N
      final near = PhotoLocation('near', centreLatDeg, 0.0);
      const far = PhotoLocation('far', -20.0, 90.0);
      final result = findCenterMostPhoto(
        locations: [far, near], // order shouldn't matter
        projection: _kProjection,
        canvasSize: _kSize,
      );
      expect(result?.assetId, 'near');
    });

    test('reflects a changed locations list rather than a stale cache', () {
      const first = PhotoLocation('only-candidate', 0.0, 0.0);
      final firstResult = findCenterMostPhoto(
        locations: [first],
        projection: _kProjection,
        canvasSize: _kSize,
      );
      expect(firstResult?.assetId, 'only-candidate');

      const second = PhotoLocation('different-candidate', 5.0, 5.0);
      final secondResult = findCenterMostPhoto(
        locations: [second], // a NEW list instance, different content
        projection: _kProjection,
        canvasSize: _kSize,
      );
      expect(secondResult?.assetId, 'different-candidate');
    });
  });

  const channel = MethodChannel('roavvy/thumbnail');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => _kFakePng);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('renders nothing when no photo is selected', (tester) async {
    await tester.pumpWidget(
      _harness(
        overrides: const [],
        child: const GlobeHeroPin(
          projection: _kProjection,
          canvasSize: _kSize,
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('renders nothing for a photo on the back face of the globe',
      (tester) async {
    // Antipodal to the projection's front-facing centre — guaranteed to
    // project to null (behind the globe).
    const backFacing = PhotoLocation('back', -60.0, 180.0);
    await tester.pumpWidget(
      _harness(
        overrides: [
          selectedMapPhotoProvider.overrideWith((ref) => backFacing),
        ],
        child: const GlobeHeroPin(
          projection: _kProjection,
          canvasSize: _kSize,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets(
      'renders and positions the pin for a front-facing selected photo, '
      'and tapping it opens the viewer', (tester) async {
    // (0, 0) is on the visible hemisphere for the default projection.
    const frontFacing = PhotoLocation('front-asset', 0.0, 0.0);
    final expectedPoint =
        _kProjection.project(frontFacing.lat, frontFacing.lng, _kSize)!;

    await tester.pumpWidget(
      _harness(
        overrides: [
          selectedMapPhotoProvider.overrideWith((ref) => frontFacing),
          photoLocationsProvider.overrideWith(
            (ref) async => [frontFacing],
          ),
        ],
        child: const GlobeHeroPin(
          projection: _kProjection,
          canvasSize: _kSize,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    // The anchor dot (bottom of the pin column) sits on the projected point;
    // "top" is offset upward by the full pin+tail+anchor height.
    expect(positioned.top, isNotNull);
    expect(positioned.left, isNotNull);
    // Sanity: the projected point used for verification is on-screen.
    expect(expectedPoint.dx, greaterThanOrEqualTo(0));
    expect(expectedPoint.dx, lessThanOrEqualTo(_kSize.width));

    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();

    expect(find.byType(MapPhotoViewer), findsOneWidget);
  });
}
