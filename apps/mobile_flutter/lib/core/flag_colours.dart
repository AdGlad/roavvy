import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Extracts up to 4 non-white fill colours from a bundled flag SVG.
///
/// Returns null when the asset cannot be loaded or no qualifying colours
/// are found (caller falls back to theme colours).
Future<List<Color>?> flagColours(String isoCode) async {
  try {
    final svg = await rootBundle.loadString(
        'assets/flags/svg/${isoCode.toLowerCase()}.svg');
    final re = RegExp(r'fill="(#[0-9a-fA-F]{6})"');
    final colours = re
        .allMatches(svg)
        .map((m) {
          final hex = m.group(1)!.substring(1);
          return Color(0xFF000000 | int.parse(hex, radix: 16));
        })
        .toSet()
        .where((c) {
          // Filter out white and near-white (lightness > 0.90).
          final hsl = HSLColor.fromColor(c);
          return hsl.lightness <= 0.90;
        })
        .take(4)
        .toList();
    return colours.length >= 2 ? colours : null;
  } catch (_) {
    return null;
  }
}
