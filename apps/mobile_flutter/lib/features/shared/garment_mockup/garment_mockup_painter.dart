import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'garment_mockup_spec.dart';
import 'mockup_transform.dart';

/// M174 — the photorealistic mockup composite: a garment photo, the user's
/// artwork transformed live inside the printable area, and the fabric's own
/// folds multiplied back over the print so it reads as ink on cloth rather
/// than a sticker.
///
/// ```
///   TOP     Fabric wrinkle/shadow pass  (multiply, masked to artwork alpha)
///   MIDDLE  User artwork                (Matrix4 pan/pinch/rotate, clipped)
///   BOTTOM  Garment photo               (BoxFit.contain)
/// ```
///
/// **Why the alpha mask matters.** A plain `multiply` of the shading over the
/// whole print rectangle darkens transparent pixels too, stamping a visible
/// grey box onto the shirt. Drawing the artwork again with [BlendMode.dstIn]
/// inside the same `saveLayer` erases the shading everywhere the artwork is
/// transparent, so folds land on the ink only.
///
/// The painter repaints from [MockupTransformController]'s notifiers, never
/// from `setState`, so a gesture costs one paint pass and zero rebuilds.
class GarmentMockupPainter extends CustomPainter {
  GarmentMockupPainter({
    required this.spec,
    required this.controller,
    this.garmentImage,
    this.shadingImage,
    this.artworkImage,
    this.artworkBlendMode = ui.BlendMode.multiply,
    this.shadingOpacity = 0.4,
    this.showGuide = true,
    this.debugPrintArea = false,
  }) : super(
         repaint: Listenable.merge([
           controller.transform,
           controller.isGestureActive,
         ]),
       );

  /// Garment background. Null renders a poster-style white page.
  final ui.Image? garmentImage;

  /// Luminance source for the fabric shading pass — the companion wrinkle map
  /// when one is bundled, otherwise the garment photo itself.
  final ui.Image? shadingImage;

  /// The user's artwork. Null renders a blank garment.
  final ui.Image? artworkImage;

  final GarmentMockupSpec spec;
  final MockupTransformController controller;

  /// [BlendMode.multiply] for opaque artwork on a white card background;
  /// [BlendMode.srcOver] for transparent-background artwork (white stamps).
  final ui.BlendMode artworkBlendMode;

  /// Strength of the fabric shading over the print (0 = none, 1 = full photo).
  final double shadingOpacity;

  /// Whether the dashed print-boundary guide may appear during a gesture.
  final bool showGuide;

  /// Calibration aid: outlines the printable area permanently.
  final bool debugPrintArea;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (garmentImage == null) {
      _paintPoster(canvas, size);
      return;
    }

    // ── Layer 1: garment ──────────────────────────────────────────────────
    final garmentRect = _drawGarment(canvas, size, garmentImage!);
    final printPixels = _printPixels(garmentRect);

    if (artworkImage != null) {
      final matrix = controller.value.toMatrix4(printPixels.size);
      final artSrc = _fullRect(artworkImage!);
      final artDst = _containRect(printPixels.size, artSrc);

      // ── Layer 2: artwork, transformed inside the printable area ─────────
      canvas.save();
      canvas.clipRect(printPixels);
      canvas.translate(printPixels.left, printPixels.top);
      canvas.transform(matrix.storage);
      canvas.drawImageRect(
        artworkImage!,
        artSrc,
        artDst,
        ui.Paint()
          ..blendMode = artworkBlendMode
          ..filterQuality = ui.FilterQuality.medium,
      );
      canvas.restore();

      // ── Layer 3: fabric folds, masked to the artwork's own pixels ───────
      if (shadingImage != null && shadingOpacity > 0) {
        canvas.save();
        canvas.clipRect(printPixels);
        canvas.saveLayer(printPixels, ui.Paint());

        // Pass A — the fold luminance, aligned to the garment.
        _drawGarment(
          canvas,
          size,
          shadingImage!,
          opacity: shadingOpacity,
          blendMode: ui.BlendMode.multiply,
        );

        // Pass B — keep the shading only where there is ink.
        canvas.save();
        canvas.translate(printPixels.left, printPixels.top);
        canvas.transform(matrix.storage);
        canvas.drawImageRect(
          artworkImage!,
          artSrc,
          artDst,
          ui.Paint()
            ..blendMode = ui.BlendMode.dstIn
            ..filterQuality = ui.FilterQuality.medium,
        );
        canvas.restore();

        canvas.restore(); // composite the masked shading down
        canvas.restore(); // clipRect
      }
    }

