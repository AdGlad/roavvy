import 'package:flutter/material.dart';

// Warm (top) → cool (bottom) path gradient: orange → sky blue.
const _kPathGradientColors = [Color(0xFFFF8C42), Color(0xFF4FC3F7)];

class TimelinePainter extends CustomPainter {
  const TimelinePainter({
    required this.positions,
    required this.nodeRadius,
    required this.pathColor,
    required this.pathShadowColor,
    this.pathProgress = 1.0,
  });

  final List<Offset> positions;
  final double nodeRadius;
  final Color pathColor;
  final Color pathShadowColor;

  /// 0.0 = no path drawn; 1.0 = full path. Drives the draw-on animation.
  final double pathProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final fullPath = _buildPath();
    final visiblePath = _trimPath(fullPath);
    if (visiblePath == null) return;

    final top = positions.first.dy;
    final bottom = positions.last.dy;

    final shadowPaint = Paint()
      ..color = pathShadowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final gradientShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: _kPathGradientColors,
    ).createShader(Rect.fromLTWH(0, top, size.width, bottom - top));

    final pathPaint = Paint()
      ..shader = gradientShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(visiblePath, shadowPaint);
    canvas.drawPath(visiblePath, pathPaint);
  }

  Path _buildPath() {
    final path = Path();
    path.moveTo(positions.first.dx, positions.first.dy);
    for (int i = 1; i < positions.length; i++) {
      final p0 = positions[i - 1];
      final p1 = positions[i];
      final gap = p1.dy - p0.dy;
      final cp1 = Offset(p0.dx, p0.dy + gap * 0.45);
      final cp2 = Offset(p1.dx, p1.dy - gap * 0.45);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }
    return path;
  }

  /// Returns only the first [pathProgress] portion of [source], or null if
  /// progress is effectively zero.
  Path? _trimPath(Path source) {
    if (pathProgress <= 0.0) return null;
    if (pathProgress >= 1.0) return source;

    final metrics = source.computeMetrics().toList();
    if (metrics.isEmpty) return null;

    final totalLength = metrics.fold(0.0, (sum, m) => sum + m.length);
    final targetLength = totalLength * pathProgress;

    final trimmed = Path();
    double consumed = 0.0;
    for (final metric in metrics) {
      final remaining = targetLength - consumed;
      if (remaining <= 0) break;
      final extractLen = remaining.clamp(0.0, metric.length);
      trimmed.addPath(metric.extractPath(0.0, extractLen), Offset.zero);
      consumed += metric.length;
    }
    return trimmed;
  }

  @override
  bool shouldRepaint(TimelinePainter old) =>
      old.positions != positions ||
      old.pathColor != pathColor ||
      old.pathProgress != pathProgress;
}

/// Computes the (x, y) centre for each timeline node given the canvas width.
///
/// Header items (year group pills) always snap to `centerX` and reset the
/// snake counter so the path continues naturally after them.
///
/// Snake pattern: centre → right → right → centre → left → left  (period 6)
List<Offset> computeTimelinePositions({
  required int count,
  required double width,
  double topPadding = 48.0,
  double nodeSpacing = 118.0,
  Set<int> headerIndices = const {},
}) {
  if (count == 0) return [];
  final leftX = width * 0.26;
  final centerX = width * 0.50;
  final rightX = width * 0.74;

  int snakeStep = 0;
  return List.generate(count, (i) {
    final y = topPadding + i * nodeSpacing;
    if (headerIndices.contains(i)) {
      snakeStep = 0;
      return Offset(centerX, y);
    }
    final x = switch (snakeStep % 6) {
      0 => centerX,
      1 => rightX,
      2 => rightX,
      3 => centerX,
      4 => leftX,
      5 => leftX,
      _ => centerX,
    };
    snakeStep++;
    return Offset(x, y);
  });
}

/// Total pixel height of a timeline with [count] nodes.
double timelineHeight({
  required int count,
  double topPadding = 48.0,
  double nodeSpacing = 118.0,
  double bottomPadding = 80.0,
}) =>
    topPadding + (count - 1) * nodeSpacing + bottomPadding;
