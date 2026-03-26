import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'passport_stamp_model.dart';
import 'stamp_typography_painter.dart';

/// Applies rare visual artefacts to passport stamps for realism (ADR-097 Decision 6).
///
/// All probabilities are checked independently and deterministically from the
/// stamp seed, so the same stamp always has the same artefacts.
///
/// Artefacts are disabled when [StampRenderConfig.enableRareArtefacts] is false.
class RareArtefactEngine {
  RareArtefactEngine._();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Apply rare artefacts to [canvas] at [stampCenter] for [stamp].
  ///
  /// Must be called after the stamp has been composited onto the main canvas.
  /// [stampRadius] is the base radius of the stamp (before scale).
  static void apply(
    Canvas canvas,
    StampData stamp,
    Offset stampCenter,
    double stampRadius,
  ) {
    if (!stamp.renderConfig.enableRareArtefacts) return;

    final rng = math.Random(stamp.seed ^ 0xAE73);

    // Each artefact is checked independently using successive random values.
    _maybeDoubleStampGhost(canvas, stamp, stampCenter, stampRadius, rng);
    _maybePartialStamp(canvas, stamp, stampCenter, stampRadius, rng);
    _maybeInkBlob(canvas, stamp, stampCenter, stampRadius, rng);
    _maybeSmudge(canvas, stamp, stampCenter, stampRadius, rng);
    _maybeCorrectionStamp(canvas, stamp, stampCenter, stampRadius, rng);
  }

  // ── Artefact implementations ────────────────────────────────────────────────

  /// Double-stamp ghost: 5% chance — redraws a thin offset version of the
  /// stamp border at 20% opacity.
  static void _maybeDoubleStampGhost(
    Canvas canvas,
    StampData stamp,
    Offset center,
    double r,
    math.Random rng,
  ) {
    if (rng.nextDouble() >= 0.05) return;

    final offsetX = (rng.nextDouble() * 2 - 1) * 3.0; // ±3px
    final offsetY = (rng.nextDouble() * 2 - 1) * 3.0;
    final ghostCenter = center + Offset(offsetX, offsetY);
    final ghostColor = stamp.inkColor.withValues(alpha: stamp.inkColor.a * 0.20);

    canvas.drawCircle(
      ghostCenter,
      r,
      Paint()
        ..color = ghostColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Partial stamp: 3% chance — clips 10–30% of the stamp area.
  ///
  /// The clip is saved/restored so it only affects the artefact paint layer.
  /// In practice this would need to wrap the full stamp paint call, so here
  /// we simulate it by drawing a semi-transparent filled rect that "erases"
  /// a portion of the edge, using [BlendMode.clear].
  static void _maybePartialStamp(
    Canvas canvas,
    StampData stamp,
    Offset center,
    double r,
    math.Random rng,
  ) {
    if (rng.nextDouble() >= 0.03) return;

    final cropFraction = 0.10 + rng.nextDouble() * 0.20; // 10–30%
    final cropSize = r * 2 * cropFraction;

    // Randomly select which edge to crop
    final edge = rng.nextInt(4); // 0=top, 1=right, 2=bottom, 3=left
    final Rect cropRect;
    switch (edge) {
      case 0: // top
        cropRect = Rect.fromLTWH(
            center.dx - r, center.dy - r, r * 2, cropSize);
      case 1: // right
        cropRect = Rect.fromLTWH(
            center.dx + r - cropSize, center.dy - r, cropSize, r * 2);
      case 2: // bottom
        cropRect = Rect.fromLTWH(
            center.dx - r, center.dy + r - cropSize, r * 2, cropSize);
      default: // left
        cropRect = Rect.fromLTWH(
            center.dx - r, center.dy - r, cropSize, r * 2);
    }

    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.transparent
        ..blendMode = BlendMode.clear,
    );
  }

  /// Heavy ink blob: 2% chance — filled circle 3–6px at stamp centre.
  static void _maybeInkBlob(
    Canvas canvas,
    StampData stamp,
    Offset center,
    double r,
    math.Random rng,
  ) {
    if (rng.nextDouble() >= 0.02) return;

    final blobRadius = 1.5 + rng.nextDouble() * 1.5; // 1.5–3px radius
    final blobOffset = Offset(
      (rng.nextDouble() * 2 - 1) * r * 0.3,
      (rng.nextDouble() * 2 - 1) * r * 0.3,
    );

    canvas.drawCircle(
      center + blobOffset,
      blobRadius,
      Paint()
        ..color = stamp.inkColor.withValues(alpha: stamp.inkColor.a * 0.80)
        ..style = PaintingStyle.fill,
    );
  }

  /// Smudge streak: 2% chance — blurred thin rect simulating an ink drag.
  static void _maybeSmudge(
    Canvas canvas,
    StampData stamp,
    Offset center,
    double r,
    math.Random rng,
  ) {
    if (rng.nextDouble() >= 0.02) return;

    final angle = rng.nextDouble() * math.pi; // random direction
    final length = r * (0.3 + rng.nextDouble() * 0.5);
    final smudgePaint = Paint()
      ..color = stamp.inkColor.withValues(alpha: stamp.inkColor.a * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final start = center + Offset(
      math.cos(angle) * length * 0.5,
      math.sin(angle) * length * 0.5,
    );
    final end = center - Offset(
      math.cos(angle) * length * 0.5,
      math.sin(angle) * length * 0.5,
    );

    canvas.drawLine(start, end, smudgePaint);
  }

  /// Correction stamp: 1% chance — small "VOID" text at 40% opacity.
  static void _maybeCorrectionStamp(
    Canvas canvas,
    StampData stamp,
    Offset center,
    double r,
    math.Random rng,
  ) {
    if (rng.nextDouble() >= 0.01) return;

    final voidOffset = Offset(
      (rng.nextDouble() * 2 - 1) * r * 0.4,
      (rng.nextDouble() * 2 - 1) * r * 0.4,
    );
    final voidColor = stamp.inkColor.withValues(alpha: stamp.inkColor.a * 0.40);

    StampTypographyPainter.drawCondensedLabel(
      canvas,
      'VOID',
      voidColor,
      7.0 * stamp.scale,
      center + voidOffset,
      stamp.seed ^ 0xC0DE,
      weight: FontWeight.w900,
    );
  }
}
