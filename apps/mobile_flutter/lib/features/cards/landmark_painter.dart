import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Procedural landmark silhouettes for Roavvy's Landmark card type.
///
/// Each landmark is drawn as a single-colour vector shape using Flutter's
/// Canvas API — no asset files required. The style is deliberately simplified
/// (bold monochrome silhouette) so artwork prints cleanly on both light and
/// dark shirts.
///
/// Coordinate convention: every function receives [w] and [h] (destination
/// dimensions) and plots coordinates in `[0, w] × [0, h]` space. The origin
/// is the top-left corner of the destination rect. Callers are expected to
/// have called `canvas.translate(dst.left, dst.top)` before calling any draw
/// function, and `canvas.restore()` afterwards.
abstract final class LandmarkShapePainter {
  /// Draws the canonical landmark silhouette for [isoCode] onto [canvas].
  ///
  /// [paint] should have `style = PaintingStyle.fill` and the desired colour.
  /// Returns `true` if a landmark was drawn, `false` when no shape is defined
  /// for [isoCode] (caller may render a fallback).
  static bool draw(
    Canvas canvas,
    double w,
    double h,
    String isoCode,
    Paint paint,
  ) {
    switch (isoCode.toUpperCase()) {
      case 'FR': _eiffelTower(canvas, w, h, paint); return true;
      case 'GB': _bigBen(canvas, w, h, paint); return true;
      case 'IT': _colosseum(canvas, w, h, paint); return true;
      case 'US': _statuOfLiberty(canvas, w, h, paint); return true;
      case 'EG': _pyramids(canvas, w, h, paint); return true;
      case 'IN': _tajMahal(canvas, w, h, paint); return true;
      case 'JP': _toriiGate(canvas, w, h, paint); return true;
      case 'CN': _greatWall(canvas, w, h, paint); return true;
      case 'AU': _operaHouse(canvas, w, h, paint); return true;
      case 'BR': _christRedeemer(canvas, w, h, paint); return true;
      case 'GR': _parthenon(canvas, w, h, paint); return true;
      case 'RU': _stBasils(canvas, w, h, paint); return true;
      case 'ES': _sagradaFamilia(canvas, w, h, paint); return true;
      case 'DE': _brandenburgGate(canvas, w, h, paint); return true;
      case 'NL': _windmill(canvas, w, h, paint); return true;
      case 'PE': _machupicchu(canvas, w, h, paint); return true;
      case 'MX': _chichenItza(canvas, w, h, paint); return true;
      case 'CA': _cnTower(canvas, w, h, paint); return true;
      case 'JO': _petra(canvas, w, h, paint); return true;
      case 'AE': _burjKhalifa(canvas, w, h, paint); return true;
      case 'SG': _merlion(canvas, w, h, paint); return true;
      case 'KH': _angkorWat(canvas, w, h, paint); return true;
      case 'TH': _watArun(canvas, w, h, paint); return true;
      case 'KR': _seoulTower(canvas, w, h, paint); return true;
      case 'TR': _hagiaSophia(canvas, w, h, paint); return true;
      default:   return false;
    }
  }

  // ── France — Eiffel Tower ────────────────────────────────────────────────

  static void _eiffelTower(Canvas canvas, double w, double h, Paint p) {
    final path = Path();
    // Wide base legs
    path.moveTo(w * 0.08, h);
    path.lineTo(w * 0.32, h * 0.62);
    path.lineTo(w * 0.40, h * 0.62);
    path.lineTo(w * 0.50, h * 0.18);
    path.lineTo(w * 0.60, h * 0.62);
    path.lineTo(w * 0.68, h * 0.62);
    path.lineTo(w * 0.92, h);
    path.close();

    // Platform 1 (bottom)
    final r1 = Rect.fromLTWH(w * 0.20, h * 0.76, w * 0.60, h * 0.06);
    // Platform 2 (middle)
    final r2 = Rect.fromLTWH(w * 0.30, h * 0.58, w * 0.40, h * 0.05);
    // Platform 3 (upper)
    final r3 = Rect.fromLTWH(w * 0.40, h * 0.40, w * 0.20, h * 0.04);

    canvas.drawPath(path, p);
    canvas.drawRect(r1, p);
    canvas.drawRect(r2, p);
    canvas.drawRect(r3, p);

    // Antenna
    canvas.drawRect(Rect.fromLTWH(w * 0.488, 0, w * 0.024, h * 0.18), p);
  }

  // ── United Kingdom — Big Ben ─────────────────────────────────────────────

