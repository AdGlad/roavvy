import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'grid_math_engine.dart';

// ── GridClipShape ─────────────────────────────────────────────────────────────

/// Clip mask applied to the flag tile area in [GridFlagsCard].
///
/// `countryOutline` and `continentOutline` are defined here but remain
/// unimplemented until M171 — they silently fall back to `circle`.
enum GridClipShape {
  /// Rectangular grid — no clip applied (default).
  none,

  /// Heart-shaped mask using [MaskCalculator.heartPath] (M170).
  heart,

  /// Circular mask; diameter = min(width, height) × 0.92 (M170).
  circle,

  /// Country silhouette clip — single-country designs only (M171).
  countryOutline,

  /// Continent silhouette clip — continent-collection designs only (M171).
  continentOutline,

  /// National animal silhouette clip — single-country designs only.
  /// Path fetched from Firebase Storage via [AnimalSilhouetteService].
  animalSilhouette,

  /// National plant silhouette clip — single-country designs only.
  /// Path fetched from Firebase Storage via [AnimalSilhouetteService].
  plantSilhouette,

  /// National landmark silhouette clip — single-country designs only.
  /// Path fetched from Firebase Storage via [AnimalSilhouetteService].
  landmarkSilhouette,
}

// ── FlagGridLayoutMode ────────────────────────────────────────────────────────

/// Selects the algorithm used to position flags in a [GridFlagsCard].
///
/// All modes preserve each flag's natural aspect ratio and avoid truncation.
enum FlagGridLayoutMode {
  /// **Default.** Flags arranged in rows whose heights are computed so that
  /// each row fills the canvas width and all rows together fill the canvas
  /// height. No cropping; each flag is drawn at its natural proportion.
  packedRow,

  /// Each flag placed inside an identical rectangular cell using contain-fit
  /// (letterbox / object-fit:contain). Useful when a visually uniform grid
  /// is preferred. Flags with non-standard aspect ratios show small gutters.
  normalizedGrid,

  /// Greedy variable-width row packing: rows are built by accumulating flags
  /// until the row width approaches the canvas width, producing rows with
  /// varying numbers of flags. Heights are scaled so the full canvas is used.
  /// Results in a more dynamic, editorial layout.
  treemap,
}

// ── FlagGridTile ──────────────────────────────────────────────────────────────

/// A flag positioned within the final canvas.
class FlagGridTile {
  const FlagGridTile({required this.code, required this.rect});

  /// ISO 3166-1 alpha-2 country code (lowercase).
  final String code;

  /// Final canvas rect for this flag (already offset by [topOffset]).
  final Rect rect;
}

// ── FlagGridLayoutEngine ─────────────────────────────────────────────────────

/// Pure static factory: computes [FlagGridTile] positions for a [GridFlagsCard].
///
/// All algorithms:
/// - Preserve natural flag aspect ratios.
/// - Add [gutter] spacing between flags.
/// - Add [padding] around the full grid boundary.
/// - Fit entirely within [canvasSize] minus [topOffset]/[bottomOffset].
class FlagGridLayoutEngine {
  FlagGridLayoutEngine._();

  // Natural width:height for most flags (ISO flag-icons 4×3 set).
  static const double _defaultAr = 4.0 / 3.0;

  // Overrides for notable non-4:3 flags.
  static const Map<String, double> _arOverrides = {
    'ch': 1.0, // Switzerland — square
    'va': 1.0, // Vatican — square
    'np': 0.6413, // Nepal — tall
    'mc': 1.0, // Monaco — roughly square
    'ci': 1.0, // Côte d'Ivoire triband — effectively 3:2 but near 1
    'qa': 28 / 11, // Qatar — very wide
    'bh': 0.526, // Bahrain variant
  };

