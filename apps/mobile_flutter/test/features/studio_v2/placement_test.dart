// M179 — Placement inside the journey.
//
// Three promises: placement is a STEP (the hero itself becomes the arranging
// surface, not a screen the flow escapes into), where the design is left is
// where it prints, and the front previews on the correct side of the garment.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/mockup_transform.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/placement_bake.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/placement_workspace.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';

class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) => throw UnimplementedError();
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

/// A solid square, so a placement's effect on the pixels is unmistakable.
Future<Uint8List> _swatch(int size, ui.Color colour) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = colour,
  );
  final img = await recorder.endRecording().toImage(size, size);
  return (await img.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

Future<(List<int>, int, int)> _decode(Uint8List png) async {
  final frame = await (await ui.instantiateImageCodec(png)).getNextFrame();
  final img = frame.image;
  final bytes = (await img.toByteData())!.buffer.asUint8List();
  return (bytes, img.width, img.height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StudioController make() => StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_NoopResolver()),
    designContext: const DesignContext(
      flagCodes: ['us', 'fr'],
      scopeKey: 'test:placement',
    ),
    initialSeed: 3,
  );

  group('placement is a step in the journey', () {
    test('the flow has a Placement stage, before Review', () {
      final stages = StudioStage.values;
      expect(stages, contains(StudioStage.placement));
      expect(
        stages.indexOf(StudioStage.placement),
        lessThan(stages.indexOf(StudioStage.review)),
        reason: 'you arrange the print, then review what you arranged',
      );
    });

    testWidgets('the step arranges the hero, and offers a way back to centre', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      final placement = MockupTransformController();
      addTearDown(placement.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacementWorkspace(controller: c, placement: placement),
          ),
        ),
      );
      await tester.pump();

      // No second shirt down here: arranging one shirt while looking at
      // another is exactly the escape this milestone closes.
      expect(find.byType(ShirtPreview), findsNothing);

      // Recentre is offered only once there is something to undo.
      final reset = find.byKey(const Key('v2-placement-reset'));
      expect(tester.widget<TextButton>(reset).onPressed, isNull);

      placement.transform.value = const MockupTransform(scale: 1.4);
      await tester.pump();
      expect(tester.widget<TextButton>(reset).onPressed, isNotNull);
      await tester.tap(reset);
      await tester.pump();
      expect(placement.value.isIdentity, isTrue);
    });
  });

  group('where the design is left is where it prints', () {
    test(
      'an untouched placement leaves the print file byte-identical',
      () async {
        final png = await _swatch(64, const ui.Color(0xFF1E88E5));
        expect(
          await bakePlacement(
            png,
            MockupTransform.identity,
            printAreaAspect: 0.75,
          ),
          same(png),
          reason: 'nothing was arranged, so nothing should be re-encoded',
        );
      },
    );

    test('the baked file takes the print area\'s shape', () async {
      final png = await _swatch(64, const ui.Color(0xFF1E88E5));
      final baked = await bakePlacement(
        png,
        const MockupTransform(scale: 1.2),
        printAreaAspect: 0.5,
        longSide: 400,
      );
      final (_, w, h) = await _decode(baked);
      expect(w / h, closeTo(0.5, 0.01));
      expect(h, 400);
    });

    test('moving the artwork moves the ink in the print file', () async {
      final png = await _swatch(64, const ui.Color(0xFF1E88E5));

      Future<double> inkCentreX(MockupTransform t) async {
        final (px, w, h) = await _decode(
          await bakePlacement(png, t, printAreaAspect: 1.0, longSide: 200),
        );
        var sum = 0.0, n = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (px[(y * w + x) * 4 + 3] > 16) {
              sum += x;
              n++;
            }
          }
        }
        return n == 0 ? -1 : sum / n / w;
      }

      // A quarter of the print area to the right is a quarter to the right.
      final centred = await inkCentreX(const MockupTransform(scale: 0.5));
      final moved = await inkCentreX(
        const MockupTransform(translation: Offset(0.25, 0), scale: 0.5),
      );
      expect(centred, closeTo(0.5, 0.02));
      expect(moved, closeTo(0.75, 0.02));
    });

    test('scaling up fills more of the print area', () async {
      final png = await _swatch(64, const ui.Color(0xFF1E88E5));

      Future<int> ink(double scale) async {
        final (px, w, h) = await _decode(
          await bakePlacement(
            png,
            MockupTransform(scale: scale),
            printAreaAspect: 1.0,
            longSide: 200,
          ),
        );
        var n = 0;
        for (var i = 0; i < w * h; i++) {
          if (px[i * 4 + 3] > 16) n++;
        }
        return n;
      }

      // Not against 1.0: that is identity, which is a passthrough by design.
      expect(await ink(1.5), greaterThan(await ink(0.75)));
    });

    test('the artwork can never bleed outside the printable area', () async {
      // Dragged hard to one corner and scaled up: the file is still exactly
      // the print area, so nothing can land on the fabric beside it.
      final png = await _swatch(64, const ui.Color(0xFF1E88E5));
      final (px, w, h) = await _decode(
        await bakePlacement(
          png,
          const MockupTransform(translation: Offset(1, 1), scale: 2.5),
          printAreaAspect: 1.0,
          longSide: 120,
        ),
      );
      expect(w, 120);
      expect(h, 120);
      expect(px.length, 120 * 120 * 4);
    });
  });

  group('the front previews on the correct side', () {
    test(
      'left and right chest are mirrored regions, and full front is not',
      () {
        final c = make();
        addTearDown(c.dispose);
        c.setSide(true);

        c.setFrontFit(FrontFit.chest);
        c.setChestSide(false);
        final left = c.frontPrintRect();
        c.setChestSide(true);
        final right = c.frontPrintRect();

        expect(left.left, isNot(right.left), reason: 'a side is a side');
        expect(left.width, closeTo(right.width, 1e-9));
        expect(
          left.center.dx + right.center.dx,
          closeTo(1.0, 0.01),
          reason: 'the two chest positions mirror about the garment centre',
        );

        c.setFrontFit(FrontFit.full);
        expect(c.frontPrintRect().width, greaterThan(left.width));

        c.setFrontFit(FrontFit.none);
        expect(c.frontPrintRect(), Rect.zero);
      },
    );

    test(
      'a chest print is a fraction of the back print, not the same area',
      () {
        final c = make();
        addTearDown(c.dispose);
        c.setSide(true);
        c.setFrontFit(FrontFit.chest);
        final chest = c.frontPrintRect();
        expect(
          chest.width * chest.height,
          lessThan(
            BundledGarments.backPrintArea.width *
                BundledGarments.backPrintArea.height,
          ),
        );
      },
    );
  });
}
