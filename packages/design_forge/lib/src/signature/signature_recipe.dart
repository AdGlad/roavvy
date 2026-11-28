import '../geo/country_names.dart';
import '../geo/iso3.dart';
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

/// An ordered pair of countries for a two-country signature (ADR-185):
/// [a] is drawn left/top, [b] right/bottom. `(fr, jp)` and `(jp, fr)` are
/// different designs. Its [key] (`"fr+jp"`) keys a pair pack's heroes, locks
/// and pair overrides.
class SignaturePair {
  SignaturePair(String a, String b)
      : a = a.toLowerCase(),
        b = b.toLowerCase() {
    if (this.a.isEmpty || this.b.isEmpty) {
      throw const FormatException('A pair needs two countries');
    }
    if (this.a == this.b) {
      throw FormatException('A pair needs two different countries ($a+$b)');
    }
  }

  /// Parses `"a+b"`.
  factory SignaturePair.parse(String key) {
    final parts = key.split('+');
    if (parts.length != 2) {
      throw FormatException('"$key" is not a country pair (expected "a+b")');
    }
    return SignaturePair(parts[0].trim(), parts[1].trim());
  }

  static bool isPairKey(String key) => key.contains('+');

  final String a;
  final String b;

  String get key => '$a+$b';
  SignaturePair get swapped => SignaturePair(b, a);

  @override
  bool operator ==(Object other) =>
      other is SignaturePair && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => key;
}

/// An ordered list of countries for a many-country signature (M214, Heart
/// Wall; pack `"countries": "n"`). Order is the input order (e.g. by first
/// visit) and is part of the design. Its [key] (`"us,fr,jp"`) keys a list
/// pack's heroes, locks and overrides, and seeds its variations.
class SignatureList {
  SignatureList(Iterable<String> codes)
      : codes =
            List.unmodifiable([for (final c in codes) c.trim().toLowerCase()]) {
    if (this.codes.isEmpty) {
      throw const FormatException('A country list needs at least one country');
    }
    if (this.codes.length > maxLength) {
      throw FormatException('A country list takes at most $maxLength countries '
          '(got ${this.codes.length})');
    }
    if (this.codes.any((c) => c.isEmpty || c.contains('+'))) {
      throw FormatException('"$key" is not a country list');
    }
    if (this.codes.toSet().length != this.codes.length) {
      throw FormatException('A country list repeats a country ($key)');
    }
  }

  /// Parses `"us,fr,jp"` (a single code is a list of one).
  factory SignatureList.parse(String key) => SignatureList(key.split(','));

  /// The most countries one design shows.
  static const int maxLength = 60;

  /// Sizes the Lab sheets and QA check a list pack at.
  static const List<int> sampleSizes = [3, 6, 12, 24, 48];

  /// A fixed traveller's order (mixed regions, emblem flags, a pennant, a
  /// square flag) whose first n countries make the sample lists.
  static const List<String> sampleOrder = [
    'fr', 'jp', 'us', 'br', 'np', 'za', 'gb', 'mx', 'it', 'ch', 'kr', 'au', //
    'es', 'ca', 'in', 'pt', 'gr', 'ar', 'th', 'eg', 'de', 'tr', 'nz', 'pe', //
    'ie', 'ma', 'vn', 'se', 'cl', 'id', 'hr', 'ke', 'no', 'is', 'cu', 'ph', //
    'nl', 'bt', 'ae', 'fi', 'co', 'sg', 'at', 'cz', 'jm', 'lk', 'dk', 'pa', //
  ];

  /// The sample lists: the first n of [sampleOrder] for each of
  /// [sampleSizes].
  static List<SignatureList> get samples => [
        for (final n in sampleSizes) SignatureList(sampleOrder.take(n)),
      ];

  final List<String> codes;

  String get key => codes.join(',');
  int get length => codes.length;

