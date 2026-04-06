import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_labels.dart';

// ── StampStyle ────────────────────────────────────────────────────────────────

/// 15 procedural stamp style templates (ADR-097).
///
/// Each style maps to a distinct geometry, typography layout, and decorative
/// elements rendered by [StampPainter].
enum StampStyle {
  airportEntry,
  airportExit,
  landBorder,
  visaApproval,
  transit,
  vintage,
  modernSans,
  triangle,
  hexBadge,
  dottedCircle,
  multiRing,
  blockText,
  oval,
  diamond,
  octagon,
}

// ── StampInkPalette ───────────────────────────────────────────────────────────

/// Twelve vibrant ink colour families drawn from real passport stamp imagery.
///
/// Colours are rich and varied — as seen in real-world passport stamps which
/// use full-saturation inks (ADR-097). Palette expanded for visual variety.
class StampInkPalette {
  StampInkPalette._();

  static const List<Color> _families = [
    Color(0xFF1565C0), // cobaltBlue
    Color(0xFFB71C1C), // vividRed
    Color(0xFF6A1B9A), // richPurple
    Color(0xFF1B5E20), // deepGreen
    Color(0xFF212121), // nearBlack
    Color(0xFFBF360C), // burnedOrange
    Color(0xFF00695C), // vividTeal
    Color(0xFF1A237E), // indigoNavy
    Color(0xFFAD1457), // magentaVisa
    Color(0xFF37474F), // slateGrey (faded blend target)
    Color(0xFF558B2F), // oliveGreen
    Color(0xFF4A148C), // deepViolet
  ];

  /// Returns the ink colour for the given [familyIndex] (0–5).
  static Color colorForFamily(int familyIndex) =>
      _families[familyIndex.abs() % _families.length];

  /// The number of ink families available.
  static int get familyCount => _families.length;

  /// Deterministic family index from a 2-char country code.
  static int familyIndexForCode(String code) {
    if (code.length < 2) return 0;
    return (code.codeUnitAt(0) * 31 + code.codeUnitAt(1)).abs() %
        familyCount;
  }
}

// ── StampAgeEffect ────────────────────────────────────────────────────────────

/// Aging level applied to a stamp during rendering.
///
/// Weights: fresh 60%, aged 30%, worn 8%, faded 2% (ADR-097).
enum StampAgeEffect {
  fresh,
  aged,
  worn,
  faded;

  /// Overall ink opacity for this aging level.
  double get opacity => switch (this) {
        StampAgeEffect.fresh => 0.90,
        StampAgeEffect.aged => 0.78,
        StampAgeEffect.worn => 0.62,
        StampAgeEffect.faded => 0.45,
      };

  /// Noise intensity scalar (higher = more gaps and variation).
  double get noiseIntensity => switch (this) {
        StampAgeEffect.fresh => 0.6,
        StampAgeEffect.aged => 0.8,
        StampAgeEffect.worn => 1.1,
        StampAgeEffect.faded => 1.4,
      };

  /// Whether this age level shifts colour toward fadedInk family.
  bool get shiftsToFaded =>
      this == StampAgeEffect.worn || this == StampAgeEffect.faded;

  /// Derive an age effect from a [value] in [0, 1) using weighted probability.
  ///
  /// fresh=60%, aged=30%, worn=8%, faded=2%
  static StampAgeEffect fromWeightedRandom(double value) {
    if (value < 0.60) return StampAgeEffect.fresh;
    if (value < 0.90) return StampAgeEffect.aged;
    if (value < 0.98) return StampAgeEffect.worn;
    return StampAgeEffect.faded;
  }
}

// ── StampRenderConfig ─────────────────────────────────────────────────────────

/// Render-time flags controlling optional stamp effects (ADR-097).
@immutable
class StampRenderConfig {
  const StampRenderConfig({
    this.enableRareArtefacts = true,
    this.enableNoise = true,
    this.enableAging = true,
  });

  final bool enableRareArtefacts;
  final bool enableNoise;
  final bool enableAging;

