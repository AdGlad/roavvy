import 'canonical_json.dart';
import 'design_recipe.dart';
import 'recipe_parts.dart';

/// A composite of the two artwork faces of one physical garment (a T-shirt) so
/// that a shirt's [front] and [back] are treated as ONE coherent product rather
/// than two unrelated designs.
///
/// A garment may carry either or both faces (front-only, back-only, or both).
/// Both faces derive from a shared [themeSeed] so the two sides stay coherent
/// (same palette/vibe/travel intent) and share a single [garmentColour].
///
/// [garmentId] is a stable content hash over the artwork-relevant fields
/// ({front.recipeId, back.recipeId, garmentColour, variant, themeSeed}), so two
/// garments that would print identically share an id — it reproduces exactly.
class GarmentDesign {
  const GarmentDesign({
    this.front,
    this.back,
    this.garmentColour,
    this.variant,
    this.themeSeed = 0,
  });

  /// The front-face design recipe (null if this garment has no front artwork).
  final DesignRecipe? front;

  /// The back-face design recipe (null if this garment has no back artwork).
  final DesignRecipe? back;

  /// The shared garment (blank) colour for the whole product, as a hex string.
  final String? garmentColour;

  /// An opaque variant key (e.g. size / SKU). Optional; part of identity.
  final String? variant;

  /// The shared theme seed both faces derive from (palette / vibe / travel
  /// coherence). Both sides of a coherent garment share this value.
  final int themeSeed;

  /// The artwork-relevant fields the [garmentId] hash covers. Uses each nested
  /// recipe's own [DesignRecipe.recipeId] so the composite id reproduces exactly
  /// whenever the two faces reproduce. Keys are canonically sorted by the encoder.
  Map<String, Object?> _hashableJson() => {
        'front': front?.recipeId,
        'back': back?.recipeId,
        'garmentColour': garmentColour,
        'variant': variant,
        'themeSeed': themeSeed,
      };

  /// Stable content hash of the whole garment (front id + back id + colour +
  /// variant + theme seed). Reproducible: identical inputs → identical id.
  String get garmentId =>
      stableContentHash(canonicalJsonEncode(_hashableJson()));

  Map<String, Object?> toJson() => {
        if (front != null) 'front': front!.toJson(),
        if (back != null) 'back': back!.toJson(),
        if (garmentColour != null) 'garmentColour': garmentColour,
        if (variant != null) 'variant': variant,
        'themeSeed': themeSeed,
        'garmentId': garmentId,
      };

  factory GarmentDesign.fromJson(Map<String, Object?> json) => GarmentDesign(
        front: json['front'] == null
            ? null
            : DesignRecipe.fromJson(
                (json['front'] as Map).cast<String, Object?>()),
        back: json['back'] == null
            ? null
            : DesignRecipe.fromJson(
                (json['back'] as Map).cast<String, Object?>()),
        garmentColour: json['garmentColour'] as String?,
        variant: json['variant'] as String?,
        themeSeed: (json['themeSeed'] as num?)?.toInt() ?? 0,
      );

  GarmentDesign copyWith({
    DesignRecipe? front,
    DesignRecipe? back,
    String? garmentColour,
    String? variant,
    int? themeSeed,
  }) =>
      GarmentDesign(
        front: front ?? this.front,
        back: back ?? this.back,
        garmentColour: garmentColour ?? this.garmentColour,
        variant: variant ?? this.variant,
        themeSeed: themeSeed ?? this.themeSeed,
      );

  // ---------------------------------------------------------------------------
  // Coherence helpers
  // ---------------------------------------------------------------------------

