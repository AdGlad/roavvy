import 'canonical_json.dart';
import 'recipe_parts.dart';
import 'versions.dart';

/// The design "family" — the top-level look. Extensible: unknown names decode to
/// [DesignFamily.unknown] so old/new recipes stay forward/backward compatible.
enum DesignFamily {
  singleHero,
  duoBlend,
  grid,
  passportStamp,
  timeline,
  typographic,
  badge,
  wordCloud,
  landmark,
  journeys,
  tornHero,
  unknown;

  String get id => this == DesignFamily.unknown ? 'unknown' : name;

  static DesignFamily fromId(String? id) {
    for (final f in DesignFamily.values) {
      if (f.name == id) return f;
    }
    return DesignFamily.unknown;
  }
}

enum Orientation {
  portrait,
  landscape,
  square;

  static Orientation fromId(String? id) {
    for (final v in Orientation.values) {
      if (v.name == id) return v;
    }
    return Orientation.portrait;
  }
}

/// One flag reference with a relative [weight] (weighting is first-class, so a
/// blend can favour one flag). [code] is an ISO-3166-1 alpha-2 lowercase code.
class FlagRef {
  const FlagRef(this.code, {this.weight = 1.0});

  final String code;
  final double weight;

  Map<String, Object?> toJson() => {'code': code, 'weight': weight};

  factory FlagRef.fromJson(Map<String, Object?> json) => FlagRef(
        json['code']! as String,
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) =>
      other is FlagRef && other.code == code && other.weight == weight;

  @override
  int get hashCode => Object.hash(code, weight);
}

/// The concrete travel content drawn.
class RecipeContent {
  const RecipeContent({required this.flags, this.source});

  final List<FlagRef> flags;
  final String? source;

  Map<String, Object?> toJson() => {
        'flags': [for (final f in flags) f.toJson()],
        if (source != null) 'source': source,
      };

  factory RecipeContent.fromJson(Map<String, Object?> json) => RecipeContent(
        flags: [
          for (final f in (json['flags'] as List? ?? const []))
            FlagRef.fromJson((f as Map).cast<String, Object?>()),
        ],
        source: json['source'] as String?,
      );
}

/// The macro layout skeleton.
class Composition {
  const Composition({
    required this.family,
    this.orientation = Orientation.portrait,
    this.layoutMode,
    this.fillAlgorithm,
    this.rowCount,
    this.density = Density.balanced,
    this.jitter = 0.0,
    this.placement,
  });

  final DesignFamily family;
  final Orientation orientation;

  /// Grid-family layout mode (null for non-grid families).
  final LayoutMode? layoutMode;

  /// How multiple flag instances pack the frame (grid template). Null = grid.
  final FillAlgorithm? fillAlgorithm;
  final int? rowCount;
  final Density density;
  final double jitter;
  final Placement? placement;

  Map<String, Object?> toJson() => {
        'family': family.id,
        'orientation': orientation.name,
        if (layoutMode != null) 'layoutMode': layoutMode!.name,
        if (fillAlgorithm != null) 'fillAlgorithm': fillAlgorithm!.name,
        if (rowCount != null) 'rowCount': rowCount,
        if (density != Density.balanced) 'density': density.name,
        if (jitter != 0.0) 'jitter': jitter,
        if (placement != null) 'placement': placement!.toJson(),
      };

  factory Composition.fromJson(Map<String, Object?> json) => Composition(
        family: DesignFamily.fromId(json['family'] as String?),
        orientation: Orientation.fromId(json['orientation'] as String?),
        layoutMode: json['layoutMode'] == null
            ? null
            : LayoutMode.fromId(json['layoutMode'] as String?),
        fillAlgorithm: json['fillAlgorithm'] == null
            ? null
            : FillAlgorithm.fromId(json['fillAlgorithm'] as String?),
        rowCount: (json['rowCount'] as num?)?.toInt(),
        density: Density.fromId(json['density'] as String?),
        jitter: (json['jitter'] as num?)?.toDouble() ?? 0.0,
        placement: json['placement'] == null
            ? null
            : Placement.fromJson(
                (json['placement'] as Map).cast<String, Object?>()),
      );
}

/// How a recipe came to exist. Never part of the content hash and never feeds
/// the seed — pure bookkeeping for studio batches / telemetry / regression.
class RecipeProvenance {
  const RecipeProvenance({
    this.generator,
    this.parentRecipeIds = const [],
    this.batchId,
    this.createdAtEpochMs,
  });

  final String? generator;
  final List<String> parentRecipeIds;
  final String? batchId;
  final int? createdAtEpochMs;

  Map<String, Object?> toJson() => {
        if (generator != null) 'generator': generator,
        if (parentRecipeIds.isNotEmpty) 'parentRecipeIds': parentRecipeIds,
        if (batchId != null) 'batchId': batchId,
        if (createdAtEpochMs != null) 'createdAtEpochMs': createdAtEpochMs,
      };

  factory RecipeProvenance.fromJson(Map<String, Object?> json) =>
      RecipeProvenance(
        generator: json['generator'] as String?,
        parentRecipeIds: [
          for (final id in (json['parentRecipeIds'] as List? ?? const []))
            id as String,
        ],
        batchId: json['batchId'] as String?,
        createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt(),
      );
}