  /// Clean config suitable for export / screenshot contexts.
  static const clean = StampRenderConfig(
    enableRareArtefacts: false,
    enableNoise: false,
    enableAging: false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampRenderConfig &&
          enableRareArtefacts == other.enableRareArtefacts &&
          enableNoise == other.enableNoise &&
          enableAging == other.enableAging;

  @override
  int get hashCode =>
      Object.hash(enableRareArtefacts, enableNoise, enableAging);
}

// ── StampData ─────────────────────────────────────────────────────────────────

/// Rendering artefact for a single passport stamp.
///
/// Not a domain model — no Firestore serialisation. Derived transiently at
/// paint time from [TripRecord] data or country codes (ADR-097).
@immutable
class StampData {
  const StampData({
    required this.countryCode,
    required this.countryName,
    required this.style,
    required this.inkFamilyIndex,
    required this.ageEffect,
    required this.rotation,
    required this.center,
    required this.scale,
    required this.isEntry,
    this.dateLabel,
    this.entryLabel = 'ARRIVAL',
    this.edgeClip,
    this.renderConfig = const StampRenderConfig(),
    this.overrideInkColor,
    this.overrideDateColor,
    });

    final String countryCode;
    final String countryName;

    /// Optional user-override ink colour (ADR-117 Decision 3).
    final Color? overrideInkColor;

    /// Optional user-override date colour (ADR-117 Decision 3).
    final Color? overrideDateColor;

    /// Stamp visual template (ADR-097: 12 styles replacing 4-shape StampShape).

  final StampStyle style;

  /// Index into [StampInkPalette._families] (0–5).
  final int inkFamilyIndex;

  /// Aging level; affects opacity, noise intensity, and colour shift.
  final StampAgeEffect ageEffect;

  /// Rotation in radians. Range: roughly ±0.35 rad (±20°).
  final double rotation;

  /// Position of the stamp centre within the canvas, in logical pixels.
  final Offset center;

  /// Scale factor (default 1.0). Used by layout engine for size variety.
  final double scale;

  /// Whether this is an entry (arrival) stamp; false = exit (departure).
  final bool isEntry;

  /// Formatted date string, e.g. "12 JAN 2023". Always set.
  final String? dateLabel;

  /// Arrival/departure label in the country's native language.
  final String entryLabel;

  /// When non-null, the stamp is clipped to this rect (edge bleed effect).
  final Rect? edgeClip;

  /// Render-time effect flags.
  final StampRenderConfig renderConfig;

  /// Ink colour, with saturation further reduced per age (ADR-097 Decision 4).
  /// Respects optional user override (ADR-117).
  Color get inkColor {
    if (overrideInkColor != null) return overrideInkColor!;
    final base = StampInkPalette.colorForFamily(inkFamilyIndex);
    if (ageEffect.shiftsToFaded) {
      // Blend 30% toward slateGrey (index 9) for aged/worn appearance
      final faded = StampInkPalette.colorForFamily(9);
      return Color.lerp(base, faded, 0.30)!;
    }
    return base;
  }

  /// Ink colour for the date text. Respects optional user override (ADR-117).
  Color get dateColor => overrideDateColor ?? inkColor;

  /// Seed for deterministic procedural effects (noise, distortion, typography).
  int get seed => countryCode.hashCode ^ style.index;

  /// Pseudo 3-letter airport/border code derived deterministically from seed.
  String get airportCode {
    final rng = math.Random(seed ^ 0x4AC0);
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final l1 =
        countryCode.isNotEmpty ? countryCode[0] : letters[rng.nextInt(26)];
    final l2 = letters[rng.nextInt(26)];
    final l3 = letters[rng.nextInt(26)];
    return '$l1$l2$l3';
  }

  /// Pseudo immigration serial number derived deterministically from seed.
  String get serialCode {
    final rng = math.Random(seed ^ 0x53A1);
    final num = 1000000 + rng.nextInt(9000000);
    final letter = String.fromCharCode(65 + rng.nextInt(26));
    return '$letter-$num';
  }

  /// Date format variant (0–2) derived from seed for visual variety.
  ///
  /// 0 = "12 JAN 2023"  1 = "12.01.23"  2 = "12/JAN/23"
  int get dateVariant => seed % 3;

