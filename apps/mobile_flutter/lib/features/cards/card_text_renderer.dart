import 'package:flutter/material.dart';

/// Shared canvas-based text renderer used by all card templates.
///
/// Draws a top title zone and a bottom branding zone (ROAVVY wordmark + country
/// count + optional date) directly onto a [Canvas]. Both zones use a fixed
/// height so all templates reserve identical space — flags / stamps must be
/// laid out in the area between [titleZoneH] and
/// `size.height − brandingZoneH`.
///
/// This is the single source of truth for card typography (the PassportStamps
/// card was the original reference). Grid, Heart, and Timeline templates
/// delegate here rather than reimplementing their own text logic.
abstract final class CardTextRenderer {
  /// Height of the top title zone in logical pixels.
  static const double titleZoneH = 28.0;

  /// Height of the bottom branding zone in logical pixels.
  static const double brandingZoneH = 20.0;

  /// Default text colour used when no override is provided.
  static const Color defaultTextColor = Color(0xFFD4A017);

  /// Default semi-transparent strip colour for both zones.
  static const Color defaultStripColor = Color(0xBB0D2137);

  // ── Title zone ──────────────────────────────────────────────────────────────

  /// Draws the top title zone: a solid [stripColor] band followed by a centred
  /// uppercase title in [textColor].
  ///
  /// [title] is the complete label string (e.g. `"12 Countries · 2024"`). It
  /// is rendered uppercase with letter-spacing of 2.
  static void drawTitle(
    Canvas canvas,
    Size size,
    String title, {
    Color textColor = defaultTextColor,
    Color stripColor = defaultStripColor,
  }) {
    // Background strip.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, titleZoneH),
      Paint()..color = stripColor,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: title.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 24);

    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (titleZoneH - tp.height) / 2,
      ),
    );
  }

  // ── Branding zone ───────────────────────────────────────────────────────────

  /// Draws the bottom branding zone: a solid [stripColor] band followed by the
  /// ROAVVY wordmark, country count (or [customLabel]), and optional date.
  ///
  /// When [customLabel] is non-null and non-empty it replaces the
  /// auto-generated `"{N} countries"` string (ADR-120).
  static void drawBranding(
    Canvas canvas,
    Size size, {
    required int countryCount,
    required String dateLabel,
    String? customLabel,
    Color textColor = defaultTextColor,
    Color stripColor = defaultStripColor,
  }) {
    final top = size.height - brandingZoneH;

    // Background strip.
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, brandingZoneH),
      Paint()..color = stripColor,
    );

    const fontSize = 9.0;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      decoration: TextDecoration.none,
      color: textColor,
    );

    final countText = (customLabel != null && customLabel.isNotEmpty)
        ? customLabel
        : '$countryCount ${countryCount == 1 ? 'country' : 'countries'}';

    final tpRoavvy = TextPainter(
      text: TextSpan(
        text: 'ROAVVY',
        style: baseStyle.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tpCount = TextPainter(
      text: TextSpan(text: countText, style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final textY = top + (brandingZoneH - tpRoavvy.height) / 2;

    tpRoavvy.paint(canvas, Offset(10, textY));
    tpCount.paint(canvas, Offset(10 + tpRoavvy.width + 8, textY));

    if (dateLabel.isNotEmpty) {
      final tpDate = TextPainter(
        text: TextSpan(text: dateLabel, style: baseStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpDate.paint(
        canvas,
        Offset(10 + tpRoavvy.width + 8 + tpCount.width + 6, textY),
      );
    }
  }
}
