import 'dart:io';

import 'package:design_forge_render/design_forge_render.dart';

/// Locates the Roavvy flag SVGs on disk (this is a dev tool, so it reads the
/// repo assets directly rather than bundling 271 files). Tries to auto-discover
/// the repo from the current directory / executable path, with a sensible
/// fallback; the path is user-overridable in the UI.
class FlagSource {
  FlagSource(this.dir);

  final Directory dir;

  static const _relFromRepo = 'apps/mobile_flutter/assets/flags/svg';

  /// Sibling silhouettes directory (`…/assets/silhouettes`).
  Directory get silhouetteDir =>
      Directory('${dir.parent.parent.path}/silhouettes');

  /// Discover the flags directory, or null if not found.
  static FlagSource? locate() {
    final candidates = <String>[];
    // Walk up from cwd and from the executable location.
    for (final start in [Directory.current.path, Platform.resolvedExecutable]) {
      var d = Directory(start);
      for (var i = 0; i < 12; i++) {
        candidates.add('${d.path}/$_relFromRepo');
        final parent = d.parent;
        if (parent.path == d.path) break;
        d = parent;
      }
    }
    // Last-resort absolute default (this machine's checkout).
    candidates.add('/Users/adglad/git/roavvy/$_relFromRepo');

    for (final c in candidates) {
      final dir = Directory(c);
      if (dir.existsSync() && File('${dir.path}/us.svg').existsSync()) {
        return FlagSource(dir);
      }
    }
    return null;
  }

  /// All available ISO-2 flag codes, sorted.
  List<String> codes() {
    final out = <String>[];
    for (final f in dir.listSync()) {
      final name = f.path.split(Platform.pathSeparator).last;
      if (name.endsWith('.svg')) out.add(name.substring(0, name.length - 4));
    }
    out.sort();
    return out;
  }

  /// Repo root (…/apps/mobile_flutter/assets/flags/svg → up 5).
  Directory get _repoRoot {
    var d = dir;
    for (var i = 0; i < 5; i++) {
      d = d.parent;
    }
    return d;
  }

  /// Silhouette source dirs by kind. The `silhouette_factory` tool holds the full
  /// per-kind sets as potrace SVGs (animals in `svg/`, plus `svg_plants/` and
  /// `svg_landmarks/`), organised in per-country subfolders. The app currently
  /// bundles only a curated one-per-country animal subset, so for the dev Lab we
  /// read the factory sets (falling back to the bundled dir for animals).
  Map<String, Directory> get _silhouetteDirs {
    final factory = '${_repoRoot.path}/tools/silhouette_factory/assets';
    final factoryAnimals = Directory('$factory/svg');
    return {
      'animal': factoryAnimals.existsSync() ? factoryAnimals : silhouetteDir,
      'plant': Directory('$factory/svg_plants'),
      'landmark': Directory('$factory/svg_landmarks'),
    };
  }

  // slug → absolute .svg path, and slug → kind. Built once, lazily.
  Map<String, String>? _index;
  final Map<String, String> _kind = {};

  void _ensureIndex() {
    if (_index != null) return;
    final idx = <String, String>{};
    _silhouetteDirs.forEach((kind, d) {
      if (!d.existsSync()) return;
      for (final f in d.listSync(recursive: true)) {
        if (f is! File) continue;
        final name = f.path.split(Platform.pathSeparator).last;
        if (!name.endsWith('.svg')) continue;
        final slug = name.substring(0, name.length - 4);
        idx.putIfAbsent(slug, () => f.path);
        _kind.putIfAbsent(slug, () => kind);
      }
    });
    _index = idx;
  }

  /// All available silhouette slugs (across animal/plant/landmark), sorted.
  List<String> silhouetteSlugs() {
    _ensureIndex();
    return _index!.keys.toList()..sort();
  }

  /// Silhouette slugs grouped by kind ('animal' / 'plant' / 'landmark'), read
  /// straight from the per-kind source dirs (accurate — no slug guessing).
  Map<String, List<String>> silhouettesByKind() {
    _ensureIndex();
    final result = <String, List<String>>{
      'animal': [],
      'plant': [],
      'landmark': [],
    };
    _kind.forEach((slug, kind) => (result[kind] ??= []).add(slug));
    for (final v in result.values) {
      v.sort();
    }
    return result;
  }

  /// Absolute path to a silhouette SVG by slug, or null.
  String? silhouettePath(String slug) {
    _ensureIndex();
    return _index![slug];
  }

  // ISO-2 (lowercase) → English country name, parsed once from the app's
  // canonical map so the Lab has a single source of truth (never duplicated).
  Map<String, String>? _names;

