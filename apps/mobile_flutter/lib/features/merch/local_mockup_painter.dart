import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'product_mockup_specs.dart';

/// [CustomPainter] that composites a card artwork image onto a product mockup.
///
/// Rendering order (t-shirt):
/// 1. Shirt background — [productImage] cropped via [spec.srcRectNorm] (or full
///    image when null) scaled to fill the canvas (BoxFit.cover semantics).
/// 2. Artwork — [artworkImage] with [BlendMode.multiply], scaled to fit inside
///    the print area defined by [spec.printAreaNorm] (BoxFit.contain, centred),
///    clipped to the print area. Multiply makes white card background areas
///    transparent so the shirt fabric shows through.
/// 3. Shirt shading overlay — [productImage] drawn again at 0.25 opacity with
///    [BlendMode.multiply], cropped to the print area only. This reapplies the
///    fabric folds and shadows so the artwork looks embedded rather than pasted
///    on top (ADR-115 Decision 2).
///
/// For posters ([productImage] == null):
/// 1. White fill.
/// 2. Artwork (full opacity, no shading overlay).
///
/// A red debug border is drawn around the print area when [debugPrintArea] is
/// true — useful during asset calibration (ADR-107 Risk 1).
class LocalMockupPainter extends CustomPainter {
  const LocalMockupPainter({
    required this.artworkImage,
    required this.spec,
    this.productImage,
    this.debugPrintArea = false,
  });

  /// The card artwork PNG. Never null.
  final ui.Image artworkImage;

  /// The product background image. Null for poster (renders white background).
  final ui.Image? productImage;

  /// Spec describing the asset path, normalised print area, and optional source
  /// crop rectangle.
  final ProductMockupSpec spec;

  /// When true, draws a red border around [spec.printAreaNorm] for calibration.
  final bool debugPrintArea;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final printPixels = Rect.fromLTWH(
      spec.printAreaNorm.left * size.width,
      spec.printAreaNorm.top * size.height,
      spec.printAreaNorm.width * size.width,
      spec.printAreaNorm.height * size.height,
    );

    if (productImage != null) {
      // 1. Shirt background (cropped to srcRectNorm if specified).
      _paintShirtBackground(canvas, size, productImage!);

      // 2. Artwork with BlendMode.multiply so white card background is
      //    transparent (shows shirt fabric) and colours are embedded in the
      //    fabric texture (ADR-115 Decision 2).
      canvas.save();
      canvas.clipRect(printPixels);
      _paintImageContainInRect(
        canvas,
        printPixels,
        artworkImage,
        blendMode: ui.BlendMode.multiply,
      );
      canvas.restore();

      // 3. Shirt shading overlay — reapplies fabric texture over artwork.
      canvas.save();
      canvas.clipRect(printPixels);
      _paintShirtBackground(
        canvas,
        size,
        productImage!,
        opacity: 0.25,
        blendMode: ui.BlendMode.multiply,
      );
      canvas.restore();
    } else {
      // Poster: white background, artwork at full opacity.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.save();
      canvas.clipRect(printPixels);
      _paintImageContainInRect(canvas, printPixels, artworkImage);
      canvas.restore();
    }

    // Debug: print area border.
    if (debugPrintArea) {
      canvas.drawRect(
        printPixels,
        Paint()
          ..color = const ui.Color(0xFFFF0000)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Paints [image] scaled to fill [canvasSize] (BoxFit.cover), cropped to
  /// [spec.srcRectNorm] if set. Supports [opacity] and [blendMode] for overlay
  /// passes (ADR-115 Decision 2).
  void _paintShirtBackground(
    ui.Canvas canvas,
    ui.Size canvasSize,
    ui.Image image, {
    double opacity = 1.0,
    ui.BlendMode blendMode = ui.BlendMode.srcOver,
  }) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // Compute the source rectangle in pixel coordinates.
    final Rect srcFullPixels;
    if (spec.srcRectNorm != null) {
      final n = spec.srcRectNorm!;
      srcFullPixels = Rect.fromLTWH(
        n.left * imgW,
        n.top * imgH,
        n.width * imgW,
        n.height * imgH,
      );
    } else {
      srcFullPixels = Rect.fromLTWH(0, 0, imgW, imgH);
    }

    // BoxFit.cover: scale so the cropped source fills the canvas entirely.
    final srcW = srcFullPixels.width;
    final srcH = srcFullPixels.height;
    final scaleX = canvasSize.width / srcW;
    final scaleY = canvasSize.height / srcH;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final visW = canvasSize.width / scale;
    final visH = canvasSize.height / scale;
    final visX = srcFullPixels.left + (srcW - visW) / 2;
    final visY = srcFullPixels.top + (srcH - visH) / 2;

    final src = Rect.fromLTWH(visX, visY, visW, visH);
    final dst = Offset.zero & canvasSize;

    final paint = Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
      ..blendMode = blendMode;

    canvas.drawImageRect(image, src, dst, paint);
  }

  /// Paints [image] scaled to fit inside [rect] (BoxFit.contain, centred) at
  /// the given [opacity] and [blendMode].
  void _paintImageContainInRect(
    ui.Canvas canvas,
    Rect rect,
    ui.Image image, {
    double opacity = 1.0,
    ui.BlendMode blendMode = ui.BlendMode.srcOver,
  }) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scaleX = rect.width / imgW;
    final scaleY = rect.height / imgH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final dstW = imgW * scale;
    final dstH = imgH * scale;
    final dstX = rect.left + (rect.width - dstW) / 2;
    final dstY = rect.top + (rect.height - dstH) / 2;

    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Rect.fromLTWH(dstX, dstY, dstW, dstH);

    final paint = Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
      ..blendMode = blendMode;

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(LocalMockupPainter old) =>
      !identical(productImage, old.productImage) ||
      !identical(artworkImage, old.artworkImage) ||
      spec != old.spec ||
      debugPrintArea != old.debugPrintArea;
}
