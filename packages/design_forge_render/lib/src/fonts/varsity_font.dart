import 'dart:convert';
import 'dart:ui' as ui;

import 'varsity_font_data.dart';

/// The embedded varsity block typeface ("Graduate", SIL OFL 1.1) used by
/// `text` clips with `font: 'varsity'`. Loaded from bytes compiled into the
/// engine, so the Lab, the phone and headless tests draw identical letters.
class VarsityFont {
  const VarsityFont._();

  static const String id = 'varsity';
  static const String family = 'RoavvyVarsity';

  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??=
      ui.loadFontFromList(base64Decode(kVarsityFontBase64), fontFamily: family);
}
