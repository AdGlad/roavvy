import 'package:shared_models/shared_models.dart';

/// Where the country list for a preset comes from.
enum MerchCountrySource {
  /// Countries from the most recent trip.
  recentTrip,

  /// Countries visited this calendar year.
  thisYear,

  /// All visited countries ever.
  allTime,

  /// A single user-selected country.
  singleCountry,
}

/// Layout density for the generated card design.
enum MerchDensity { sparse, balanced, dense }

/// Whether to show entry-only stamps or entry + exit stamps.
enum MerchStampMode { entryOnly, entryExit }

/// Configuration values that drive artwork generation for a merch preset.
///
/// Users never edit this directly — they apply overrides via
/// [copyWithOverrides], which layers nullable changes on top of an existing
/// config (ADR-147).
class MerchPresetConfig {
  const MerchPresetConfig({
    required this.layout,
    required this.source,
    required this.jitter,
    required this.density,
    required this.stampMode,
  });

  /// Card template type used for the generated artwork.
  final CardTemplateType layout;

  /// Determines which country codes are used to generate the artwork.
  final MerchCountrySource source;

  /// Stamp scatter randomness — 0.0 (ordered) to 1.0 (fully random).
  final double jitter;

  final MerchDensity density;
  final MerchStampMode stampMode;

  /// Returns a new config with non-null overrides applied.
  ///
  /// Null fields in the override are ignored (original value preserved).
  MerchPresetConfig copyWithOverrides({
    CardTemplateType? layout,
    MerchCountrySource? source,
    double? jitter,
    MerchDensity? density,
    MerchStampMode? stampMode,
  }) {
    return MerchPresetConfig(
      layout: layout ?? this.layout,
      source: source ?? this.source,
      jitter: jitter ?? this.jitter,
      density: density ?? this.density,
      stampMode: stampMode ?? this.stampMode,
    );
  }

  /// Returns the [stampJitterFactor] value for [CardImageRenderer.render].
  double get stampJitterFactor => jitter;

  /// Returns the [stampSizeMultiplier] for [CardImageRenderer.render].
  ///
  /// Dense layouts use a slightly smaller multiplier to fit more flags.
  double get stampSizeMultiplier => switch (density) {
    MerchDensity.sparse => 1.2,
    MerchDensity.balanced => 1.0,
    MerchDensity.dense => 0.8,
  };

  /// Returns `entryOnly` value for [CardImageRenderer.render].
  bool get entryOnly => stampMode == MerchStampMode.entryOnly;
}

/// A named design preset that drives the initial artwork on the merch screen.
class MerchPreset {
  const MerchPreset({
    required this.id,
    required this.label,
    required this.config,
  });

  final String id;

  /// Short human-readable label shown in the preset picker.
  final String label;

  final MerchPresetConfig config;
}

// ── Built-in presets ──────────────────────────────────────────────────────────

const MerchPreset kPresetRecentTrip = MerchPreset(
  id: 'recent_trip',
  label: 'Recent Trip',
  config: MerchPresetConfig(
    layout: CardTemplateType.passport,
    source: MerchCountrySource.recentTrip,
    jitter: 0.8,
    density: MerchDensity.balanced,
    stampMode: MerchStampMode.entryExit,
  ),
);

const MerchPreset kPresetThisYear = MerchPreset(
  id: 'this_year',
  label: 'This Year',
  config: MerchPresetConfig(
    layout: CardTemplateType.grid,
    source: MerchCountrySource.thisYear,
    jitter: 0.2,
    density: MerchDensity.balanced,
    stampMode: MerchStampMode.entryExit,
  ),
);

const MerchPreset kPresetAllTime = MerchPreset(
  id: 'all_time',
  label: 'All Countries',
  config: MerchPresetConfig(
    layout: CardTemplateType.grid,
    source: MerchCountrySource.allTime,
    jitter: 0.1,
    density: MerchDensity.dense,
    stampMode: MerchStampMode.entryExit,
  ),
);

const MerchPreset kPresetSingleCountry = MerchPreset(
  id: 'single_country',
  label: 'Single Country',
  config: MerchPresetConfig(
    layout: CardTemplateType.passport,
    source: MerchCountrySource.singleCountry,
    jitter: 0.5,
    density: MerchDensity.sparse,
    stampMode: MerchStampMode.entryOnly,
  ),
);

const MerchPreset kPresetLandmarks = MerchPreset(
  id: 'landmarks',
  label: 'Landmarks',
  config: MerchPresetConfig(
    layout: CardTemplateType.landmark,
    source: MerchCountrySource.allTime,
    jitter: 0.0,
    density: MerchDensity.balanced,
    stampMode: MerchStampMode.entryOnly,
  ),
);

/// All built-in presets in display order.
const List<MerchPreset> kMerchPresets = [
  kPresetRecentTrip,
  kPresetThisYear,
  kPresetAllTime,
  kPresetLandmarks,
  kPresetSingleCountry,
];
