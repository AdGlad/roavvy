import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../asset_resolver.dart';
import '../fonts/brush_font.dart';

/// Draws [DesignRecipe.captions] over the finished artwork: a line above and
/// a line below, each fitted to its band (shrunk to the width, or wrapped onto
/// two lines when a long name would get too small), in the flag's strongest
/// colour, with optional dry-brush grit knocked out of the letters.
class CaptionsPainter {
  const CaptionsPainter._();

  static Future<ui.Image> paint(ui.Image art, DesignRecipe recipe,
      AssetResolver assets, ui.Color? background) async {
    final c = recipe.captions!;
    final w = art.width.toDouble(), h = art.height.toDouble();
    final family = await embeddedFontFamily(c.font);
    final ink = await _ink(c.colour, recipe, assets, background);
    final rng = DeterministicRng(recipe.seed).stream('captions:grit');

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(art, ui.Offset.zero, ui.Paint());
    final margin = h * 0.03;
    void band(String? text, double top, double height) {
      if (text == null || text.trim().isEmpty) return;
      final t = c.upperCase ? text.trim().toUpperCase() : text.trim();
      var rect = ui.Rect.fromLTWH(w * 0.07, top, w * 0.86, height);
      // Accented capitals (Å, Ô, Ü) rise above the line box: leave them
      // headroom so they never run into the edge of the print.
      if (t.runes.any((r) => r > 0x7F)) {
        rect = ui.Rect.fromLTRB(
            rect.left, rect.top + height * 0.22, rect.right, rect.bottom);
      }
      canvas.saveLayer(rect.inflate(height * 0.3), ui.Paint());
      _fitText(canvas, t, rect, family, ink);
      if (c.grit > 0) _grit(canvas, rect, c.grit, rng);
      canvas.restore();
    }

    band(c.top, margin, h * c.topSize);
    band(c.bottom, h - margin - h * c.bottomSize, h * c.bottomSize);
    return recorder.endRecording().toImage(art.width, art.height);
  }

  static ui.Paragraph _layout(
      String text, double size, double width, String? family, ui.Color ink, int maxLines) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: size,
      fontFamily: family,
      fontWeight: family == null ? ui.FontWeight.w800 : ui.FontWeight.w400,
      maxLines: maxLines,
      height: 1.0,
    ))
      ..pushStyle(ui.TextStyle(color: ink))
      ..addText(text);
    return b.build()..layout(ui.ParagraphConstraints(width: width));
  }

  /// One line shrunk to the width, or two lines when that would be much
  /// larger — whichever gives the bigger letters.
  static void _fitText(
      ui.Canvas canvas, String text, ui.Rect rect, String? family, ui.Color ink) {
    double oneLineSize() {
      final p = _layout(text, 100, 100000, family, ink, 1);
      final scale = math.min(rect.width / p.longestLine, rect.height / p.height);
      return 100 * scale;
    }

    var size = oneLineSize();
    var lines = 1;
    if (text.contains(' ')) {
      // Two lines: the band height split, width-limited by the longer half.
      var two = rect.height / 2;
      for (var k = 0; k < 20; k++) {
        final p = _layout(text, two, rect.width, family, ink, 2);
        if (p.height <= rect.height * 1.02 && !p.didExceedMaxLines) break;
        two *= 0.93;
      }
      if (two > size * 1.15) {
        size = two;
        lines = 2;
      }
    }
    final p = _layout(text, size, rect.width, family, ink, lines);
    canvas.drawParagraph(
        p, ui.Offset(rect.left, rect.center.dy - p.height / 2));
  }

  /// Small irregular specks knocked out of the letters (dstOut).
  static void _grit(ui.Canvas canvas, ui.Rect rect, double grit, DeterministicRng rng) {
    final cell = rect.height * 0.045;
    final count = (grit.clamp(0.0, 1.0) * rect.width * rect.height / (cell * cell) * 0.35).round();
    final paint = ui.Paint()..blendMode = ui.BlendMode.dstOut;
    for (var k = 0; k < count; k++) {
      final x = rect.left + rng.nextDouble() * rect.width;
      final y = rect.top + rng.nextDouble() * rect.height;
      final r = cell * (0.25 + 0.75 * math.pow(rng.nextDouble(), 2));
      canvas.drawOval(
          ui.Rect.fromCenter(center: ui.Offset(x, y), width: r * (1.5 + rng.nextDouble()), height: r),
          paint);
    }
  }

  static Future<ui.Color> _ink(String colour, DesignRecipe recipe,
      AssetResolver assets, ui.Color? background) async {
    // The shirt: the recipe's own garment colour when it has one (a print file
    // is rendered on transparent, so that is the only way it can know), else
    // what the artwork is drawn against.
    final shirt = _hex(recipe.palette?.garmentColour) ?? background;
    final dark = shirt == null || shirt.computeLuminance() >= 0.3;
    final legible = dark ? const ui.Color(0xFF1A1A1A) : const ui.Color(0xFFF2F2F2);
    ui.Color? chosen;
    if (colour.startsWith('#')) {
      chosen = _hex(colour);
    } else if (colour == Captions.flagColour && recipe.content.flags.isNotEmpty) {
      chosen = await _strongestFlagColour(assets, recipe.content.flags.first.code);
    }
    if (chosen == null) return legible;
    // Never ink that vanishes into the shirt (a red caption on a red tee, a
    // navy one on black): fall back to the legible tone.
    if (shirt != null && _contrast(chosen, shirt) < minContrast) return legible;
    return chosen;
  }

  /// Least WCAG contrast ratio a caption keeps against its shirt.
  static const double minContrast = 2.0;

  static double _contrast(ui.Color a, ui.Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static ui.Color? _hex(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? null : ui.Color(0xFF000000 | v);
  }

  /// The most common clearly-coloured (not white / black / grey) colour.
  static Future<ui.Color?> _strongestFlagColour(AssetResolver assets, String code) async {
    final img = await assets.resolveFlag(code, width: 96, height: 72);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = data!.buffer.asUint8List();
    final counts = <int, int>{};
    for (var i = 0; i < px.length; i += 4) {
      if (px[i + 3] < 200) continue;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
      if (mx < 40 || mx - mn < 60) continue; // black, white, grey
      final key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final key = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return ui.Color.fromARGB(255, ((key >> 8) & 0xF) * 17 + 8,
        ((key >> 4) & 0xF) * 17 + 8, (key & 0xF) * 17 + 8);
  }
}
