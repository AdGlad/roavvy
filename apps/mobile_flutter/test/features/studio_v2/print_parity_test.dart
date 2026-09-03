// M180 — the preview is a promise.
//
// Preview and print file are produced by different code paths. That they agree
// on placement, garment colour and artwork scale is the assumption the whole
// product rests on: someone is paying for a physical object based on a picture.
// These tests make a parity break fail here rather than at a customer's door.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/mockup_transform.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/placement_bake.dart';
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2/host/studio_garments.dart';

class _SquareResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF1E88E5),
    );
    return recorder.endRecording().toImage(width, height);
  }

  @override
  Future<ui.Image?> resolveClipMask(
    ClipShape shape,
    String? code, {
    required int width,
    required int height,
  }) async => null;

  @override
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StudioController make() => StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_SquareResolver()),
    designContext: const DesignContext(
      flagCodes: ['us', 'fr', 'jp'],
      scopeKey: 'test:parity',
    ),
    initialSeed: 7,
  );

  /// The print area the PREVIEW uses for a face — read off the same spec the
  /// hero paints, not restated here.
  Rect previewArea(StudioController c, {required bool front}) =>
      StudioGarments.specFor(
        garmentColour: c.hero.palette?.garmentColour,
        front: front,
        printArea: front ? c.frontPrintRect() : null,
      ).printAreaNorm;

  Future<(int, int)> pngSize(Uint8List png) async {
    final img =
        (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
    try {
      return (img.width, img.height);
    } finally {
      img.dispose();
    }
  }

  group('the garment geometry the two paths share', () {
    testWidgets('the photo dimensions match the shipped assets', (
      tester,
    ) async {
      // The print file is cut to the print area's real shape, which is only
      // knowable from the photo's proportions. If new photography changes them
      // and these constants do not follow, every print file silently comes out
      // the wrong shape.
      await tester.runAsync(() async {
        for (final (path, expected) in [
          (BundledGarments.tintBaseFront, BundledGarments.tintBaseFrontSize),
          (BundledGarments.tintBaseBack, BundledGarments.tintBaseBackSize),
        ]) {
          final bytes = (await rootBundle.load(path)).buffer.asUint8List();
          final img =
              (await (await ui.instantiateImageCodec(bytes)).getNextFrame())
                  .image;
          expect(
            Size(img.width.toDouble(), img.height.toDouble()),
            expected,
            reason: '$path no longer matches its recorded size',
          );
          img.dispose();
        }
      });
    });

    test('a print area is NOT square just because its fractions look it', () {
      // The trap this guards: 0.42 × 0.56 reads as 3:4, but on a 487 × 640
      // photo it is not.
      final naive =
          BundledGarments.backPrintArea.width /
          BundledGarments.backPrintArea.height;
      final real = printAreaAspect(
        BundledGarments.backPrintArea,
        BundledGarments.tintBaseBackSize,
      );
      expect(real, isNot(closeTo(naive, 0.01)));
    });
  });

  group('preview and print file agree, on every face and placement', () {
    for (final (name, fit, right) in [
      ('full front', FrontFit.full, false),
      ('left chest', FrontFit.chest, false),
      ('right chest', FrontFit.chest, true),
    ]) {
      testWidgets('$name prints at the shape it previews', (tester) async {
        final c = make();
        addTearDown(c.dispose);
        c.setSide(true);
        c.setFrontFit(fit);
        c.setChestSide(right);

        final previewAspect = printAreaAspect(
          previewArea(c, front: true),
          BundledGarments.tintBaseFrontSize,
        );

        late (int, int) size;
        await tester.runAsync(() async {
          // A moved design — the default is the easy case, and the one a
          // customer is least likely to be looking at.
          final req = buildGarmentCartRequest(
            c,
            frontPlacement: const MockupTransform(
              translation: Offset(0.2, -0.1),
              scale: 1.3,
            ),
          );
          size = await pngSize(await req.renderFrontArtwork!());
        });
        expect(size.$1 / size.$2, closeTo(previewAspect, 0.02));
      });
    }

    testWidgets('the back prints at the shape it previews', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      final previewAspect = printAreaAspect(
        previewArea(c, front: false),
        BundledGarments.tintBaseBackSize,
      );

      late (int, int) size;
      await tester.runAsync(() async {
        final req = buildGarmentCartRequest(
          c,
          backPlacement: const MockupTransform(scale: 0.8, rotation: 0.15),
        );
        size = await pngSize(await req.renderBackArtwork());
      });
      expect(size.$1 / size.$2, closeTo(previewAspect, 0.02));
    });

    testWidgets('a blank front sends no print file at all', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.none);
      expect(buildGarmentCartRequest(c).renderFrontArtwork, isNull);
    });
  });

  group('the garment colour is the same colour', () {
    testWidgets('what tints the preview is what is ordered', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      for (final (hex, name) in StudioController.garments) {
        c.setGarment(hex);
        final req = buildGarmentCartRequest(c);
        expect(req.garmentColourHex, hex);
        expect(req.garmentColourName, name);
        // …and the preview tints from the same value, not a lookalike.
        expect(
          StudioGarments.specFor(
            garmentColour: c.hero.palette?.garmentColour,
            front: false,
          ).tintColour,
          Color(int.parse('FF${hex.substring(1)}', radix: 16)),
        );
      }
    });
  });

  group('the artwork is the same artwork', () {
    testWidgets('the print file carries no garment fill behind the design', (
      tester,
    ) async {
      // The preview composites the artwork onto fabric, so anything opaque
      // behind it prints as a rectangle on the shirt.
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');

      late List<int> px;
      late int w;
      await tester.runAsync(() async {
        final png = await buildGarmentCartRequest(c).renderBackArtwork();
        final img =
            (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
        px = (await img.toByteData())!.buffer.asUint8List();
        w = img.width;
        img.dispose();
      });
      // The corners of a print file are transparent — fabric, not ink.
      expect(
        px[3],
        0,
        reason: 'top-left of the print file must be see-through',
      );
      expect(px[(w - 1) * 4 + 3], 0);
    });

    testWidgets('an unmoved design is handed over exactly as rendered', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      late Uint8List handed;
      late Uint8List rendered;
      await tester.runAsync(() async {
        handed = await buildGarmentCartRequest(c).renderBackArtwork();
        rendered = (await c.service.renderArtwork(c.hero)).pngBytes;
      });
      expect(handed, rendered, reason: 'no placement means no re-encoding');
    });
  });
}
