import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Rect, Size;

import 'mockup_transform.dart';

/// The true width/height of a printable area.
///
/// [printAreaNorm] is expressed as fractions of the garment PHOTOGRAPH, so its
/// shape depends on the photo's own proportions — which differ between the
/// front and back shirts. Reading the aspect off the fractions alone is how a
/// design comes to preview at one shape and print at another.
double printAreaAspect(Rect printAreaNorm, Size garmentPixelSize) {
  final w = printAreaNorm.width * garmentPixelSize.width;
  final h = printAreaNorm.height * garmentPixelSize.height;
  return h <= 0 ? 1.0 : w / h;
}

/// Bakes an arranged [MockupTransform] into a print file.
///
/// Where the design is left on the mockup is where it prints. The mockup shows
/// the artwork moved, resized and twisted inside the garment's printable area;
/// the print file that reaches the fulfiller is just the artwork, which the
/// fulfiller then drops into that same printable area unchanged. So the
/// arrangement has to travel inside the image itself: the artwork is composited
/// onto a transparent canvas the shape of the print area, under the transform,
/// and it is that canvas that becomes the print file.
///
/// The geometry deliberately matches `MerchImageProcessor`'s — contain-fit
/// first, then translate about the fitted rect's centre by a fraction of the
/// CANVAS, then rotate, then scale — so the preview and the print agree to the
/// pixel rather than merely looking similar.
///
/// An identity transform returns [artworkPng] untouched: nothing was arranged,
/// so nothing should be recompressed, re-fitted, or padded.
Future<Uint8List> bakePlacement(
  Uint8List artworkPng,
  MockupTransform transform, {
  required double printAreaAspect,
  int longSide = 2048,
}) async {
  if (transform.isIdentity) return artworkPng;

  final codec = await ui.instantiateImageCodec(artworkPng);
  final src = (await codec.getNextFrame()).image;
  try {
    final (canvasW, canvasH) =
        printAreaAspect >= 1
            ? (longSide, (longSide / printAreaAspect).round())
            : ((longSide * printAreaAspect).round(), longSide);
    final canvasRect = ui.Rect.fromLTWH(
      0,
      0,
      canvasW.toDouble(),
      canvasH.toDouble(),
    );

    // Contain-fit: scale 1.0 means the artwork exactly fits the print area.
    final scale =
        (canvasW / src.width) < (canvasH / src.height)
            ? canvasW / src.width
            : canvasH / src.height;
    final w = src.width * scale, h = src.height * scale;
    final dstRect = ui.Rect.fromLTWH(
      (canvasW - w) / 2,
      (canvasH - h) / 2,
      w,
      h,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, canvasRect);
    canvas.clipRect(canvasRect);
    final c = dstRect.center;
    canvas.translate(
      c.dx + transform.translation.dx * canvasW,
      c.dy + transform.translation.dy * canvasH,
    );
    canvas.rotate(transform.rotation);
    canvas.scale(transform.scale);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      dstRect,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final out = await recorder.endRecording().toImage(canvasW, canvasH);
    try {
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      out.dispose();
    }
  } finally {
    src.dispose();
  }
}
