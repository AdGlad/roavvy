// M26 — what the customer approved is what Roavvy prints.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/mockup_transform.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/placement_bake.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/production_print_specs.dart';

/// A resolver with no real assets: every flag is a flat square. Keeps these
/// tests about geometry, resolution and determinism rather than about art.
class _FlatResolver implements AssetResolver {
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
    final pic = recorder.endRecording();
    final img = await pic.toImage(width, height);
    pic.dispose();
    return img;
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

/// Shared with `print_placement_test.dart`.
StudioController studio() => StudioController(
  generator: LabShowcaseGenerator(
    silhouettesByShape: const {},
    countryNames: const {},
  ),
  service: RenderService(_FlatResolver()),
  designContext: demoStudioContext.toDesignContext(),
  initialSeed: 7,
);

Future<ui.Image> decode(Uint8List png) async =>
    (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;

/// Alpha of the pixel at [x],[y] in a decoded print file.
Future<int Function(int, int)> alphaReader(ui.Image img) async {
  final px = (await img.toByteData())!.buffer.asUint8List();
  return (x, y) => px[(y * img.width + x) * 4 + 3];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the print file is the product configuration, not a guess', () {
    test('its size is the one Printful was verified to want', () {
      final dims = TshirtPrintProfile.dimensions;
      expect((dims.widthPx, dims.heightPx), (1800, 2400));
      expect(dims.dpi, 150);
      expect(dims.transparent, isTrue);
      // 12" × 16", which is what those numbers mean.
      expect(dims.widthPx / dims.dpi, 12.0);
      expect(dims.heightPx / dims.dpi, 16.0);
    });

    testWidgets('every face renders onto that canvas', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.full);

      late List<ProductionArtwork> files;
      late List<(int, int)> decoded;
      await tester.runAsync(() async {
        files = await renderPrintFiles(c);
        decoded = [
          for (final f in files)
            await (() async {
              final img = await decode(f.bytes);
              final size = (img.width, img.height);
              img.dispose();
              return size;
            })(),
        ];
      });

      expect(files, hasLength(2));
      for (final f in files) {
        expect((f.widthPx, f.heightPx), (1800, 2400));
        expect(f.dpi, 150);
        expect(f.physicalInches, (12.0, 16.0));
        expect(f.format, ProductionImageFormat.png);
      }
      expect(decoded, everyElement((1800, 2400)));
    });

