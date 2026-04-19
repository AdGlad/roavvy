import 'dart:math' as math;

import 'package:flutter/painting.dart';

// ── GridLayout ────────────────────────────────────────────────────────────────

/// Result of [gridLayout] — the geometry for a [GridFlagsCard] tile grid.
class GridLayout {
  const GridLayout({
    required this.cols,
    required this.rows,
    required this.tileSize,
    required this.overflow,
  });

  /// Number of tiles per row.
  final int cols;

  /// Number of tile rows needed to display all visible flags.
  final int rows;

  /// Side length of each square tile in logical pixels, clamped to [28, 90].
  final double tileSize;

  /// Number of flags that exceed the 40-tile cap and are not displayed.
  final int overflow;

  /// Returned when [n] == 0 or the canvas has zero area.
  static const empty = GridLayout(cols: 0, rows: 0, tileSize: 0, overflow: 0);
}

// ── gridLayout ────────────────────────────────────────────────────────────────

/// Aspect-ratio-aware tile geometry for a grid of [n] flags on [canvasSize]
/// (ADR-118).
///
/// Algorithm:
/// 1. `cols = max(1, ⌈sqrt(n × width / height)⌉)`
/// 2. `tileSize = clamp(width / cols, 28, 90)`
/// 3. `rows = ⌈n / cols⌉`
/// 4. `overflow = max(0, n − 40)`   (max 40 visible flags)
///
/// Returns [GridLayout.empty] when [n] == 0 or the canvas has zero area.
GridLayout gridLayout(Size canvasSize, int n) {
  if (n <= 0 || canvasSize.width <= 0 || canvasSize.height <= 0) {
    return GridLayout.empty;
  }

  final cols =
      math.max(1, (math.sqrt(n * canvasSize.width / canvasSize.height)).ceil());
  final tileSize = (canvasSize.width / cols).clamp(28.0, 90.0);
  final rows = (n / cols).ceil();
  final overflow = math.max(0, n - 40);

  return GridLayout(
    cols: cols,
    rows: rows,
    tileSize: tileSize,
    overflow: overflow,
  );
}
