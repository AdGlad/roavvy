import 'package:flutter/material.dart';

/// Stamp color mode for passport card t-shirt orders.
/// Shared between [CardEditorScreen] and [LocalMockupPreviewScreen].
enum PassportColorMode { multicolor, black, white }

extension PassportColorParams on PassportColorMode {
  Color? get stampColor => switch (this) {
    PassportColorMode.multicolor => null,
    PassportColorMode.black      => const Color(0xFF1A1A1A),
    PassportColorMode.white      => Colors.white,
  };

  Color? get dateColor => switch (this) {
    PassportColorMode.multicolor => null,
    PassportColorMode.black      => const Color(0xFF1A1A1A),
    PassportColorMode.white      => Colors.white,
  };

  bool get transparentBackground => this == PassportColorMode.white;
}
