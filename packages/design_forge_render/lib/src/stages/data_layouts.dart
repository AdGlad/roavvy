import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'render_stage.dart';

/// Builds the artwork for the **data-driven** design families that read the
/// travel history in `recipe.content.entries` (country + label + trip dates +
/// visit weight), rather than just flags:
///   * [DesignFamily.timeline]  — a dated, chronological trip list with a spine;
///   * [DesignFamily.journeys]  — flag "stops" along a winding dotted route;
///   * [DesignFamily.wordCloud] — country names sized by visit frequency.
///
/// Everything is headless `ui.Canvas`; text uses `ui.Paragraph`. The result is a
/// transparent artwork image (so clip/edge/effects/colour stages still apply).
class DataLayouts {
  const DataLayouts._();

  static const _ink = ui.Color(0xFF23262B);
  static const _muted = ui.Color(0xFF6B7078);
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// True for families this builder handles.
  static bool handles(DesignFamily f) =>
      f == DesignFamily.timeline ||
      f == DesignFamily.journeys ||
      f == DesignFamily.wordCloud;

  static Future<void> build(DesignRecipe recipe, RenderContext ctx) async {
    final entries = recipe.content.entries.isNotEmpty
        ? recipe.content.entries
        : [for (final f in recipe.content.flags) RecipeEntry(code: f.code)];
    if (entries.isEmpty) return;

    // Resolve each distinct flag once (chips), at a modest working size.
    final flags = <String, ui.Image>{};
    for (final e in entries) {
      flags[e.code] ??= await ctx.assets.resolveFlag(e.code, width: 256, height: 256);
    }

    switch (recipe.composition.family) {
      case DesignFamily.timeline:
        ctx.artwork = await _timeline(ctx, entries, flags);
        break;
      case DesignFamily.journeys:
        ctx.artwork = await _journey(ctx, entries, flags, recipe.seed);
        break;
      case DesignFamily.wordCloud:
        ctx.artwork = await _wordCloud(ctx, entries, flags, recipe.seed);
        break;
      default:
        break;
    }
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  static Future<ui.Image> _timeline(RenderContext ctx, List<RecipeEntry> entries,
      Map<String, ui.Image> flags) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    // Chronological; cap so rows stay legible.
    final rows = [...entries]
      ..sort((a, b) => (a.start ?? DateTime(0)).compareTo(b.start ?? DateTime(0)));
    final shown = rows.take(10).toList();
    return ctx.rasterise((canvas) {
      final padX = w * 0.08, padY = h * 0.08;
      final spineX = padX + w * 0.06;
      final rowH = (h - padY * 2) / shown.length;
      // Spine.
      canvas.drawLine(ui.Offset(spineX, padY + rowH * 0.5),
          ui.Offset(spineX, padY + rowH * (shown.length - 0.5)),
          ui.Paint()
            ..color = _muted
            ..strokeWidth = math.max(2, w * 0.004));
      for (var i = 0; i < shown.length; i++) {
        final e = shown[i];
        final cy = padY + rowH * (i + 0.5);
        // Node dot.
        canvas.drawCircle(ui.Offset(spineX, cy), math.max(4, w * 0.012),
            ui.Paint()..color = _ink);
        // Flag chip (rounded) just right of the spine.
        final chip = math.min(rowH * 0.62, w * 0.14);
        final chipRect = ui.Rect.fromCenter(
            center: ui.Offset(spineX + w * 0.09, cy), width: chip * 1.5, height: chip);
        _flagChip(canvas, flags[e.code]!, chipRect, chip * 0.16);
        // Text: name (bold) + date range.
        final tx = chipRect.right + w * 0.03;
        final name = e.label.isEmpty ? e.code.toUpperCase() : e.label;
        _text(canvas, name.toUpperCase(), ui.Offset(tx, cy - rowH * 0.30),
            rowH * 0.30, _ink, ui.FontWeight.w800, maxWidth: w - tx - padX);
        _text(canvas, _range(e), ui.Offset(tx, cy + rowH * 0.02),
            rowH * 0.22, _muted, ui.FontWeight.w500, maxWidth: w - tx - padX);
      }
    });
  }

  // ── Journeys (winding route with stops) ──────────────────────────────────────