  static double _ar(String code) =>
      _arOverrides[code.toLowerCase()] ?? _defaultAr;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Computes tile rects for [codes] on a canvas of [canvasSize].
  ///
  /// [topOffset] and [bottomOffset] are the title and branding zone heights
  /// already reserved by the card; the grid fills the remaining space.
  ///
  /// [flagRepeatCount] — how many times each code appears (1–9). Codes are
  /// expanded and spread via the non-adjacency interleave algorithm so that
  /// identical flags are never adjacent where avoidable.
  static List<FlagGridTile> compute({
    required List<String> codes,
    required Size canvasSize,
    required double topOffset,
    required double bottomOffset,
    FlagGridLayoutMode mode = FlagGridLayoutMode.packedRow,
    double gutter = 2.0,
    double padding = 4.0,
    int flagRepeatCount = 1,
    int? rowCount,
  }) {
    if (codes.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
      return [];
    }

    final availH = canvasSize.height - topOffset - bottomOffset;
    if (availH <= 0) return [];

    final gridW = canvasSize.width - padding * 2;
    final gridH = availH - padding * 2;
    final originY = topOffset + padding;

    if (gridW <= 0 || gridH <= 0) return [];

    // For single-country row-based mode: compute colsPerRow from geometry so
    // every row is complete and flags render at their natural aspect ratio.
    // Then centre the flag block horizontally.
    int effectiveRepeat = flagRepeatCount;
    double originX = padding;
    if (rowCount != null && codes.length == 1 && mode == FlagGridLayoutMode.packedRow) {
      final R = rowCount;
      // Actual row height that _scaleRowsToFit will produce (fills gridH).
      final rowH = (gridH - gutter * (R - 1)) / R;
      if (rowH > 0) {
        final flagAR = _ar(codes[0]);
        // Pack as many flags per row as fit while staying inside gridW.
        // Each flag cell is flagAR × rowH wide (the gutter is baked into the
        // cell so the last column's trailing gap is counted as +gutter in the
        // numerator when testing fit).
        final colsPerRow = math.max(
          1,
          ((gridW + gutter) / (flagAR * rowH)).floor(),
        );
        effectiveRepeat = R * colsPerRow;
        // Centre: remaining whitespace split equally on left and right.
        final usedW = colsPerRow * flagAR * rowH - gutter;
        originX = padding + (gridW - usedW) / 2;
      }
    }

    // Expand codes by repeat count and spread to avoid adjacency.
    final expanded = effectiveRepeat > 1
        ? _expandAndSpread(codes, effectiveRepeat)
        : List<String>.from(codes);

    final grid = Size(gridW, gridH);

    return switch (mode) {
      FlagGridLayoutMode.packedRow => _packedRow(
        expanded,
        grid,
        originX,
        originY,
        gutter,
        rowCount: rowCount,
      ),
      FlagGridLayoutMode.normalizedGrid => _normalizedGrid(
        expanded,
        grid,
        originX,
        originY,
        gutter,
      ),
      FlagGridLayoutMode.treemap => _treemap(
        expanded,
        grid,
        originX,
        originY,
        gutter,
      ),
    };
  }

  /// Expands [codes] by [repeat] times and shuffles them into a random order.
  ///
  /// Uses a deterministic seed derived from the code list and repeat count so
  /// the layout is stable across repaints (no flickering) while appearing
  /// random rather than sequential (A,B,C,A,B,C…).
  ///
  /// For a single country all tiles are identical — ordering has no effect.
  static List<String> _expandAndSpread(List<String> codes, int repeat) {
    if (codes.isEmpty) return [];
    if (codes.length == 1) {
      return List.filled(repeat, codes.first);
    }

    // Build the full repeated list.
    final expanded = <String>[];
    for (final code in codes) {
      for (int i = 0; i < repeat; i++) {
        expanded.add(code);
      }
    }

    // Shuffle with a deterministic seed so the layout is stable across
    // repaints within a session but looks random, not sequential.
    final seed =
        codes.fold<int>(17, (h, c) => h * 31 + c.hashCode) ^
        (repeat * 0x9e3779b9);
    expanded.shuffle(math.Random(seed));
    return expanded;
  }

  /// Returns a representative tile width for SVG pre-loading at any mode.
  ///
  /// All three algorithms ultimately render flags at a size proportional to
  /// sqrt(gridArea / n), so this gives a cache-friendly single target size.
  static double representativeTileWidth(Size gridSize, int n) {
    if (n <= 0 || gridSize.width <= 0 || gridSize.height <= 0) return 60.0;
    return math.sqrt(gridSize.width * gridSize.height / n).clamp(30.0, 200.0);
  }

  // ── Packed Row ─────────────────────────────────────────────────────────────

  /// Divides [codes] into roughly equal-count rows; scales row heights so all
  /// rows together fill [grid.height] exactly. Each row fills [grid.width].
  static List<FlagGridTile> _packedRow(
    List<String> codes,
    Size grid,
    double originX,
    double originY,
    double gutter, {
    int? rowCount,
  }) {
    final n = codes.length;
    // Number of rows: use forced rowCount when provided (uniform rows), otherwise
    // aim for a visually square overall grid.
    final R = rowCount ?? math.max(1, math.sqrt(n * grid.height / grid.width).round());

    // Chunk into R sequential rows.
    final rows = _chunkIntoRows(codes, R);

    return _scaleRowsToFit(rows, grid, originX, originY, gutter);
  }

  // ── Normalized Grid ────────────────────────────────────────────────────────

