import '../determinism/deterministic_rng.dart';
import 'recipe_path.dart';

/// The allowed values for one recipe parameter in a Signature Recipe's
/// variation envelope (ADR-181).
sealed class ParamRange {
  const ParamRange();

  /// True when [value] lies inside this range.
  bool contains(Object? value);

  /// Draws a value inside this range from [rng].
  Object? sample(DeterministicRng rng);

  Map<String, Object?> toJson();

  static ParamRange fromJson(Map<String, Object?> json) {
    if (json.containsKey('values')) {
      _onlyKeys(json, const {'values'});
      final values = json['values'];
      if (values is! List || values.isEmpty) {
        throw const FormatException('"values" must be a non-empty list');
      }
      for (final v in values) {
        if (v is Map || v is List) {
          throw const FormatException('"values" must hold scalars only');
        }
      }
      return ValueSet(List<Object?>.unmodifiable(values));
    }
    _onlyKeys(json, const {'min', 'max', 'integer'});
    final min = json['min'];
    final max = json['max'];
    if (min is! num || max is! num || min > max) {
      throw const FormatException('A range needs numeric "min" <= "max"');
    }
    return NumRange(min, max, integer: json['integer'] == true);
  }
}

/// A numeric range `[min, max]` (inclusive). [integer] ranges sample whole
/// numbers; others are rounded to 4 decimals so recipes stay readable and
/// near-identical draws hash identically.
class NumRange extends ParamRange {
  const NumRange(this.min, this.max, {this.integer = false});

  final num min;
  final num max;
  final bool integer;

  @override
  bool contains(Object? value) =>
      value is num &&
      value >= min &&
      value <= max &&
      (!integer || value == value.roundToDouble());

  @override
  Object? sample(DeterministicRng rng) {
    if (integer) return rng.nextIntRange(min.toInt(), max.toInt());
    final v = rng.nextRange(min.toDouble(), max.toDouble());
    return (v * 10000).roundToDouble() / 10000;
  }

  @override
  Map<String, Object?> toJson() =>
      {'min': min, 'max': max, if (integer) 'integer': true};

  @override
  bool operator ==(Object other) =>
      other is NumRange &&
      other.min == min &&
      other.max == max &&
      other.integer == integer;

  @override
  int get hashCode => Object.hash(min, max, integer);
}

/// A fixed set of allowed scalar values, picked uniformly.
class ValueSet extends ParamRange {
  const ValueSet(this.values);

  final List<Object?> values;

  @override
  bool contains(Object? value) => values.contains(value);

  @override
  Object? sample(DeterministicRng rng) => rng.pick(values);

  @override
  Map<String, Object?> toJson() => {'values': values};

  @override
  bool operator ==(Object other) =>
      other is ValueSet &&
      other.values.length == values.length &&
      Iterable<int>.generate(values.length)
          .every((i) => other.values[i] == values[i]);

  @override
  int get hashCode => Object.hashAll(values);
}

/// Which parameters a variation may change, and within what range. Every
/// parameter not listed is fixed at the base (or override) value.
class VariationEnvelope {
  VariationEnvelope(Map<String, ParamRange> ranges)
      : ranges = Map.unmodifiable({
          for (final key in (ranges.keys.toList()..sort())) key: ranges[key]!,
        }) {
    for (final p in this.ranges.keys) {
      RecipePath(p); // validates syntax
    }
  }

  static final VariationEnvelope empty = VariationEnvelope(const {});

  /// Path → allowed range, sorted by path (sampling order is part of the
  /// determinism contract only through the per-path sub-stream, not order).
  final Map<String, ParamRange> ranges;

  bool get isEmpty => ranges.isEmpty;

  Map<String, Object?> toJson() => {
        for (final e in ranges.entries) e.key: e.value.toJson(),
      };

  factory VariationEnvelope.fromJson(Map<String, Object?> json) =>
      VariationEnvelope({
        for (final e in json.entries)
          e.key: ParamRange.fromJson(_asMap(e.value, 'envelope.${e.key}')),
      });

  @override
  bool operator ==(Object other) =>
      other is VariationEnvelope &&
      other.ranges.length == ranges.length &&
      ranges.entries.every((e) => other.ranges[e.key] == e.value);

  @override
  int get hashCode => Object.hashAll(
      ranges.entries.map((e) => Object.hash(e.key, e.value)));
}

void _onlyKeys(Map<String, Object?> json, Set<String> allowed) {
  for (final k in json.keys) {
    if (!allowed.contains(k)) {
      throw FormatException('Unknown field "$k" (allowed: ${allowed.join(', ')})');
    }
  }
}

Map<String, Object?> _asMap(Object? v, String where) {
  if (v is! Map) throw FormatException('$where must be an object');
  return v.cast<String, Object?>();
}