  static Future<ui.Image> _journey(RenderContext ctx, List<RecipeEntry> entries,
      Map<String, ui.Image> flags, int seed) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    final stops = entries.take(12).toList();
    return ctx.rasterise((canvas) {
      final n = stops.length;
      final padY = h * 0.12;
      final usableH = h - padY * 2;
      // A vertical serpentine: y descends, x sine-wobbles.
      ui.Offset at(int i) {
        final t = n == 1 ? 0.5 : i / (n - 1);
        final y = padY + usableH * t;
        final x = w * 0.5 + math.sin(t * math.pi * 2.2) * (w * 0.30);
        return ui.Offset(x, y);
      }

      // Dotted route.
      final dot = ui.Paint()..color = _muted;
      for (var i = 0; i < n - 1; i++) {
        final a = at(i), b = at(i + 1);
        const steps = 14;
        for (var s = 1; s < steps; s++) {
          final p = ui.Offset.lerp(a, b, s / steps)!;
          canvas.drawCircle(p, math.max(1.5, w * 0.004), dot);
        }
      }
      // Stops: circular flag chips + label.
      final chip = math.min(w * 0.16, usableH / n * 0.9);
      for (var i = 0; i < n; i++) {
        final e = stops[i];
        final c = at(i);
        _flagCircle(canvas, flags[e.code]!, c, chip / 2);
        final name = e.label.isEmpty ? e.code.toUpperCase() : e.label;
        _text(canvas, name.toUpperCase(), ui.Offset(c.dx - w * 0.18, c.dy + chip * 0.55),
            chip * 0.26, _ink, ui.FontWeight.w700,
            maxWidth: w * 0.36, center: true);
      }
    });
  }

  // ── Word cloud (names sized by visit frequency) ──────────────────────────────

  static Future<ui.Image> _wordCloud(RenderContext ctx, List<RecipeEntry> entries,
      Map<String, ui.Image> flags, int seed) async {
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    // Largest weight first for a centred, size-varied flow.
    final words = [...entries]..sort((a, b) => b.weight.compareTo(a.weight));
    final maxW = words.first.weight.clamp(1, 1 << 20);
    // Per-word colour sampled from its flag so the cloud stays travel-themed.
    final colours = <String, ui.Color>{};
    for (final e in words) {
      colours[e.code] ??= await _dominantColour(flags[e.code]!);
    }
    return ctx.rasterise((canvas) {
      final padX = w * 0.06;
      var x = padX, y = h * 0.14;
      var rowH = 0.0;
      for (final e in words) {
        final name = (e.label.isEmpty ? e.code.toUpperCase() : e.label).toUpperCase();
        final size = (h * 0.045) + (h * 0.11) * math.sqrt(e.weight / maxW);
        final para = _para(name, size, colours[e.code]!, ui.FontWeight.w800);
        para.layout(const ui.ParagraphConstraints(width: 100000));
        final tw = para.longestLine, th = para.height;
        if (x + tw > w - padX) {
          x = padX;
          y += rowH + h * 0.015;
          rowH = 0;
        }
        canvas.drawParagraph(para, ui.Offset(x, y));
        x += tw + w * 0.03;
        rowH = math.max(rowH, th);
      }
    });
  }

  // ── shared drawing helpers ───────────────────────────────────────────────────

  static void _flagChip(ui.Canvas canvas, ui.Image img, ui.Rect rect, double radius) {
    canvas.save();
    canvas.clipRRect(ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)));
    _cover(canvas, img, rect);
    canvas.restore();
  }

  static void _flagCircle(ui.Canvas canvas, ui.Image img, ui.Offset c, double r) {
    final rect = ui.Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(rect));
    _cover(canvas, img, rect);
    canvas.restore();
    canvas.drawCircle(c, r,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = r * 0.09
          ..color = const ui.Color(0xFFFFFFFF));
  }

  static void _cover(ui.Canvas canvas, ui.Image img, ui.Rect rect) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final s = math.max(rect.width / iw, rect.height / ih);
    final dw = iw * s, dh = ih * s;
    canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, iw, ih),
        ui.Rect.fromCenter(center: rect.center, width: dw, height: dh),
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
  }

  static ui.Paragraph _para(
      String text, double size, ui.Color color, ui.FontWeight weight,
      {bool center = false}) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: size,
      fontWeight: weight,
      textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
    ))
      ..pushStyle(ui.TextStyle(color: color))
      ..addText(text);
    return b.build();
  }

  static void _text(ui.Canvas canvas, String text, ui.Offset topLeft, double size,
      ui.Color color, ui.FontWeight weight,
      {double maxWidth = 100000, bool center = false}) {
    final para = _para(text, size, color, weight, center: center);
    para.layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(para, topLeft);
  }

  static String _range(RecipeEntry e) {
    String fmt(DateTime d) => '${_months[d.month - 1]} ${d.year}';
    if (e.start == null) return '';
    if (e.end == null || fmt(e.start!) == fmt(e.end!)) return fmt(e.start!);
    return '${fmt(e.start!)} – ${fmt(e.end!)}';
  }

  /// Average colour of a flag image (a few strides), darkened slightly for text.
  static Future<ui.Color> _dominantColour(ui.Image img) async {
    final data = (await img.toByteData())?.buffer.asUint8List();
    if (data == null) return _ink;
    var r = 0, g = 0, b = 0, n = 0;
    final total = img.width * img.height;
    final step = math.max(1, total ~/ 400);
    for (var i = 0; i < total; i += step) {
      final o = i * 4;
      if (data[o + 3] < 40) continue;
      r += data[o]; g += data[o + 1]; b += data[o + 2]; n++;
    }
    if (n == 0) return _ink;
    // Darken toward ink so light flags stay legible on a light page.
    double mix(int v) => (v / n) * 0.82;
    return ui.Color.fromARGB(255, mix(r).round(), mix(g).round(), mix(b).round());
  }
}
