import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Realistic typography for passport stamps (ADR-097 Decision 7).
///
/// Country names and labels use the system sans-serif (null fontFamily) —
/// this gives the bold condensed look of real stamp typefaces.
/// Dates and serial numbers use Courier New for the monospaced feel.
///
/// Letter-spacing is positive for large text (authentic wide-tracked stamp
/// look) and near-zero for small sublabels.
///
/// All effects are deterministic from [seed]. No external packages.
class StampTypographyPainter {
  StampTypographyPainter._();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Draw a condensed label centred at [offset].
  ///
  /// [seed] drives baseline jitter and ink-break character selection.
  static void drawCondensedLabel(
    Canvas canvas,
    String text,
    Color color,
    double fontSize,
    Offset offset,
    int seed, {
    FontWeight weight = FontWeight.bold,
  }) {
    if (text.isEmpty) return;
    final rng = math.Random(seed ^ 0xA1A1);

    // Select 1–2 characters for ink break (60% opacity)
    final breakIndices = _inkBreakIndices(text, rng);

    _drawCharsByChar(
      canvas,
      text,
      color,
      fontSize,
      offset,
      seed,
      weight: weight,
      letterSpacingFactor: _letterSpacingFor(fontSize),
      breakIndices: breakIndices,
      baselineJitter: true,
    );
  }

  /// Draw a date string in monospaced style centred at [offset].
  ///
  /// Characters are drawn with a fixed advance width for authentic stamp look.
  static void drawMonoDate(
    Canvas canvas,
    String date,
    Color color,
    double fontSize,
    Offset offset,
  ) {
    if (date.isEmpty) return;
    final charWidth = fontSize * 0.65;
    final totalWidth = charWidth * date.length;
    final startX = offset.dx - totalWidth / 2;

    for (var i = 0; i < date.length; i++) {
      final char = date[i];
      final tp = _buildSpan(char, color, fontSize,
          fontWeight: FontWeight.w600, letterSpacing: 0, monospace: true);
      tp.layout();
      final x = startX + i * charWidth + charWidth / 2 - tp.width / 2;
      tp.paint(canvas, Offset(x, offset.dy - tp.height / 2));
    }
  }

