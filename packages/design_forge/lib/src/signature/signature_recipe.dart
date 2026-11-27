import '../recipe/design_recipe.dart';
import 'recipe_path.dart';
import 'variation_envelope.dart';

/// Whether a Signature Recipe may be shown to users.
enum SignatureStatus {
  /// Being tuned in the Design Lab. Never shown in a release build.
  draft,

  /// Approved by the owner in the Design Lab.
  approved;

  static SignatureStatus fromId(Object? id) => switch (id) {
        'draft' => draft,
        'approved' => approved,
        _ => throw FormatException('Unknown signature status "$id"'),
      };
}

/// A parameter fix for one country, with the reason it is needed.
///
/// Overrides may only change parameters; they never add a flag's anatomy to
/// the shared recipe (ADR-179's Seychelles lesson). An override on a path that
/// is also in the envelope pins that path for this country (variations stop
/// varying it) and must lie inside the envelope's range.
class CountryOverride {
  CountryOverride({required Map<String, Object?> params, required this.reason})
      : params = Map.unmodifiable(params) {
    if (reason.trim().isEmpty) {
      throw const FormatException('A country override needs a reason');
    }
    if (params.isEmpty) {
      throw const FormatException('A country override must change something');
    }
  }

  final Map<String, Object?> params;
  final String reason;

  Map<String, Object?> toJson() => {'params': params, 'reason': reason};