  @override
  bool operator ==(Object other) => other is SignatureList && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
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
    Map<String, String> tokens = const {},
    Map<String, Object?> layout = const {},
    this.countries = 1,
    List<String> samplePairs = const [],
    this.approvedAt,
    this.notes,
  })  : tokens = Map.unmodifiable(tokens),
        samplePairs = List.unmodifiable(
            [for (final p in samplePairs) SignaturePair.parse(p).key]),
        layout = Map.unmodifiable(deepCopyJson(layout) as Map<String, Object?>),
        base = Map.unmodifiable(deepCopyJson(base) as Map<String, Object?>),
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

  /// Tokens every pack gets without declaring a default: `country` (the
  /// lowercase ISO code), `country3` (its 3-letter code, e.g. USA) and
  /// `countryName` (its display name, e.g. Greece).
  static const Set<String> builtInTokens = {
    'country',
    'country3',
    'countryName',
    ...pairTokens,
    ...listTokens,
  };

  /// Tokens of a two-country pack ([countries] = 2): country A (left/top)
  /// and country B (right/bottom), each as code, 3-letter code and name.
  static const Set<String> pairTokens = {
    'countryA',
    'countryA3',
    'countryAName',
    'countryB',
    'countryB3',
    'countryBName',
  };

  /// [countries] value of a many-country pack (`"countries": "n"` in the
  /// file).
  static const int anyCount = 0;

  /// A list pack's flags: a JSON string value that is exactly this token is
  /// replaced by the list of flag refs (`{"code": cc, "weight": 1.0}`), one
  /// per country, in order. `{{countryCount}}` is the number of countries.
  static const String countriesToken = '{{countries}}';

  /// Tokens of a list pack.
  static const Set<String> listTokens = {'countries', 'countryCount'};

  /// List used to validate a list pack (and open it in the Lab).
  static final SignatureList defaultSampleList =
      SignatureList(['us', 'fr', 'jp', 'br', 'za', 'au']);

  static const Set<String> _singleTokens = {
    'country',
    'country3',
    'countryName',
  };

  /// In a pair pack's country override params, this path segment stands for
  /// the flag slot the overridden country occupies: `0` when it is country A,
  /// `1` when it is country B. `content.flags.{slot}.weight` therefore only
  /// touches that country's half. Paths without it apply to the whole design.
  static const String slotSegment = '{slot}';

  /// Pair used to validate a pair pack when it lists no [samplePairs].
  static final SignaturePair defaultSamplePair = SignaturePair('us', 'co');

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

  /// Default values for the base's other `{{name}}` tokens (e.g. a trip's
  /// `entry` / `exit` dates). The Lab renders with these; the app passes the
  /// traveller's real values, which take precedence. Every token the base
  /// uses (besides [countryToken]) must have a default.
  final Map<String, String> tokens;

  /// Where the design prints on the t-shirt by default — front/back zones and
  /// their sizes, as `design_studio`'s `PrintLayout` JSON. Empty means the
  /// app's default (a full back print). Opaque here: it is garment data, not
  /// recipe data, so it never changes a hero's `recipeId` or its lock.
  final Map<String, Object?> layout;

  /// How many countries the design takes: 1 (the default; keys are country
  /// codes), 2 (a pair pack; keys are `"a+b"`, see [SignaturePair]) or
  /// [anyCount] (a list pack, `"n"` in the file; keys are `"a,b,c"`, see
  /// [SignatureList]).
  final int countries;

  /// Pair packs only: the fixed pairs the Lab sheets and QA run over
  /// (`"a+b"` keys, order matters).
  final List<String> samplePairs;

  bool get isApproved => status == SignatureStatus.approved;
  bool get isPair => countries == 2;

  /// A many-country pack (Heart Wall).
  bool get isList => countries == anyCount;

  /// A one-country pack (keys are country codes).
  bool get isSingle => countries == 1;

  /// A list pack's base with its countries filled in, in order. A fresh
  /// mutable copy every call.
  Map<String, Object?> instantiateList(Iterable<String> codes,
      {Map<String, String> tokens = const {}}) {
    final list = SignatureList(codes);
    final all = {
      ...this.tokens,
      ...tokens,
      'countryCount': '${list.length}',
    };
    Object? expand(Object? node) {
      if (node == countriesToken) {
        return [
          for (final c in list.codes) {'code': c, 'weight': 1.0},
        ];
      }
      if (node is Map) {
        return {for (final e in node.entries) e.key: expand(e.value)};
      }
      if (node is List) return [for (final v in node) expand(v)];
      return node;
    }

    return _substitute(expand(deepCopyJson(base)), all) as Map<String, Object?>;
  }

  /// The pair a pair pack is validated (and opened in the Lab) with.
  SignaturePair get firstPair => samplePairs.isEmpty
      ? defaultSamplePair
      : SignaturePair.parse(samplePairs.first);

  /// A pair pack's base with both countries' tokens filled in. A fresh
  /// mutable copy every call.
  Map<String, Object?> instantiatePair(String a, String b,
      {Map<String, String> tokens = const {}}) {
    final p = SignaturePair(a, b);
    final all = {
      ...this.tokens,
      ...tokens,
      'countryA': p.a,
      'countryA3': countryAlpha3(p.a),
      'countryAName': countryDisplayName(p.a),
      'countryB': p.b,
      'countryB3': countryAlpha3(p.b),
      'countryBName': countryDisplayName(p.b),
    };
    return _substitute(deepCopyJson(base), all) as Map<String, Object?>;
  }

  /// [instantiate] or [instantiatePair] for a heroes/locks key: a country
  /// code for single packs, `"a+b"` for pair packs.
  Map<String, Object?> instantiateKey(String key,
      {Map<String, String> tokens = const {}}) {
    if (isList) {
      return instantiateList(SignatureList.parse(key).codes, tokens: tokens);
    }
    if (!isPair) return instantiate(key, tokens: tokens);
    final p = SignaturePair.parse(key);
    return instantiatePair(p.a, p.b, tokens: tokens);
  }

  /// A pair-pack override param [path] for the country in [slot] (0 = A,
  /// 1 = B), with [slotSegment] filled in.
  static String slotPath(String path, int slot) =>
      path.replaceAll(slotSegment, '$slot');

  /// The base template with [countryToken] (and any extra `{{name}}` tokens)
  /// substituted. A fresh mutable copy every call.
  Map<String, Object?> instantiate(String country,
      {Map<String, String> tokens = const {}}) {
    final all = {
      ...this.tokens,
      ...tokens,
      'country': country.toLowerCase(),
      'country3': countryAlpha3(country),
      'countryName': countryDisplayName(country),
    };
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
    Map<String, String>? tokens,
    Map<String, Object?>? layout,
    int? countries,
    List<String>? samplePairs,
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
        tokens: tokens ?? this.tokens,
        layout: layout ?? this.layout,
        countries: countries ?? this.countries,
        samplePairs: samplePairs ?? this.samplePairs,
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
    if (countries != 1 && countries != 2 && countries != anyCount) {
      throw FormatException('countries must be 1, 2 or "n" (got $countries)');
    }
    final usedTokens = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}')
        .allMatches(_strings(base).join('\n'))
        .map((m) => m.group(1)!)
        .toSet();
    if (isList) {
      if (!usedTokens.contains('countries')) {
        throw const FormatException(
            "a list pack's base must use {{countries}} (its flag list)");
      }
      final other = usedTokens.intersection({..._singleTokens, ...pairTokens});
      if (other.isNotEmpty) {
        throw FormatException('a list pack must not use '
            '${other.map((t) => '{{$t}}').join(', ')}; use {{countries}}');
      }
      if (samplePairs.isNotEmpty) {
        throw const FormatException(
            'samplePairs is only for pair packs (countries: 2)');
      }
    } else if (usedTokens.intersection(listTokens).isNotEmpty) {
      throw const FormatException(
          '{{countries}}/{{countryCount}} need a list pack ("countries": "n")');
    } else if (isPair) {
      final usesA = usedTokens.any((t) => t.startsWith('countryA'));
      final usesB = usedTokens.any((t) => t.startsWith('countryB'));
      if (!usesA || !usesB) {
        throw const FormatException(
            "a pair pack's base must use both {{countryA}} and {{countryB}}");
      }
      final single = usedTokens.intersection(_singleTokens);
      if (single.isNotEmpty) {
        throw FormatException('a pair pack must not use '
            '${single.map((t) => '{{$t}}').join(', ')}; '
            'use {{countryA}}/{{countryB}}');
      }
    } else {
      if (samplePairs.isNotEmpty) {
        throw const FormatException(
            'samplePairs is only for pair packs (countries: 2)');
      }
      if (!_containsToken(base, countryToken) &&
          !_containsToken(base, '{{country3}}')) {
        throw const FormatException(
            'base must use {{country}} so it works for every country');
      }
      final pair = usedTokens.intersection(pairTokens);
      if (pair.isNotEmpty) {
        throw FormatException('${pair.map((t) => '{{$t}}').join(', ')} '
            'need a pair pack ("countries": 2)');
      }
    }
    for (final k in heroes.keys) {
      _checkKey(k, 'hero');
    }
    for (final k in locks.keys) {
      _checkKey(k, 'lock');
    }
    for (final k in overrides.keys) {
      if (isList) {
        SignatureList.parse(k);
        continue;
      }
      if (SignaturePair.isPairKey(k)) {
        if (!isPair) {
          throw FormatException(
              'override "$k" is a pair, but this is a single-country pack');
        }
        SignaturePair.parse(k);
      }
    }

    // Every other token needs a default, so the Lab can always render.
    final used = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}')
        .allMatches(_strings(base).join('\n'))
        .map((m) => m.group(1)!)
        .toSet()
      ..removeAll(builtInTokens);
    final missing = used.difference(tokens.keys.toSet());
    if (missing.isNotEmpty) {
      throw FormatException(
          'base uses tokens without defaults: ${missing.map((t) => '{{$t}}').join(', ')}');
    }

    // The base must be a real recipe once a country is filled in.
    Map<String, Object?> fill() => isList
        ? instantiateList(defaultSampleList.codes)
        : isPair
            ? instantiatePair(firstPair.a, firstPair.b)
            : instantiate('us');
    final sample = fill();
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
        final probe = fill();
        path.write(probe, v);
        try {
          DesignRecipe.fromJson(probe);
        } catch (e) {
          throw FormatException('envelope "${entry.key}" allows $v: $e');
        }
      }
    }
    for (final o in overrides.entries) {
      final countryInPair = isPair && !SignaturePair.isPairKey(o.key);
      for (final p in o.value.params.entries) {
        if (p.key.contains(slotSegment) && !countryInPair) {
          throw FormatException('override ${o.key}: "${p.key}" uses '
              '$slotSegment, which only a country override in a pair pack has');
        }
        // A {slot} path must be valid for either slot.
        for (final slot in countryInPair ? const [0, 1] : const [-1]) {
          final path = slot < 0 ? p.key : slotPath(p.key, slot);
          _checkValue(path, p.value, sample, 'override ${o.key}');
        }
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

  void _checkKey(String key, String what) {
    if (isList) {
      SignatureList.parse(key);
      return;
    }
    if (isPair) {
      if (!SignaturePair.isPairKey(key)) {
        throw FormatException(
            '$what "$key" must be a country pair ("a+b") in a pair pack');
      }
      SignaturePair.parse(key);
    } else if (SignaturePair.isPairKey(key)) {
      throw FormatException(
          '$what "$key" is a pair, but this is a single-country pack');
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

Iterable<String> _strings(Object? node) sync* {
  if (node is String) yield node;
  if (node is Map) {
    for (final v in node.values) {
      yield* _strings(v);
    }
  }
  if (node is List) {
    for (final v in node) {
      yield* _strings(v);
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
      for (final e in node.entries)
        e.key.toString(): _substitute(e.value, tokens),
    };
  }
  if (node is List) return [for (final v in node) _substitute(v, tokens)];
  return node;
}

bool _scalarMapEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
