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

  /// Optional hit-test: returns true if [localPosition] falls on the source
  /// country. When provided, the slingshot only activates on country touches;
  /// all other touches pass through to the map for panning.
  final bool Function(Offset localPosition)? hitTestFn;

  /// Called when the slingshot starts/stops actively tracking a gesture, so
  /// the map can suppress its own drag recognizer during slingshot operation.
  final void Function(bool active)? onActiveChanged;

  /// When true, releasing the drag freezes the aim for review (calls
  /// [WorldLeapController.confirmAim]) instead of firing immediately — the
  /// screen shows a separate FIRE button and the player may re-aim by
  /// starting a new drag before committing.
  final bool beginnerMode;

  const SlingshotWidget({
    super.key,
    required this.controller,
    this.maxDragPixels,
    this.hitTestFn,
    this.onActiveChanged,
    this.beginnerMode = false,
  });

  @override
  State<SlingshotWidget> createState() => SlingshotWidgetState();
}

class SlingshotWidgetState extends State<SlingshotWidget>
    with SingleTickerProviderStateMixin {
  Offset? _dragStart;
  Offset? _dragCurrent;

  // Pointer tracking — only the pointer that started on the source country.
  int? _trackingPointer;

  // Snap-back animation
  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        setState(() {});
      });
    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _snapAnimation = null;
        });
      }
    });
    // Beginner mode freezes the drag visuals on release so the aim can be
    // reviewed before the FIRE button is tapped. Once the controller moves
    // past Aiming (fired, failed, or a new turn started elsewhere), clear
    // the frozen state so a stale arrow doesn't appear on the next turn.
    widget.controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    _snapController.dispose();
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (widget.controller.state is! WorldLeapStateAiming &&
        (_dragStart != null || _dragCurrent != null)) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
    }
  }

  Offset? get _dragDelta =>
      _dragCurrent != null && _dragStart != null
          ? _dragCurrent! - _dragStart!
          : null;

  /// The effective drag delta shown to the painter — either the live drag or
  /// the in-progress snap-back animation, whichever is active.
  Offset? get _effectiveDragDelta {
    if (_dragDelta != null) return _dragDelta;
    if (_snapAnimation != null && _snapController.isAnimating) {
      return _snapAnimation!.value;
    }
    return null;
  }

  void _startTracking(Offset localPosition) {
    _snapController.stop();
    setState(() {
      _snapAnimation = null;
      _dragStart = localPosition;
      _dragCurrent = localPosition;
    });
    widget.onActiveChanged?.call(true);
  }

  void _updateTracking(Offset localPosition, double maxPixels) {
    setState(() => _dragCurrent = localPosition);
    final delta = _dragDelta;
    if (delta == null) return;
    final bearing = computeBearing(delta.dx, delta.dy);
    final power = computePower(delta.dx, delta.dy, maxPixels);
    widget.controller.updateAim(bearingDeg: bearing, power: power);
  }

  void _endTracking({required bool launch}) {
    final lastDelta = _dragDelta;
    final hasAimed = lastDelta != null && lastDelta.distance >= 1;
    // Beginner mode + a real release (not a cancel): freeze the pull band in
    // place instead of snapping back to zero, so the aim stays visible for
    // review until the player fires or starts a new drag.
    final freeze = widget.beginnerMode && launch && hasAimed;

    setState(() {
      if (!freeze) {
        _dragStart = null;
        _dragCurrent = null;
      }
      _trackingPointer = null;
    });
    widget.onActiveChanged?.call(false);
    if (!freeze && hasAimed) {
      final curved = CurvedAnimation(
        parent: _snapController,
        curve: Curves.elasticOut,
      );
      _snapAnimation = Tween<Offset>(
        begin: lastDelta,
        end: Offset.zero,
      ).animate(curved);
      _snapController.forward(from: 0);
    }
    if (launch) {
      if (widget.beginnerMode) {
        if (hasAimed) widget.controller.confirmAim();
      } else {
        widget.controller.launch();
      }
    }
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
      final effectiveDelta = _effectiveDragDelta;
      bool onTarget = false;
      if (effectiveDelta != null && targetBearing != null) {
        final aimBearing = computeBearing(effectiveDelta.dx, effectiveDelta.dy);
        final diff = ((aimBearing - targetBearing) + 360) % 360;
        onTarget = diff <= 20 || diff >= 340;
      }

      return Listener(
        // translucent: pointer events also reach the map beneath, so the map
        // can pan when the slingshot is not actively tracking.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (_trackingPointer != null) return; // already tracking
          final hitTest = widget.hitTestFn;
          if (hitTest != null && !hitTest(event.localPosition)) return;
          _trackingPointer = event.pointer;
          _startTracking(event.localPosition);
        },
        onPointerMove: (event) {
          if (event.pointer != _trackingPointer) return;
          _updateTracking(event.localPosition, maxPixels);
        },
        onPointerUp: (event) {
          if (event.pointer != _trackingPointer) return;
          _endTracking(launch: true);
        },
        onPointerCancel: (event) {
          if (event.pointer != _trackingPointer) return;
          _endTracking(launch: false);
        },
        child: Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SlingshotPainter(
                anchor: anchor,
                dragDelta: effectiveDelta,
                maxDragPixels: maxPixels,
                onTarget: onTarget,
              ),
            ),
            // "ON TARGET" flash label
            if (onTarget && effectiveDelta != null)
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

  /// Computes the band colour based on normalised pull power (0–1).
  /// 0–0.5 → white → amber; 0.5–1.0 → amber → red.
  static Color _bandColor(double power) {
    const white = Color(0xFFFFFFFF);
    const amber = Color(0xFFFFB300);
    const red = Color(0xFFE53935);
    if (power <= 0.5) {
      return Color.lerp(white, amber, power / 0.5)!;
    } else {
      return Color.lerp(amber, red, (power - 0.5) / 0.5)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Anchor circle
    canvas.drawCircle(
      anchor,
      16,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (dragDelta == null || dragDelta!.distance < 1) return;

    final power = computePower(dragDelta!.dx, dragDelta!.dy, maxDragPixels);
    final bandColor = _bandColor(power);

    // 2. Drag band — colour shifts with pull power
    canvas.drawLine(
      anchor,
      anchor + dragDelta!,
      Paint()
        ..color = bandColor.withValues(alpha: 0.85)
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
        : Colors.white.withValues(alpha: 0.75);
    final dotPaint = Paint()..color = dotColor;
    for (int i = 0; i < dots.length; i++) {
      // Gradually increase dot size toward destination when on target.
      final radius = onTarget ? (3.0 + i * 0.15) : 4.0;
      canvas.drawCircle(dots[i], radius, dotPaint);
    }

    // 4. Power arc
    final arcPaint = Paint()
      ..color = Color.lerp(Colors.green, Colors.red, power)!.withValues(alpha: 0.7)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: anchor, radius: 28),
      -math.pi / 2,
      2 * math.pi * power,
      false,
      arcPaint,
    );

    // 5. Power meter bar — 28px left of anchor, only while dragging
    const barWidth = 8.0;
    const barHeight = 80.0;
    const barOffsetLeft = 28.0;
    final barLeft = anchor.dx - barOffsetLeft - barWidth;
    final barTop = anchor.dy - barHeight / 2;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
      const Radius.circular(4),
    );
    // Background track
    canvas.drawRRect(
      barRect,
      Paint()..color = const Color(0x55FFFFFF),
    );
    // Fill from bottom upward
    final fillHeight = barHeight * power;
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barTop + barHeight - fillHeight, barWidth, fillHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      fillRect,
      Paint()..color = bandColor,
    );
  }

  @override
  bool shouldRepaint(_SlingshotPainter old) =>
      old.dragDelta != dragDelta ||
      old.anchor != anchor ||
      old.onTarget != onTarget ||
      old.maxDragPixels != maxDragPixels;
}