/// A deterministic, PARAMETRIC description of one T-shirt design — a reproducible
/// recipe (rules + parameters + [seed]), never a stored raster.
///
/// Given the same `(schemaVersion, engineVersion, grammarVersion, assetsVersion,
/// seed, content, composition)` the renderer must produce visually-equivalent
/// output. [recipeId] is a stable content hash over exactly those fields
/// ([provenance] is excluded), so two recipes that render identically share an
/// id — caches, telemetry, and regression goldens all key off it.
///
/// This is the Phase-0 minimal core (identity + content + composition). New
/// dimensions (clip, edge treatment, colour, effects, typography, motifs) are
/// added as append-only optional fields so old recipes keep their meaning.
class DesignRecipe {
  const DesignRecipe({
    required this.seed,
    required this.content,
    required this.composition,
    this.flagCombination,
    this.clip,
    this.edgeTreatment,
    this.palette,
    this.effects,
    this.typography,
    this.motifs = const [],
    this.schemaVersion = kSchemaVersion,
    this.engineVersion = kEngineVersion,
    this.grammarVersion = kGrammarVersion,
    this.assetsVersion = kAssetsVersion,
    this.provenance,
  });

  final int schemaVersion;
  final String engineVersion;
  final String grammarVersion;
  final String assetsVersion;

  /// The deterministic driver. Every stochastic grammar choice derives from a
  /// named sub-stream of this seed. Persisted so print == preview.
  final int seed;

  final RecipeContent content;
  final Composition composition;

  // Optional, append-only dimension groups. Absent groups don't affect the hash.
  final FlagCombination? flagCombination;
  final Clip? clip;
  final EdgeTreatment? edgeTreatment;
  final Palette? palette;
  final Effects? effects;
  final Typography? typography;
  final List<Motif> motifs;

  final RecipeProvenance? provenance;

  /// The fields that define the artwork — everything the hash covers.
  Map<String, Object?> _hashableJson() => {
        'schemaVersion': schemaVersion,
        'engineVersion': engineVersion,
        'grammarVersion': grammarVersion,
        'assetsVersion': assetsVersion,
        'seed': seed,
        'content': content.toJson(),
        'composition': composition.toJson(),
        if (flagCombination != null) 'flagCombination': flagCombination!.toJson(),
        if (clip != null) 'clip': clip!.toJson(),
        if (edgeTreatment != null) 'edgeTreatment': edgeTreatment!.toJson(),
        if (palette != null) 'palette': palette!.toJson(),
        if (effects != null) 'effects': effects!.toJson(),
        if (typography != null) 'typography': typography!.toJson(),
        if (motifs.isNotEmpty)
          'motifs': [for (final m in motifs) m.toJson()],
      };

  /// Stable content hash of the design (excludes [provenance] and [recipeId]).
  String get recipeId => stableContentHash(canonicalJsonEncode(_hashableJson()));

  Map<String, Object?> toJson() => {
        ..._hashableJson(),
        'recipeId': recipeId,
        if (provenance != null) 'provenance': provenance!.toJson(),
      };

  factory DesignRecipe.fromJson(Map<String, Object?> json) => DesignRecipe(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? kSchemaVersion,
        engineVersion: json['engineVersion'] as String? ?? kEngineVersion,
        grammarVersion: json['grammarVersion'] as String? ?? kGrammarVersion,
        assetsVersion: json['assetsVersion'] as String? ?? kAssetsVersion,
        seed: (json['seed'] as num).toInt(),
        content:
            RecipeContent.fromJson((json['content'] as Map).cast<String, Object?>()),
        composition: Composition.fromJson(
            (json['composition'] as Map).cast<String, Object?>()),
        flagCombination: _obj(json['flagCombination'], FlagCombination.fromJson),
        clip: _obj(json['clip'], Clip.fromJson),
        edgeTreatment: _obj(json['edgeTreatment'], EdgeTreatment.fromJson),
        palette: _obj(json['palette'], Palette.fromJson),
        effects: _obj(json['effects'], Effects.fromJson),
        typography: _obj(json['typography'], Typography.fromJson),
        motifs: [
          for (final m in (json['motifs'] as List? ?? const []))
            Motif.fromJson((m as Map).cast<String, Object?>()),
        ],
        provenance: _obj(json['provenance'], RecipeProvenance.fromJson),
      );

  DesignRecipe copyWith({
    int? seed,
    RecipeContent? content,
    Composition? composition,
    FlagCombination? flagCombination,
    Clip? clip,
    EdgeTreatment? edgeTreatment,
    Palette? palette,
    Effects? effects,
    Typography? typography,
    List<Motif>? motifs,
    RecipeProvenance? provenance,
  }) =>
      DesignRecipe(
        seed: seed ?? this.seed,
        content: content ?? this.content,
        composition: composition ?? this.composition,
        flagCombination: flagCombination ?? this.flagCombination,
        clip: clip ?? this.clip,
        edgeTreatment: edgeTreatment ?? this.edgeTreatment,
        palette: palette ?? this.palette,
        effects: effects ?? this.effects,
        typography: typography ?? this.typography,
        motifs: motifs ?? this.motifs,
        schemaVersion: schemaVersion,
        engineVersion: engineVersion,
        grammarVersion: grammarVersion,
        assetsVersion: assetsVersion,
        provenance: provenance ?? this.provenance,
      );
}

/// Decode an optional nested object with [fromJson] if present, else null.
T? _obj<T>(Object? value, T Function(Map<String, Object?>) fromJson) =>
    value == null ? null : fromJson((value as Map).cast<String, Object?>());