  /// Country display names by lowercase ISO-2 code (e.g. `sc` → `Seychelles`).
  /// Read from `apps/mobile_flutter/lib/core/country_names.dart`; empty if that
  /// file is missing. Values may be single- or double-quoted in the source.
  Map<String, String> countryNames() {
    if (_names != null) return _names!;
    final out = <String, String>{};
    final f = File(
        '${_repoRoot.path}/apps/mobile_flutter/lib/core/country_names.dart');
    if (f.existsSync()) {
      final re = RegExp("'([A-Z]{2})':\\s*(['\"])(.*?)\\2");
      for (final m in re.allMatches(f.readAsStringSync())) {
        out[m.group(1)!.toLowerCase()] = m.group(3)!;
      }
    }
    _names = out;
    return out;
  }

  Directory get _assetsDir => dir.parent.parent;
  Directory get countryPathsDir => Directory('${_assetsDir.path}/country_paths');

  /// Real passport entry/exit stamp PNGs (ink on transparent) live in the app's
  /// `assets/mobile_png/`, named `<country>-<cc>-<entry|exit>.png`.
  Directory get _stampDir => Directory('${_assetsDir.path}/mobile_png');

  // Normalised slug (`sc_entry`, `us_exit`) → absolute PNG path. Normalising to
  // the `cc_<name>` convention lets the same single-country filtering used for
  // silhouettes work unchanged. Built once, lazily.
  Map<String, String>? _stampIndex;

  void _ensureStampIndex() {
    if (_stampIndex != null) return;
    final idx = <String, String>{};
    final d = _stampDir;
    if (d.existsSync()) {
      final re = RegExp(r'^.+-([a-z]{2})-(entry|exit)\.png$', caseSensitive: false);
      for (final f in d.listSync()) {
        if (f is! File) continue;
        final name = f.path.split(Platform.pathSeparator).last;
        final m = re.firstMatch(name);
        if (m == null) continue;
        final cc = m.group(1)!.toLowerCase();
        final dir = m.group(2)!.toLowerCase();
        var slug = '${cc}_$dir';
        // Disambiguate rare per-country variants (e.g. two entry stamps).
        var n = 2;
        while (idx.containsKey(slug)) {
          slug = '${cc}_$dir$n';
          n++;
        }
        idx[slug] = f.path;
      }
    }
    _stampIndex = idx;
  }

  /// Normalised passport-stamp slugs (`sc_entry`, `sc_exit`, …), sorted.
  List<String> passportStampSlugs() {
    _ensureStampIndex();
    return _stampIndex!.keys.toList()..sort();
  }

  /// Absolute path to a passport-stamp PNG by slug, or null.
  String? passportStampPath(String slug) {
    _ensureStampIndex();
    return _stampIndex![slug];
  }

  Directory get continentPathsDir =>
      Directory('${_assetsDir.path}/continent_paths');

  /// Continent outline ids available (e.g. 'europe', 'asia'), excluding the
  /// per-country variants.
  List<String> continents() {
    final d = continentPathsDir;
    if (!d.existsSync()) return const [];
    final out = <String>[];
    for (final f in d.listSync()) {
      final name = f.path.split(Platform.pathSeparator).last;
      if (name.endsWith('.json') && !name.endsWith('_countries.json')) {
        out.add(name.substring(0, name.length - 5));
      }
    }
    out.sort();
    return out;
  }

  SvgFlagResolver resolver() => SvgFlagResolver(
        (code) => File('${dir.path}/$code.svg').readAsString(),
        silhouetteLookup: (slug) {
          final path = silhouettePath(slug) ?? '${silhouetteDir.path}/$slug.svg';
          return File(path).readAsString();
        },
        countryOutlineLookup: (code) =>
            File('${countryPathsDir.path}/$code.json').readAsString(),
        continentOutlineLookup: (name) =>
            File('${continentPathsDir.path}/$name.json').readAsString(),
        passportStampLookup: (slug) {
          final path = passportStampPath(slug);
          if (path == null) throw StateError('no passport stamp for $slug');
          return File(path).readAsBytes();
        },
      );

  /// `<repo>/design_studio/generated_batches/lab_export`, created on demand.
  Directory get labOutputDir {
    // dir = <repo>/apps/mobile_flutter/assets/flags/svg → up 5 to <repo>.
    var repo = dir;
    for (var i = 0; i < 5; i++) {
      repo = repo.parent;
    }
    final out =
        Directory('${repo.path}/design_studio/generated_batches/lab_export');
    out.createSync(recursive: true);
    return out;
  }
}