  static String _formatDate(DateTime dt, int variant) {
    switch (variant % 3) {
      case 0:
        return DateFormat('dd MMM yyyy').format(dt).toUpperCase();
      case 1:
        return DateFormat('dd.MM.yy').format(dt);
      default:
        final day = dt.day.toString().padLeft(2, '0');
        final mon = DateFormat('MMM').format(dt).toUpperCase();
        final yr = (dt.year % 100).toString().padLeft(2, '0');
        return '$day/$mon/$yr';
    }
  }

  /// Deterministic placeholder date for code-only stamps (no real trip).
  ///
  /// Picks a date between 2020 and 2023 from [code]'s hash so it is stable
  /// across devices and sessions.
  static DateTime _placeholderDate(String code) {
    final rng = math.Random(code.hashCode ^ 0xDADA);
    return DateTime(
      2020 + rng.nextInt(4), // 2020–2023
      1 + rng.nextInt(12),
      1 + rng.nextInt(28), // max 28 avoids invalid Feb dates
    );
  }

  /// Create a [StampData] from a [TripRecord].
  ///
  /// [stampDate] overrides the date shown on the stamp. Defaults to
  /// [TripRecord.startedOn]. Pass [TripRecord.endedOn] for exit stamps so the
  /// departure date is shown rather than the arrival date.
  factory StampData.fromTrip(
    TripRecord trip, {
    DateTime? stampDate,
    required StampStyle style,
    required int inkFamilyIndex,
    required StampAgeEffect ageEffect,
    required double rotation,
    required Offset center,
    required bool isEntry,
    double scale = 1.0,
    String countryName = '',
    Rect? edgeClip,
    StampRenderConfig renderConfig = const StampRenderConfig(),
  }) {
    final variant = (trip.countryCode.hashCode ^ style.index) % 3;
    final label = isEntry
        ? nativeArrivalLabel(trip.countryCode)
        : nativeDepartureLabel(trip.countryCode);
    final date = stampDate ?? trip.startedOn;
    return StampData(
      countryCode: trip.countryCode,
      countryName: countryName,
      style: style,
      inkFamilyIndex: inkFamilyIndex,
      ageEffect: ageEffect,
      rotation: rotation,
      center: center,
      scale: scale,
      isEntry: isEntry,
      dateLabel: _formatDate(date, variant),
      entryLabel: label,
      edgeClip: edgeClip,
      renderConfig: renderConfig,
    );
  }

  /// Create a [StampData] from a bare country code (no trip data).
  ///
  /// Generates a deterministic placeholder date so every stamp shows a date.
  factory StampData.fromCode(
    String code, {
    required StampStyle style,
    required int inkFamilyIndex,
    required StampAgeEffect ageEffect,
    required double rotation,
    required Offset center,
    double scale = 1.0,
    String countryName = '',
    Rect? edgeClip,
    StampRenderConfig renderConfig = const StampRenderConfig(),
  }) {
    final variant = (code.hashCode ^ style.index) % 3;
    return StampData(
      countryCode: code,
      countryName: countryName,
      style: style,
      inkFamilyIndex: inkFamilyIndex,
      ageEffect: ageEffect,
      rotation: rotation,
      center: center,
      scale: scale,
      isEntry: true,
      dateLabel: _formatDate(_placeholderDate(code), variant),
      entryLabel: nativeArrivalLabel(code),
      edgeClip: edgeClip,
      renderConfig: renderConfig,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampData &&
          countryCode == other.countryCode &&
          style == other.style &&
          inkFamilyIndex == other.inkFamilyIndex &&
          ageEffect == other.ageEffect &&
          rotation == other.rotation &&
          center == other.center &&
          scale == other.scale &&
          isEntry == other.isEntry &&
          dateLabel == other.dateLabel &&
          entryLabel == other.entryLabel &&
          edgeClip == other.edgeClip &&
          renderConfig == other.renderConfig;

  @override
  int get hashCode => Object.hash(
        countryCode,
        style,
        inkFamilyIndex,
        ageEffect,
        rotation,
        center,
        scale,
        isEntry,
        dateLabel,
        entryLabel,
        edgeClip,
        renderConfig,
      );
}
