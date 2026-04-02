import 'package:flutter/material.dart';

/// A product-ready branding strip rendered at the bottom of every card
/// template. Contains the Roavvy wordmark, country count, and an optional
/// date-range label.
///
/// [dateLabel] — pre-computed date range string (e.g. `"2024"` or
/// `"2018–2024"`). Pass an empty string to omit the date label entirely.
///
/// Used by [GridFlagsCard], [HeartFlagsCard], and [PassportStampsCard]
/// (ADR-101). Visible in the PNG captured by [CardImageRenderer].
class CardBrandingFooter extends StatelessWidget {
  const CardBrandingFooter({
    super.key,
    required this.countryCount,
    required this.dateLabel,
    this.textColor = const Color(0xFFD4A017),
    this.backgroundColor = Colors.transparent,
  });

  final int countryCount;

  /// Date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string → date label not rendered.
  final String dateLabel;

  /// Colour used for wordmark, count, and date label. Defaults to amber.
  final Color textColor;

  /// Background colour of the footer strip. Defaults to transparent.
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 5),
      child: Row(
        children: [
          Text(
            'ROAVVY',
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$countryCount countries',
              style: TextStyle(color: textColor, fontSize: 9),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              dateLabel,
              style: TextStyle(color: textColor, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}