  factory CountryOverride.fromJson(Map<String, Object?> json) {
    for (final k in json.keys) {
      if (k != 'params' && k != 'reason') {
        throw FormatException('Unknown override field "$k"');
      }
    }
    final params = json['params'];
    if (params is! Map) {
      throw const FormatException('Override "params" must be an object');
    }
    return CountryOverride(
      params: params.cast<String, Object?>(),
      reason: (json['reason'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CountryOverride &&
      other.reason == reason &&
      _scalarMapEquals(other.params, params);

  @override
  int get hashCode =>
      Object.hash(reason, Object.hashAll(params.entries.map((e) => e.key)));
}

/// One of the v2 signature T-shirt designs (ADR-181): a base recipe that works
/// for every country, the ranges its variations may move within, sparse
/// per-country fixes, curated heroes, and locks that catch engine drift.
///
/// This is data. [SignatureResolver] turns it into a [DesignRecipe] for a
/// country; `SignaturePackCodec` reads and writes it as a pack file.
class SignatureRecipe {
  SignatureRecipe({
    required this.id,
    required this.title,
    required this.version,
    required this.status,
    required Map<String, Object?> base,
    VariationEnvelope? envelope,
    Map<String, CountryOverride> overrides = const {},
    Map<String, Map<String, Object?>> heroes = const {},
    Map<String, String> locks = const {},
    this.approvedAt,
    this.notes,
  })  : base = Map.unmodifiable(deepCopyJson(base) as Map<String, Object?>),
        envelope = envelope ?? VariationEnvelope.empty,
        overrides = Map.unmodifiable(_lowerKeys(overrides)),
        heroes = Map.unmodifiable({
          for (final e in _lowerKeys(heroes).entries)
            e.key: Map<String, Object?>.unmodifiable(e.value),
        }),
        locks = Map.unmodifiable(_lowerKeys(locks)) {
    _validate();
  }

  /// Token replaced by the lowercase ISO country code in every string of the
  /// base recipe (e.g. the flag code).
  static const String countryToken = '{{country}}';

  /// Stable id, also the pack file name: `torn_flag` → `torn_flag.pack.json`.
  final String id;
  final String title;

  /// Bumped on every approval. Part of the variation seed, so approving a
  /// new version reshuffles variations (heroes are pinned by [locks]).
  final int version;
  final SignatureStatus status;

  /// ISO-8601 timestamp of the approval, null while [SignatureStatus.draft].
  final String? approvedAt;
  final String? notes;

  /// Recipe JSON template (no `recipeId`/`provenance`); strings may contain
  /// [countryToken].
  final Map<String, Object?> base;
  final VariationEnvelope envelope;

  /// Lowercase country code → fix.
  final Map<String, CountryOverride> overrides;

  /// Lowercase country code → curated envelope values for the hero.
  final Map<String, Map<String, Object?>> heroes;

  /// Lowercase country code → the hero's expected `recipeId`.
  final Map<String, String> locks;

  bool get isApproved => status == SignatureStatus.approved;

  /// The base template with [countryToken] (and any extra `{{name}}` tokens)
  /// substituted. A fresh mutable copy every call.
  Map<String, Object?> instantiate(String country,
      {Map<String, String> tokens = const {}}) {
    final all = {'country': country.toLowerCase(), ...tokens};
    return _substitute(deepCopyJson(base), all) as Map<String, Object?>;
  }

  SignatureRecipe copyWith({
    String? title,
    int? version,
    SignatureStatus? status,
    Map<String, Object?>? base,
    VariationEnvelope? envelope,
    Map<String, CountryOverride>? overrides,
    Map<String, Map<String, Object?>>? heroes,
    Map<String, String>? locks,
    String? approvedAt,
    String? notes,
  }) =>
      SignatureRecipe(
        id: id,
        title: title ?? this.title,
        version: version ?? this.version,
        status: status ?? this.status,
        base: base ?? this.base,
        envelope: envelope ?? this.envelope,
        overrides: overrides ?? this.overrides,
        heroes: heroes ?? this.heroes,
        locks: locks ?? this.locks,
        approvedAt: approvedAt ?? this.approvedAt,
        notes: notes ?? this.notes,
      );

  void _validate() {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id)) {
      throw FormatException('Signature id "$id" must be lower_snake_case');
    }
    if (version < 1) throw const FormatException('version must be >= 1');
    if (status == SignatureStatus.approved && approvedAt == null) {
      throw const FormatException('An approved signature needs approvedAt');
    }
    if (base.containsKey('recipeId') || base.containsKey('provenance')) {
      throw const FormatException(
          'base must not carry recipeId/provenance (they are derived)');
    }
    if (!_containsToken(base, countryToken)) {
      throw const FormatException(
          'base must use {{country}} so it works for every country');
    }

    // The base must be a real recipe once a country is filled in.
    final sample = instantiate('us');
    try {
      DesignRecipe.fromJson(sample);
    } catch (e) {
      throw FormatException('base is not a valid DesignRecipe: $e');
    }

    for (final entry in envelope.ranges.entries) {
      final path = RecipePath(entry.key);
      final current = _readOrFail(path, sample, 'envelope');
      if (current is String && current.contains('{{')) {
        throw FormatException(
            'envelope path "${entry.key}" addresses a templated value');
      }
      // Every bound of the range must make a valid recipe (e.g. rotation
      // only takes quarter turns), so a bad range fails here, not at render.
      final probes = switch (entry.value) {
        NumRange(:final min, :final max) => [min, max],
        ValueSet(:final values) => values,
      };
      for (final v in probes) {
        final probe = instantiate('us');
        path.write(probe, v);
        try {
          DesignRecipe.fromJson(probe);
        } catch (e) {
          throw FormatException('envelope "${entry.key}" allows $v: $e');
        }
      }
    }
    for (final o in overrides.entries) {
      for (final p in o.value.params.entries) {
        _checkValue(p.key, p.value, sample, 'override ${o.key}');
      }
    }
    for (final h in heroes.entries) {
      for (final p in h.value.entries) {
        if (!envelope.ranges.containsKey(p.key)) {
          throw FormatException(
              'hero ${h.key}: "${p.key}" is not in the envelope');
        }
        _checkValue(p.key, p.value, sample, 'hero ${h.key}');
      }
    }
  }

  void _checkValue(
      String path, Object? value, Map<String, Object?> sample, String where) {
    _readOrFail(RecipePath(path), sample, where);
    if (value is Map || value is List) {
      throw FormatException('$where: "$path" must be a scalar');
    }
    final range = envelope.ranges[path];
    if (range != null && !range.contains(value)) {
      throw FormatException(
          '$where: "$path" = $value is outside the envelope ${range.toJson()}');
    }
  }

  Object? _readOrFail(
      RecipePath path, Map<String, Object?> json, String where) {
    try {
      return path.read(json);
    } on RecipePathError catch (e) {
      throw FormatException('$where: ${e.path} ${e.reason}');
    }
  }
}

Map<String, V> _lowerKeys<V>(Map<String, V> m) =>
    {for (final e in m.entries) e.key.toLowerCase(): e.value};

bool _containsToken(Object? node, String token) {
  if (node is String) return node.contains(token);
  if (node is Map) return node.values.any((v) => _containsToken(v, token));
  if (node is List) return node.any((v) => _containsToken(v, token));
  return false;
}

Object? _substitute(Object? node, Map<String, String> tokens) {
  if (node is String) {
    var s = node;
    for (final t in tokens.entries) {
      s = s.replaceAll('{{${t.key}}}', t.value);
    }
    return s;
  }
  if (node is Map) {
    return <String, Object?>{
      for (final e in node.entries) e.key.toString(): _substitute(e.value, tokens),
    };
  }
  if (node is List) return [for (final v in node) _substitute(v, tokens)];
  return node;
}

bool _scalarMapEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
