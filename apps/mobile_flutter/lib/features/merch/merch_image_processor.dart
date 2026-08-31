import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'mockup_transform_controller.dart';

/// On-device image processor replicating the server-side Sharp operations.
///
/// Produces:
///   - Full-resolution front print PNG (widthPx × heightPx)
///   - Mockup-optimised front PNG for Printful v2 mockup API
///   - Full-resolution back print PNG (widthPx × heightPx)
///
/// All processing uses Flutter's GPU-backed Canvas/Picture API for speed.
class MerchImageProcessor {
  static const double _tshirtFrontPrintWIn = 12.0;
  static const double _tshirtFrontPrintHIn = 16.0;

  /// Processes front artwork into a print file + Printful mockup file.
  ///
  /// Returns null when [frontPosition] is 'none' or [sourceBytes] is empty.
  static Future<({Uint8List printBytes, Uint8List mockupBytes})?> processFront({
    required Uint8List sourceBytes,
    required String frontPosition,
    required int widthPx,
    required int heightPx,
    required int dpi,
    required bool transparentBackground,
    MockupTransform transform = MockupTransform.identity,
  }) async {
    if (frontPosition == 'none' || sourceBytes.isEmpty) return null;

    final src = await _decode(sourceBytes);
    final srcW = src.width.toDouble();
    final srcH = src.height.toDouble();

    final Uint8List printBytes;
    final Uint8List mockupBytes;

    final isLeft =
        frontPosition == 'left_chest' || frontPosition == 'front_left';
    final isRight =
        frontPosition == 'right_chest' || frontPosition == 'front_right';
    // 'front' is the mapped value for the app's 'center' front placement.
    final isCenter = frontPosition == 'center' ||
        frontPosition == 'front_center' ||
        frontPosition == 'front';
    final isChest = isLeft || isRight || isCenter;

    if (isChest) {
      // Positioning matches M167 server-side constants (index.ts):
      //   logo: 3.5" × 3.5" square
      //   top:  3.0" below top of print area
      //   left_chest centre: 10.0" from canvas left → left edge at 8.25"
      //   right_chest centre:  2.0" from canvas left → left edge at 0.25"
      //   centre:              6.0" from canvas left (mid of 12") → edge at 4.25"
      final sizePx = (3.5 * dpi).round().toDouble(); // 525 px at 150 DPI
      final maxW = sizePx;
      final maxH = sizePx;
      final topOffset = (3.0 * dpi).round().toDouble(); // 450 px at 150 DPI
      final centerIn = isLeft
          ? 10.0
          : isRight
              ? 2.0
              : 6.0;
      // Left edge = centre − half logo width (mirrors Math.round(sizePx/2) in TS)
      final leftOffset =
          ((centerIn * dpi).round() - (sizePx / 2).round()).toDouble();

      // Fit inside sizePx × sizePx while preserving aspect ratio.
      final scale = min(maxW / srcW, maxH / srcH);
      final rw = srcW * scale;
      final rh = srcH * scale;
      // Centre-align within the sizePx column to match server behaviour.
      final compositeLeft = leftOffset + (maxW - rw) / 2;

      printBytes = await _renderToCanvas(
        src: src,
        srcRect: ui.Rect.fromLTWH(0, 0, srcW, srcH),
        dstRect: ui.Rect.fromLTWH(compositeLeft, topOffset, rw, rh),
        canvasW: widthPx,
        canvasH: heightPx,
        bgColor: const ui.Color(0x00000000),
        transform: transform,
      );

      // Mockup: small square crop sent to Printful mockup API.
      final chestPx = (3.5 * dpi).round();
      mockupBytes = await _contain(
        src: src,
        targetW: chestPx,
        targetH: chestPx,
        bgColor: const ui.Color(0x00000000),
      );
    } else {
      // Center print: full canvas, fit contain.
      printBytes = await _contain(
        src: src,
        targetW: widthPx,
        targetH: heightPx,
        bgColor: transparentBackground
            ? const ui.Color(0x00000000)
            : const ui.Color(0xFFFFFFFF),
        transform: transform,
      );

      // Mockup: fill Printful's full DTG print area.
      final mockupW = (_tshirtFrontPrintWIn * dpi).round();
      final mockupH = (_tshirtFrontPrintHIn * dpi).round();
      mockupBytes = await _contain(
        src: src,
        targetW: mockupW,
        targetH: mockupH,
        bgColor: const ui.Color(0x00000000),
      );
    }

    src.dispose();
    return (printBytes: printBytes, mockupBytes: mockupBytes);
  }

