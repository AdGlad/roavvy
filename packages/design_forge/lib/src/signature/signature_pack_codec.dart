import 'dart:convert';

import '../recipe/design_recipe.dart';
import 'recipe_path.dart';
import 'signature_recipe.dart';
import 'variation_envelope.dart';

/// Reads and writes `roavvy.signature_pack` files (ADR-181 §2).
///
/// Output is stable: keys sorted, two-space indent, trailing newline, so a
/// pack written by the Lab diffs cleanly and `encode(decode(file)) == file`.
/// Unknown fields are rejected so a newer pack never half-loads in an older
/// app, and a typo never silently does nothing.
class SignaturePackCodec {
  const SignaturePackCodec._();

  static const String format = 'roavvy.signature_pack';
  static const int formatVersion = 1;

  static const Set<String> _fields = {
    'format',
    'formatVersion',
    'id',
    'title',
    'version',
    'status',
    'approvedAt',
    'notes',
    'base',
    'envelope',
    'overrides',
    'heroes',
    'locks',
  };

  static String encode(SignatureRecipe s) {
    final json = <String, Object?>{
      'format': format,
      'formatVersion': formatVersion,
      'id': s.id,
      'title': s.title,
      'version': s.version,
      'status': s.status.name,
      if (s.approvedAt != null) 'approvedAt': s.approvedAt,
      if (s.notes != null) 'notes': s.notes,
      'base': s.base,
      'envelope': s.envelope.toJson(),
      'overrides': {
        for (final e in s.overrides.entries) e.key: e.value.toJson(),
      },
      'heroes': s.heroes,
      'locks': s.locks,
    };
    return '${const JsonEncoder.withIndent('  ').convert(_sorted(json))}\n';
  }

  static SignatureRecipe decode(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map) throw const FormatException('A pack must be an object');
    final json = raw.cast<String, Object?>();
    if (json['format'] != format) {
      throw FormatException('Not a signature pack (format ${json['format']})');
    }
    final v = json['formatVersion'];
    if (v != formatVersion) {
      throw FormatException(
          'Unsupported signature pack formatVersion $v (this app reads $formatVersion)');
    }
    for (final k in json.keys) {
      if (!_fields.contains(k)) {
        throw FormatException('Unknown signature pack field "$k"');
      }
    }
    return SignatureRecipe(
      id: _req<String>(json, 'id'),
      title: _req<String>(json, 'title'),
      version: _req<num>(json, 'version').toInt(),
      status: SignatureStatus.fromId(json['status']),
      approvedAt: json['approvedAt'] as String?,
      notes: json['notes'] as String?,
      base: _map(json['base'], 'base'),
      envelope: VariationEnvelope.fromJson(_map(json['envelope'] ?? {}, 'envelope')),
      overrides: {
        for (final e in _map(json['overrides'] ?? {}, 'overrides').entries)
          e.key: CountryOverride.fromJson(_map(e.value, 'overrides.${e.key}')),
      },
      heroes: {
        for (final e in _map(json['heroes'] ?? {}, 'heroes').entries)
          e.key: _map(e.value, 'heroes.${e.key}'),
      },
      locks: {
        for (final e in _map(json['locks'] ?? {}, 'locks').entries)
          e.key: e.value as String,
      },
    );
  }

  /// A draft pack whose base is [recipe] with its flag code replaced by the
  /// country token — how a Lab preset becomes the start of a signature.
  /// The lock pins [recipe]'s own country, so the new pack reproduces the
  /// preset exactly for it.
  static SignatureRecipe draftFromRecipe({
    required String id,
    required String title,
    required DesignRecipe recipe,
    String? notes,
  }) {
    final json = recipe.toJson()
      ..remove('recipeId')
      ..remove('provenance');
    final flags = RecipePath('content.flags.0.code');
    final country = (flags.read(json) as String).toLowerCase();
    flags.write(json, SignatureRecipe.countryToken);
    final draft = SignatureRecipe(
      id: id,
      title: title,
      version: 1,
      status: SignatureStatus.draft,
      base: json,
      notes: notes,
    );
    return draft.copyWith(locks: {country: recipe.recipeId});
  }

  static T _req<T>(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is! T) throw FormatException('Signature pack needs "$key"');
    return v;
  }

  static Map<String, Object?> _map(Object? v, String where) {
    if (v is! Map) throw FormatException('$where must be an object');
    return (deepCopyJson(v) as Map<String, Object?>);
  }

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final e in v) _sorted(e)];
    return v;
  }
}