  /// Places each flag inside an identical cell using contain-fit. Cells are
  /// computed from [gridLayout] (existing square-cell math).
  static List<FlagGridTile> _normalizedGrid(
    List<String> codes,
    Size grid,
    double originX,
    double originY,
    double gutter,
  ) {
    final layout = gridLayout(grid, codes.length);
    if (layout.cols == 0 || layout.rows == 0) return [];

    // Cells distribute evenly, leaving gutters between them.
    final cellW = (grid.width - gutter * (layout.cols - 1)) / layout.cols;
    final cellH = (grid.height - gutter * (layout.rows - 1)) / layout.rows;

    final tiles = <FlagGridTile>[];
    final visible = math.min(codes.length, layout.cols * layout.rows);
    for (int i = 0; i < visible; i++) {
      final r = i ~/ layout.cols;
      final c = i % layout.cols;
      tiles.add(
        FlagGridTile(
          code: codes[i],
          rect: Rect.fromLTWH(
            originX + c * (cellW + gutter),
            originY + r * (cellH + gutter),
            math.max(1, cellW),
            math.max(1, cellH),
          ),
        ),
      );
    }
    return tiles;
  }

  // ── Treemap (greedy variable-width rows) ───────────────────────────────────

  /// Greedily packs flags into rows by accumulating flags until the
  /// scaled row width would noticeably exceed [grid.width]. Produces rows
  /// with varying flag counts, giving an editorial magazine layout.
  static List<FlagGridTile> _treemap(
    List<String> codes,
    Size grid,
    double originX,
    double originY,
    double gutter,
  ) {
    if (codes.isEmpty) return [];

    // Target row height so that rows roughly fill the canvas.
    final sumAr = codes.map(_ar).fold<double>(0, (a, b) => a + b);
    final targetH = math.sqrt(grid.width * grid.height / sumAr);

    // Greedily group into rows.
    final rows = <List<String>>[];
    var current = <String>[];
    double currentW = 0;
    for (final code in codes) {
      final w = _ar(code) * targetH;
      // Start a new row when adding this flag would exceed 110% of grid width.
      if (current.isNotEmpty && currentW + w > grid.width * 1.10) {
        rows.add(current);
        current = [code];
        currentW = w;
      } else {
        current.add(code);
        currentW += w;
      }
    }
    if (current.isNotEmpty) rows.add(current);

    return _scaleRowsToFit(rows, grid, originX, originY, gutter);
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Splits [codes] into [R] sequential chunks of as-equal-as-possible size.
  static List<List<String>> _chunkIntoRows(List<String> codes, int R) {
    final n = codes.length;
    final chunkSize = (n / R).ceil();
    final rows = <List<String>>[];
    for (int i = 0; i < n; i += chunkSize) {
      rows.add(codes.sublist(i, math.min(i + chunkSize, n)));
    }
    return rows;
  }

  /// Scales the row heights so they sum to [grid.height], then assigns rects.
  ///
  /// For each row, natural height = (grid.width − internal gutters) / ΣAR.
  /// All natural heights are multiplied by a common scale so their total
  /// (plus inter-row gutters) equals [grid.height].
  static List<FlagGridTile> _scaleRowsToFit(
    List<List<String>> rows,
    Size grid,
    double originX,
    double originY,
    double gutter,
  ) {
    if (rows.isEmpty) return [];

    // Compute natural height for each row.
    final naturalHeights = <double>[];
    for (final row in rows) {
      final sumAr = row.map(_ar).fold<double>(0, (a, b) => a + b);
      final innerGutterW = gutter * (row.length - 1);
      final h = sumAr > 0 ? (grid.width - innerGutterW) / sumAr : 1.0;
      naturalHeights.add(h);
    }

    // Scale so all row heights + inter-row gutters = grid.height.
    final totalNaturalH = naturalHeights.fold<double>(0, (a, b) => a + b);
    final interRowGutters = gutter * (rows.length - 1);
    final scale =
        totalNaturalH > 0
            ? (grid.height - interRowGutters) / totalNaturalH
            : 1.0;

    // Assign rects.
    final tiles = <FlagGridTile>[];
    double y = originY;
    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      final rowH = naturalHeights[r] * scale;
      double x = originX;
      for (final code in row) {
        final w = _ar(code) * rowH;
        tiles.add(
          FlagGridTile(
            code: code,
            rect: Rect.fromLTWH(
              x,
              y,
              math.max(1.0, w - gutter),
              math.max(1.0, rowH - gutter),
            ),
          ),
        );
        x += w;
      }
      y += rowH + gutter;
    }
    return tiles;
  }
}
