// M174 — the print file must carry the placement the user arranged on the
// mockup. If it didn't, the preview would be a lie: the shirt that arrives
// would have the design back in its default spot.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/merch_image_processor.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/mockup_transform.dart';

/// A small opaque square, PNG-encoded — stands in for card artwork.
Future<Uint8List> squarePng(int size) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

/// Alpha of the pixel at (x, y).
Future<int> alphaAt(Uint8List png, int x, int y) async {
  final image = await decode(png);
  final data = (await image.toByteData())!.buffer.asUint8List();
  final a = data[(y * image.width + x) * 4 + 3];
  image.dispose();
  return a;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const w = 120, h = 160;

  testWidgets('the back print file carries the user placement', (tester) async {
    await tester.runAsync(() async {
      final src = await squarePng(64);

      final plain = await MerchImageProcessor.processBack(
        sourceBytes: src,
        widthPx: w,
        heightPx: h,
        transparentBackground: true,
      );
      final moved = await MerchImageProcessor.processBack(
        sourceBytes: src,
        widthPx: w,
        heightPx: h,
        transparentBackground: true,
        transform: const MockupTransform(
          translation: Offset(0.25, 0),
          scale: 1.2,
        ),
      );

      expect(plain, isNotNull);
      expect(moved, isNotNull);
      expect(
        moved,
        isNot(plain),
        reason: 'the print file ignored the arranged placement',
      );
    });
  });

  testWidgets('an identity transform leaves the print file byte-identical', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final src = await squarePng(64);
      final a = await MerchImageProcessor.processBack(
        sourceBytes: src,
        widthPx: w,
        heightPx: h,
        transparentBackground: true,
      );
      final b = await MerchImageProcessor.processBack(
        sourceBytes: src,
        widthPx: w,
        heightPx: h,
        transparentBackground: true,
        transform: MockupTransform.identity,
      );
      expect(b, a, reason: 'default placement must not perturb the print file');
    });
  });

  testWidgets('the same placement always renders the same print file', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final src = await squarePng(64);
      const t = MockupTransform(
        translation: Offset(-0.2, 0.1),
        scale: 1.4,
        rotation: 0.3,
      );
      Future<Uint8List?> run() => MerchImageProcessor.processBack(
        sourceBytes: src,
        widthPx: w,
        heightPx: h,
        transparentBackground: true,
        transform: t,
      );
      expect(await run(), await run());
    });
  });

  testWidgets('a design dragged past the edge is clipped, not bled', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final src = await squarePng(64);
      // Pushed a full print area to the right and scaled up: whatever lands
      // outside the printable canvas must simply be cut off.
      final png = await MerchImageProcessor.processBack(
        sourceBytes: src,
        widthPx: w,
        heightPx: h,
        transparentBackground: true,
        transform: const MockupTransform(
          translation: Offset(1.0, 0),
          scale: 2.5,
        ),
      );
      expect(png, isNotNull);
      final image = await decode(png!);
      expect(image.width, w);
      expect(image.height, h);
      image.dispose();
      // The far left of the canvas is now empty — the art has moved right.
      expect(await alphaAt(png, 1, h ~/ 2), 0);
    });
  });

  testWidgets('the front print file carries the placement too', (tester) async {
    await tester.runAsync(() async {
      final src = await squarePng(64);
      // The chest badge is positioned in inches × dpi, so a small dpi keeps the
      // badge inside this deliberately tiny test canvas (at 150 dpi the badge
      // lands at 637,450 — far outside a 120×160 sheet, and both files would be
      // empty and identical for the wrong reason).
      const dpi = 10;
      final plain = await MerchImageProcessor.processFront(
        sourceBytes: src,
        frontPosition: 'center',
        widthPx: w,
        heightPx: h,
        dpi: dpi,
        transparentBackground: true,
      );
      final moved = await MerchImageProcessor.processFront(
        sourceBytes: src,
        frontPosition: 'center',
        widthPx: w,
        heightPx: h,
        dpi: dpi,
        transparentBackground: true,
        transform: const MockupTransform(translation: Offset(0.2, 0.1)),
      );
      expect(plain, isNotNull);
      expect(moved, isNotNull);
      // Sanity: the badge is actually on the sheet, so the comparison means
      // something.
      expect(await alphaAt(plain!.printBytes, w ~/ 2, 35), greaterThan(0));
      expect(moved!.printBytes, isNot(plain.printBytes));
    });
  });
}