  /// Processes back artwork into a full-resolution print file.
  ///
  /// [fillFraction] (0–1, from the chosen Image Size) is the fraction of the
  /// printable area the artwork fills. The artwork is contain-fit into a centred
  /// box of that fraction of the printfile, so the printed size matches the
  /// preview (M190). `1.0` fills the whole printable area (previous behaviour).
  static Future<Uint8List?> processBack({
    required Uint8List sourceBytes,
    required int widthPx,
    required int heightPx,
    required bool transparentBackground,
    double fillFraction = 1.0,
    MockupTransform transform = MockupTransform.identity,
  }) async {
    if (sourceBytes.isEmpty) return null;
    final src = await _decode(sourceBytes);
    final result = await _containScaled(
      src: src,
      canvasW: widthPx,
      canvasH: heightPx,
      fillFraction: fillFraction,
      bgColor: transparentBackground
          ? const ui.Color(0x00000000)
          : const ui.Color(0xFFFFFFFF),
      transform: transform,
    );
    src.dispose();
    return result;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Resize [src] to fit inside [targetW]×[targetH], centered, with [bgColor].
  static Future<Uint8List> _contain({
    required ui.Image src,
    required int targetW,
    required int targetH,
    required ui.Color bgColor,
    MockupTransform transform = MockupTransform.identity,
  }) {
    final srcW = src.width.toDouble();
    final srcH = src.height.toDouble();
    final scale = min(targetW / srcW, targetH / srcH);
    final rw = srcW * scale;
    final rh = srcH * scale;
    final left = (targetW - rw) / 2;
    final top = (targetH - rh) / 2;
    return _renderToCanvas(
      src: src,
      srcRect: ui.Rect.fromLTWH(0, 0, srcW, srcH),
      dstRect: ui.Rect.fromLTWH(left, top, rw, rh),
      canvasW: targetW,
      canvasH: targetH,
      bgColor: bgColor,
      transform: transform,
    );
  }

  /// Contain-fits [src] into a centred box that is [fillFraction] of the
  /// [canvasW]×[canvasH] canvas, on a full-size canvas filled with [bgColor].
  /// At `fillFraction == 1.0` this is identical to [_contain].
  static Future<Uint8List> _containScaled({
    required ui.Image src,
    required int canvasW,
    required int canvasH,
    required double fillFraction,
    required ui.Color bgColor,
    MockupTransform transform = MockupTransform.identity,
  }) {
    final f = fillFraction.clamp(0.05, 1.0);
    final srcW = src.width.toDouble();
    final srcH = src.height.toDouble();
    final boxW = canvasW * f;
    final boxH = canvasH * f;
    final scale = min(boxW / srcW, boxH / srcH);
    final rw = srcW * scale;
    final rh = srcH * scale;
    final left = (canvasW - rw) / 2;
    final top = (canvasH - rh) / 2;
    return _renderToCanvas(
      src: src,
      srcRect: ui.Rect.fromLTWH(0, 0, srcW, srcH),
      dstRect: ui.Rect.fromLTWH(left, top, rw, rh),
      canvasW: canvasW,
      canvasH: canvasH,
      bgColor: bgColor,
      transform: transform,
    );
  }

  /// Renders [src] at [dstRect] on a [canvasW]×[canvasH] canvas.
  ///
  /// [transform] (M174) is the placement the user arranged on the mockup. The
  /// print canvas IS the printable area, so the same normalised values apply
  /// here unchanged — translation as a fraction of the canvas, scale/rotation
  /// about the artwork's own centre — which is what makes the printed file
  /// match the on-screen preview. Artwork is clipped to the canvas, so a
  /// dragged design can never escape the printable area.
  static Future<Uint8List> _renderToCanvas({
    required ui.Image src,
    required ui.Rect srcRect,
    required ui.Rect dstRect,
    required int canvasW,
    required int canvasH,
    required ui.Color bgColor,
    MockupTransform transform = MockupTransform.identity,
  }) async {
    final canvasRect =
        ui.Rect.fromLTWH(0, 0, canvasW.toDouble(), canvasH.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, canvasRect);

    if (bgColor.a > 0) {
      canvas.drawRect(canvasRect, ui.Paint()..color = bgColor);
    }

    final transformed = !transform.isIdentity;
    if (transformed) {
      canvas.save();
      canvas.clipRect(canvasRect);
      final c = dstRect.center;
      canvas.translate(
        c.dx + transform.translation.dx * canvasW,
        c.dy + transform.translation.dy * canvasH,
      );
      canvas.rotate(transform.rotation);
      canvas.scale(transform.scale);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawImageRect(
      src,
      srcRect,
      dstRect,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    if (transformed) canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasW, canvasH);
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}
