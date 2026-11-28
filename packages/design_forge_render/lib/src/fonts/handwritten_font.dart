import 'dart:convert';
import 'dart:ui' as ui;

import 'handwritten_font_data.dart';

/// The embedded casual handwritten marker typeface ("Kalam" Regular, SIL OFL
/// 1.1, Latin subset) for captions with `font: 'handwritten'` — the Brush
/// Flag signature's country name. Loaded from bytes compiled into the engine.
class HandwrittenFont {
  const HandwrittenFont._();

  static const String id = 'handwritten';
  static const String family = 'RoavvyHandwritten';

  static Future<void>? _loading;

  static Future<void> ensureLoaded() =>
      _loading ??= ui.loadFontFromList(base64Decode(kHandwrittenFontBase64),
          fontFamily: family);
}
