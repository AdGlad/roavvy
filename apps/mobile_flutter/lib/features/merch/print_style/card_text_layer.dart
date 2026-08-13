import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../cards/card_text_renderer.dart';
import 'print_style.dart';
import 'print_style_pipeline.dart';

/// Composites a design's TITLE and FOOTER as an independent, always-legible
/// layer on top of finished (already print-styled) artwork bytes.
///
/// Why this exists: in the Auto-designs pipeline the flags/artwork are rendered
/// text-free, the destructive [PrintStylePipeline] passes (torn edge `dstOut`,
/// ripped-flag gash `dstIn`, halftone, distress erosion…) run on that artwork
/// ONLY, and then the title/footer are drawn here — AFTER the filter. As a
/// result the text can never be torn, gashed, halftoned or clipped: it always
/// appears in full.
///
/// A style can still *tint* the text (via [tone]) so it reads as part of the
/// design, but the tone is a colour-only filter — it re-colours glyph pixels,
/// it never removes them. The text zones mirror [CardTextRenderer]'s top title
/// zone and bottom branding zone, in the same logical space [CardImageRenderer]
/// renders in, so the overlay lands exactly where the reserved zones are.
abstract final class CardTextLayer {
  /// Logical card width used by `CardImageRenderer` (its `_logicalWidth`). Text
  /// zones are defined in this space and scaled to the artwork resolution.
  static const double _logicalWidth = 340.0;

  /// Whether [showTitle]/[showFooter] would draw anything at all.
  static bool wouldDraw({required bool showTitle, required bool showFooter}) =>
      showTitle || showFooter;

  /// Returns [artworkBytes] with the title/footer drawn on top as a separate
  /// full layer. When neither zone is shown the input bytes are returned
  /// unchanged (same instance), so the toggle-off path is free.
  ///
  /// [title] is the complete title label (e.g. `"1 COUNTRY"` before the
  /// renderer uppercases it). [countryCount]/[dateLabel]/[subtitleLine] feed the
  /// branding footer exactly as [CardTextRenderer.drawBranding] expects.
  /// [textColor] is the garment-matched ink. [tone] (optional) tints the text to
  /// match the print style; pass null for an untreated design.
  static Future<Uint8List> compose(
    Uint8List artworkBytes, {
    required bool showTitle,
    required bool showFooter,
    required String title,
    required int countryCount,
    String dateLabel = '',
    String? subtitleLine,
    required Color textColor,
    PrintStyleParams? tone,
  }) async {
    if (!showTitle && !showFooter) return artworkBytes;

    final codec = await ui.instantiateImageCodec(artworkBytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    try {
      final w = src.width;
      final h = src.height;
      if (w <= 0 || h <= 0) return artworkBytes;
      final scale = w / _logicalWidth;
      final logicalSize = Size(_logicalWidth, h / scale);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 1. The finished (styled) artwork underneath.
      canvas.drawImage(src, Offset.zero, Paint());

      // 2. Title/footer on top, in logical space, ALWAYS full. A colour-only
      //    tone filter (never alpha-removing) keeps the text on-style.
      canvas.save();
      canvas.scale(scale);
      final toneFilter =
          tone == null ? null : PrintStylePipeline.instance.toneColorFilter(tone);
      final zone = Rect.fromLTWH(0, 0, logicalSize.width, logicalSize.height);
      if (toneFilter != null) {
        canvas.saveLayer(zone, Paint()..colorFilter = toneFilter);
      }
      if (showTitle) {
        CardTextRenderer.drawTitle(
          canvas,
          logicalSize,
          title,
          textColor: textColor,
          stripColor: Colors.transparent,
        );
      }
      if (showFooter) {
        CardTextRenderer.drawBranding(
          canvas,
          logicalSize,
          countryCount: countryCount,
          dateLabel: dateLabel,
          subtitleLine: subtitleLine,
          textColor: textColor,
          stripColor: Colors.transparent,
        );
      }
      if (toneFilter != null) canvas.restore();
      canvas.restore();

      final picture = recorder.endRecording();
      final out = await picture.toImage(w, h);
      picture.dispose();
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      if (data == null) return artworkBytes;
      return data.buffer.asUint8List();
    } finally {
      src.dispose();
    }
  }
}