  /// Builds a coherent garment from a [front] recipe and a shared [themeSeed].
  ///
  /// The [garmentColour] (falling back to the front recipe's own
  /// `palette.garmentColour`) is applied to BOTH faces so the product reads as
  /// one item. If [back] is omitted a complementary back is produced via
  /// [deriveBack]; if supplied it is still re-coloured to the shared garment
  /// colour so the two faces match.
  factory GarmentDesign.withSharedTheme({
    required DesignRecipe front,
    required int themeSeed,
    String? garmentColour,
    String? variant,
    DesignRecipe? back,
  }) {
    final colour = garmentColour ?? front.palette?.garmentColour;
    final resolvedFront = _recipeWithGarmentColour(front, colour);
    final resolvedBack = back == null
        ? deriveBack(front, themeSeed: themeSeed, garmentColour: colour)
        : _recipeWithGarmentColour(back, colour);
    return GarmentDesign(
      front: resolvedFront,
      back: resolvedBack,
      garmentColour: colour,
      variant: variant,
      themeSeed: themeSeed,
    );
  }

  /// Produces a complementary back recipe for [front] that shares its palette
  /// (hence vibe + [garmentColour]) and the garment [themeSeed].
  ///
  /// RULE (deliberately simple and documented): the back keeps the front's
  /// travel content and palette so the two sides stay coherent, but draws with a
  /// distinct, deterministic seed derived from [themeSeed] (see
  /// [backSeedFromTheme]) so the artwork differs rather than duplicating the
  /// front. Callers may override [composition] and/or [content] to make the back
  /// a different family/layout while keeping the shared theme.
  static DesignRecipe deriveBack(
    DesignRecipe front, {
    required int themeSeed,
    String? garmentColour,
    Composition? composition,
    RecipeContent? content,
    int? seed,
  }) {
    final colour = garmentColour ?? front.palette?.garmentColour;
    final coloured = _recipeWithGarmentColour(front, colour);
    return coloured.copyWith(
      seed: seed ?? backSeedFromTheme(themeSeed),
      composition: composition,
      content: content,
    );
  }

  /// Deterministic back-face seed from a garment [themeSeed]. Mixed with the
  /// 64-bit golden-ratio constant so the back seed is stable, reproducible, and
  /// distinct from the theme/front seed.
  static int backSeedFromTheme(int themeSeed) {
    const int mask = 0x7FFFFFFFFFFFFFFF;
    return (themeSeed ^ 0x9E3779B97F4A7C15) & mask;
  }

  /// Returns a new garment with [front] and [back] swapped.
  GarmentDesign flipSides() => GarmentDesign(
        front: back,
        back: front,
        garmentColour: garmentColour,
        variant: variant,
        themeSeed: themeSeed,
      );

  /// Returns a new garment with [colour] set as the shared garment colour AND
  /// applied to both faces' `palette.garmentColour`. Pure/immutable — the
  /// receiver is unchanged.
  GarmentDesign withGarmentColour(String colour) => GarmentDesign(
        front: front == null ? null : _recipeWithGarmentColour(front!, colour),
        back: back == null ? null : _recipeWithGarmentColour(back!, colour),
        garmentColour: colour,
        variant: variant,
        themeSeed: themeSeed,
      );

  @override
  bool operator ==(Object other) =>
      other is GarmentDesign &&
      // DesignRecipe has no value equality, so compare faces by their stable
      // recipeId (artwork identity) — consistent with [garmentId]/[hashCode].
      other.front?.recipeId == front?.recipeId &&
      other.back?.recipeId == back?.recipeId &&
      other.garmentColour == garmentColour &&
      other.variant == variant &&
      other.themeSeed == themeSeed;

  @override
  int get hashCode => Object.hash(
        front?.recipeId,
        back?.recipeId,
        garmentColour,
        variant,
        themeSeed,
      );
}

/// Returns [r] with its `palette.garmentColour` set to [colour], preserving all
/// other palette fields. A no-op (returns [r]) when [colour] is null. Pure.
DesignRecipe _recipeWithGarmentColour(DesignRecipe r, String? colour) {
  if (colour == null) return r;
  final base = r.palette ?? const Palette();
  return r.copyWith(
    palette: Palette(
      garmentColour: colour,
      strategy: base.strategy,
      accents: base.accents,
      vintageGrade: base.vintageGrade,
    ),
  );
}
