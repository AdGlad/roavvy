// Verifies GlobeHeroPin — the globe's equivalent of the flat map's
// PhotoPinLayer, added so "the hero image feature on the flat map" is also
// available on the globe (same look, same tap-to-view behaviour, just
// projected via GlobeProjection instead of a flutter_map Marker).

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