    test('a spec that does not fit its canvas is refused, not clamped', () {
      expect(
        () => ProductionRenderSpec(
          placement: PrintPlacement.backFull,
          canvasWidthPx: 1800,
          canvasHeightPx: 2400,
          dpi: 150,
          artworkArea: const Rect.fromLTWH(0, 0, 2000, 2400),
        ),
        throwsA(isA<ProductionRenderException>()),
      );
      expect(
        () => ProductionRenderSpec(
          placement: PrintPlacement.backFull,
          canvasWidthPx: 0,
          canvasHeightPx: 2400,
          dpi: 150,
          artworkArea: const Rect.fromLTWH(0, 0, 10, 10),
        ),
        throwsA(isA<ProductionRenderException>()),
      );
    });
  });

  group('the design that was approved is the design that prints', () {
    testWidgets('the exact recipe reaches the printer', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSelectedCountries(const ['fr', 'jp']);
      c.commitTitle('EUROPE 2026');
      final approved = c.hero.recipeId;

      late List<ProductionArtwork> files;
      await tester.runAsync(() async => files = await renderPrintFiles(c));

      final back = files.firstWhere((f) => f.side == PrintSide.back);
      expect(back.recipeId, approved);
      expect(back.garmentId, c.garment.garmentId);
      expect(back.engineVersion, c.hero.engineVersion);
      expect(back.grammarVersion, c.hero.grammarVersion);
      expect(back.assetsVersion, c.hero.assetsVersion);
      expect(back.productKey, 'tshirt');
    });

    testWidgets('the same design twice is the same file', (tester) async {
      final c = studio();
      addTearDown(c.dispose);

      late ProductionArtwork first, second;
      await tester.runAsync(() async {
        first = (await renderPrintFiles(c)).first;
        second = (await renderPrintFiles(c)).first;
      });
      expect(second.recipeId, first.recipeId);
      expect(
        second.imageHash,
        first.imageHash,
        reason: 'no re-roll, no randomness, no drift between exports',
      );
    });

    testWidgets('exporting changes nothing about the session', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSelectedCountries(const ['fr', 'jp']);
      final before = (
        c.hero.recipeId,
        c.frontFace.recipeId,
        c.history.length,
        c.frontFit,
      );
      final countries = c.selectedCountryCodes.toSet();

      await tester.runAsync(() async => renderPrintFiles(c));

      expect(
        (
          c.hero.recipeId,
          c.frontFace.recipeId,
          c.history.length,
          c.frontFit,
        ),
        before,
      );
      expect(c.selectedCountryCodes, countries);
    });
  });

  group('it is artwork, and only artwork', () {
    testWidgets('no garment is baked into the file', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');

      late List<int> corners;
      await tester.runAsync(() async {
        final back = (await renderPrintFiles(c)).first;
        final img = await decode(back.bytes);
        final alpha = await alphaReader(img);
        corners = [
          alpha(0, 0),
          alpha(img.width - 1, 0),
          alpha(0, img.height - 1),
          alpha(img.width - 1, img.height - 1),
        ];
        img.dispose();
      });

      // The corners of a print file are outside the printable area entirely,
      // so nothing at all may be there — least of all a red rectangle.
      expect(
        corners,
        everyElement(0),
        reason: 'the print file carries a background in a corner',
      );
    });

    testWidgets('the artwork itself is actually there', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      late int middle;
      await tester.runAsync(() async {
        final img = await decode((await renderPrintFiles(c)).first.bytes);
        middle = (await alphaReader(img))(img.width ~/ 2, img.height ~/ 2);
        img.dispose();
      });
      expect(
        middle,
        greaterThan(0),
        reason: 'an empty print file is a blank shirt',
      );
    });

    testWidgets('it is drawn at print size, not blown up from a preview', (
      tester,
    ) async {
      // The artwork occupies most of a 1800×2400 canvas. A preview-sized
      // render (the Studio hero is 1024 on its long side) stretched to fit
      // would be soft; rendering natively means the renderer was ASKED for
      // those pixels.
      final c = studio();
      addTearDown(c.dispose);
      final spec = tshirtPrintSpec(PrintPlacement.backFull)!;
      final art = ProductionRenderer.fitInside(
        spec.artworkArea,
        ProductionRenderer.aspectOf(c.hero),
      );
      expect(art.height, greaterThan(1024));

      var askedFor = (0, 0);
      final printer = ProductionRenderer(
        _RecordingRenderer(c.service.renderer, (t) => askedFor = (t.width, t.height)),
      );
      await tester.runAsync(() async => printer.render(c.hero, spec));
      expect(askedFor, (art.width.round(), art.height.round()));
    });
  });

  group('front and back are two separate things', () {
    testWidgets('a blank front produces no file at all', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.none);

      expect(tshirtPrintSpec(frontPlacementOf(c)), isNull);
      late List<ProductionArtwork> files;
      await tester.runAsync(() async => files = await renderPrintFiles(c));
      expect(files, hasLength(1));
      expect(files.single.side, PrintSide.back);
    });

    test('a chest logo is placed in inches, where the fulfiller puts it', () {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.chest);

      c.setChestSide(false);
      final left = tshirtPrintSpec(frontPlacementOf(c))!;
      c.setChestSide(true);
      final right = tshirtPrintSpec(frontPlacementOf(c))!;

      const dpi = 150;
      expect(left.artworkArea.width, TshirtPrintProfile.logoInches * dpi);
      expect(left.artworkArea.height, TshirtPrintProfile.logoInches * dpi);
      expect(left.artworkArea.top, TshirtPrintProfile.logoTopInches * dpi);
      expect(
        left.artworkArea.center.dx,
        TshirtPrintProfile.leftChestCentreInches * dpi,
      );
      expect(
        right.artworkArea.center.dx,
        TshirtPrintProfile.rightChestCentreInches * dpi,
      );
      expect(left.artworkArea.center.dx, isNot(right.artworkArea.center.dx));
    });

    testWidgets('a full front fills the printable area, a chest logo does not', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);

      c.setFrontFit(FrontFit.full);
      final full = tshirtPrintSpec(frontPlacementOf(c))!;
      c.setFrontFit(FrontFit.chest);
      final chest = tshirtPrintSpec(frontPlacementOf(c))!;

      expect(
        full.artworkArea.height,
        greaterThan(chest.artworkArea.height * 3),
        reason: 'these are not the same print',
      );
    });

    testWidgets('rendering the front leaves the back alone', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.full);
      final backBefore = c.hero.recipeId;

      late ProductionArtwork backAlone, backWithFront;
      await tester.runAsync(() async {
        final printer = ProductionRenderer(c.service.renderer);
        backAlone = await printer.render(
          c.hero,
          tshirtPrintSpec(PrintPlacement.backFull)!,
        );
        await printer.render(c.frontFace, tshirtPrintSpec(frontPlacementOf(c))!);
        backWithFront = await printer.render(
          c.hero,
          tshirtPrintSpec(PrintPlacement.backFull)!,
        );
      });

      expect(c.hero.recipeId, backBefore);
      expect(backWithFront.imageHash, backAlone.imageHash);
    });

    testWidgets('the two faces are genuinely different files', (tester) async {
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.full);
      late List<ProductionArtwork> files;
      await tester.runAsync(() async => files = await renderPrintFiles(c));
      expect(files.map((f) => f.side).toSet(), {
        PrintSide.back,
        PrintSide.front,
      });
      expect(
        files[0].imageHash,
        isNot(files[1].imageHash),
        reason: 'the front is not a copy of the back',
      );
    });
  });

  group('preview and print are one interpretation at two sizes', () {
    test('the printable area is the provider geometry, not the mockup', () {
      // M26.1: the mockup's back rect is 0.571 because its HEIGHT was anchored
      // to garment landmarks, not derived from the 12:16 print it was
      // calibrated against. Production reads the provider geometry.
      final spec = tshirtPrintSpec(PrintPlacement.backFull)!;
      expect(spec.artworkArea, TshirtPrintProfile.canvas);
      expect(
        spec.artworkArea.width / spec.artworkArea.height,
        closeTo(12.0 / 16.0, 0.001),
      );
      expect(
        printAreaAspect(
          BundledGarments.backPrintArea,
          BundledGarments.tintBaseBackSize,
        ),
        closeTo(0.571, 0.01),
        reason: 'the mockup convention is still what it was — and unused here',
      );
    });

    test('the artwork keeps the recipe aspect the preview renders at', () {
      final c = studio();
      addTearDown(c.dispose);
      final spec = tshirtPrintSpec(PrintPlacement.backFull)!;
      final art = ProductionRenderer.fitInside(
        spec.artworkArea,
        ProductionRenderer.aspectOf(c.hero),
      );
      final (pw, ph) = RenderService.dimsFor(
        c.hero.composition.orientation,
        1024,
      );
      expect(art.width / art.height, closeTo(pw / ph, 0.01));
      expect(art.width, lessThanOrEqualTo(spec.artworkArea.width + 0.5));
      expect(art.height, lessThanOrEqualTo(spec.artworkArea.height + 0.5));
    });

    testWidgets('an arrangement moves the print the way it moved the preview', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      const moved = MockupTransform(
        translation: Offset(0.2, -0.1),
        scale: 1.3,
      );

      late ProductionArtwork still, shifted;
      await tester.runAsync(() async {
        still = (await renderPrintFiles(c)).first;
        shifted = (await renderPrintFiles(c, backPlacement: moved)).first;
      });
      expect(shifted.imageHash, isNot(still.imageHash));
      expect((shifted.widthPx, shifted.heightPx), (still.widthPx, still.heightPx));
    });

    testWidgets('an arrangement cannot print outside the printable area', (
      tester,
    ) async {
      // Shown on the chest, where the printable area is a 3.5" square and the
      // canvas around it is 12"×16" of nothing. A design shoved and blown up
      // must still stop at the square's edge.
      final c = studio();
      addTearDown(c.dispose);
      c.setSide(true);
      c.setFrontFit(FrontFit.chest);
      c.setChestSide(false);

      final spec = tshirtPrintSpec(
        frontPlacementOf(c),
        arrangement: const MockupTransform(
          translation: Offset(0.9, 0.9),
          scale: 3,
        ),
      )!;

      late List<int> outside;
      await tester.runAsync(() async {
        final f = await ProductionRenderer(
          c.service.renderer,
        ).render(c.frontFace, spec);
        final img = await decode(f.bytes);
        final alpha = await alphaReader(img);
        final area = spec.artworkArea;
        outside = [
          alpha(0, 0),
          alpha(img.width - 1, img.height - 1),
          alpha(area.left.round() - 12, area.center.dy.round()),
          alpha(area.right.round() + 12, area.center.dy.round()),
          alpha(area.center.dx.round(), area.bottom.round() + 12),
        ];
        img.dispose();
      });
      expect(outside, everyElement(0));
    });
  });

  group('when it cannot be done, it says so', () {
    testWidgets('a renderer that fails fails the export, loudly', (
      tester,
    ) async {
      final c = studio();
      addTearDown(c.dispose);
      final printer = ProductionRenderer(_BrokenRenderer());
      final spec = tshirtPrintSpec(PrintPlacement.backFull)!;

      Object? thrown;
      await tester.runAsync(() async {
        try {
          await printer.render(c.hero, spec);
        } catch (e) {
          thrown = e;
        }
      });

      expect(thrown, isA<ProductionRenderException>());
      final e = thrown! as ProductionRenderException;
      expect(e.recipeId, c.hero.recipeId, reason: 'M27 needs to know which');
      expect(e.cause, isNotNull);
      // …and the session is exactly where it was.
      expect(c.hero.recipeId, isNotNull);
      expect(c.history, isEmpty);
    });
  });
}

/// Wraps a renderer to record the target it was asked for.
class _RecordingRenderer implements Renderer {
  _RecordingRenderer(this._inner, this._onTarget);

  final Renderer _inner;
  final void Function(RenderTarget) _onTarget;

  @override
  Future<RenderResult> render(DesignRecipe recipe, RenderTarget target) {
    _onTarget(target);
    return _inner.render(recipe, target);
  }
}

class _BrokenRenderer implements Renderer {
  @override
  Future<RenderResult> render(DesignRecipe recipe, RenderTarget target) async =>
      throw StateError('no GPU surface');
}
