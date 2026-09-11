// M26.1 — a full front is not a chest logo, and no string decides which.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/placement_bake.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/print_calibration.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/production_print_specs.dart';

import 'production_render_test.dart' show studio;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the placement is chosen, never inferred', () {
    test('every front choice maps to exactly one placement', () {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);

      c.setFrontFit(FrontFit.full);
      expect(frontPlacementOf(c), PrintPlacement.frontFull);

      c.setFrontFit(FrontFit.chest);
      c.setChestSide(false);
      expect(frontPlacementOf(c), PrintPlacement.frontLeftChest);
      c.setChestSide(true);
      expect(frontPlacementOf(c), PrintPlacement.frontRightChest);

      c.setFrontFit(FrontFit.none);
      expect(frontPlacementOf(c), PrintPlacement.none);
    });

    test('a full front is not a chest logo, and cannot become one', () {
      final full = tshirtPrintSpec(PrintPlacement.frontFull)!;
      expect(full.placement.isChestLogo, isFalse);
      expect(full.artworkArea, TshirtPrintProfile.canvas);
      // 12" wide, not 3.5".
      expect(full.artworkArea.width / full.dpi, 12.0);
      expect(
        full.artworkArea.width / full.dpi,
        isNot(TshirtPrintProfile.logoInches),
      );
    });

    test('the chest logos keep the M167 geometry the pipeline prints to', () {
      for (final (placement, centreIn) in [
        (PrintPlacement.frontLeftChest, TshirtPrintProfile.leftChestCentreInches),
        (
          PrintPlacement.frontRightChest,
          TshirtPrintProfile.rightChestCentreInches,
        ),
      ]) {
        final spec = tshirtPrintSpec(placement)!;
        final dpi = spec.dpi;
        expect(spec.placement.isChestLogo, isTrue);
        expect(spec.artworkArea.width / dpi, TshirtPrintProfile.logoInches);
        expect(spec.artworkArea.height / dpi, TshirtPrintProfile.logoInches);
        expect(spec.artworkArea.top / dpi, TshirtPrintProfile.logoTopInches);
        expect(spec.artworkArea.center.dx / dpi, centreIn);
      }
    });

    test('none has no placement, no area and no spec', () {
      expect(PrintPlacement.none.printsSomething, isFalse);
      expect(PrintPlacement.none.side, isNull);
      expect(tshirtPrintSpec(PrintPlacement.none), isNull);
      expect(
        () => TshirtPrintProfile.artworkArea(PrintPlacement.none),
        throwsA(isA<ProductionRenderException>()),
      );
      expect(
        () => ProductionRenderSpec(
          placement: PrintPlacement.none,
          canvasWidthPx: 1800,
          canvasHeightPx: 2400,
          dpi: 150,
          artworkArea: const ui.Rect.fromLTWH(0, 0, 100, 100),
        ),
        throwsA(isA<ProductionRenderException>()),
      );
    });

    test('no ambiguous placement word survives the production boundary', () {
      // "center" is the word that means a 3.5" chest logo on the server and a
      // full-canvas print in the client processor. It decides nothing here.
      final source =
          File(
            'lib/features/studio_v2_commerce/production_print_specs.dart',
          ).readAsStringSync();
      for (final word in ['center', 'centre_chest', 'front_center']) {
        expect(
          RegExp("'$word'").hasMatch(source),
          isFalse,
          reason: 'production placement must not turn on the string "$word"',
        );
      }
      // …and the placements a print file can carry are the explicit five.
      expect(PrintPlacement.values.map((p) => p.name), [
        'backFull',
        'frontFull',
        'frontLeftChest',
        'frontRightChest',
        'none',
      ]);
    });
  });

  group('the geometry a print file is built from', () {
    test('the back print area is the provider 12x16, at 0.75', () {
      final back = tshirtPrintSpec(PrintPlacement.backFull)!;
      expect(back.artworkArea.width / back.dpi, 12.0);
      expect(back.artworkArea.height / back.dpi, 16.0);
      expect(
        back.artworkArea.width / back.artworkArea.height,
        closeTo(0.75, 0.0001),
      );
    });

    test('the 0.571 mockup rect is preview geometry and stays out of it', () {
      // Its WIDTH is provider-derived (0.75 of the photographed torso). Its
      // HEIGHT is not: a 12x16 print that wide is 0.426 photo-heights tall,
      // not 0.56. Production must not inherit the difference.
      const rect = BundledGarments.backPrintArea;
      const photo = BundledGarments.tintBaseBackSize;
      expect(printAreaAspect(rect, photo), closeTo(0.571, 0.005));

      final impliedHeight = rect.width * photo.width * (16 / 12) / photo.height;
      expect(impliedHeight, closeTo(0.426, 0.005));
      expect(
        rect.height,
        greaterThan(impliedHeight),
        reason: 'the mockup rect is taller than the print it describes',
      );

      final back = tshirtPrintSpec(PrintPlacement.backFull)!;
      expect(
        back.artworkArea.width / back.artworkArea.height,
        isNot(closeTo(printAreaAspect(rect, photo), 0.05)),
      );
    });
  });

  group('the calibration targets', () {
    testWidgets('there is one per real placement, at production size', (
      tester,
    ) async {
      late List<ProductionArtwork> sheets;
      await tester.runAsync(() async => sheets = await calibrationSheets());

      expect(sheets.map((s) => s.placement), [
        PrintPlacement.backFull,
        PrintPlacement.frontFull,
        PrintPlacement.frontLeftChest,
        PrintPlacement.frontRightChest,
      ]);
      for (final s in sheets) {
        expect((s.widthPx, s.heightPx), (1800, 2400));
        expect(s.dpi, 150);
        expect(s.physicalInches, (12.0, 16.0));
        expect(s.format, ProductionImageFormat.png);
        expect(s.bytes, isNotEmpty);
      }
    });

    testWidgets('they are ink on nothing — no garment, transparent corners', (
      tester,
    ) async {
      late List<int> corners;
      await tester.runAsync(() async {
        final sheet = await PrintCalibration.sheet(PrintPlacement.frontLeftChest);
        final img =
            (await (await ui.instantiateImageCodec(
              sheet.bytes,
            )).getNextFrame()).image;
        final px = (await img.toByteData())!.buffer.asUint8List();
        int alpha(int x, int y) => px[(y * img.width + x) * 4 + 3];
        corners = [
          alpha(40, 40),
          alpha(img.width - 41, 40),
          alpha(40, img.height - 41),
        ];
        img.dispose();
      });
      // Inside the thin canvas-bounds marker and before the first inch line:
      // empty. A garment photograph here would be opaque everywhere.
      expect(corners, everyElement(0));
    });

    testWidgets('generating one touches no design and no session', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      final before = (c.hero.recipeId, c.frontFace.recipeId, c.history.length);

      await tester.runAsync(() async => calibrationSheets());

      expect(
        (c.hero.recipeId, c.frontFace.recipeId, c.history.length),
        before,
      );
    });

    testWidgets('a calibration sheet is never mistaken for a design', (
      tester,
    ) async {
      late ProductionArtwork sheet;
      await tester.runAsync(
        () async => sheet = await PrintCalibration.sheet(PrintPlacement.backFull),
      );
      expect(sheet.recipeId, startsWith('calibration:'));
      expect(sheet.engineVersion, 'calibration');
      expect(sheet.garmentId, isNull);
    });

    test('there is no calibration target for a face that does not print', () {
      expect(
        () => PrintCalibration.sheet(PrintPlacement.none),
        throwsA(isA<ProductionRenderException>()),
      );
    });
  });
}
