import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'region_detail_sheet.dart';
import 'region_progress_notifier.dart';

// ── RegionChipsMarkerLayer ────────────────────────────────────────────────────

/// Renders floating progress chips at region centroids on the [FlutterMap]
/// canvas (ADR-069).
///
/// Chips are only visible at zoom ≥ 4.0. Below that zoom level an empty
/// [MarkerLayer] is returned to avoid cluttering the map.
///
/// Each chip shows "N/M [Region]" with a circular arc progress ring.
/// Tapping a chip opens [showRegionDetailSheet].
class RegionChipsMarkerLayer extends ConsumerWidget {
  const RegionChipsMarkerLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = MapCamera.of(context);
    if (camera.zoom < 4.0) {
      return const MarkerLayer(markers: []);
    }

    final regions = ref.watch(regionProgressProvider);
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final visits = visitsAsync.valueOrNull ?? const <EffectiveVisitedCountry>[];

    final markers = regions.map((data) {
      return Marker(
        point: data.centroid,
        width: 80,
        height: 40,
        child: GestureDetector(
          onTap: () => showRegionDetailSheet(context, data, visits),
          child: _RegionChip(data: data),
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}

// ── Chip widget ───────────────────────────────────────────────────────────────

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.data});

  final RegionProgressData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFB300), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Arc progress ring
          SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ArcPainter(fraction: data.ratio, isComplete: data.isComplete),
            ),
          ),
          const SizedBox(width: 4),
          // Label
          Flexible(
            child: Text(
              '${data.visitedCount}/${data.totalCount}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arc progress CustomPainter ────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.fraction, required this.isComplete});

  final double fraction;
  final bool isComplete;

  static const _amber = Color(0xFFFFB300);
  static const _amberDark = Color(0xFFFF8F00);
  static const _grey = Color(0xFFE0E0E0);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (math.min(size.width, size.height) / 2) - 2;
    final strokeWidth = 2.5;

    // Background ring
    final bgPaint = Paint()
      ..color = _grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    if (fraction <= 0) return;

    if (isComplete) {
      // Full ring in amber
      final completePaint = Paint()
        ..color = _amberDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(Offset(cx, cy), radius, completePaint);

      // Checkmark
      final checkPaint = Paint()
        ..color = _amberDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = ui.Path()
        ..moveTo(cx - 4, cy)
        ..lineTo(cx - 1, cy + 3)
        ..lineTo(cx + 5, cy - 4);
      canvas.drawPath(path, checkPaint);
    } else {
      // Partial arc
      final arcPaint = Paint()
        ..color = _amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // top of circle
      final sweepAngle = 2 * math.pi * fraction.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.isComplete != isComplete;
}
