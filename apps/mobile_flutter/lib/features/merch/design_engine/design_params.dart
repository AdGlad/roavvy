import 'package:shared_models/shared_models.dart';

import '../../cards/flag_grid_layout_engine.dart';
import '../merch_preset.dart';
import '../product_mockup_specs.dart';

/// A fully-specified, renderable t-shirt design — the "genome" the AI design
/// engine searches over (M197). Every field maps to an argument already
/// accepted by `CardImageRenderer` / `LocalMockupPreviewScreen`, so any valid
/// [DesignParams] is printable by construction (see the architecture doc §0/§4).
///
/// This is an immutable value type with a stable [contentHash] used as the cache
/// key for renders/scores and as the on-wire form for persistence + telemetry.
class DesignParams {
  const DesignParams({
    required this.template,
    required this.source,
    required this.countryCodes,
    this.gridLayoutMode = FlagGridLayoutMode.packedRow,
    this.clipShape = GridClipShape.none,
    this.clipCode,
    this.rowCount = 3,
    this.density = MerchDensity.balanced,
    this.jitter = 0.2,
    this.stampMode = MerchStampMode.entryExit,
    this.isPortrait = false,
    this.imageSize = ImageSize.medium,
    this.shirtColour = 'Black',
    this.seed = 0,
  });

  /// Which card template renders this design.
  final CardTemplateType template;

  /// Semantic provenance of [countryCodes] (recent trip / this year / …).
  final MerchCountrySource source;

  /// The concrete country codes this design draws. Resolved from a
  /// [TravelProfile] country-set at generation time.
  final List<String> countryCodes;

  // ── Flag-grid genes (only meaningful when template == grid) ────────────────
  final FlagGridLayoutMode gridLayoutMode;
  final GridClipShape clipShape;
  final String? clipCode;
  final int rowCount;

  // ── Shared genes ───────────────────────────────────────────────────────────
  final MerchDensity density;
  final double jitter;
  final MerchStampMode stampMode;
  final bool isPortrait;
  final ImageSize imageSize;
  final String shirtColour;

  /// Randomisation seed (montage / stamp shuffle) — kept in the genome so a
  /// design renders identically every time (print == preview).
  final int seed;

  /// The design recipe consumed by the existing renderer/preview. Title/subtitle
  /// are applied downstream (AI title generation), not part of the search genome.
  MerchPresetConfig toPresetConfig() => MerchPresetConfig(
    layout: template,
    source: source,
    jitter: jitter,
    density: density,
    stampMode: stampMode,
  );

  DesignParams copyWith({
    CardTemplateType? template,
    MerchCountrySource? source,
    List<String>? countryCodes,
    FlagGridLayoutMode? gridLayoutMode,
    GridClipShape? clipShape,
    Object? clipCode = _sentinel,
    int? rowCount,
    MerchDensity? density,
    double? jitter,
    MerchStampMode? stampMode,
    bool? isPortrait,
    ImageSize? imageSize,
    String? shirtColour,
    int? seed,
  }) {
    return DesignParams(
      template: template ?? this.template,
      source: source ?? this.source,
      countryCodes: countryCodes ?? this.countryCodes,
      gridLayoutMode: gridLayoutMode ?? this.gridLayoutMode,
      clipShape: clipShape ?? this.clipShape,
      clipCode: clipCode == _sentinel ? this.clipCode : clipCode as String?,
      rowCount: rowCount ?? this.rowCount,
      density: density ?? this.density,
      jitter: jitter ?? this.jitter,
      stampMode: stampMode ?? this.stampMode,
      isPortrait: isPortrait ?? this.isPortrait,
      imageSize: imageSize ?? this.imageSize,
      shirtColour: shirtColour ?? this.shirtColour,
      seed: seed ?? this.seed,
    );
  }

  /// Whether the gene combination is legal (some genes only apply to some
  /// templates / set sizes). Illegal genomes are never scored/rendered — call
  /// [normalize] to coerce a genome into its nearest legal form.
  bool get isValid => _violation() == null;

  /// Coerces illegal gene combinations to their nearest legal form so mutation
  /// / crossover output is always renderable.
  DesignParams normalize() {
    if (countryCodes.isEmpty) {
      // Nothing to render; callers should filter empty sets out earlier.
      return this;
    }
    var next = this;
    final isGrid = template == CardTemplateType.grid;
    // Flag-grid genes only apply to the grid template.
    if (!isGrid) {
      next = next.copyWith(
        gridLayoutMode: FlagGridLayoutMode.packedRow,
        clipShape: GridClipShape.none,
        clipCode: null,
      );
    }
    // Silhouette / country-outline clips are single-country only.
    if (countryCodes.length != 1 && _isSingleCountryClip(next.clipShape)) {
      next = next.copyWith(clipShape: GridClipShape.none, clipCode: null);
    }
    // Continent-outline clip needs a continent scope (a clipCode).
    if (next.clipShape == GridClipShape.continentOutline && next.clipCode == null) {
      next = next.copyWith(clipShape: GridClipShape.none);
    }
    // Outline/silhouette clips require a clipCode to resolve the path.
    if (_clipNeedsCode(next.clipShape) && next.clipCode == null) {
      next = next.copyWith(clipShape: GridClipShape.none);
    }
    // Rows clamp.
    if (next.rowCount < 1 || next.rowCount > 10) {
      next = next.copyWith(rowCount: next.rowCount.clamp(1, 10));
    }
    // Jitter clamp.
    if (next.jitter < 0 || next.jitter > 1) {
      next = next.copyWith(jitter: next.jitter.clamp(0.0, 1.0));
    }
    return next;
  }

  String? _violation() {
    if (countryCodes.isEmpty) return 'empty country set';
    final isGrid = template == CardTemplateType.grid;
    if (!isGrid &&
        (gridLayoutMode != FlagGridLayoutMode.packedRow ||
            clipShape != GridClipShape.none)) {
      return 'flag-grid genes on non-grid template';
    }
    if (countryCodes.length != 1 && _isSingleCountryClip(clipShape)) {
      return 'single-country clip on multi-country set';
    }
    if (_clipNeedsCode(clipShape) && clipCode == null) {
      return 'clip shape ${clipShape.name} requires a clipCode';
    }
    if (rowCount < 1 || rowCount > 10) return 'rowCount out of range';
    if (jitter < 0 || jitter > 1) return 'jitter out of range';
    return null;
  }

  static bool _isSingleCountryClip(GridClipShape s) =>
      s == GridClipShape.countryOutline ||
      s == GridClipShape.animalSilhouette ||
      s == GridClipShape.plantSilhouette ||
      s == GridClipShape.landmarkSilhouette;

  static bool _clipNeedsCode(GridClipShape s) =>
      _isSingleCountryClip(s) || s == GridClipShape.continentOutline;

  /// Canonical, stable content hash — the cache key for renders/scores and the
  /// identity for de-duplication. Order-independent for [countryCodes].
  String get contentHash {
    final codes = ([...countryCodes]..sort()).join(',');
    return [
      template.name,
      source.name,
      codes,
      gridLayoutMode.name,
      clipShape.name,
      clipCode ?? '',
      rowCount,
      density.name,
      jitter.toStringAsFixed(3),
      stampMode.name,
      isPortrait ? 'p' : 'l',
      imageSize.name,
      shirtColour,
      seed,
    ].join('|');
  }

  @override
  bool operator ==(Object other) =>
      other is DesignParams && other.contentHash == contentHash;

  @override
  int get hashCode => contentHash.hashCode;

  @override
  String toString() => 'DesignParams($contentHash)';
}

const Object _sentinel = Object();