    if (showGuide && controller.isGestureActive.value) {
      _drawDashedGuide(canvas, printPixels);
    }
    if (debugPrintArea) {
      canvas.drawRect(
        printPixels,
        ui.Paint()
          ..color = const ui.Color(0xFFFF0000)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  // ── Geometry ───────────────────────────────────────────────────────────────

  /// The printable area in canvas pixels, derived from the garment's drawn rect.
  ui.Rect _printPixels(ui.Rect garmentRect) => ui.Rect.fromLTWH(
    garmentRect.left + spec.printAreaNorm.left * garmentRect.width,
    garmentRect.top + spec.printAreaNorm.top * garmentRect.height,
    spec.printAreaNorm.width * garmentRect.width,
    spec.printAreaNorm.height * garmentRect.height,
  );

  static ui.Rect _fullRect(ui.Image img) =>
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

  /// [src] contain-fitted and centred in a box of [size], in box-local
  /// coordinates (origin at the box's top-left).
  static ui.Rect _containRect(ui.Size size, ui.Rect src) {
    final scale =
        (size.width / src.width) < (size.height / src.height)
            ? size.width / src.width
            : size.height / src.height;
    final w = src.width * scale, h = src.height * scale;
    return ui.Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  /// Draws [image] contain-fitted into [size] (honouring [spec.srcRectNorm])
  /// and returns the destination rect. Both the garment and the shading pass go
  /// through this, so the folds always land in register with the photo.
  ui.Rect _drawGarment(
    ui.Canvas canvas,
    ui.Size size,
    ui.Image image, {
    double opacity = 1.0,
    ui.BlendMode blendMode = ui.BlendMode.srcOver,
  }) {
    final imgW = image.width.toDouble(), imgH = image.height.toDouble();
    final crop = spec.srcRectNorm;
    final src =
        crop == null
            ? ui.Rect.fromLTWH(0, 0, imgW, imgH)
            : ui.Rect.fromLTWH(
              crop.left * imgW,
              crop.top * imgH,
              crop.width * imgW,
              crop.height * imgH,
            );

    final scale =
        (size.width / src.width) < (size.height / src.height)
            ? size.width / src.width
            : size.height / src.height;
    final w = src.width * scale, h = src.height * scale;
    final dst = ui.Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );

    canvas.drawImageRect(
      image,
      src,
      dst,
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
        ..blendMode = blendMode
        ..filterQuality = ui.FilterQuality.medium,
    );
    return dst;
  }

  void _paintPoster(ui.Canvas canvas, ui.Size size) {
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    if (artworkImage == null) return;
    final printPixels = ui.Rect.fromLTWH(
      spec.printAreaNorm.left * size.width,
      spec.printAreaNorm.top * size.height,
      spec.printAreaNorm.width * size.width,
      spec.printAreaNorm.height * size.height,
    );
    final src = _fullRect(artworkImage!);
    canvas.save();
    canvas.clipRect(printPixels);
    canvas.translate(printPixels.left, printPixels.top);
    canvas.transform(controller.value.toMatrix4(printPixels.size).storage);
    canvas.drawImageRect(
      artworkImage!,
      src,
      _containRect(printPixels.size, src),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();
  }

  /// A subtle dashed outline of the printable area, shown only while the user
  /// is actively moving the design.
  void _drawDashedGuide(ui.Canvas canvas, ui.Rect rect) {
    final paint =
        ui.Paint()
          ..color = const ui.Color(0x99FFFFFF)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5;
    const dash = 6.0, gap = 5.0;

    void dashedLine(ui.Offset a, ui.Offset b) {
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len <= 0) return;
      final ux = dx / len, uy = dy / len;
      var t = 0.0;
      while (t < len) {
        final end = (t + dash) > len ? len : t + dash;
        canvas.drawLine(
          ui.Offset(a.dx + ux * t, a.dy + uy * t),
          ui.Offset(a.dx + ux * end, a.dy + uy * end),
          paint,
        );
        t = end + gap;
      }
    }

    dashedLine(rect.topLeft, rect.topRight);
    dashedLine(rect.topRight, rect.bottomRight);
    dashedLine(rect.bottomRight, rect.bottomLeft);
    dashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(GarmentMockupPainter old) =>
      !identical(garmentImage, old.garmentImage) ||
      !identical(shadingImage, old.shadingImage) ||
      !identical(artworkImage, old.artworkImage) ||
      !identical(controller, old.controller) ||
      spec.assetPath != old.spec.assetPath ||
      spec.printAreaNorm != old.spec.printAreaNorm ||
      artworkBlendMode != old.artworkBlendMode ||
      shadingOpacity != old.shadingOpacity ||
      showGuide != old.showGuide ||
      debugPrintArea != old.debugPrintArea;
}
