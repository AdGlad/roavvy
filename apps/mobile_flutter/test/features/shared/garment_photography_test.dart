// M183 — the acceptance harness for the garment photography.
//
// The shirt is the hero of every screen in the Studio, and the GREY shirt is
// the tint base every other colour is derived from — so its framing and its
// edge against the sweep set the ceiling for all eight. Reshooting is asset
// work; these are the properties a reshoot has to preserve, so a new set that
// reframes the garment or loses its separable edge fails here rather than
// silently moving every print area.
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Rect, Size;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_tint.dart';

/// What the cutout leaves behind: where the garment sits in the frame, how
/// solidly it filled its own bounding box, and the raw alpha for edge checks.
typedef Cut = ({Rect box, double fill, List<int> px, int w, int h});

Future<Cut> cutoutOf(String assetPath) async {
  final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
  final photo =
      (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
  final cut = await GarmentTint.cutout(photo);
  final px = (await cut.toByteData())!.buffer.asUint8List();
  final w = cut.width, h = cut.height;

  var minX = w, minY = h, maxX = -1, maxY = -1, opaque = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] > 32) {
        opaque++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  photo.dispose();
  cut.dispose();
  final box = Rect.fromLTRB(minX / w, minY / h, (maxX + 1) / w, (maxY + 1) / h);
  return (
    box: box,
    fill: opaque / (box.width * w * box.height * h),
    px: px,
    w: w,
    h: h,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final faces = {
    'front': BundledGarments.tintBaseFront,
    'back': BundledGarments.tintBaseBack,
  };

  group('the photography is registered, and registered correctly', () {
    testWidgets('both tint bases are bundled and decodable', (tester) async {
      await tester.runAsync(() async {
        for (final path in faces.values) {
          expect(
            () async => (await rootBundle.load(path)).lengthInBytes,
            returnsNormally,
            reason: '$path is not bundled',
          );
        }
      });
    });

    testWidgets('the recorded dimensions match the files', (tester) async {
      // The print file is cut to the print area's real shape, which depends on
      // these. New photography that changes them without updating the
      // constants silently reshapes every print file.
      await tester.runAsync(() async {
        for (final (path, size) in [
          (BundledGarments.tintBaseFront, BundledGarments.tintBaseFrontSize),
          (BundledGarments.tintBaseBack, BundledGarments.tintBaseBackSize),
        ]) {
          final bytes = (await rootBundle.load(path)).buffer.asUint8List();
          final img =
              (await (await ui.instantiateImageCodec(bytes)).getNextFrame())
                  .image;
          expect(Size(img.width.toDouble(), img.height.toDouble()), size);
          img.dispose();
        }
      });
    });
  });

  group('the framing the print geometry depends on', () {
    testWidgets('the two faces are framed alike across the width', (
      tester,
    ) async {
      // Print areas are normalised to the photo, so a garment that sits
      // differently in its frame moves every print on that face without any
      // code changing. The horizontal framing is what the chest positions and
      // the back panel are calibrated against.
      late Cut front, back;
      await tester.runAsync(() async {
        front = await cutoutOf(faces['front']!);
        back = await cutoutOf(faces['back']!);
      });
      expect(front.box.left, closeTo(back.box.left, 0.006));
      expect(front.box.width, closeTo(back.box.width, 0.006));
    });

    testWidgets('each face keeps the framing the print areas were cut for', (
      tester,
    ) async {
      // Pinned per face rather than only against each other: a reshoot that
      // moved BOTH garments identically would pass the comparison above while
      // still invalidating every calibrated print area.
      final expected = {
        'front': const Rect.fromLTRB(0.0019, 0.0063, 0.9961, 0.9954),
        'back': const Rect.fromLTRB(0.0041, 0.0484, 0.9959, 0.9906),
      };
      for (final entry in faces.entries) {
        late Cut cut;
        await tester.runAsync(() async => cut = await cutoutOf(entry.value));
        final want = expected[entry.key]!;
        for (final (label, got, expect_) in [
          ('left', cut.box.left, want.left),
          ('top', cut.box.top, want.top),
          ('right', cut.box.right, want.right),
          ('bottom', cut.box.bottom, want.bottom),
        ]) {
          expect(
            got,
            closeTo(expect_, 0.01),
            reason: '${entry.key} garment moved in the frame ($label)',
          );
        }
      }
    });
  });

  group('the edge the whole tint pipeline rests on', () {
    testWidgets('the sweep comes away and the garment does not', (
      tester,
    ) async {
      // A white garment on a white sweep is what forced the tint base to grey
      // in the first place: with no separable edge the flood fill eats into
      // the shoulders and every recoloured shirt comes out full of holes.
      for (final entry in faces.entries) {
        late Cut cut;
        await tester.runAsync(() async => cut = await cutoutOf(entry.value));
        final (px, w, h) = (cut.px, cut.w, cut.h);
        int alpha(int x, int y) => px[(y * w + x) * 4 + 3];

        // Every corner is backdrop, so the fill has somewhere to start.
        for (final (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]) {
          expect(
            alpha(x, y),
            0,
            reason: '${entry.key}: the sweep survived at ($x, $y)',
          );
        }

        // …and the garment itself is solid, not eaten through.
        expect(
          alpha(w ~/ 2, h ~/ 2),
          greaterThan(200),
          reason: '${entry.key}: the middle of the shirt was cut away',
        );
        expect(
          cut.fill,
          greaterThan(0.6),
          reason:
              '${entry.key}: only ${(cut.fill * 100).round()}% of the garment '
              'survived the cutout — the backdrop fill is reaching inside it',
        );
      }
    });

    testWidgets('a recoloured garment keeps the same silhouette', (
      tester,
    ) async {
      // Tinting must change colour and nothing else: if recolour disagrees
      // with cutout about where the garment is, the print lands on fabric that
      // is not there.
      for (final entry in faces.entries) {
        late int cutoutOpaque, tintedOpaque;
        await tester.runAsync(() async {
          final bytes =
              (await rootBundle.load(entry.value)).buffer.asUint8List();
          final photo =
              (await (await ui.instantiateImageCodec(bytes)).getNextFrame())
                  .image;
          Future<int> opaqueOf(ui.Image img) async {
            final p = (await img.toByteData())!.buffer.asUint8List();
            var n = 0;
            for (var i = 0; i < img.width * img.height; i++) {
              if (p[i * 4 + 3] > 32) n++;
            }
            return n;
          }

          final cut = await GarmentTint.cutout(photo);
          cutoutOpaque = await opaqueOf(cut);
          final tinted = await GarmentTint.recolour(
            photo,
            const ui.Color(0xFFFF1B2B),
          );
          tintedOpaque = await opaqueOf(tinted);
          photo.dispose();
          cut.dispose();
          tinted.dispose();
        });
        expect(
          tintedOpaque / cutoutOpaque,
          closeTo(1.0, 0.02),
          reason: '${entry.key}: tinting changed the garment silhouette',
        );
      }
    });
  });

  group('resolution', () {
    testWidgets('the photography is crisp at full studio-hero size', (
      tester,
    ) async {
      // The hero renders its artwork at 1024 on the long side while the
      // garment behind it is 640 — so the shirt is upscaled on every screen in
      // the Studio. 2–3× the current resolution is the bar for a reshoot.
      await tester.runAsync(() async {
        for (final path in faces.values) {
          final bytes = (await rootBundle.load(path)).buffer.asUint8List();
          final img =
              (await (await ui.instantiateImageCodec(bytes)).getNextFrame())
                  .image;
          expect(
            img.height,
            greaterThanOrEqualTo(1280),
            reason: '$path is ${img.width}×${img.height} — soft as a hero',
          );
          img.dispose();
        }
      });
      // Everything above this test passes today and guards a reshoot. This one
      // states the bar the current assets do NOT meet: the shipped shirts are
      // 513×640 and 487×640, taken for the small merch preview. Delete this
      // skip when the new photography lands — no other change is needed.
    }, skip: true);
  });
}