  static void _bigBen(Canvas canvas, double w, double h, Paint p) {
    // Base plinth
    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.84, w * 0.60, h * 0.16), p);
    // Tower body
    canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.30, w * 0.44, h * 0.55), p);
    // Belfry (slightly wider)
    canvas.drawRect(Rect.fromLTWH(w * 0.22, h * 0.22, w * 0.56, h * 0.10), p);
    // Clock face cutout (white circle inside tower)
    final clockPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.50, h * 0.52), w * 0.11, clockPaint);
    // Hands (small cross)
    final handPaint = Paint()
      ..color = p.color
      ..strokeWidth = w * 0.03
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.50, h * 0.44), Offset(w * 0.50, h * 0.60), handPaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.52), Offset(w * 0.58, h * 0.52), handPaint);
    // Gothic spire
    final spire = Path();
    spire.moveTo(w * 0.22, h * 0.22);
    spire.lineTo(w * 0.50, 0);
    spire.lineTo(w * 0.78, h * 0.22);
    spire.close();
    canvas.drawPath(spire, p);
  }

  // ── Italy — Colosseum ───────────────────────────────────────────────────

  static void _colosseum(Canvas canvas, double w, double h, Paint p) {
    final cx = w * 0.50;
    final cy = h * 0.58;
    final rx = w * 0.46;
    final ry = h * 0.40;

    // Outer ellipse (filled)
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), p);

    // Inner hollow (white)
    final hollow = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.5, height: ry * 1.35), hollow);

    // Three tiers of arches
    final archPaint = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.025;
    for (int tier = 0; tier < 3; tier++) {
      final tRx = rx * (1.0 - tier * 0.14);
      final tRy = ry * (1.0 - tier * 0.14);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: tRx * 2, height: tRy * 2),
        archPaint,
      );
    }

    // Ground base
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.90, w * 0.92, h * 0.10), p);
  }

  // ── USA — Statue of Liberty ─────────────────────────────────────────────

  static void _statuOfLiberty(Canvas canvas, double w, double h, Paint p) {
    // Pedestal
    canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.72, w * 0.44, h * 0.28), p);
    // Robe body
    canvas.drawRect(Rect.fromLTWH(w * 0.34, h * 0.46, w * 0.32, h * 0.28), p);
    // Head (circle)
    canvas.drawCircle(Offset(w * 0.50, h * 0.36), w * 0.10, p);
    // Crown spikes
    for (int i = -2; i <= 2; i++) {
      final spike = Path();
      spike.moveTo(w * 0.50 + i * w * 0.07, h * 0.28);
      spike.lineTo(w * 0.50 + i * w * 0.035, h * 0.20);
      spike.lineTo(w * 0.50 + (i + 1) * w * 0.07, h * 0.28);
      spike.close();
      canvas.drawPath(spike, p);
    }
    // Raised torch arm
    final arm = Path();
    arm.moveTo(w * 0.64, h * 0.52);
    arm.lineTo(w * 0.80, h * 0.30);
    arm.lineTo(w * 0.84, h * 0.32);
    arm.lineTo(w * 0.68, h * 0.55);
    arm.close();
    canvas.drawPath(arm, p);
    // Torch flame
    canvas.drawCircle(Offset(w * 0.82, h * 0.24), w * 0.06, p);
  }

  // ── Egypt — Pyramids of Giza ─────────────────────────────────────────────

  static void _pyramids(Canvas canvas, double w, double h, Paint p) {
    // Main pyramid
    final main = Path();
    main.moveTo(w * 0.10, h);
    main.lineTo(w * 0.50, h * 0.08);
    main.lineTo(w * 0.90, h);
    main.close();
    canvas.drawPath(main, p);

    // Right smaller pyramid (behind)
    final right = Path();
    right.moveTo(w * 0.62, h);
    right.lineTo(w * 0.86, h * 0.36);
    right.lineTo(w * 0.98, h);
    right.close();
    canvas.drawPath(right, p);

    // Left smaller pyramid
    final left = Path();
    left.moveTo(w * 0.02, h);
    left.lineTo(w * 0.14, h * 0.38);
    left.lineTo(w * 0.32, h);
    left.close();
    canvas.drawPath(left, p);

    // Desert baseline
    canvas.drawRect(Rect.fromLTWH(0, h * 0.95, w, h * 0.05), p);
  }

  // ── India — Taj Mahal ───────────────────────────────────────────────────

  static void _tajMahal(Canvas canvas, double w, double h, Paint p) {
    // Left minaret
    canvas.drawRect(Rect.fromLTWH(w * 0.06, h * 0.28, w * 0.09, h * 0.72), p);
    _roundedTop(canvas, w * 0.10, h * 0.24, w * 0.04, h * 0.10, p);
    // Right minaret
    canvas.drawRect(Rect.fromLTWH(w * 0.85, h * 0.28, w * 0.09, h * 0.72), p);
    _roundedTop(canvas, w * 0.90, h * 0.24, w * 0.04, h * 0.10, p);
    // Main platform
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.70, w * 0.70, h * 0.30), p);
    // Central arch body
    canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.44, w * 0.44, h * 0.28), p);
    // Arch cutout (white)
    final archWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.35, h * 0.50, w * 0.30, h * 0.22),
        topLeft: Radius.circular(w * 0.15),
        topRight: Radius.circular(w * 0.15),
      ),
      archWhite,
    );
    // Central dome
    final dome = Path();
    dome.moveTo(w * 0.25, h * 0.44);
    dome.quadraticBezierTo(w * 0.25, h * 0.14, w * 0.50, h * 0.10);
    dome.quadraticBezierTo(w * 0.75, h * 0.14, w * 0.75, h * 0.44);
    dome.close();
    canvas.drawPath(dome, p);
    // Finial
    canvas.drawRect(Rect.fromLTWH(w * 0.486, h * 0.03, w * 0.028, h * 0.08), p);
    canvas.drawCircle(Offset(w * 0.50, h * 0.02), w * 0.025, p);
  }

  static void _roundedTop(Canvas canvas, double cx, double cy, double rx, double ry, Paint p) {
    final path = Path();
    path.moveTo(cx - rx, cy + ry);
    path.quadraticBezierTo(cx - rx, cy, cx, cy - ry);
    path.quadraticBezierTo(cx + rx, cy, cx + rx, cy + ry);
    path.close();
    canvas.drawPath(path, p);
  }

  // ── Japan — Torii Gate ──────────────────────────────────────────────────

  static void _toriiGate(Canvas canvas, double w, double h, Paint p) {
    final postW = w * 0.10;
    // Left post
    canvas.drawRect(Rect.fromLTWH(w * 0.14, h * 0.28, postW, h * 0.72), p);
    // Right post
    canvas.drawRect(Rect.fromLTWH(w * 0.76, h * 0.28, postW, h * 0.72), p);
    // Top curved beam (kasagi)
    final topBeam = Path();
    topBeam.moveTo(w * 0.04, h * 0.18);
    topBeam.cubicTo(w * 0.20, h * 0.04, w * 0.80, h * 0.04, w * 0.96, h * 0.18);
    topBeam.lineTo(w * 0.96, h * 0.28);
    topBeam.cubicTo(w * 0.80, h * 0.14, w * 0.20, h * 0.14, w * 0.04, h * 0.28);
    topBeam.close();
    canvas.drawPath(topBeam, p);
    // Straight lower beam (nuki)
    canvas.drawRect(Rect.fromLTWH(w * 0.14, h * 0.38, w * 0.72, h * 0.08), p);
  }

  // ── China — Great Wall ──────────────────────────────────────────────────

  static void _greatWall(Canvas canvas, double w, double h, Paint p) {
    // Wavy wall path
    final wall = Path();
    wall.moveTo(0, h * 0.65);
    wall.cubicTo(w * 0.20, h * 0.45, w * 0.35, h * 0.75, w * 0.50, h * 0.60);
    wall.cubicTo(w * 0.65, h * 0.45, w * 0.80, h * 0.70, w, h * 0.55);
    wall.lineTo(w, h * 0.68);
    wall.cubicTo(w * 0.80, h * 0.83, w * 0.65, h * 0.58, w * 0.50, h * 0.73);
    wall.cubicTo(w * 0.35, h * 0.88, w * 0.20, h * 0.58, 0, h * 0.78);
    wall.close();
    canvas.drawPath(wall, p);

    // Battlements (merlons) along top
    const int merlon = 7;
    for (int i = 0; i < merlon; i++) {
      final x = (i / (merlon - 1)) * w;
      // Interpolate height along the wall curve (approximate)
      final t = i / (merlon - 1);
      final baseY = h * (0.65 + math.sin(t * math.pi) * -0.12);
      canvas.drawRect(
        Rect.fromLTWH(x - w * 0.04, baseY - h * 0.10, w * 0.08, h * 0.10),
        p,
      );
    }

    // Mountain hints
    final mt = Path();
    mt.moveTo(w * 0.10, h * 0.50);
    mt.lineTo(w * 0.22, h * 0.28);
    mt.lineTo(w * 0.34, h * 0.52);
    mt.close();
    canvas.drawPath(mt, p);
    final mt2 = Path();
    mt2.moveTo(w * 0.70, h * 0.44);
    mt2.lineTo(w * 0.82, h * 0.22);
    mt2.lineTo(w * 0.94, h * 0.46);
    mt2.close();
    canvas.drawPath(mt2, p);
  }

  // ── Australia — Sydney Opera House ──────────────────────────────────────

  static void _operaHouse(Canvas canvas, double w, double h, Paint p) {
    // Base platform
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.82, w * 0.92, h * 0.18), p);
    // Left (larger) sail shell
    final sail1 = Path();
    sail1.moveTo(w * 0.08, h * 0.82);
    sail1.quadraticBezierTo(w * 0.12, h * 0.20, w * 0.54, h * 0.28);
    sail1.quadraticBezierTo(w * 0.54, h * 0.60, w * 0.54, h * 0.82);
    sail1.close();
    canvas.drawPath(sail1, p);
    // Second smaller inner sail
    final sail2 = Path();
    sail2.moveTo(w * 0.18, h * 0.82);
    sail2.quadraticBezierTo(w * 0.22, h * 0.40, w * 0.54, h * 0.46);
    sail2.quadraticBezierTo(w * 0.54, h * 0.65, w * 0.54, h * 0.82);
    sail2.close();
    final s2fill = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawPath(sail2, s2fill);
    // Right section sails
    final sail3 = Path();
    sail3.moveTo(w * 0.56, h * 0.82);
    sail3.quadraticBezierTo(w * 0.58, h * 0.36, w * 0.88, h * 0.44);
    sail3.quadraticBezierTo(w * 0.88, h * 0.65, w * 0.88, h * 0.82);
    sail3.close();
    canvas.drawPath(sail3, p);
    final sail4 = Path();
    sail4.moveTo(w * 0.62, h * 0.82);
    sail4.quadraticBezierTo(w * 0.64, h * 0.50, w * 0.88, h * 0.56);
    sail4.quadraticBezierTo(w * 0.88, h * 0.68, w * 0.88, h * 0.82);
    sail4.close();
    canvas.drawPath(sail4, s2fill);
  }

  // ── Brazil — Christ the Redeemer ─────────────────────────────────────────

  static void _christRedeemer(Canvas canvas, double w, double h, Paint p) {
    // Mountain/pedestal
    final mtn = Path();
    mtn.moveTo(0, h);
    mtn.lineTo(w * 0.30, h * 0.48);
    mtn.lineTo(w * 0.50, h * 0.54);
    mtn.lineTo(w * 0.70, h * 0.48);
    mtn.lineTo(w, h);
    mtn.close();
    canvas.drawPath(mtn, p);
    // Pedestal block
    canvas.drawRect(Rect.fromLTWH(w * 0.41, h * 0.44, w * 0.18, h * 0.12), p);
    // Robe (elongated body)
    canvas.drawRect(Rect.fromLTWH(w * 0.40, h * 0.26, w * 0.20, h * 0.20), p);
    // Arms (outstretched horizontal bar)
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.30, w * 0.84, h * 0.07), p);
    // Head
    canvas.drawCircle(Offset(w * 0.50, h * 0.20), w * 0.09, p);
  }

  // ── Greece — Parthenon ──────────────────────────────────────────────────

  static void _parthenon(Canvas canvas, double w, double h, Paint p) {
    // Steps base (three levels)
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.86, w * 0.92, h * 0.14), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.80, w * 0.84, h * 0.08), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.74, w * 0.76, h * 0.07), p);
    // Entablature (frieze)
    canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.50, w * 0.76, h * 0.10), p);
    // Pediment (triangle)
    final ped = Path();
    ped.moveTo(w * 0.12, h * 0.50);
    ped.lineTo(w * 0.50, h * 0.16);
    ped.lineTo(w * 0.88, h * 0.50);
    ped.close();
    canvas.drawPath(ped, p);
    // Columns (8 columns)
    const int cols = 8;
    final colW = w * 0.06;
    final spacing = (w * 0.76 - cols * colW) / (cols - 1);
    for (int i = 0; i < cols; i++) {
      final x = w * 0.12 + i * (colW + spacing);
      canvas.drawRect(Rect.fromLTWH(x, h * 0.60, colW, h * 0.14), p);
    }
  }

  // ── Russia — St Basil's Cathedral ───────────────────────────────────────

  static void _stBasils(Canvas canvas, double w, double h, Paint p) {
    // Base body
    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.60, w * 0.60, h * 0.40), p);
    // Central large onion dome
    _onionDome(canvas, w * 0.50, h * 0.40, w * 0.14, h * 0.26, p);
    // Flanking domes
    _onionDome(canvas, w * 0.26, h * 0.52, w * 0.10, h * 0.18, p);
    _onionDome(canvas, w * 0.74, h * 0.52, w * 0.10, h * 0.18, p);
    _onionDome(canvas, w * 0.14, h * 0.64, w * 0.08, h * 0.14, p);
    _onionDome(canvas, w * 0.86, h * 0.64, w * 0.08, h * 0.14, p);
  }

  static void _onionDome(Canvas canvas, double cx, double cy, double rx, double ry, Paint p) {
    final path = Path();
    path.moveTo(cx - rx, cy);
    path.quadraticBezierTo(cx - rx * 1.3, cy - ry * 0.5, cx, cy - ry);
    path.quadraticBezierTo(cx + rx * 1.3, cy - ry * 0.5, cx + rx, cy);
    path.close();
    canvas.drawPath(path, p);
    // Stem
    canvas.drawRect(Rect.fromLTWH(cx - rx * 0.3, cy, rx * 0.6, ry * 0.3), p);
  }

  // ── Spain — Sagrada Família ──────────────────────────────────────────────

  static void _sagradaFamilia(Canvas canvas, double w, double h, Paint p) {
    // Base facade
    canvas.drawRect(Rect.fromLTWH(w * 0.14, h * 0.48, w * 0.72, h * 0.52), p);
    // Central entrance arch
    final arch = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.38, h * 0.62, w * 0.24, h * 0.38),
        topLeft: Radius.circular(w * 0.12),
        topRight: Radius.circular(w * 0.12),
      ),
      arch,
    );
    // Spires (4 main + 1 taller center)
    _spire(canvas, w * 0.50, h * 0.48, w * 0.07, h * 0.50, p); // center tallest
    _spire(canvas, w * 0.28, h * 0.48, w * 0.065, h * 0.35, p);
    _spire(canvas, w * 0.72, h * 0.48, w * 0.065, h * 0.35, p);
    _spire(canvas, w * 0.16, h * 0.48, w * 0.055, h * 0.25, p);
    _spire(canvas, w * 0.84, h * 0.48, w * 0.055, h * 0.25, p);
  }

  static void _spire(Canvas canvas, double cx, double baseY, double rx, double height, Paint p) {
    final path = Path();
    path.moveTo(cx - rx, baseY);
    path.lineTo(cx - rx * 0.6, baseY - height * 0.7);
    path.lineTo(cx, baseY - height);
    path.lineTo(cx + rx * 0.6, baseY - height * 0.7);
    path.lineTo(cx + rx, baseY);
    path.close();
    canvas.drawPath(path, p);
  }

  // ── Germany — Brandenburg Gate ───────────────────────────────────────────

  static void _brandenburgGate(Canvas canvas, double w, double h, Paint p) {
    // Plinth base
    canvas.drawRect(Rect.fromLTWH(w * 0.06, h * 0.88, w * 0.88, h * 0.12), p);
    // Entablature (top horizontal block)
    canvas.drawRect(Rect.fromLTWH(w * 0.06, h * 0.50, w * 0.88, h * 0.12), p);
    // Attic (upper section)
    canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.28, w * 0.76, h * 0.24), p);
    // Quadriga silhouette on top
    final quad = Path();
    quad.moveTo(w * 0.24, h * 0.28);
    quad.lineTo(w * 0.24, h * 0.16);
    quad.lineTo(w * 0.76, h * 0.16);
    quad.lineTo(w * 0.76, h * 0.28);
    quad.close();
    canvas.drawPath(quad, p);
    // Horses (3 bumps on top)
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(w * (0.30 + i * 0.13), h * 0.10),
        w * 0.06,
        p,
      );
    }
    // 6 columns
    const int cols = 6;
    final cw = w * 0.065;
    final gap = (w * 0.88 - cols * cw) / (cols - 1);
    for (int i = 0; i < cols; i++) {
      final x = w * 0.06 + i * (cw + gap);
      canvas.drawRect(Rect.fromLTWH(x, h * 0.62, cw, h * 0.26), p);
    }
  }

  // ── Netherlands — Windmill ──────────────────────────────────────────────

  static void _windmill(Canvas canvas, double w, double h, Paint p) {
    // Tower body (octagonal approximation using rectangle + trapezoid)
    final tower = Path();
    tower.moveTo(w * 0.35, h);
    tower.lineTo(w * 0.40, h * 0.40);
    tower.lineTo(w * 0.60, h * 0.40);
    tower.lineTo(w * 0.65, h);
    tower.close();
    canvas.drawPath(tower, p);
    // Cap (triangular roof)
    final cap = Path();
    cap.moveTo(w * 0.38, h * 0.40);
    cap.lineTo(w * 0.50, h * 0.20);
    cap.lineTo(w * 0.62, h * 0.40);
    cap.close();
    canvas.drawPath(cap, p);
    // Hub
    canvas.drawCircle(Offset(w * 0.50, h * 0.38), w * 0.04, p);
    // 4 blades at 45-degree increments
    final bladePaint = Paint()
      ..color = p.color
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 + math.pi / 4;
      const bladeLen = 0.36;
      canvas.drawLine(
        Offset(w * 0.50, h * 0.38),
        Offset(w * 0.50 + math.cos(angle) * w * bladeLen,
               h * 0.38 + math.sin(angle) * w * bladeLen),
        bladePaint,
      );
    }
    // Window cutout
    final win = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(w * 0.43, h * 0.56, w * 0.14, h * 0.14), win);
  }

  // ── Peru — Machu Picchu ─────────────────────────────────────────────────

  static void _machupicchu(Canvas canvas, double w, double h, Paint p) {
    // Background mountains
    final mtn1 = Path();
    mtn1.moveTo(0, h);
    mtn1.lineTo(w * 0.20, h * 0.20);
    mtn1.lineTo(w * 0.42, h * 0.52);
    mtn1.lineTo(w, h);
    mtn1.close();
    canvas.drawPath(mtn1, p);
    final mtn2 = Path();
    mtn2.moveTo(w * 0.40, h);
    mtn2.lineTo(w * 0.68, h * 0.10);
    mtn2.lineTo(w, h * 0.40);
    mtn2.lineTo(w, h);
    mtn2.close();
    canvas.drawPath(mtn2, p);
    // Terraces (horizontal step layers)
    final terraceWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.22 + i * w * 0.01, h * (0.56 + i * 0.08),
                      w * (0.56 - i * 0.04), h * 0.015),
        terraceWhite,
      );
    }
    // Ruins building silhouette on terrace
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.44, w * 0.40, h * 0.14), p);
  }

  // ── Mexico — Chichen Itza ───────────────────────────────────────────────

  static void _chichenItza(Canvas canvas, double w, double h, Paint p) {
    // Stepped pyramid - 4 levels
    const int levels = 4;
    for (int i = 0; i < levels; i++) {
      final inset = i * 0.09;
      canvas.drawRect(
        Rect.fromLTWH(w * (0.04 + inset), h * (0.68 + i * 0.01 - levels * 0.07 + i * 0.065),
                      w * (0.92 - inset * 2), h * 0.065),
        p,
      );
    }
    // Temple on top
    canvas.drawRect(Rect.fromLTWH(w * 0.38, h * 0.26, w * 0.24, h * 0.16), p);
    // Roof comb / small temple roof
    final roof = Path();
    roof.moveTo(w * 0.36, h * 0.26);
    roof.lineTo(w * 0.50, h * 0.12);
    roof.lineTo(w * 0.64, h * 0.26);
    roof.close();
    canvas.drawPath(roof, p);
    // Ground base
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.90, w * 0.92, h * 0.10), p);
  }

  // ── Canada — CN Tower ──────────────────────────────────────────────────

  static void _cnTower(Canvas canvas, double w, double h, Paint p) {
    // Wide base legs
    final base = Path();
    base.moveTo(w * 0.26, h);
    base.lineTo(w * 0.40, h * 0.56);
    base.lineTo(w * 0.60, h * 0.56);
    base.lineTo(w * 0.74, h);
    base.close();
    canvas.drawPath(base, p);
    // Slim shaft
    canvas.drawRect(Rect.fromLTWH(w * 0.44, h * 0.16, w * 0.12, h * 0.42), p);
    // Observation pod (wider disc)
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.34, w * 0.40, h * 0.10), p);
    // Antenna
    canvas.drawRect(Rect.fromLTWH(w * 0.488, 0, w * 0.024, h * 0.17), p);
    canvas.drawCircle(Offset(w * 0.50, h * 0.14), w * 0.025, p);
  }

  // ── Jordan — Petra ──────────────────────────────────────────────────────

  static void _petra(Canvas canvas, double w, double h, Paint p) {
    // Cliff face background
    canvas.drawRect(Rect.fromLTWH(0, h * 0.06, w, h * 0.94), p);
    // Façade cut-out elements (white)
    final cut = Paint()..color = Colors.white..style = PaintingStyle.fill;
    // Main entrance arch
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.34, h * 0.54, w * 0.32, h * 0.46),
        topLeft: Radius.circular(w * 0.16),
        topRight: Radius.circular(w * 0.16),
      ),
      cut,
    );
    // Pediment columns
    for (final x in [0.16, 0.24, 0.68, 0.76]) {
      canvas.drawRect(Rect.fromLTWH(w * x, h * 0.38, w * 0.07, h * 0.32), cut);
    }
    // Upper triangular pediment
    final ped = Path();
    ped.moveTo(w * 0.10, h * 0.38);
    ped.lineTo(w * 0.50, h * 0.10);
    ped.lineTo(w * 0.90, h * 0.38);
    ped.lineTo(w * 0.90, h * 0.42);
    ped.lineTo(w * 0.10, h * 0.42);
    ped.close();
    canvas.drawPath(ped, cut);
    // Urn on top
    canvas.drawCircle(Offset(w * 0.50, h * 0.06), w * 0.07, cut);
  }

  // ── UAE — Burj Khalifa ─────────────────────────────────────────────────

  static void _burjKhalifa(Canvas canvas, double w, double h, Paint p) {
    // Three-buttress stepped profile
    final body = Path();
    body.moveTo(w * 0.22, h);
    body.lineTo(w * 0.28, h * 0.60);
    body.lineTo(w * 0.36, h * 0.52);
    body.lineTo(w * 0.40, h * 0.36);
    body.lineTo(w * 0.44, h * 0.26);
    body.lineTo(w * 0.48, h * 0.08);
    body.lineTo(w * 0.50, 0);
    body.lineTo(w * 0.52, h * 0.08);
    body.lineTo(w * 0.56, h * 0.26);
    body.lineTo(w * 0.60, h * 0.36);
    body.lineTo(w * 0.64, h * 0.52);
    body.lineTo(w * 0.72, h * 0.60);
    body.lineTo(w * 0.78, h);
    body.close();
    canvas.drawPath(body, p);
    // Setbacks (white lines to indicate tier changes)
    final setback = Paint()
      ..color = Colors.white
      ..strokeWidth = h * 0.012
      ..style = PaintingStyle.stroke;
    for (final yFrac in [0.26, 0.36, 0.52, 0.60]) {
      canvas.drawLine(Offset(w * 0.22, h * yFrac), Offset(w * 0.78, h * yFrac), setback);
    }
  }

  // ── Singapore — Merlion ────────────────────────────────────────────────

  static void _merlion(Canvas canvas, double w, double h, Paint p) {
    // Fish tail (lower body)
    final tail = Path();
    tail.moveTo(w * 0.30, h * 0.70);
    tail.cubicTo(w * 0.10, h * 0.60, w * 0.06, h * 0.90, w * 0.20, h);
    tail.lineTo(w * 0.80, h);
    tail.cubicTo(w * 0.94, h * 0.90, w * 0.90, h * 0.60, w * 0.70, h * 0.70);
    tail.close();
    canvas.drawPath(tail, p);
    // Body
    final body = Path();
    body.moveTo(w * 0.26, h * 0.40);
    body.lineTo(w * 0.30, h * 0.70);
    body.lineTo(w * 0.70, h * 0.70);
    body.lineTo(w * 0.74, h * 0.40);
    body.close();
    canvas.drawPath(body, p);
    // Lion head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.28), width: w * 0.54, height: h * 0.32),
      p,
    );
    // Mane (rough circle, slightly lighter)
    // Water spout from mouth
    final spout = Path();
    spout.moveTo(w * 0.50, h * 0.16);
    spout.lineTo(w * 0.50, 0);
    spout.lineTo(w * 0.60, h * 0.08);
    spout.close();
    canvas.drawPath(spout, p);
    // Eyes
    final eye = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.40, h * 0.24), w * 0.04, eye);
    canvas.drawCircle(Offset(w * 0.60, h * 0.24), w * 0.04, eye);
  }

  // ── Cambodia — Angkor Wat ──────────────────────────────────────────────

  static void _angkorWat(Canvas canvas, double w, double h, Paint p) {
    // Wide flat base platform
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.86, w * 0.92, h * 0.14), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.10, h * 0.74, w * 0.80, h * 0.14), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.62, w * 0.64, h * 0.14), p);
    // 5 towers (lotus bud silhouettes)
    final heights = [0.36, 0.20, 0.04, 0.20, 0.36];
    final positions = [0.16, 0.31, 0.50, 0.69, 0.84];
    for (int i = 0; i < 5; i++) {
      _lotusSpire(canvas, w * positions[i], h * heights[i], h * 0.62, w * 0.09, p);
    }
  }

  static void _lotusSpire(Canvas canvas, double cx, double topY, double baseY, double rx, Paint p) {
    final path = Path();
    final mid = topY + (baseY - topY) * 0.6;
    path.moveTo(cx - rx * 0.5, baseY);
    path.lineTo(cx - rx * 0.7, mid);
    path.quadraticBezierTo(cx - rx * 0.8, topY + (baseY - topY) * 0.2, cx, topY);
    path.quadraticBezierTo(cx + rx * 0.8, topY + (baseY - topY) * 0.2, cx + rx * 0.7, mid);
    path.lineTo(cx + rx * 0.5, baseY);
    path.close();
    canvas.drawPath(path, p);
  }

  // ── Thailand — Wat Arun ────────────────────────────────────────────────

  static void _watArun(Canvas canvas, double w, double h, Paint p) {
    // Central prang (tapering tower)
    final mainPrang = Path();
    mainPrang.moveTo(w * 0.30, h * 0.90);
    mainPrang.lineTo(w * 0.36, h * 0.52);
    mainPrang.lineTo(w * 0.42, h * 0.36);
    mainPrang.lineTo(w * 0.48, h * 0.12);
    mainPrang.lineTo(w * 0.50, 0);
    mainPrang.lineTo(w * 0.52, h * 0.12);
    mainPrang.lineTo(w * 0.58, h * 0.36);
    mainPrang.lineTo(w * 0.64, h * 0.52);
    mainPrang.lineTo(w * 0.70, h * 0.90);
    mainPrang.close();
    canvas.drawPath(mainPrang, p);
    // Horizontal tier bands
    final band = Paint()..color = Colors.white..strokeWidth = h * 0.018..style = PaintingStyle.stroke;
    for (final y in [0.36, 0.52, 0.68]) {
      canvas.drawLine(Offset(w * 0.10, h * y), Offset(w * 0.90, h * y), band);
    }
    // 4 smaller corner prangs
    for (final cx in [w * 0.18, w * 0.82]) {
      final sp = Path();
      sp.moveTo(cx - w * 0.10, h * 0.90);
      sp.lineTo(cx - w * 0.04, h * 0.58);
      sp.lineTo(cx, h * 0.44);
      sp.lineTo(cx + w * 0.04, h * 0.58);
      sp.lineTo(cx + w * 0.10, h * 0.90);
      sp.close();
      canvas.drawPath(sp, p);
    }
    // Base
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.88, w * 0.84, h * 0.12), p);
  }

  // ── South Korea — Seoul Tower (N Seoul Tower) ───────────────────────────

  static void _seoulTower(Canvas canvas, double w, double h, Paint p) {
    // Base structure on hill
    final hill = Path();
    hill.moveTo(0, h);
    hill.quadraticBezierTo(w * 0.50, h * 0.66, w, h);
    hill.close();
    canvas.drawPath(hill, p);
    // Tower base legs
    canvas.drawRect(Rect.fromLTWH(w * 0.36, h * 0.58, w * 0.28, h * 0.10), p);
    // Slim shaft
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.22, w * 0.10, h * 0.38), p);
    // Observation deck (disc)
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.36, w * 0.40, h * 0.10), p);
    // Antenna
    canvas.drawRect(Rect.fromLTWH(w * 0.488, 0, w * 0.024, h * 0.23), p);
  }

  // ── Turkey — Hagia Sophia ──────────────────────────────────────────────

  static void _hagiaSophia(Canvas canvas, double w, double h, Paint p) {
    // Base / walls
    canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.58, w * 0.76, h * 0.42), p);
    // Half-domes on sides
    final leftHD = Path();
    leftHD.moveTo(w * 0.12, h * 0.58);
    leftHD.quadraticBezierTo(w * 0.12, h * 0.36, w * 0.30, h * 0.36);
    leftHD.quadraticBezierTo(w * 0.30, h * 0.58, w * 0.12, h * 0.58);
    canvas.drawPath(leftHD, p);
    final rightHD = Path();
    rightHD.moveTo(w * 0.88, h * 0.58);
    rightHD.quadraticBezierTo(w * 0.88, h * 0.36, w * 0.70, h * 0.36);
    rightHD.quadraticBezierTo(w * 0.70, h * 0.58, w * 0.88, h * 0.58);
    canvas.drawPath(rightHD, p);
    // Main dome
    final dome = Path();
    dome.moveTo(w * 0.20, h * 0.58);
    dome.quadraticBezierTo(w * 0.20, h * 0.18, w * 0.50, h * 0.14);
    dome.quadraticBezierTo(w * 0.80, h * 0.18, w * 0.80, h * 0.58);
    dome.close();
    canvas.drawPath(dome, p);
    // Two minarets
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.20, w * 0.07, h * 0.80), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.89, h * 0.20, w * 0.07, h * 0.80), p);
    // Minaret tips
    final lTip = Path()
      ..moveTo(w * 0.04, h * 0.20)
      ..lineTo(w * 0.075, h * 0.06)
      ..lineTo(w * 0.11, h * 0.20)
      ..close();
    canvas.drawPath(lTip, p);
    final rTip = Path()
      ..moveTo(w * 0.89, h * 0.20)
      ..lineTo(w * 0.925, h * 0.06)
      ..lineTo(w * 0.96, h * 0.20)
      ..close();
    canvas.drawPath(rTip, p);
  }
}
