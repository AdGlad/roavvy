import 'dart:math' as math;

class GridMathResult {
  const GridMathResult({
    required this.columns,
    required this.rows,
    required this.itemWidth,
    required this.itemHeight,
  });

  final int columns;
  final int rows;
  final double itemWidth;
  final double itemHeight;
}

class GridMathEngine {
  /// Calculates the optimal grid layout to fit [itemCount] items of a given
  /// [itemAspectRatio] into a bounding box of [width] x [height].
  static GridMathResult calculate({
    required double width,
    required double height,
    required int itemCount,
    double itemAspectRatio = 4.0 / 3.0,
  }) {
    if (itemCount <= 0 || width <= 0 || height <= 0) {
      return const GridMathResult(
        columns: 0,
        rows: 0,
        itemWidth: 0,
        itemHeight: 0,
      );
    }

    int bestCols = 1;
    int bestRows = itemCount;
    double maxItemWidth = 0;

    for (int cols = 1; cols <= itemCount; cols++) {
      final rows = (itemCount / cols).ceil();
      final itemWidthByCols = width / cols;
      final itemWidthByRows = (height / rows) * itemAspectRatio;
      final effectiveItemWidth = math.min(itemWidthByCols, itemWidthByRows);

      if (effectiveItemWidth > maxItemWidth) {
        maxItemWidth = effectiveItemWidth;
        bestCols = cols;
        bestRows = rows;
      } else if (effectiveItemWidth == maxItemWidth) {
        // Tie-breaker: prefer fewer rows for a wider/more horizontal grid if sizes are equal
        if (rows < bestRows) {
          bestCols = cols;
          bestRows = rows;
        }
      }
    }

    return GridMathResult(
      columns: bestCols,
      rows: bestRows,
      itemWidth: maxItemWidth,
      itemHeight: maxItemWidth / itemAspectRatio,
    );
  }
}
