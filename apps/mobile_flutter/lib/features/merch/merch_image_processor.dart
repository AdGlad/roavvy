import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  }) async {
    if (frontPosition == 'none' || sourceBytes.isEmpty) return null;

    final src = await _decode(sourceBytes);
    final srcW = src.width.toDouble();
    final srcH = src.height.toDouble();

    final Uint8List printBytes;
    final Uint8List mockupBytes;

    final isChest = frontPosition == 'left_chest' ||
        frontPosition == 'front_left' ||
        frontPosition == 'right_chest' ||
        frontPosition == 'front_right';

    if (isChest) {
      // Fit design inside the chest box then composite onto transparent canvas.
      final maxW = (widthPx * 0.29).round().toDouble();
      final maxH = (heightPx * 0.30).round().toDouble();
      final topOffset = (heightPx * 0.07).round().toDouble();
      final leftFraction =
          (frontPosition == 'left_chest' || frontPosition == 'front_left')
              ? 0.58
              : 0.13;
      final leftOffset = (widthPx * leftFraction).roundToDouble();

      // Fit inside maxW×maxH while preserving aspect ratio.
      final scale = min(maxW / srcW, maxH / srcH);
      final rw = srcW * scale;
      final rh = srcH * scale;
      // Centre-align within the maxW column to match server behaviour.
      final compositeLeft = leftOffset + (maxW - rw) / 2;

      printBytes = await _renderToCanvas(
        src: src,
        srcRect: ui.Rect.fromLTWH(0, 0, srcW, srcH),
        dstRect: ui.Rect.fromLTWH(compositeLeft, topOffset, rw, rh),
        canvasW: widthPx,
        canvasH: heightPx,
        bgColor: const ui.Color(0x00000000),
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
  static Future<Uint8List?> processBack({
    required Uint8List sourceBytes,
    required int widthPx,
    required int heightPx,
    required bool transparentBackground,
  }) async {
    if (sourceBytes.isEmpty) return null;
    final src = await _decode(sourceBytes);
    final result = await _contain(
      src: src,
      targetW: widthPx,
      targetH: heightPx,
      bgColor: transparentBackground
          ? const ui.Color(0x00000000)
          : const ui.Color(0xFFFFFFFF),
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
    );
  }

  /// Renders [src] at [dstRect] on a [canvasW]×[canvasH] canvas.
  static Future<Uint8List> _renderToCanvas({
    required ui.Image src,
    required ui.Rect srcRect,
    required ui.Rect dstRect,
    required int canvasW,
    required int canvasH,
    required ui.Color bgColor,
  }) async {
    final canvasRect =
        ui.Rect.fromLTWH(0, 0, canvasW.toDouble(), canvasH.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, canvasRect);

    if (bgColor.a > 0) {
      canvas.drawRect(canvasRect, ui.Paint()..color = bgColor);
    }
    canvas.drawImageRect(
      src,
      srcRect,
      dstRect,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasW, canvasH);
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}
