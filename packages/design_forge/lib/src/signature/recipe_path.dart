/// Dotted paths into a recipe's JSON, used by Signature Recipes (ADR-181) to
/// name the parameters a variation envelope or a per-country override may
/// touch: `seed`, `tornStrips.distress`, `content.flags.0.code`.
///
/// Segments are map keys, or list indices written as plain integers. A path
/// only ever addresses a **leaf** (a JSON scalar) that already exists in the
/// pack's base recipe — a typo must fail when the pack is loaded, never
/// silently create a field the renderer ignores.
class RecipePath {
  RecipePath(this.path) : segments = path.split('.') {
    if (path.isEmpty || segments.any((s) => s.isEmpty)) {
      throw FormatException('Invalid recipe path "$path"');
    }
  }

  final String path;
  final List<String> segments;

  /// The leaf value at this path in [json], or throws [RecipePathError] when
  /// the path does not exist or does not end at a scalar.
  Object? read(Map<String, Object?> json) {
    Object? node = json;
    for (final seg in segments) {
      node = _child(node, seg);
    }
    if (node is Map || node is List) {
      throw RecipePathError(path, 'addresses an object, not a value');
    }
    return node;
  }

  /// Writes [value] at this path in [json] (mutating it). The path must
  /// already exist and end at a scalar.
  void write(Map<String, Object?> json, Object? value) {
    read(json); // validates existence + leaf-ness
    Object? node = json;
    for (final seg in segments.take(segments.length - 1)) {
      node = _child(node, seg);
    }
    final last = segments.last;
    if (node is Map) {
      node[last] = value;
    } else if (node is List) {
      node[int.parse(last)] = value;
    }
  }

  /// True when the path exists in [json] and ends at a scalar.
  bool existsIn(Map<String, Object?> json) {
    try {
      read(json);
      return true;
    } on RecipePathError {
      return false;
    }
  }

  Object? _child(Object? node, String seg) {
    if (node is Map) {
      if (!node.containsKey(seg)) {
        throw RecipePathError(path, 'no field "$seg"');
      }
      return node[seg];
    }
    if (node is List) {
      final i = int.tryParse(seg);
      if (i == null || i < 0 || i >= node.length) {
        throw RecipePathError(path, 'no list index "$seg"');
      }
      return node[i];
    }
    throw RecipePathError(path, '"$seg" is below a value');
  }

  @override
  bool operator ==(Object other) => other is RecipePath && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => path;
}

/// A recipe path that does not exist in the recipe it was applied to.
class RecipePathError implements Exception {
  RecipePathError(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => 'RecipePathError: "$path" $reason';
}

/// Deep copy of a JSON-like value (maps, lists, scalars).
Object? deepCopyJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final e in value.entries) e.key.toString(): deepCopyJson(e.value),
    };
  }
  if (value is List) return [for (final v in value) deepCopyJson(v)];
  return value;
}
