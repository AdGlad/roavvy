import 'dart:math' as math;
import 'dart:ui' as ui;

/// Builds a typography clip mask: [text] rendered as opaque white glyphs on a
/// transparent [w]×[h] image, scaled to fit [rect], positioned at its centre and
/// rotated by [rotationDeg]. Applied `dstIn` so the flag artwork fills the
/// letterforms. Deterministic (pure layout of a bundled font).
class TextMask {
  const TextMask._();

  static Future<ui.Image> build({
    required int w,
    required int h,
    required ui.Rect rect,
    required double rotationDeg,
    required String text,
    String? fontFamily,
  }) async {
    final content = text.trim().isEmpty ? ' ' : text.trim();

    ui.Paragraph layout(double fontSize) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        // Left-aligned so glyphs start at x=0 in the huge layout width; the
        // caller centres the measured block. (center would push text ~width/2.)
        textAlign: ui.TextAlign.left,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w800,
        fontFamily: fontFamily,
      ))
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
        ..addText(content);
      return builder.build()
        ..layout(const ui.ParagraphConstraints(width: 100000));
    }

    const base = 120.0;
    final p0 = layout(base);
    final w0 = p0.longestLine <= 0 ? p0.maxIntrinsicWidth : p0.longestLine;
    final h0 = p0.height;
    if (w0 <= 0 || h0 <= 0) return _blank(w, h);

    final scale = math.min(rect.width / w0, rect.height / h0);
    final para = layout(base * scale);
    final tw = para.longestLine <= 0 ? para.maxIntrinsicWidth : para.longestLine;
    final thh = para.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(rect.center.dx, rect.center.dy);
    if (rotationDeg != 0) canvas.rotate(rotationDeg * math.pi / 180);
    canvas.translate(-tw / 2, -thh / 2);
    // Paragraph is centre-aligned within its own width; draw over that width.
    canvas.drawParagraph(para, ui.Offset.zero);
    return recorder.endRecording().toImage(w, h);
  }

  static Future<ui.Image> _blank(int w, int h) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    return recorder.endRecording().toImage(w, h);
  }
}
