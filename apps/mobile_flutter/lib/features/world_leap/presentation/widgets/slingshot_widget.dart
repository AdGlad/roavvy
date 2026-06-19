// lib/features/world_leap/presentation/widgets/slingshot_widget.dart
//
// Slingshot UI & Trajectory Preview — Milestone 8

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/world_leap_controller.dart';
import '../../application/world_leap_state.dart';
import '../../world_leap_config.dart';

// ── Package-private pure functions (importable by tests) ──────────────────────

/// Computes a compass bearing (0–360°, clockwise from north) from a drag
/// offset [dx]/[dy] in Flutter screen coordinates (y increases downward).
/// Catapult style: the launch direction is OPPOSITE to the drag direction.
///
/// Pull left  → launch right (east)
/// Pull down  → launch up (north)
/// bearing = atan2(-dx, dy) converted to degrees, normalised to [0, 360)
double computeBearing(double dx, double dy) {
  final rad = math.atan2(-dx, dy);
  return (rad * 180 / math.pi + 360) % 360;
}

/// Computes normalised launch power (0.0–1.0) from drag distance and max pixels.
double computePower(double dx, double dy, double maxPixels) {
  if (maxPixels <= 0) return 0;
  final distance = math.sqrt(dx * dx + dy * dy);
  return (distance / maxPixels).clamp(0.0, 1.0);
}

/// Returns [count] evenly-spaced screen-space preview dot positions along
/// the drag direction, up to [maxDragPixels] from [anchor].
///
/// Dots are in screen coordinates (absolute positions within the widget).
/// These are screen-space dots for the visual preview only — actual geo
/// calculation is done by WorldLeapController.
List<Offset> computeTrajectoryDots({
  required Offset anchor,
  required double dx,
  required double dy,
  required int count,
  required double maxDragPixels,
}) {
  final distance = math.sqrt(dx * dx + dy * dy).clamp(0.0, maxDragPixels);
  if (distance == 0) return [];
  return List.generate(count, (i) {
    final t = (i + 1) / count;
    return anchor + Offset(dx * t, dy * t);
  });
}

// ── SlingshotWidget ───────────────────────────────────────────────────────────

class SlingshotWidget extends StatefulWidget {
  final WorldLeapController controller;

  /// Maximum drag distance in pixels that maps to power = 1.0.
  /// Defaults to screen height * WorldLeapConfig.maxPullFraction.
  final double? maxDragPixels;

  const SlingshotWidget({
    super.key,
    required this.controller,
    this.maxDragPixels,
  });

  @override
  State<SlingshotWidget> createState() => _SlingshotWidgetState();
}

class _SlingshotWidgetState extends State<SlingshotWidget> {
  Offset? _dragStart;
  Offset? _dragCurrent;

  Offset? get _dragDelta =>
      _dragCurrent != null && _dragStart != null
          ? _dragCurrent! - _dragStart!
          : null;

  void _onPanStart(DragStartDetails details, Offset anchor, double maxPixels) {
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Offset anchor, double maxPixels) {
    setState(() => _dragCurrent = details.localPosition);
    final delta = _dragDelta;
    if (delta == null) return;
    final bearing = computeBearing(delta.dx, delta.dy);
    final power = computePower(delta.dx, delta.dy, maxPixels);
    widget.controller.updateAim(bearingDeg: bearing, power: power);
  }

  void _onPanEnd() {
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
    widget.controller.launch();
  }

  @override
  Widget build(BuildContext context) {
    // Only active when aiming
    if (widget.controller.state is! WorldLeapStateAiming) {
      return const SizedBox.shrink();
    }

    final targetBearing = widget.controller.targetBearingDeg;

    return LayoutBuilder(builder: (context, constraints) {
      final maxPixels = widget.maxDragPixels ??
          constraints.maxHeight * WorldLeapConfig.maxPullFraction;
      final anchor = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

      // Check if current aim is "on target" (within ±20° of target bearing).
      bool onTarget = false;
      if (_dragDelta != null && targetBearing != null) {
        final aimBearing = computeBearing(_dragDelta!.dx, _dragDelta!.dy);
        final diff = ((aimBearing - targetBearing) + 360) % 360;
        onTarget = diff <= 20 || diff >= 340;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _onPanStart(details, anchor, maxPixels),
        onPanUpdate: (details) => _onPanUpdate(details, anchor, maxPixels),
        onPanEnd: (_) => _onPanEnd(),
        child: Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SlingshotPainter(
                anchor: anchor,
                dragDelta: _dragDelta,
                maxDragPixels: maxPixels,
                onTarget: onTarget,
              ),
            ),
            // "ON TARGET" flash label
            if (onTarget && _dragDelta != null)
              Positioned(
                left: anchor.dx - 50,
                top: anchor.dy - 70,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🎯 ON TARGET',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ── _SlingshotPainter ─────────────────────────────────────────────────────────

class _SlingshotPainter extends CustomPainter {
  final Offset anchor;
  final Offset? dragDelta;
  final double maxDragPixels;
  final bool onTarget;

  const _SlingshotPainter({
    required this.anchor,
    required this.dragDelta,
    required this.maxDragPixels,
    this.onTarget = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Anchor circle
    canvas.drawCircle(
      anchor,
      16,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (dragDelta == null || dragDelta!.distance < 1) return;

    // 2. Drag line
    canvas.drawLine(
      anchor,
      anchor + dragDelta!,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // 3. Trajectory dots — shown in launch direction (opposite of drag)
    final dots = computeTrajectoryDots(
      anchor: anchor,
      dx: -dragDelta!.dx,
      dy: -dragDelta!.dy,
      count: WorldLeapConfig.trajectoryDotCount,
      maxDragPixels: maxDragPixels,
    );
    // Gold dots when on target, white otherwise.
    final dotColor = onTarget
        ? const Color(0xFFFFD700).withValues(alpha: 0.9)
        : Colors.white.withOpacity(0.75);
    final dotPaint = Paint()..color = dotColor;
    for (int i = 0; i < dots.length; i++) {
      // Gradually increase dot size toward destination when on target.
      final radius = onTarget ? (3.0 + i * 0.15) : 4.0;
      canvas.drawCircle(dots[i], radius, dotPaint);
    }

    // 4. Power arc
    final power = computePower(dragDelta!.dx, dragDelta!.dy, maxDragPixels);
    final arcPaint = Paint()
      ..color = Color.lerp(Colors.green, Colors.red, power)!.withOpacity(0.7)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: anchor, radius: 28),
      -math.pi / 2,
      2 * math.pi * power,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_SlingshotPainter old) =>
      old.dragDelta != dragDelta || old.anchor != anchor || old.onTarget != onTarget;
}
