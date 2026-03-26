import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'passport_stamp_model.dart';
import 'stamp_noise_generator.dart';
import 'stamp_shape_distorter.dart';
import 'stamp_typography_painter.dart';

/// CustomPainter that draws a single passport stamp onto the canvas.
///
/// Each stamp is rendered into an offscreen [ui.PictureRecorder] canvas, then
/// composited onto the main canvas at [StampData.center] + [StampData.rotation].
///
/// Pipeline per stamp (ADR-097 Decision 10):
/// 1. [ui.PictureRecorder] offscreen canvas
/// 2. Dispatch to one of 15 style renderers
/// 3. [StampNoiseGenerator.applyNoiseMask] — ink-wear opacity mask
/// 4. Age opacity applied via [Paint.color] alpha at composite time
/// 5. [ui.Canvas.drawPicture] onto main canvas at position/rotation
class StampPainter extends CustomPainter {
  const StampPainter(this.stamp);

  final StampData stamp;

  @override
  void paint(Canvas canvas, Size size) {
    final center = stamp.center;
    final baseRadius = 38.0 * stamp.scale;

    // Build offscreen canvas sized to stamp bounding box
    final stampW = baseRadius * 2.8;
    final stampH = baseRadius * 2.8;
    final bounds = Rect.fromLTWH(0, 0, stampW, stampH);
    final localCenter = Offset(stampW / 2, stampH / 2);

    final recorder = ui.PictureRecorder();
    final offscreen = Canvas(recorder);

    // Apply ink bleed to stroke paints (MaskFilter.blur)
    final bleedSigma = stamp.renderConfig.enableNoise
        ? StampNoiseGenerator.bleedSigma(stamp.seed)
        : 0.0;

    final color = stamp.inkColor;

    // Draw geometry on offscreen canvas
    switch (stamp.style) {
      case StampStyle.airportEntry:
        _drawAirportEntry(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.airportExit:
        _drawAirportExit(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.landBorder:
        _drawLandBorder(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.visaApproval:
        _drawVisaApproval(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.transit:
        _drawTransit(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.vintage:
        _drawVintage(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.modernSans:
        _drawModernSans(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.triangle:
        _drawTriangle(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.hexBadge:
        _drawHexBadge(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.dottedCircle:
        _drawDottedCircle(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.multiRing:
        _drawMultiRing(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.blockText:
        _drawBlockText(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.oval:
        _drawOval(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.diamond:
        _drawDiamond(offscreen, color, baseRadius, localCenter, bleedSigma);
      case StampStyle.octagon:
        _drawOctagon(offscreen, color, baseRadius, localCenter, bleedSigma);
    }

    // Apply noise mask to offscreen canvas
    if (stamp.renderConfig.enableNoise) {
      StampNoiseGenerator.applyNoiseMask(
        offscreen,
        bounds,
        stamp.seed,
        intensity: stamp.ageEffect.noiseIntensity,
      );
    }

    final picture = recorder.endRecording();

    // Composite onto main canvas at stamp center + rotation
    final ageOpacity =
        stamp.renderConfig.enableAging ? stamp.ageEffect.opacity : 0.90;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(stamp.rotation);
    canvas.translate(-stampW / 2, -stampH / 2);
    // Apply age opacity via saveLayer alpha when < 1.0
    final needsAlphaLayer = ageOpacity < 0.999;
    if (needsAlphaLayer) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Color.fromARGB((ageOpacity * 255).round(), 255, 255, 255),
      );
    }
    canvas.drawPicture(picture);
    if (needsAlphaLayer) {
      canvas.restore();
    }
    canvas.restore();

    picture.dispose();
  }

  // ── Style renderers ──────────────────────────────────────────────────────────

  void _drawAirportEntry(Canvas c, Color color, double r, Offset o, double bleed) {
    _doubleCircle(c, color, r, o, bleed);
    // Takeoff: plane angled up-right
    _drawAirplane(c, color, r * 0.38, o, -math.pi / 6);
    // Airport code arced along the top ring
    StampTypographyPainter.drawArcText(
        c, stamp.airportCode, color, 5.0 * stamp.scale, o, r * 0.87,
        -math.pi / 2);
    // Serial number arced along the bottom ring
    StampTypographyPainter.drawArcText(
        c,
        stamp.serialCode,
        color.withValues(alpha: color.a * 0.55),
        3.5 * stamp.scale,
        o,
        r * 0.87,
        math.pi / 2);
    _stampLabels(c, color, r, o, sublabel: 'IMMIGRATION');
  }

  void _drawAirportExit(Canvas c, Color color, double r, Offset o, double bleed) {
    _singleCircle(c, color, r, o, bleed);
    // Landing: plane angled down-left (mirrored)
    _drawAirplane(c, color, r * 0.38, o, math.pi / 6);
    // Airport code arced along the top
    StampTypographyPainter.drawArcText(
        c, stamp.airportCode, color, 5.0 * stamp.scale, o, r * 0.87,
        -math.pi / 2);
    _stampLabels(c, color, r, o, sublabel: 'DEPARTURE');
  }

  void _drawLandBorder(Canvas c, Color color, double r, Offset o, double bleed) {
    final w = r * 2.2;
    final h = r * 1.5;
    final rect = Rect.fromCenter(center: o, width: w, height: h);
    final rrect = StampShapeDistorter.distortedRect(rect, 4.0, stamp.seed);
    c.drawRRect(rrect, _strokePaint(color, 2.5, bleed));
    _maybePlaneDecoration(c, color, r * 0.65, o);
    _stampLabels(c, color, r * 0.65, o, textMaxWidth: r * 2.0);
  }

  void _drawVisaApproval(Canvas c, Color color, double r, Offset o, double bleed) {
    final w = r * 2.0;
    final h = r * 1.4;
    final outer = Rect.fromCenter(center: o, width: w, height: h);
    final inner = Rect.fromCenter(center: o, width: w - 6, height: h - 6);
    c.drawRect(outer, _strokePaint(color, 2.5, bleed));
    c.drawRect(inner, _strokePaint(color, 1.0, bleed));
    StampTypographyPainter.drawSublabel(
        c, 'APPROVED', color, 5.0 * stamp.scale, o - Offset(0, h * 0.3));
    _maybePlaneDecoration(c, color, r * 0.65, o);
    _stampLabels(c, color, r * 0.65, o);
  }

  void _drawTransit(Canvas c, Color color, double r, Offset o, double bleed) {
    _singleCircle(c, color, r, o, bleed, strokeWidth: 1.5);
    final hasIcon =
        _drawCountryIcon(c, color, r * 0.42, o - Offset(0, r * 0.20));
    final innerR = r * (hasIcon ? 0.55 : 0.72);
    StampTypographyPainter.drawHeroText(
        c,
        stamp.countryName.isNotEmpty
            ? stamp.countryName.toUpperCase()
            : stamp.countryCode,
        color,
        innerR * 0.55,
        o + Offset(0, hasIcon ? r * 0.30 : -r * 0.10),
        stamp.seed,
        maxWidth: r * 1.72);
    if (stamp.dateLabel != null) {
      StampTypographyPainter.drawMonoDate(
          c, stamp.dateLabel!, color, 5.0 * stamp.scale,
          o + Offset(0, r * 0.60));
    }
    StampTypographyPainter.drawCondensedLabel(
        c, stamp.entryLabel, color, 5.5 * stamp.scale,
        o + Offset(0, hasIcon ? r * 0.74 : r * 0.52), stamp.seed ^ 0xFF,
        weight: FontWeight.bold);
  }

  void _drawVintage(Canvas c, Color color, double r, Offset o, double bleed) {
    c.drawCircle(o, r, _strokePaint(color, 4.0, bleed));
    // Cross-hatch ring: 12 radial segments
    final segPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 12; i++) {
      final angle = 2 * math.pi * i / 12;
      c.drawLine(
        o + Offset(math.cos(angle) * r * 0.70, math.sin(angle) * r * 0.70),
        o + Offset(math.cos(angle) * r * 0.88, math.sin(angle) * r * 0.88),
        segPaint,
      );
    }
    // Airport code arced at top inside the ring
    StampTypographyPainter.drawArcText(
        c, stamp.airportCode, color, 5.5 * stamp.scale, o, r * 0.58,
        -math.pi / 2);
    _stampLabels(c, color, r * 0.60, o, sublabel: 'VISA');
  }

  void _drawModernSans(Canvas c, Color color, double r, Offset o, double bleed) {
    final w = r * 2.4;
    final h = r * 1.5;
    final rect = Rect.fromCenter(center: o, width: w, height: h);
    final rrect = StampShapeDistorter.distortedRect(rect, h * 0.48, stamp.seed);
    c.drawRRect(rrect, _strokePaint(color, 2.0, bleed));
    _maybePlaneDecoration(c, color, r * 0.65, o);
    _stampLabels(c, color, r * 0.65, o, textMaxWidth: r * 2.2);
  }

  void _drawTriangle(Canvas c, Color color, double r, Offset o, double bleed) {
    final path = StampShapeDistorter.distortedPolygon([
      Offset(o.dx, o.dy - r * 1.05),
      Offset(o.dx + r * 1.2, o.dy + r * 0.65),
      Offset(o.dx - r * 1.2, o.dy + r * 0.65),
    ], stamp.seed, r * 0.022);
    c.drawPath(path, _strokePaint(color, 2.0, bleed));
    StampTypographyPainter.drawHeroText(
        c,
        stamp.countryName.isNotEmpty
            ? stamp.countryName.toUpperCase()
            : stamp.countryCode,
        color,
        r * 0.38,
        o + Offset(0, r * 0.18),
        stamp.seed,
        maxWidth: r * 2.0);
    if (stamp.dateLabel != null) {
      StampTypographyPainter.drawMonoDate(
          c, stamp.dateLabel!, color, 5.0 * stamp.scale,
          o - Offset(0, r * 0.24));
    }
    StampTypographyPainter.drawCondensedLabel(
        c, stamp.entryLabel, color, 5.5 * stamp.scale,
        o + Offset(0, r * 0.52), stamp.seed ^ 0xFF,
        weight: FontWeight.bold);
  }

  void _drawHexBadge(Canvas c, Color color, double r, Offset o, double bleed) {
    final vertices = [
      for (var i = 0; i < 6; i++)
        Offset(o.dx + r * math.cos(math.pi / 6 + i * math.pi / 3),
            o.dy + r * math.sin(math.pi / 6 + i * math.pi / 3)),
    ];
    c.drawPath(StampShapeDistorter.distortedPolygon(vertices, stamp.seed, r * 0.020),
        _strokePaint(color, 2.0, bleed));
    _stampLabels(c, color, r * 0.60, o);
  }

  void _drawDottedCircle(Canvas c, Color color, double r, Offset o, double bleed) {
    const arcCount = 36;
    final paint = _strokePaint(color, 2.0, bleed)
      ..strokeCap = StrokeCap.round;
    const gapFraction = 0.35;
    for (var i = 0; i < arcCount; i++) {
      final startAngle = 2 * math.pi * i / arcCount;
      final sweepAngle = 2 * math.pi / arcCount * (1 - gapFraction);
      c.drawArc(
        Rect.fromCircle(center: o, radius: r),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
    // Serial number arced at bottom
    StampTypographyPainter.drawArcText(
        c,
        stamp.serialCode,
        color.withValues(alpha: color.a * 0.55),
        3.5 * stamp.scale,
        o,
        r * 0.88,
        math.pi / 2);
    _stampLabels(c, color, r * 0.72, o);
  }

  void _drawMultiRing(Canvas c, Color color, double r, Offset o, double bleed) {
    // Two concentric rings only
    c.drawCircle(o, r, _strokePaint(color, 2.5, bleed));
    c.drawCircle(o, r * 0.72, _strokePaint(color, 1.2, bleed));
    // Airport code arced at top between outer and middle rings
    StampTypographyPainter.drawArcText(
        c, stamp.airportCode, color, 5.0 * stamp.scale, o, r * 0.90,
        -math.pi / 2);
    _stampLabels(c, color, r * 0.48, o);
  }

  void _drawBlockText(Canvas c, Color color, double r, Offset o, double bleed) {
    final w = r * 2.4;
    final h = r * 1.3;
    c.drawRect(
      Rect.fromCenter(center: o, width: w, height: h),
      _strokePaint(color, 2.0, bleed),
    );
    _maybePlaneDecoration(c, color, r * 0.60, o);
    StampTypographyPainter.drawHeroText(
        c,
        stamp.countryName.isNotEmpty
            ? stamp.countryName.toUpperCase()
            : stamp.countryCode,
        color,
        h * 0.42,
        o - Offset(0, h * 0.12),
        stamp.seed,
        maxWidth: w * 0.90);
    if (stamp.dateLabel != null) {
      StampTypographyPainter.drawMonoDate(
          c, stamp.dateLabel!, color, 4.5 * stamp.scale,
          o + Offset(0, h * 0.20));
    }
    StampTypographyPainter.drawCondensedLabel(
        c, stamp.entryLabel, color, 5.5 * stamp.scale,
        o + Offset(0, h * 0.38), stamp.seed ^ 0xFF,
        weight: FontWeight.bold);
  }

  void _drawOval(Canvas c, Color color, double r, Offset o, double bleed) {
    final rx = r * 1.15;
    final ry = r * 0.82;
    c.drawPath(_ovalPath(o, rx, ry, stamp.seed), _strokePaint(color, 2.0, bleed));
    c.drawPath(
        _ovalPath(o, rx - 5, ry - 5, stamp.seed ^ 0x33),
        _strokePaint(color, 1.0, bleed));
    _maybePlaneDecoration(c, color, ry * 0.85, o);
    _stampLabels(c, color, ry * 0.85, o);
  }

  Path _ovalPath(Offset center, double rx, double ry, int seed) {
    final rng = math.Random(seed ^ 0xE0E0);
    const pts = 64;
    final path = Path();
    for (var i = 0; i < pts; i++) {
      final angle = 2 * math.pi * i / pts;
      final jitter = (rng.nextDouble() * 2 - 1) * 0.018;
      final x = center.dx + rx * (1 + jitter) * math.cos(angle);
      final y = center.dy + ry * (1 + jitter) * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawDiamond(Canvas c, Color color, double r, Offset o, double bleed) {
    final outer = StampShapeDistorter.distortedPolygon([
      Offset(o.dx, o.dy - r * 1.2),
      Offset(o.dx + r * 0.85, o.dy),
      Offset(o.dx, o.dy + r * 1.2),
      Offset(o.dx - r * 0.85, o.dy),
    ], stamp.seed, r * 0.022);
    c.drawPath(outer, _strokePaint(color, 2.0, bleed));
    final inner = StampShapeDistorter.distortedPolygon([
      Offset(o.dx, o.dy - r * 0.90),
      Offset(o.dx + r * 0.63, o.dy),
      Offset(o.dx, o.dy + r * 0.90),
      Offset(o.dx - r * 0.63, o.dy),
    ], stamp.seed ^ 0x22, r * 0.018);
    c.drawPath(inner, _strokePaint(color, 1.0, bleed));
    _stampLabels(c, color, r * 0.58, o);
  }

  void _drawOctagon(Canvas c, Color color, double r, Offset o, double bleed) {
    final vertices = [
      for (var i = 0; i < 8; i++)
        Offset(o.dx + r * math.cos(math.pi / 8 + i * math.pi / 4),
            o.dy + r * math.sin(math.pi / 8 + i * math.pi / 4)),
    ];
    c.drawPath(StampShapeDistorter.distortedPolygon(vertices, stamp.seed, r * 0.020),
        _strokePaint(color, 2.0, bleed));
    _stampLabels(c, color, r * 0.60, o);
  }

  // ── Shared geometry helpers ─────────────────────────────────────────────────

  void _doubleCircle(Canvas c, Color color, double r, Offset o, double bleed) {
    c.drawCircle(o, r, _strokePaint(color, 2.5, bleed));
    c.drawCircle(o, r * 0.75, _strokePaint(color, 1.0, bleed));
  }

  void _singleCircle(Canvas c, Color color, double r, Offset o, double bleed,
      {double strokeWidth = 2.0}) {
    c.drawCircle(o, r, _strokePaint(color, strokeWidth, bleed));
  }

  /// Draws a top-down airplane silhouette centred at [center].
  ///
  /// Nose points in the direction of [angle] (0 = up, positive = clockwise).
  /// [opacity] is applied on top of [color]'s existing alpha.
  void _drawAirplane(
      Canvas c, Color color, double size, Offset center, double angle,
      {double opacity = 0.48}) {
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..style = PaintingStyle.fill;

    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);

    // Fuselage
    c.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: size * 0.20, height: size * 0.90),
        paint);

    // Main wings (swept back)
    c.drawPath(
        Path()
          ..moveTo(0, -size * 0.05)
          ..lineTo(-size * 0.78, size * 0.28)
          ..lineTo(-size * 0.56, size * 0.40)
          ..lineTo(0, size * 0.20)
          ..lineTo(size * 0.56, size * 0.40)
          ..lineTo(size * 0.78, size * 0.28)
          ..close(),
        paint);

    // Tail fins
    c.drawPath(
        Path()
          ..moveTo(0, size * 0.40)
          ..lineTo(-size * 0.30, size * 0.55)
          ..lineTo(size * 0.30, size * 0.55)
          ..close(),
        paint);

    c.restore();
  }

  /// Adds a small airplane to 25% of rectangular/polygon stamps.
  ///
  /// Takeoff angle for ENTRY stamps, banking angle for EXIT stamps.
  void _maybePlaneDecoration(Canvas c, Color color, double r, Offset o) {
    if (stamp.seed % 4 != 0) return;
    final angle = stamp.isEntry ? -math.pi / 5 : math.pi / 5;
    _drawAirplane(c, color, r * 0.22,
        o - Offset(r * 0.52, r * 0.52), angle,
        opacity: 0.30);
  }

  void _stampLabels(
    Canvas c,
    Color color,
    double r,
    Offset o, {
    String? sublabel,
    double? textMaxWidth,
  }) {
    // Country icon: semi-transparent watermark drawn before text
    _drawCountryIcon(c, color, r * 0.40, o + Offset(0, r * 0.08));

    if (sublabel != null) {
      StampTypographyPainter.drawSublabel(
          c, sublabel, color, 4.5 * stamp.scale, o - Offset(0, r * 0.68));
    }

    // Start hero text large and let drawHeroText auto-shrink for long names.
    // textMaxWidth defaults to inner diameter; callers may pass a wider value
    // for rectangular stamps where the usable width exceeds the inner radius.
    final maxWidth = textMaxWidth ?? r * 1.80;
    StampTypographyPainter.drawHeroText(
        c,
        stamp.countryName.isNotEmpty
            ? stamp.countryName.toUpperCase()
            : stamp.countryCode,
        color,
        r * 0.55,
        o - Offset(0, r * 0.26),
        stamp.seed,
        maxWidth: maxWidth);

    if (stamp.dateLabel != null) {
      StampTypographyPainter.drawMonoDate(
          c, stamp.dateLabel!, color, 5.5 * stamp.scale,
          o + Offset(0, r * 0.14));
    }
    StampTypographyPainter.drawCondensedLabel(
        c, stamp.entryLabel, color, 6.0 * stamp.scale,
        o + Offset(0, r * 0.40), stamp.seed ^ 0xFF,
        weight: FontWeight.bold);
  }

  // ── Country icon helpers ─────────────────────────────────────────────────────

  /// Draws a country-specific icon centred at [center] with radius [iconSize].
  ///
  /// Returns true if an icon was drawn. Icons are filled at 28% opacity so
  /// they read as watermarks beneath the stamp text.
  bool _drawCountryIcon(Canvas c, Color color, double iconSize, Offset center) {
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * 0.28)
      ..style = PaintingStyle.fill;

    switch (stamp.countryCode) {
      case 'JP':
        // Rising sun — solid circle
        c.drawCircle(center, iconSize * 0.65, paint);
        return true;
      case 'CA':
        c.drawPath(_mapleLeafPath(center, iconSize), paint);
        return true;
      case 'US' || 'DE' || 'MX':
        // Heraldic spread-eagle
        c.drawPath(_eaglePath(center, iconSize * 0.82), paint);
        return true;
      case 'ES':
        // Osborne bull silhouette
        c.drawPath(_bullPath(center, iconSize * 0.72), paint);
        return true;
      case 'FR' || 'BE':
        // Fleur-de-lis
        _drawFleurDeLis(c, paint, center, iconSize * 0.55);
        return true;
      case 'IN':
        // Lotus flower
        _drawLotus(c, paint, center, iconSize * 0.58);
        return true;
      case 'AU' || 'NZ':
        // Southern Cross constellation
        _drawSouthernCross(c, paint, center, iconSize * 0.68);
        return true;
      case 'NL':
        // Tulip
        _drawTulip(c, paint, center, iconSize * 0.58);
        return true;
      case 'CH' || 'DK' || 'NO' || 'SE' || 'FI':
        // Equal-armed cross
        final arm = iconSize * 0.32;
        c.drawRect(
            Rect.fromCenter(
                center: center, width: arm, height: iconSize * 1.8),
            paint);
        c.drawRect(
            Rect.fromCenter(
                center: center, width: iconSize * 1.8, height: arm),
            paint);
        return true;
      case 'GB':
        c.drawPath(_crownPath(center, iconSize * 0.75), paint);
        return true;
      case 'CN' || 'SG' || 'BR':
        c.drawPath(_star5Path(center, iconSize * 0.78), paint);
        return true;
      default:
        return false;
    }
  }

  // ── Icon path helpers ───────────────────────────────────────────────────────

  /// 5-pointed star with outer radius [size].
  Path _star5Path(Offset center, double size) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? size : size * 0.38;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Heraldic spread-eagle: two wing triangles + narrow body.
  Path _eaglePath(Offset o, double s) {
    return Path()
      // Left wing
      ..moveTo(o.dx - s * 0.05, o.dy - s * 0.05)
      ..lineTo(o.dx - s, o.dy - s * 0.48)
      ..lineTo(o.dx - s * 0.38, o.dy + s * 0.28)
      ..close()
      // Right wing
      ..moveTo(o.dx + s * 0.05, o.dy - s * 0.05)
      ..lineTo(o.dx + s, o.dy - s * 0.48)
      ..lineTo(o.dx + s * 0.38, o.dy + s * 0.28)
      ..close()
      // Body (narrow oval)
      ..addOval(Rect.fromCenter(
          center: o + Offset(0, s * 0.22), width: s * 0.28, height: s * 0.56));
  }

  /// Simplified Osborne-style bull: body + head + horns.
  Path _bullPath(Offset o, double s) {
    return Path()
      // Body
      ..addOval(Rect.fromCenter(
          center: o + Offset(-s * 0.10, s * 0.15),
          width: s * 1.30,
          height: s * 0.60))
      // Head
      ..addOval(Rect.fromCenter(
          center: o + Offset(s * 0.58, -s * 0.06),
          width: s * 0.40,
          height: s * 0.35))
      // Left horn
      ..moveTo(o.dx + s * 0.42, o.dy - s * 0.18)
      ..lineTo(o.dx + s * 0.30, o.dy - s * 0.52)
      ..lineTo(o.dx + s * 0.52, o.dy - s * 0.24)
      ..close()
      // Right horn
      ..moveTo(o.dx + s * 0.66, o.dy - s * 0.18)
      ..lineTo(o.dx + s * 0.76, o.dy - s * 0.50)
      ..lineTo(o.dx + s * 0.76, o.dy - s * 0.24)
      ..close();
  }

  /// Simple 3-prong crown.
  Path _crownPath(Offset o, double s) {
    return Path()
      ..moveTo(o.dx - s, o.dy + s * 0.35)
      ..lineTo(o.dx - s, o.dy - s * 0.05)
      ..lineTo(o.dx - s * 0.52, o.dy - s * 0.52)
      ..lineTo(o.dx - s * 0.32, o.dy - s * 0.08)
      ..lineTo(o.dx, o.dy - s * 0.72)
      ..lineTo(o.dx + s * 0.32, o.dy - s * 0.08)
      ..lineTo(o.dx + s * 0.52, o.dy - s * 0.52)
      ..lineTo(o.dx + s, o.dy - s * 0.05)
      ..lineTo(o.dx + s, o.dy + s * 0.35)
      ..close();
  }

  /// 11-lobe maple leaf.
  Path _mapleLeafPath(Offset o, double s) {
    const pts = <List<double>>[
      [0.0, -0.95],
      [0.10, -0.60], [0.22, -0.75], [0.15, -0.45],
      [0.55, -0.52], [0.32, -0.12],
      [0.68, 0.07], [0.38, 0.06],
      [0.25, 0.35], [0.15, 0.14],
      [0.10, 0.58], [0.05, 0.58], [0.05, 0.95],
      [-0.05, 0.95], [-0.05, 0.58], [-0.10, 0.58],
      [-0.15, 0.14], [-0.25, 0.35],
      [-0.38, 0.06], [-0.68, 0.07],
      [-0.32, -0.12], [-0.55, -0.52],
      [-0.15, -0.45], [-0.22, -0.75], [-0.10, -0.60],
    ];
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = o.dx + pts[i][0] * s;
      final y = o.dy + pts[i][1] * s;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Fleur-de-lis: 3 oval lobes + horizontal band + stem.
  void _drawFleurDeLis(Canvas c, Paint p, Offset o, double s) {
    c.drawOval(Rect.fromCenter(
        center: o - Offset(0, s * 0.25), width: s * 0.44, height: s * 0.70), p);
    c.drawOval(Rect.fromCenter(
        center: o - Offset(s * 0.38, s * 0.08), width: s * 0.36, height: s * 0.58), p);
    c.drawOval(Rect.fromCenter(
        center: o + Offset(s * 0.38, -s * 0.08), width: s * 0.36, height: s * 0.58), p);
    c.drawRect(
        Rect.fromCenter(
            center: o + Offset(0, s * 0.22), width: s * 1.05, height: s * 0.14),
        p);
    c.drawOval(Rect.fromCenter(
        center: o + Offset(0, s * 0.62), width: s * 0.20, height: s * 0.42), p);
  }

  /// 8-petal lotus flower.
  void _drawLotus(Canvas c, Paint p, Offset o, double s) {
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(angle);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(0, -s * 0.42), width: s * 0.26, height: s * 0.52),
          p);
      c.restore();
    }
    c.drawCircle(o, s * 0.15, p);
  }

  /// Southern Cross: 5 stars in constellation pattern.
  void _drawSouthernCross(Canvas c, Paint p, Offset o, double s) {
    final positions = [
      Offset(0.0, -s * 0.55),
      Offset(-s * 0.32, -s * 0.10),
      Offset(s * 0.28, s * 0.08),
      Offset(-s * 0.12, s * 0.40),
      Offset(s * 0.18, s * 0.52),
    ];
    final sizes = [s * 0.27, s * 0.22, s * 0.22, s * 0.22, s * 0.15];
    for (var i = 0; i < 5; i++) {
      c.drawPath(_star5Path(o + positions[i], sizes[i]), p);
    }
  }

  /// Tulip: 3 petals + stem + leaf.
  void _drawTulip(Canvas c, Paint p, Offset o, double s) {
    c.drawOval(Rect.fromCenter(
        center: o - Offset(s * 0.22, s * 0.15), width: s * 0.32, height: s * 0.62), p);
    c.drawOval(Rect.fromCenter(
        center: o - Offset(0, s * 0.20), width: s * 0.32, height: s * 0.68), p);
    c.drawOval(Rect.fromCenter(
        center: o + Offset(s * 0.22, -s * 0.15), width: s * 0.32, height: s * 0.62), p);
    c.drawRect(
        Rect.fromCenter(
            center: o + Offset(0, s * 0.55), width: s * 0.10, height: s * 0.40),
        p);
    c.drawOval(Rect.fromCenter(
        center: o + Offset(s * 0.18, s * 0.50), width: s * 0.28, height: s * 0.16), p);
  }

  Paint _strokePaint(Color color, double width, double bleedSigma) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (bleedSigma > 0) {
      p.maskFilter = MaskFilter.blur(BlurStyle.normal, bleedSigma * 0.4);
    }
    return p;
  }

  @override
  bool shouldRepaint(StampPainter oldDelegate) => oldDelegate.stamp != stamp;
}
