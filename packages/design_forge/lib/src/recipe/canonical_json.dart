import 'dart:convert';

/// Canonical JSON serialisation used for content hashing.
///
/// Produces a deterministic string for any JSON-like value: map keys are
/// emitted in sorted order and there is no incidental whitespace, so two
/// logically-equal structures always yield byte-identical output regardless of
/// insertion order. This is the basis of a stable `recipeId`.
String canonicalJsonEncode(Object? value) {
  final buffer = StringBuffer();
  _writeCanonical(buffer, value);
  return buffer.toString();
}

void _writeCanonical(StringBuffer out, Object? value) {
  if (value == null) {
    out.write('null');
  } else if (value is String) {
    out.write(jsonEncode(value));
  } else if (value is bool) {
    out.write(value ? 'true' : 'false');
  } else if (value is num) {
    // Normalise integral doubles (1.0 -> 1) so 1 and 1.0 hash identically.
    if (value is double && value == value.roundToDouble() && value.isFinite) {
      out.write(value.toInt().toString());
    } else {
      out.write(value.toString());
    }
  } else if (value is List) {
    out.write('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) out.write(',');
      _writeCanonical(out, value[i]);
    }
    out.write(']');
  } else if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    out.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) out.write(',');
      out.write(jsonEncode(keys[i]));
      out.write(':');
      _writeCanonical(out, value[keys[i]]);
    }
    out.write('}');
  } else {
    throw ArgumentError('Not JSON-encodable: ${value.runtimeType}');
  }
}

/// Stable 64-bit FNV-1a hash of [s], returned as a 16-char lowercase hex string.
/// Independent of the engine RNG so the hash never shifts if the RNG evolves.
String stableContentHash(String s) {
  const int mask = 0xFFFFFFFFFFFFFFFF;
  var h = 0xCBF29CE484222325;
  for (final unit in s.codeUnits) {
    h = (h ^ unit) & mask;
    h = (h * 0x100000001B3) & mask;
  }
  return (h & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}
