import 'package:flutter/material.dart';

/// Draws the snake path connecting timeline nodes.
///
/// [positions] is the list of node centres in canvas space, newest at top.
/// [nodeRadius] is used to clip the path ends so the line doesn't overdraw
/// the node circles.
class TimelinePainter extends CustomPainter {
  const TimelinePainter({
    required this.positions,
    required this.nodeRadius,
    required this.pathColor,
    required this.pathShadowColor,
  });

  final List<Offset> positions;
  final double nodeRadius;
  final Color pathColor;
  final Color pathShadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final shadowPaint = Paint()
      ..color = pathShadowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final pathPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final path = _buildPath();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, pathPaint);
  }

  Path _buildPath() {
    final path = Path();
    path.moveTo(positions.first.dx, positions.first.dy);

    for (int i = 1; i < positions.length; i++) {
      final p0 = positions[i - 1];
      final p1 = positions[i];
      // Control points pull toward each node's x at ±40% of the gap.
      final gap = p1.dy - p0.dy;
      final cp1 = Offset(p0.dx, p0.dy + gap * 0.45);
      final cp2 = Offset(p1.dx, p1.dy - gap * 0.45);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(TimelinePainter old) =>
      old.positions != positions ||
      old.pathColor != pathColor;
}

/// Computes the (x, y) centre for each timeline node given the canvas width.
///
/// [isHeader] marks indices that are year-group headers — these always snap to
/// `centerX` and reset the snake counter so the path continues naturally after them.
///
/// The snake follows: centre → right → right → centre → left → left → centre …
/// (period 6) for a Duolingo-style feel.
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
      snakeStep = 0; // reset snake after header
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
