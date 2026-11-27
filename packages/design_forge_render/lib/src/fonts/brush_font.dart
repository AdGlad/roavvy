import 'dart:convert';
import 'dart:ui' as ui;

import 'brush_font_data.dart';
import 'varsity_font.dart';

/// The embedded brush-marker typeface ("Permanent Marker", Apache 2.0) for
/// captions with `font: 'brush'`. Loaded from bytes compiled into the engine.
class BrushFont {
  const BrushFont._();

  static const String id = 'brush';
  static const String family = 'RoavvyBrush';

  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??=
      ui.loadFontFromList(base64Decode(kBrushFontBase64), fontFamily: family);
}

/// Resolves an embedded font id to a loaded family name (null = platform).
Future<String?> embeddedFontFamily(String? id) async {
  switch (id) {
    case BrushFont.id:
      await BrushFont.ensureLoaded();
      return BrushFont.family;
    case VarsityFont.id:
      await VarsityFont.ensureLoaded();
      return VarsityFont.family;
  }
  return null;
}
