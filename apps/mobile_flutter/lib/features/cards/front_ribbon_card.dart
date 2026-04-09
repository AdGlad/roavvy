import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'flag_tile_renderer.dart';
import 'heart_layout_engine.dart'; // for HeartTilePosition

class FrontRibbonCard extends StatelessWidget {
  const FrontRibbonCard({
    super.key,
    required this.countryCodes,
    required this.travelerLevel,
    this.textColor = Colors.white,
    this.maxPerRow = 8,
  });

  final List<String> countryCodes;
  final String travelerLevel;
  final Color textColor;
  final int maxPerRow;

  @override
  Widget build(BuildContext context) {
    if (countryCodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Assume the parent provides a constrained width.
        final w = constraints.maxWidth;
        if (w <= 0 || w.isInfinite) {
          return const SizedBox.shrink();
        }

        final tileWidth = w / maxPerRow;
        final tileHeight = tileWidth * (3.0 / 4.0);
        final rows = (countryCodes.length / maxPerRow).ceil();
        final gridHeight = rows * tileHeight;

        // Branding and status areas proportional to the width
        final topHeight = w * 0.14;
        final bottomHeight = w * 0.14;

        final totalHeight = topHeight + gridHeight + bottomHeight;

        return AspectRatio(
          aspectRatio: w / totalHeight,
          child: CustomPaint(
            size: Size(w, totalHeight),
            painter: _RibbonPainter(
              countryCodes: countryCodes,
              travelerLevel: travelerLevel,
              textColor: textColor,
              maxPerRow: maxPerRow,
              topHeight: topHeight,
              bottomHeight: bottomHeight,
              tileWidth: tileWidth,
              tileHeight: tileHeight,
              rows: rows,
            ),
          ),
        );
      },
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({
    required this.countryCodes,
    required this.travelerLevel,
    required this.textColor,
    required this.maxPerRow,
    required this.topHeight,
    required this.bottomHeight,
    required this.tileWidth,
    required this.tileHeight,
    required this.rows,
  });

  final List<String> countryCodes;
  final String travelerLevel;
  final Color textColor;
  final int maxPerRow;
  final double topHeight;
  final double bottomHeight;
  final double tileWidth;
  final double tileHeight;
  final int rows;

  static final _sharedCache = FlagImageCache();

  @override
  void paint(Canvas canvas, Size size) {
    if (countryCodes.isEmpty) return;

    // 1. Draw top branding (ROAVVY)
    final tpTop = TextPainter(
      text: TextSpan(
        text: 'ROAVVY',
        style: TextStyle(
          color: textColor,
          fontSize: topHeight * 0.45,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    tpTop.paint(
      canvas,
      Offset((size.width - tpTop.width) / 2, (topHeight - tpTop.height) / 2),
    );

    // 2. Draw Flag Grid
    // Flags are drawn row by row. If the last row is not full, center it.
    int index = 0;
    final gridStartY = topHeight;

    for (int r = 0; r < rows; r++) {
      int itemsInThisRow = maxPerRow;
      if (r == rows - 1) {
        itemsInThisRow = countryCodes.length - (r * maxPerRow);
      }

      final rowWidth = tileWidth * itemsInThisRow;
      final startX = (size.width - rowWidth) / 2.0;

      for (int c = 0; c < itemsInThisRow; c++) {
        final code = countryCodes[index];
        final rect = Rect.fromLTWH(
          startX + c * tileWidth,
          gridStartY + r * tileHeight,
          tileWidth,
          tileHeight,
        );

        final tile = HeartTilePosition(rect: rect, countryCode: code);
        // Using a 1px gap internally, proportionally scaled to tile width?
        // Since tile width varies, let's keep gapWidth absolute or proportional.
        // A gap of 1 logical pixel is fine if rendered large, but for ribbons,
        // it might be nice to have proportional. Let's stick to 1.0 gap.
        final gap = math.max(1.0, tileWidth * 0.02);

        FlagTileRenderer.renderFromCache(
          canvas,
          tile,
          _sharedCache,
          cornerRadius: gap, // slight rounding
          gapWidth: gap,
        );

        index++;
      }
    }

    // 3. Draw bottom traveler level
    final tpBottom = TextPainter(
      text: TextSpan(
        text: travelerLevel.toUpperCase(),
        style: TextStyle(
          color: textColor.withValues(alpha: 0.9),
          fontSize: bottomHeight * 0.35,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bottomStartY = topHeight + (rows * tileHeight);
    tpBottom.paint(
      canvas,
      Offset(
        (size.width - tpBottom.width) / 2,
        bottomStartY + (bottomHeight - tpBottom.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.countryCodes != countryCodes ||
      old.travelerLevel != travelerLevel ||
      old.textColor != textColor ||
      old.maxPerRow != maxPerRow;
}
