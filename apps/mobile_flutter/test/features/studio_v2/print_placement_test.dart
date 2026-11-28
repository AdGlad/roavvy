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
      // …and the placements a print file can carry are the explicit seven.
      expect(PrintPlacement.values.map((p) => p.name), [
        'backFull',
        'frontFull',
        'frontLeftChest',
        'frontRightChest',
        'backUpper',
        'backNeck',
        'none',
      ]);
    });
  });

  group('print layout zones', () {
    test('full-size shipped zones land on the shipped print areas', () {
      for (final (zone, placement) in [
        (PrintZone.fullBack, PrintPlacement.backFull),
        (PrintZone.fullFront, PrintPlacement.frontFull),
        (PrintZone.leftChest, PrintPlacement.frontLeftChest),
        (PrintZone.rightChest, PrintPlacement.frontRightChest),
      ]) {
        expect(
          TshirtPrintProfile.zoneArea(ZonePrint(zone)),
          TshirtPrintProfile.artworkArea(placement),
          reason: zone.name,
        );
      }
    });

    test('a zone at a smaller size prints smaller, from the same top line', () {
      final full = TshirtPrintProfile.zoneArea(const ZonePrint(PrintZone.upperBack));
      expect(full, const ui.Rect.fromLTWH(150, 112.5, 1500, 750));
      final small = tshirtPrintSpec(
        PrintPlacement.backUpper,
        zone: const ZonePrint(PrintZone.upperBack, scale: 0.6),
      )!;
      expect(small.artworkArea.top, full.top);
      expect(small.artworkArea.width, closeTo(900, 1e-6));
      expect(small.artworkArea.center.dx, closeTo(900, 1e-6));
      expect(small.side, PrintSide.back);
    });
  });

  group('the Roavvy mark on the back print file', () {
    testWidgets('prints below the collar, the design starts below it', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      final spec = tshirtPrintSpec(
        PrintPlacement.backFull,
        zone: const ZonePrint(PrintZone.fullBack),
        layout: PrintLayout.standard,
        garmentHex: '#0E0E0E',
      )!;
      expect(spec.artworkArea, const ui.Rect.fromLTRB(0, 210, 1800, 2400));
      final mark = spec.marks.single;
      expect(mark.rect, const ui.Rect.fromLTWH(712.5, 67.5, 375, 82.5));
      // Light ink on a black shirt.
      expect(mark.ink, const ui.Color(0xFFF2F2F2));

      late List<int> px;
      await tester.runAsync(() async {
        final art = await ProductionRenderer(c.service.renderer).render(
          c.hero,
          spec,
        );
        final img =
            (await (await ui.instantiateImageCodec(art.bytes)).getNextFrame())
                .image;
        px = (await img.toByteData())!.buffer.asUint8List();
      });
      int alpha(int x, int y) => px[(y * 1800 + x) * 4 + 3];
      var inked = 0;
      for (var y = 68; y < 150; y += 4) {
        for (var x = 713; x < 1087; x += 4) {
          if (alpha(x, y) > 0) inked++;
        }
      }
      expect(inked, greaterThan(0), reason: 'the mark is in the pixels');
      // Nothing between the mark and the design, and nothing beside the mark.
      for (var x = 0; x < 1800; x += 50) {
        expect(alpha(x, 180), 0, reason: 'clear band at x=$x');
      }
      expect(alpha(300, 100), 0);
    });

    test('no mark on a front file, or when switched off', () {
      expect(
        tshirtPrintSpec(
          PrintPlacement.frontLeftChest,
          zone: const ZonePrint(PrintZone.leftChest),
          layout: PrintLayoutPreset.crestAndBack.layout,
        )!.marks,
        isEmpty,
      );
      final off = PrintLayout.standard.withBrandMark(false);
      final spec = tshirtPrintSpec(
        PrintPlacement.backFull,
        zone: const ZonePrint(PrintZone.fullBack),
        layout: off,
      )!;
      expect(spec.marks, isEmpty);
      expect(spec.artworkArea, TshirtPrintProfile.artworkArea(PrintPlacement.backFull));
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
