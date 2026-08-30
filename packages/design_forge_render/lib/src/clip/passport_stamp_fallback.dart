import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../asset_resolver.dart';
import 'shape_geometry.dart';

/// Built-in passport-stamp artwork, drawn from procedural geometry + text — no
/// bundled assets, no IO, fully deterministic.
///
/// This is the Passport family's floor: when a host ships no real stamp PNGs (or
/// has none for the selected countries), a Passport design still renders as
/// passport stamps rather than degrading into a plain flag print. Arrivals get
/// the serrated border block (`entryStamp`), departures the round rubber seal
/// (`passportStamp`), each carrying its country code and the trip date — the
/// same entry/exit + date semantics the real stamp artwork uses.
///
/// The output is an **alpha mask** (opaque ink on transparent) laid out with the
/// same shuffled-grid + jitter scatter as `SvgFlagResolver.resolvePassportCollage`,
/// so the artwork below shows through the stamps.
class PassportStampFallback {
  const PassportStampFallback._();

  static const _ink = ui.Color(0xFFFFFFFF);

  /// A [width]×[height] mask of [stamps] scattered across the page. [seed] fixes
  /// the layout, [scatter] (0…1) the jitter within each grid cell, and
  /// [stampScale] scales every stamp.
  static Future<ui.Image> build(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final n = stamps.length;
    if (n > 0) {
      final rng = DeterministicRng(seed != 0
              ? seed
              : _stableHash([for (final s in stamps) s.slug].join(',')))
          .stream('collage');

      // Deterministic Fisher–Yates shuffle, then one stamp per grid cell.
      final order = List<int>.generate(n, (i) => i);
      for (var i = n - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final t = order[i];
        order[i] = order[j];
        order[j] = t;
      }

      const margin = 0.05;
      final marginX = width * margin, marginY = height * margin;
      final usableW = width - marginX * 2, usableH = height - marginY * 2;
      final aspect = usableW / math.max(1.0, usableH);
      final rows = math.max(1, math.sqrt(n / aspect).ceil());
      final cols = math.max(1, (n / rows).ceil());
      final cellW = usableW / cols, cellH = usableH / rows;
      final base = math.min(cellW, cellH);

      for (var k = 0; k < n; k++) {
        final ref = stamps[order[k]];
        final col = k % cols, row = k ~/ cols;
        final jx = (rng.nextDouble() - 0.5) * cellW * scatter;
        final jy = (rng.nextDouble() - 0.5) * cellH * scatter;
        final variety = 0.9 + rng.nextDouble() * 0.2;
        final target = math.min(
            base * 1.12 * variety * stampScale, math.min(width, height) * 0.8);
        final half = target * 0.55;
        final cx = (marginX + (col + 0.5) * cellW + jx)
            .clamp(marginX + half, width - marginX - half);
        final cy = (marginY + (row + 0.5) * cellH + jy)
            .clamp(marginY + half, height - marginY - half);
        final deg = (rng.nextDouble() * 2 - 1) * 20;

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(deg * math.pi / 180);
        _drawStamp(canvas, ref, target);
        canvas.restore();
      }
    }
    return recorder.endRecording().toImage(width, height);
  }

  /// One stamp centred on the canvas origin, fitting a [size]² box.
  static void _drawStamp(ui.Canvas canvas, PassportStampRef ref, double size) {
    final exit = ref.slug.toLowerCase().endsWith('_exit');
    final cc = ref.slug.split('_').first.toUpperCase();
    final stroke = ui.Paint()
      ..color = _ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = size * 0.035
      ..isAntiAlias = true;

    // Departures are the round rubber seal, arrivals the serrated border block —
    // so entry and exit stay visually distinct, as on the real stamps.
    final rect = exit
        ? ui.Rect.fromCenter(center: ui.Offset.zero, width: size, height: size)
        : ui.Rect.fromCenter(
            center: ui.Offset.zero, width: size, height: size * 0.68);
    final path =
        ShapeGeometry.build(exit ? 'passportStamp' : 'entryStamp', rect, 0);
    if (path != null) canvas.drawPath(path, stroke);

    // Inner keyline, as on a real stamp.
    final inner = exit
        ? ui.Rect.fromCenter(
            center: ui.Offset.zero, width: size * 0.78, height: size * 0.78)
        : ui.Rect.fromCenter(
            center: ui.Offset.zero, width: size * 0.86, height: size * 0.5);
    if (exit) {
      canvas.drawCircle(
          ui.Offset.zero, inner.width / 2, stroke..strokeWidth = size * 0.022);
    } else {
      canvas.drawRect(inner, stroke..strokeWidth = size * 0.022);
    }

    final label = exit ? 'DEPARTURE' : 'ARRIVAL';
    _text(canvas, cc, size * 0.16, ui.Offset(0, -size * 0.13));
    _text(canvas, label, size * 0.075, ui.Offset(0, size * 0.02));
    final date = ref.date?.trim();
    if (date != null && date.isNotEmpty) {
      _text(canvas, date, size * 0.095, ui.Offset(0, size * 0.13));
    }
  }

  /// Draw [text] centred at [centre] at [fontSize].
  static void _text(
      ui.Canvas canvas, String text, double fontSize, ui.Offset centre) {
    final para = (ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontSize: fontSize,
      fontWeight: ui.FontWeight.w800,
    ))
          ..pushStyle(ui.TextStyle(color: _ink, letterSpacing: fontSize * 0.08))
          ..addText(text))
        .build()
      ..layout(const ui.ParagraphConstraints(width: 100000));
    final w = para.longestLine <= 0 ? para.maxIntrinsicWidth : para.longestLine;
    canvas.drawParagraph(
        para, ui.Offset(centre.dx - w / 2, centre.dy - para.height / 2));
  }

  /// FNV-1a, matching `SvgFlagResolver`'s stable collage hash.
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 0x01000193;
      h &= 0x7fffffff;
    }
    return h;
  }
}
