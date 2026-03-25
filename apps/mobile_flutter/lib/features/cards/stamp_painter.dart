import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'passport_stamp_model.dart';

/// CustomPainter that draws a single passport stamp onto the canvas.
///
/// Uses canvas.save/translate/rotate/restore so rotation has no layout
/// side-effects (ADR-096). Each stamp shape has specific anatomy:
///
/// - circular: concentric circles, country name arc along top, date centre
/// - rectangular: double-border rect, stacked text
/// - oval: rounded-rect border, stacked text
/// - doubleRing: two concentric circles + serrated inner ring, stacked text
class StampPainter extends CustomPainter {
  const StampPainter(this.stamp);

  final StampData stamp;

  @override
  void paint(Canvas canvas, Size size) {
    final center = stamp.center;
    final rotation = stamp.rotation;
    final color = stamp.color.color.withValues(alpha: 0.75);
    final baseRadius = 38.0 * stamp.scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    switch (stamp.shape) {
      case StampShape.circular:
        _drawCircular(canvas, color, baseRadius);
      case StampShape.rectangular:
        _drawRectangular(canvas, color, baseRadius);
      case StampShape.oval:
        _drawOval(canvas, color, baseRadius);
      case StampShape.doubleRing:
        _drawDoubleRing(canvas, color, baseRadius);
    }

    canvas.restore();
  }

  void _drawCircular(Canvas canvas, Color color, double r) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer circle
    canvas.drawCircle(Offset.zero, r, borderPaint);
    // Inner circle
    canvas.drawCircle(Offset.zero, r * 0.75, innerPaint);

    // Country code at top (simpler than full arc text)
    _drawText(
      canvas,
      stamp.countryCode,
      color,
      fontSize: 9.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, -(r * 0.45)),
    );

    // Date in centre
    if (stamp.dateLabel != null) {
      _drawText(
        canvas,
        stamp.dateLabel!,
        color,
        fontSize: 6.5 * stamp.scale,
        offset: Offset.zero,
      );
    }

    // Entry label at bottom
    _drawText(
      canvas,
      stamp.entryLabel,
      color,
      fontSize: 7.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, r * 0.45),
    );
  }

  void _drawRectangular(Canvas canvas, Color color, double r) {
    final w = r * 1.9;
    final h = r * 1.3;
    final outerRect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final innerRect = Rect.fromCenter(
      center: Offset.zero,
      width: w - 6,
      height: h - 6,
    );

    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(outerRect, outerPaint);
    canvas.drawRect(innerRect, innerPaint);

    _drawText(
      canvas,
      stamp.countryCode,
      color,
      fontSize: 9.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, -(h * 0.22)),
    );
    if (stamp.dateLabel != null) {
      _drawText(
        canvas,
        stamp.dateLabel!,
        color,
        fontSize: 5.5 * stamp.scale,
        offset: Offset(0, h * 0.05),
      );
    }
    _drawText(
      canvas,
      stamp.entryLabel,
      color,
      fontSize: 6.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, h * 0.28),
    );
  }

  void _drawOval(Canvas canvas, Color color, double r) {
    final w = r * 2.1;
    final h = r * 1.4;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(h * 0.45),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, paint);

    _drawText(
      canvas,
      stamp.countryCode,
      color,
      fontSize: 9.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, -(h * 0.2)),
    );
    if (stamp.dateLabel != null) {
      _drawText(
        canvas,
        stamp.dateLabel!,
        color,
        fontSize: 5.5 * stamp.scale,
        offset: Offset(0, h * 0.06),
      );
    }
    _drawText(
      canvas,
      stamp.entryLabel,
      color,
      fontSize: 6.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, h * 0.28),
    );
  }

  void _drawDoubleRing(Canvas canvas, Color color, double r) {
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset.zero, r, outerPaint);
    canvas.drawCircle(Offset.zero, r * 0.78, innerPaint);

    // Serrated inner ring: short radial tick marks
    const ticks = 24;
    final innerR = r * 0.78;
    final tickPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < ticks; i++) {
      final angle = 2 * math.pi * i / ticks;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      canvas.drawLine(
        Offset(cos * (innerR - 4), sin * (innerR - 4)),
        Offset(cos * innerR, sin * innerR),
        tickPaint,
      );
    }

    _drawText(
      canvas,
      stamp.countryCode,
      color,
      fontSize: 9.0 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, -(r * 0.35)),
    );
    if (stamp.dateLabel != null) {
      _drawText(
        canvas,
        stamp.dateLabel!,
        color,
        fontSize: 6.0 * stamp.scale,
        offset: Offset(0, r * 0.1),
      );
    }
    _drawText(
      canvas,
      stamp.entryLabel,
      color,
      fontSize: 6.5 * stamp.scale,
      fontWeight: FontWeight.bold,
      offset: Offset(0, r * 0.4),
    );
  }

  /// Draw centred text at [offset] relative to the canvas origin.
  void _drawText(
    Canvas canvas,
    String text,
    Color color, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    required Offset offset,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Courier New',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      offset - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(StampPainter oldDelegate) => oldDelegate.stamp != stamp;
}