  /// Draw a sublabel (ARRIVAL / DEPARTURE / IMMIGRATION) centred at [offset].
  ///
  /// Slightly reduced opacity, wide letter-spacing for the classic stamp feel.
  static void drawSublabel(
    Canvas canvas,
    String label,
    Color color,
    double fontSize,
    Offset offset,
  ) {
    if (label.isEmpty) return;
    final faded = color.withValues(alpha: color.a * 0.82);
    final tp = _buildSpan(
      label,
      faded,
      fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    tp.layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }

  /// Draw the country name as dominant hero text (w900, wide tracking).
  ///
  /// Font size auto-scales down to keep the text within [maxWidth] if provided.
  /// Long names are truncated to 11 characters before scaling.
  static void drawHeroText(
    Canvas canvas,
    String text,
    Color color,
    double fontSize,
    Offset offset,
    int seed, {
    double? maxWidth,
  }) {
    if (text.isEmpty) return;
    final display =
        text.length > 11 ? text.substring(0, 11).trim() : text;

    // Auto-shrink font until text fits within maxWidth
    var size = fontSize;
    if (maxWidth != null) {
      while (size > fontSize * 0.45) {
        final tp = _buildSpan(display, color, size,
            fontWeight: FontWeight.w900,
            letterSpacing: _heroSpacingFor(size));
        tp.layout();
        if (tp.width <= maxWidth) break;
        size -= 0.5;
      }
    }

    final tp = _buildSpan(display, color, size,
        fontWeight: FontWeight.w900, letterSpacing: _heroSpacingFor(size));
    tp.layout();
    final rng = math.Random(seed ^ 0xC3C3);
    final jitter = (rng.nextDouble() * 2 - 1) * 0.4;
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2 + jitter));
  }

  /// Draw a pseudo serial number in small spaced monospace text centred at [offset].
  ///
  /// Rendered at 55% opacity so it reads as a secondary element.
  static void drawSerialNumber(
    Canvas canvas,
    String serial,
    Color color,
    double fontSize,
    Offset offset,
  ) {
    if (serial.isEmpty) return;
    final faded = color.withValues(alpha: color.a * 0.55);
    final tp = _buildSpan(serial, faded, fontSize,
        fontWeight: FontWeight.normal, letterSpacing: 1.5, monospace: true);
    tp.layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }

  /// Draw text arced along a circle of [radius] centred at [center].
  ///
  /// [startAngle] positions the midpoint of the text arc (radians, 0 = right,
  /// −π/2 = top). Each character is individually transformed.
  static void drawArcText(
    Canvas canvas,
    String text,
    Color color,
    double fontSize,
    Offset center,
    double radius,
    double startAngle,
  ) {
    if (text.isEmpty) return;

    final charAngle = (fontSize * 1.1) / radius;
    final totalAngle = charAngle * text.length;
    var angle = startAngle - totalAngle / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    for (var i = 0; i < text.length; i++) {
      final tp = _buildSpan(
        text[i],
        color,
        fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      );
      tp.layout();

      canvas.save();
      canvas.rotate(angle + charAngle / 2);
      canvas.translate(-tp.width / 2, -radius);
      tp.paint(canvas, Offset.zero);
      canvas.restore();

      angle += charAngle;
    }

    canvas.restore();
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Positive letter-spacing for large hero text — wide-tracked stamp look.
  static double _heroSpacingFor(double fontSize) {
    if (fontSize >= 12) return 2.5;
    if (fontSize >= 9) return 2.0;
    return 1.5;
  }

  static double _letterSpacingFor(double fontSize) {
    if (fontSize >= 10) return 1.5;
    if (fontSize >= 7) return 0.8;
    return 0.2;
  }

  static Set<int> _inkBreakIndices(String text, math.Random rng) {
    if (text.length <= 1) return const {};
    final count = rng.nextDouble() < 0.5 ? 1 : 2;
    final indices = <int>{};
    for (var i = 0; i < count * 3 && indices.length < count; i++) {
      indices.add(rng.nextInt(text.length));
    }
    return indices;
  }

  static void _drawCharsByChar(
    Canvas canvas,
    String text,
    Color color,
    double fontSize,
    Offset centreOffset,
    int seed, {
    required FontWeight weight,
    required double letterSpacingFactor,
    required Set<int> breakIndices,
    required bool baselineJitter,
  }) {
    final rng = math.Random(seed ^ 0xB2B2);

    final measureTp = _buildSpan(
      text,
      color,
      fontSize,
      fontWeight: weight,
      letterSpacing: letterSpacingFactor,
    );
    measureTp.layout();
    final totalWidth = measureTp.width;

    var x = centreOffset.dx - totalWidth / 2;

    for (var i = 0; i < text.length; i++) {
      final isBreak = breakIndices.contains(i);
      final charColor =
          isBreak ? color.withValues(alpha: color.a * 0.60) : color;

      final jitter =
          baselineJitter ? (rng.nextDouble() * 2 - 1) * 0.5 : 0.0;

      final tp = _buildSpan(
        text[i],
        charColor,
        fontSize,
        fontWeight: weight,
        letterSpacing: letterSpacingFactor,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(x, centreOffset.dy - tp.height / 2 + jitter),
      );
      x += tp.width;
    }
  }

  static TextPainter _buildSpan(
    String text,
    Color color,
    double fontSize, {
    required FontWeight fontWeight,
    required double letterSpacing,
    bool monospace = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          // System sans-serif for stamp labels; Courier New for dates/serials
          fontFamily: monospace ? 'Courier New' : null,
          letterSpacing: letterSpacing,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
  }
}
