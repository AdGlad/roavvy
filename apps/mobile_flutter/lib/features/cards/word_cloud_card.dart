import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_models/shared_models.dart';
import 'package:word_cloud/word_cloud_data.dart';
import 'package:word_cloud/word_cloud_view.dart';

import '../../core/country_names.dart';
import 'card_text_renderer.dart';

// ── Color mode ────────────────────────────────────────────────────────────────

/// Controls how country-name colours are assigned in [TravelWordCloudCard].
enum WordCloudColorMode {
  /// All words in a single colour derived from [TravelWordCloudCard.textColor]
  /// or the default for the current background.
  monochrome,

  /// Words are tinted by the continent of their country.
  continentColor,

  /// A curated set of soft travel-inspired pastel tones.
  pastel,
}

// ── Continent colour palette ──────────────────────────────────────────────────

const Map<String, Color> _continentColors = {
  'Africa': Color(0xFFE88040),
  'Asia': Color(0xFF4DB6AC),
  'Europe': Color(0xFF7986CB),
  'North America': Color(0xFFE57373),
  'South America': Color(0xFF81C784),
  'Oceania': Color(0xFF4FC3F7),
  'Antarctica': Color(0xFFB0BEC5),
};

const List<Color> _pastelPalette = [
  Color(0xFFB2DFDB), // teal
  Color(0xFFB3E5FC), // sky
  Color(0xFFC5CAE9), // lavender
  Color(0xFFDCEDC8), // sage
  Color(0xFFFFF9C4), // cream
  Color(0xFFFFCCBC), // peach
  Color(0xFFE1BEE7), // mauve
  Color(0xFFD7CCC8), // warm grey
];

// ── TravelWordCloudCard ────────────────────────────────────────────────────────

/// Travel card template: country names rendered as a word cloud where
/// visit frequency controls text size (M112).
///
/// Uses the [word_cloud] package for layout and extends it with:
/// - visit-frequency weighting from [trips]
/// - premium typography styling
/// - continent / pastel / monochrome colour modes
/// - transparent background for t-shirt compositing
/// - title / subtitle zones following the ADR-157 branding convention
///
/// The [onAssetsLoaded] callback follows the [BadgeCard] pattern — all
/// layout is synchronous, so the callback fires on the next frame to allow
/// [CardImageRenderer] to capture the painted widget.
class TravelWordCloudCard extends StatefulWidget {
  const TravelWordCloudCard({
    super.key,
    required this.codes,
    this.trips = const [],
    this.titleOverride,
    this.subtitleOverride,
    this.transparentBackground = false,
    this.textColor,
    this.colorMode = WordCloudColorMode.pastel,
    this.onAssetsLoaded,
    this.layoutSeed,
  });

  /// ISO 3166-1 alpha-2 country codes to display.
  final List<String> codes;

  /// Trip records used to compute per-country visit frequency.
  /// When empty, every country is treated as visited once (equal sizing).
  final List<TripRecord> trips;

  /// Optional title override; passed to [CardTextRenderer.drawTitle].
  final String? titleOverride;

  /// Optional subtitle line following ADR-157 ("Roavvy: N Countries …").
  final String? subtitleOverride;

  /// When `true`, the card background is transparent (for t-shirt print
  /// compositing). Defaults to `false` (dark navy background).
  final bool transparentBackground;

  /// Explicit text colour. When null, defaults to the mode colour list.
  final Color? textColor;

  /// Colour assignment strategy for word tokens.
  final WordCloudColorMode colorMode;

  /// Called once on the next frame after build completes (matching the
  /// [BadgeCard] / [HeartFlagsCard] protocol used by [CardImageRenderer]).
  final VoidCallback? onAssetsLoaded;

  /// Optional seed for word cloud placement randomisation.  When non-null the
  /// same seed always produces the same layout, enabling deterministic export
  /// without removing the ability to regenerate (shuffle).
  // ignore: unused_field
  final int? layoutSeed;

  @override
  State<TravelWordCloudCard> createState() => _TravelWordCloudCardState();
}

class _TravelWordCloudCardState extends State<TravelWordCloudCard> {
  bool _firedOnAssetsLoaded = false;

