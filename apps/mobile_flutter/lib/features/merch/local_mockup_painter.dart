import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'product_mockup_specs.dart';

/// [CustomPainter] that composites a card artwork image onto a product mockup.
///
/// Rendering order:
/// 1. Product background — [productImage] scaled to fill the canvas
///    ([BoxFit.cover] semantics). Skipped (white fill) when [productImage] is
///    null (poster variant — ADR-107 Decision 5).
/// 2. Artwork — [artworkImage] scaled to fit inside the print area defined by
///    [spec.printAreaNorm], centred ([BoxFit.contain] semantics).
/// 3. Subtle inner shadow at the print area border (t-shirt only; skipped when
///    [productImage] is null).
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

  /// Spec describing the asset path and normalised print area.
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

    // 1. Background layer.
    if (productImage != null) {
      _paintImageFitCover(canvas, size, productImage!);
    } else {
      // Poster: white background.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const ui.Color(0xFFFFFFFF),
      );
    }

    // 2. Artwork layer — BoxFit.contain inside print area.
    canvas.save();
    canvas.clipRect(printPixels);
    _paintImageContainInRect(canvas, printPixels, artworkImage);
    canvas.restore();

    // 3. Inner shadow at print area border (t-shirt only).
    if (productImage != null) {
      final shadowPaint = Paint()
        ..color = const ui.Color(0x1F000000) // ~12% black
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.inner, 3);
      canvas.drawRect(printPixels, shadowPaint);
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

  /// Paints [image] scaled to fill [canvasSize] (BoxFit.cover).
  void _paintImageFitCover(ui.Canvas canvas, ui.Size canvasSize, ui.Image image) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scaleX = canvasSize.width / imgW;
    final scaleY = canvasSize.height / imgH;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final srcW = canvasSize.width / scale;
    final srcH = canvasSize.height / scale;
    final srcX = (imgW - srcW) / 2;
    final srcY = (imgH - srcH) / 2;

    final src = Rect.fromLTWH(srcX, srcY, srcW, srcH);
    final dst = Offset.zero & canvasSize;
    canvas.drawImageRect(image, src, dst, Paint());
  }

  /// Paints [image] scaled to fit inside [rect] (BoxFit.contain, centred).
  void _paintImageContainInRect(ui.Canvas canvas, Rect rect, ui.Image image) {
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
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(LocalMockupPainter old) =>
      !identical(productImage, old.productImage) ||
      !identical(artworkImage, old.artworkImage) ||
      spec != old.spec ||
      debugPrintArea != old.debugPrintArea;
}
