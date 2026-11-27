import 'package:design_forge/design_forge.dart';

/// Pure edits on a [SignatureRecipe] for the Signature Workbench (M191).
///
/// Every edit returns a new pack (the constructor re-validates, so an invalid
/// edit throws [FormatException] and the UI keeps the old pack). Editing an
/// APPROVED pack turns it back into a draft at the next version: what users
/// see never changes until the owner approves again, and the version bump
/// reshuffles variations only for the new review.
class SignatureEdit {
  const SignatureEdit._();

  /// Version fields are engine-owned; content holds the country token.
  static const Set<String> _hiddenRoots = {
    'schemaVersion',
    'engineVersion',
    'grammarVersion',
    'assetsVersion',
    'content',
  };

  /// Every editable parameter path in the pack's base recipe, sorted, with
  /// `seed` first.
  static List<String> editablePaths(SignatureRecipe pack) {
    final out = <String>[];
    void walk(Object? node, String prefix) {
      if (node is Map) {
        for (final e in node.entries) {
          final key = e.key.toString();
          if (prefix.isEmpty && _hiddenRoots.contains(key)) continue;
          walk(e.value, prefix.isEmpty ? key : '$prefix.$key');
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], '$prefix.$i');
        }
      } else if (!(node is String && node.contains('{{'))) {
        out.add(prefix);
      }
    }

    walk(pack.base, '');
    out.sort((a, b) => a == 'seed'
        ? -1
        : b == 'seed'
            ? 1
            : a.compareTo(b));
    return out;
  }

  static Object? baseValue(SignatureRecipe pack, String path) =>
      RecipePath(path).read(pack.base);

  static SignatureRecipe setBase(
      SignatureRecipe pack, String path, Object? value) {
    final base = deepCopyJson(pack.base) as Map<String, Object?>;
    RecipePath(path).write(base, value);
    return _edit(pack, base: base);
  }

  /// Sets (or with null, removes) the envelope range for [path]. Removing a
  /// range also drops hero values for that path.
  static SignatureRecipe setRange(
      SignatureRecipe pack, String path, ParamRange? range) {
    final ranges = {...pack.envelope.ranges};
    if (range == null) {
      ranges.remove(path);
    } else {
      ranges[path] = range;
    }
    final heroes = {
      for (final e in pack.heroes.entries)
        e.key: {...e.value}..removeWhere((k, _) => !ranges.containsKey(k)),
    }..removeWhere((_, v) => v.isEmpty);
    return _edit(pack, envelope: VariationEnvelope(ranges), heroes: heroes);
  }

  static SignatureRecipe setOverride(
      SignatureRecipe pack, String country, CountryOverride? override) {
    final overrides = {...pack.overrides};
    if (override == null) {
      overrides.remove(country.toLowerCase());
    } else {
      overrides[country.toLowerCase()] = override;
    }
    return _edit(pack, overrides: overrides);
  }

  static SignatureRecipe setHero(
      SignatureRecipe pack, String country, Map<String, Object?>? values) {
    final heroes = {...pack.heroes};
    if (values == null || values.isEmpty) {
      heroes.remove(country.toLowerCase());
    } else {
      heroes[country.toLowerCase()] = values;
    }
    return _edit(pack, heroes: heroes);
  }

  /// The envelope values [variation] was drawn with — saving them as the
  /// country's hero makes that exact variation the hero.
  static Map<String, Object?> heroValuesOf(
      SignatureRecipe pack, DesignRecipe variation) {
    final json = variation.toJson();
    return {
      for (final p in pack.envelope.ranges.keys) p: RecipePath(p).read(json),
    };
  }

  /// The approved pack: status approved, [approvedAt], locks recomputed for
  /// [lockCountries]. Keeps the version, so the variations the owner reviewed
  /// are exactly the ones that ship.
  static SignatureRecipe approve(SignatureRecipe pack,
      {required List<String> lockCountries, required DateTime approvedAt}) {
    final locks = SignatureResolver.lockFor(pack, lockCountries);
    return SignatureRecipe(
      id: pack.id,
      title: pack.title,
      version: pack.version,
      status: SignatureStatus.approved,
      approvedAt: approvedAt.toUtc().toIso8601String(),
      notes: pack.notes,
      base: pack.base,
      envelope: pack.envelope,
      overrides: pack.overrides,
      heroes: pack.heroes,
      locks: locks,
    );
  }

  static SignatureRecipe _edit(
    SignatureRecipe pack, {
    Map<String, Object?>? base,
    VariationEnvelope? envelope,
    Map<String, CountryOverride>? overrides,
    Map<String, Map<String, Object?>>? heroes,
  }) {
    final reopen = pack.isApproved;
    return SignatureRecipe(
      id: pack.id,
      title: pack.title,
      version: reopen ? pack.version + 1 : pack.version,
      status: SignatureStatus.draft,
      approvedAt: null,
      notes: pack.notes,
      base: base ?? pack.base,
      envelope: envelope ?? pack.envelope,
      overrides: overrides ?? pack.overrides,
      heroes: heroes ?? pack.heroes,
      locks: pack.locks,
    );
  }

  /// Parses a value typed into the workbench, keeping the base value's type.
  static Object? parseLike(Object? current, String text) {
    final t = text.trim();
    if (current is bool) {
      if (t == 'true') return true;
      if (t == 'false') return false;
      throw FormatException('"$t" is not true/false');
    }
    if (current is int) {
      return int.tryParse(t) ?? (throw FormatException('"$t" is not a whole number'));
    }
    if (current is num) {
      return double.tryParse(t) ?? (throw FormatException('"$t" is not a number'));
    }
    if (current == null && t == 'null') return null;
    return t;
  }

  /// A sensible starting range for a parameter currently at [value].
  static ParamRange defaultRange(String path, Object? value) {
    if (path == 'seed') return const NumRange(1, 1000000, integer: true);
    // Upright or on its side. 180 is never a default: an upside-down flag is
    // a distress/protest signal.
    if (path == 'composition.rotation') return const ValueSet([0, 90]);
    if (value is bool) return const ValueSet([true, false]);
    if (value is int) return NumRange(value, value + 10, integer: true);
    if (value is num) {
      final v = value.toDouble();
      final lo = (v - 0.1).clamp(v >= 0 && v <= 1 ? 0.0 : v - 1, v);
      final hi = (v + 0.1).clamp(v, v >= 0 && v <= 1 ? 1.0 : v + 1);
      return NumRange(_r(lo), _r(hi));
    }
    return ValueSet([value]);
  }

  static double _r(double v) => (v * 1000).roundToDouble() / 1000;
}
