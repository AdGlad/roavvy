// M174 — the interactive mockup canvas: gestures move the artwork, the HUD
// re-aligns it, the design stays inside the printable area, and the fabric
// shading pass reaches the ink without stamping a grey box on the shirt.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/mockup_transform.dart';
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_canvas.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_painter.dart';

/// A solid [colour] image — stands in for a garment photo or a shading map.
Future<ui.Image> solid(int w, int h, ui.Color colour) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = colour,
  );
  return recorder.endRecording().toImage(w, h);
}

/// Artwork with a transparent margin — the shape that exposes the "grey box"
/// bug when shading is multiplied over the whole print rectangle.
Future<ui.Image> artworkWithTransparentMargin(int size) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(size * 0.25, size * 0.25, size * 0.5, size * 0.5),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  return recorder.endRecording().toImage(size, size);
}

/// Renders [painter] into an image and returns its raw RGBA bytes.
Future<Uint8List> rasterise(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

ui.Color pixelAt(Uint8List rgba, Size size, int x, int y) {
  final i = (y * size.width.round() + x) * 4;
  return ui.Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spec = ProductMockupSpec(
    assetPath: 'test://shirt',
    // A generous central print area so test coordinates are easy to reason about.
    printAreaNorm: Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
  );
  const canvasSize = Size(200, 200);

  // A realistic phone-width surface, so the HUD pill is fully on screen.
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 360, height: 360, child: child)),
  );

  group('composite', () {
    testWidgets('fabric shading reaches the ink but not bare shirt', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final shirt = await solid(200, 200, const ui.Color(0xFFFFFFFF));
        // A dark shading source: anywhere it lands, pixels get much darker.
        final shading = await solid(200, 200, const ui.Color(0xFF303030));
        final art = await artworkWithTransparentMargin(100);
        final controller = MockupTransformController();
        addTearDown(controller.dispose);

        final rgba = await rasterise(
          GarmentMockupPainter(
            spec: spec,
            controller: controller,
            garmentImage: shirt,
            shadingImage: shading,
            artworkImage: art,
            artworkBlendMode: ui.BlendMode.srcOver,
            shadingOpacity: 1.0,
          ),
          canvasSize,
        );

        // Centre of the print area = artwork ink: shaded (darkened) red.
        final ink = pixelAt(rgba, canvasSize, 100, 100);
        expect(ink.r, greaterThan(0), reason: 'ink should still be there');
        expect(ink.r, lessThan(255), reason: 'fabric shading must darken ink');

        // Inside the print area but on the artwork's transparent margin: the
        // shirt must stay clean — this is the "no dark rectangle" criterion.
        final margin = pixelAt(rgba, canvasSize, 57, 57);
        expect(
          margin,
          const ui.Color(0xFFFFFFFF),
          reason: 'shading leaked onto transparent artwork pixels',
        );
      });
    });

    testWidgets('no ghost rectangle above and below a contain-fitted design', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // A print area TALLER than it is wide. A square design contain-fits to
        // its width, leaving a band above and below that sits inside the print
        // rectangle but outside the artwork's own rect. A `dstIn` mask can
        // never reach that band — a Porter-Duff blend only touches the pixels
        // its geometry covers — so the fold pass used to survive there and
        // print the outline of the print area onto the shirt.
        //
        // The existing shading test cannot catch this: its print area is
        // square and its artwork is square, so the artwork covers the print
        // rectangle exactly and no such band exists.
        const tallSpec = ProductMockupSpec(
          assetPath: 'test://shirt',
          printAreaNorm: Rect.fromLTWH(0.25, 0.1, 0.5, 0.8),
        );
        final shirt = await solid(200, 200, const ui.Color(0xFFFFFFFF));
        final shading = await solid(200, 200, const ui.Color(0xFF303030));
        final art = await artworkWithTransparentMargin(100);
        final controller = MockupTransformController();
        addTearDown(controller.dispose);

        final rgba = await rasterise(
          GarmentMockupPainter(
            spec: tallSpec,
            controller: controller,
            garmentImage: shirt,
            shadingImage: shading,
            artworkImage: art,
            artworkBlendMode: ui.BlendMode.srcOver,
            shadingOpacity: 1.0,
          ),
          canvasSize,
        );

        // Print area spans y 20..180; the square artwork contain-fits to
        // y 50..150. y = 30 and y = 165 are inside the print rectangle and
        // outside the design — bare shirt, and it must stay bare.
        for (final y in [30, 165]) {
          expect(
            pixelAt(rgba, canvasSize, 100, y),
            const ui.Color(0xFFFFFFFF),
            reason: 'the print area is showing as a shadow at y=$y',
          );
        }
      });
    });

    testWidgets('artwork never escapes the printable area', (tester) async {
      await tester.runAsync(() async {
        final shirt = await solid(200, 200, const ui.Color(0xFFFFFFFF));
        final art = await solid(100, 100, const ui.Color(0xFFFF0000));
        // Dragged hard to one corner and blown up past the print area.
        final controller =
            MockupTransformController()..restore(
              const MockupTransform(translation: Offset(1.0, 1.0), scale: 2.5),
            );
        addTearDown(controller.dispose);

        final rgba = await rasterise(
          GarmentMockupPainter(
            spec: spec,
            controller: controller,
            garmentImage: shirt,
            artworkImage: art,
            artworkBlendMode: ui.BlendMode.srcOver,
            shadingOpacity: 0,
          ),
          canvasSize,
        );

        // Print area is x,y ∈ [50,150). Just outside it must be bare shirt.
        for (final p in const [(45, 100), (155, 100), (100, 45), (100, 155)]) {
          expect(
            pixelAt(rgba, canvasSize, p.$1, p.$2),
            const ui.Color(0xFFFFFFFF),
            reason: 'artwork bled outside the print area at $p',
          );
        }
      });
    });

    testWidgets('a blank garment renders with no artwork', (tester) async {
      await tester.runAsync(() async {
        final shirt = await solid(200, 200, const ui.Color(0xFF112233));
        final controller = MockupTransformController();
        addTearDown(controller.dispose);
        final rgba = await rasterise(
          GarmentMockupPainter(
            spec: spec,
            controller: controller,
            garmentImage: shirt,
          ),
          canvasSize,
        );
        expect(pixelAt(rgba, canvasSize, 100, 100), const ui.Color(0xFF112233));
      });
    });
  });

  group('interaction', () {
    late MockupTransformController controller;
    late ui.Image shirt;
    late ui.Image art;

    setUp(() async {
      controller = MockupTransformController();
      shirt = await solid(200, 200, const ui.Color(0xFFFFFFFF));
      art = await solid(100, 100, const ui.Color(0xFFFF0000));
    });

    tearDown(() => controller.dispose());

    Widget canvas({bool interactive = true}) => host(
      GarmentMockupCanvas(
        spec: spec,
        controller: controller,
        garmentImage: shirt,
        artworkImage: art,
        interactive: interactive,
      ),
    );

    testWidgets('a drag moves the design and commits once', (tester) async {
      final commits = <MockupTransform>[];
      await tester.pumpWidget(
        host(
          GarmentMockupCanvas(
            spec: spec,
            controller: controller,
            garmentImage: shirt,
            artworkImage: art,
            onTransformCommitted: commits.add,
          ),
        ),
      );

      await tester.drag(find.byType(GarmentMockupCanvas), const Offset(45, 0));
      await tester.pumpAndSettle();

      // The 200×200 garment contain-fits 360×360, so the print area is
      // 0.5 × 360 = 180px wide — 45px is a quarter of it.
      expect(controller.value.translation.dx, closeTo(0.25, 1e-6));
      expect(commits, hasLength(1));
    });

    testWidgets('gestures repaint without rebuilding the widget tree', (
      tester,
    ) async {
      await tester.pumpWidget(canvas());
      final buildsBefore = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(GarmentMockupCanvas),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      await tester.drag(find.byType(GarmentMockupCanvas), const Offset(20, 20));
      await tester.pumpAndSettle();

      final buildsAfter = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(GarmentMockupCanvas),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // Same painter instance: the drag drove the notifier, not a rebuild.
      expect(identical(buildsBefore.painter, buildsAfter.painter), isTrue);
      expect(controller.value.isIdentity, isFalse);
    });

    testWidgets('a non-interactive canvas ignores touch and hides the HUD', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(interactive: false));
      await tester.drag(find.byType(GarmentMockupCanvas), const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(controller.value, MockupTransform.identity);
      expect(find.byKey(const Key('mockup-hud-center')), findsNothing);
    });

    testWidgets('HUD quick actions re-align the design', (tester) async {
      await tester.pumpWidget(canvas());

      await tester.tap(find.byKey(const Key('mockup-hud-left-chest')));
      await tester.pumpAndSettle();
      expect(controller.value.scale, lessThan(0.5));
      expect(controller.value.translation, isNot(Offset.zero));

      await tester.tap(find.byKey(const Key('mockup-hud-center')));
      await tester.pumpAndSettle();
      expect(controller.value.translation, Offset.zero);

      await tester.tap(find.byKey(const Key('mockup-hud-reset')));
      await tester.pumpAndSettle();
      expect(controller.value, MockupTransform.identity);
    });

    testWidgets('Reset is disabled until the design has been moved', (
      tester,
    ) async {
      await tester.pumpWidget(canvas());
      // Untouched design → nothing to reset.
      await tester.tap(find.byKey(const Key('mockup-hud-reset')));
      await tester.pumpAndSettle();
      expect(controller.value, MockupTransform.identity);

      await tester.tap(find.byKey(const Key('mockup-hud-left-chest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mockup-hud-reset')));
      await tester.pumpAndSettle();
      expect(controller.value, MockupTransform.identity);
    });

    testWidgets('the boundary guide only shows during a gesture', (
      tester,
    ) async {
      await tester.pumpWidget(canvas());
      expect(controller.isGestureActive.value, isFalse);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GarmentMockupCanvas)),
      );
      await gesture.moveBy(const Offset(15, 15));
      await tester.pump();
      expect(controller.isGestureActive.value, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.isGestureActive.value, isFalse);
    });
  });

  group('spec', () {
    test('a garment with no companion map shades from its own photo', () {
      final s = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'front',
      );
      expect(s.shadingAssetPath, s.assetPath);
    });

    test('a registered companion map overrides the shading source', () {
      const s = ProductMockupSpec(
        assetPath: 'a.png',
        printAreaNorm: Rect.fromLTWH(0, 0, 1, 1),
        shadowMapAssetPath: 'a_wrinkles.png',
      );
      expect(s.shadingAssetPath, 'a_wrinkles.png');
    });
  });
}