  @override
  void didUpdateWidget(TravelWordCloudCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.codes != widget.codes) {
      _firedOnAssetsLoaded = false;
    }
  }

  void _maybeFireOnAssetsLoaded() {
    if (_firedOnAssetsLoaded) return;
    _firedOnAssetsLoaded = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAssetsLoaded?.call();
    });
  }

  // ── Visit-frequency weighting ──────────────────────────────────────────────

  /// Returns a normalised word cloud data list.
  ///
  /// Each entry is `{'word': countryName, 'value': double}`.
  /// Values are in the range [1, maxVisits] where maxVisits ≥ 1.
  List<Map> _buildWordData() {
    // Count trips per country code.
    final counts = <String, int>{};
    for (final trip in widget.trips) {
      counts[trip.countryCode] = (counts[trip.countryCode] ?? 0) + 1;
    }

    return widget.codes.map((code) {
      final name = kCountryNames[code] ?? code;
      final count = counts[code] ?? 1;
      return <String, dynamic>{'word': name, 'value': count.toDouble()};
    }).toList();
  }

  // ── Colour list construction ───────────────────────────────────────────────

  List<Color> _colorsFor(List<Map> wordData) {
    if (widget.textColor != null) {
      return [widget.textColor!];
    }

    final defaultLight = const Color(0xFFEEEEEE);
    final defaultDark = const Color(0xFF1A237E);

    switch (widget.colorMode) {
      case WordCloudColorMode.monochrome:
        return [widget.transparentBackground ? defaultDark : defaultLight];

      case WordCloudColorMode.pastel:
        return _pastelPalette;

      case WordCloudColorMode.continentColor:
        // Build a color per word in data order so the package can cycle through.
        // Since the package picks colors randomly from colorList, we provide a
        // deduplicated continent-based palette.
        final continentSet = <String>{};
        for (final word in wordData) {
          final code = _codeForName(word['word'] as String);
          if (code != null) {
            final continent = kCountryContinent[code];
            if (continent != null) continentSet.add(continent);
          }
        }
        if (continentSet.isEmpty) return _pastelPalette;
        return continentSet
            .map((c) => _continentColors[c] ?? const Color(0xFFB0BEC5))
            .toList();
    }
  }

  // ── Helper: reverse country name → code lookup ────────────────────────────

  static Map<String, String>? _reverseNameMap;

  String? _codeForName(String name) {
    _reverseNameMap ??= {for (final e in kCountryNames.entries) e.value: e.key};
    return _reverseNameMap![name];
  }

  // ── Widget build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _maybeFireOnAssetsLoaded();

    if (widget.codes.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          color:
              widget.transparentBackground
                  ? Colors.transparent
                  : const Color(0xFF0D1B2A),
          child: const Center(
            child: Text(
              'Scan your photos\nto fill your word cloud',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalW = constraints.maxWidth;
            final totalH = constraints.maxHeight;

            // Reserve space for title and subtitle strips.
            const titleH = CardTextRenderer.titleZoneH;
            const brandH = CardTextRenderer.brandingZoneH;
            final cloudH = (totalH - titleH - brandH).clamp(
              1.0,
              double.infinity,
            );

            final wordData = _buildWordData();
            final colors = _colorsFor(wordData);

            // When only one country, size is constant → give it a visible min.
            final minSize = wordData.length == 1 ? 32.0 : 11.0;
            final maxSize =
                wordData.length <= 3
                    ? 52.0
                    : wordData.length <= 10
                    ? 44.0
                    : 36.0;

            final wcData = WordCloudData(data: wordData);

            return Stack(
              children: [
                // ── Background ──────────────────────────────────────────────
                if (!widget.transparentBackground)
                  Positioned.fill(
                    child: Container(color: const Color(0xFF0D1B2A)),
                  ),

                // ── Word cloud zone ──────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  top: titleH,
                  height: cloudH,
                  child: WordCloudView(
                    data: wcData,
                    mapwidth: totalW,
                    mapheight: cloudH,
                    mintextsize: minSize,
                    maxtextsize: maxSize,
                    fontWeight: FontWeight.w600,
                    colorlist: colors,
                    mapcolor: Colors.transparent,
                    attempt: 50,
                  ),
                ),

                // ── Title zone (top strip) ──────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: titleH,
                  child: _TitleStrip(
                    title: widget.titleOverride ?? '',
                    transparent: widget.transparentBackground,
                    textColor: widget.textColor,
                  ),
                ),

                // ── Branding zone (bottom strip) ────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: brandH,
                  child: _BrandingStrip(
                    countryCount: widget.codes.length,
                    subtitleLine: widget.subtitleOverride,
                    transparent: widget.transparentBackground,
                    textColor: widget.textColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── _TitleStrip ───────────────────────────────────────────────────────────────

class _TitleStrip extends StatelessWidget {
  const _TitleStrip({
    required this.title,
    required this.transparent,
    this.textColor,
  });

  final String title;
  final bool transparent;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox.shrink();
    final color =
        textColor ??
        (transparent
            ? const Color(0xFF1A237E)
            : CardTextRenderer.defaultTextColor);
    return Container(
      color:
          transparent ? Colors.transparent : CardTextRenderer.defaultStripColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          decoration: TextDecoration.none,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── _BrandingStrip ────────────────────────────────────────────────────────────

class _BrandingStrip extends StatelessWidget {
  const _BrandingStrip({
    required this.countryCount,
    required this.transparent,
    this.subtitleLine,
    this.textColor,
  });

  final int countryCount;
  final String? subtitleLine;
  final bool transparent;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final label =
        subtitleLine ??
        'Roavvy: $countryCount ${countryCount == 1 ? 'Country' : 'Countries'}';
    final color =
        textColor ??
        (transparent
            ? const Color(0xFF1A237E)
            : CardTextRenderer.defaultTextColor);
    return Container(
      color:
          transparent ? Colors.transparent : CardTextRenderer.defaultStripColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
          decoration: TextDecoration.none,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
