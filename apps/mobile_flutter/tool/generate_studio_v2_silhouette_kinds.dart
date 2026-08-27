// Dev script: regenerates
//   lib/features/studio_v2/host/silhouette_inventory.g.dart
// from the actual bundled files in assets/silhouettes/, classifying each into
// animal / plant / landmark by cross-referencing the silhouette-factory source
// folders (tools/silhouette_factory/assets/{svg,svg_plants,svg_landmarks}).
//
// Run from the app root (apps/mobile_flutter):
//   dart run tool/generate_studio_v2_silhouette_kinds.dart
//
// The mobile app bundles ONE curated national silhouette per country — the
// subject varies (mostly animals, a few landmarks). This script records the
// KIND per bundled slug so Studio V2's Detail step can offer Animals / Plants /
// Landmarks pickers over the real bundled inventory (no reduction). Slugs whose
// kind cannot be resolved from the factory default to `animal` (manual review of
// the current bundle confirms every such slug is an animal). It is the Studio-V2
// counterpart to `features/merch/bundled_silhouette_manifest.dart`, kept
// separate so the frozen V1 merch code is never imported.
import 'dart:io';

const _bundleDir = 'assets/silhouettes';
const _factory = '../../tools/silhouette_factory/assets';
const _outPath = 'lib/features/studio_v2/host/silhouette_inventory.g.dart';

// Factory kind folders (basename → kind). Filenames match the bundled ones
// exactly (`fr_eiffel_tower.svg`), so a full-basename lookup is reliable.
const _kindDirs = {
  'animal': 'svg',
  'plant': 'svg_plants',
  'landmark': 'svg_landmarks',
};

void main() {
  final bundle = Directory(_bundleDir);
  if (!bundle.existsSync()) {
    stderr.writeln('Asset dir not found: $_bundleDir (run from apps/mobile_flutter)');
    exitCode = 1;
    return;
  }

  // Index the factory: full basename (lowercase) → kind.
  final kindOf = <String, String>{};
  _kindDirs.forEach((kind, sub) {
    final root = Directory('$_factory/$sub');
    if (!root.existsSync()) return;
    for (final cc in root.listSync().whereType<Directory>()) {
      for (final f in cc.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.svg')) continue;
        kindOf.putIfAbsent(name.substring(0, name.length - 4).toLowerCase(),
            () => kind);
      }
    }
  });

  final byKind = <String, List<String>>{'animal': [], 'plant': [], 'landmark': []};
  for (final f in bundle.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.svg')) continue;
    final slug = name.substring(0, name.length - 4);
    final kind = kindOf[slug.toLowerCase()] ?? 'animal';
    byKind[kind]!.add(slug);
  }
  for (final v in byKind.values) {
    v.sort();
  }

  final b = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run tool/generate_studio_v2_silhouette_kinds.dart')
    ..writeln('//')
    ..writeln('// The Studio V2 silhouette inventory: bundled national-silhouette slugs at')
    ..writeln('// `assets/silhouettes/<slug>.svg`, grouped by kind. Feeds the Detail step\'s')
    ..writeln('// Animals / Plants / Landmarks pickers. Kept separate from the frozen V1 merch')
    ..writeln('// manifest so `features/merch` is never imported by `features/studio_v2`.')
    ..writeln('')
    ..writeln('/// Bundled silhouette slugs grouped by kind (\'animal\' / \'plant\' / \'landmark\').')
    ..writeln('const Map<String, List<String>> kStudioV2SilhouettesByKind = {');
  for (final kind in const ['animal', 'plant', 'landmark']) {
    b.writeln("  '$kind': [");
    for (final slug in byKind[kind]!) {
      b.writeln("    '$slug',");
    }
    b.writeln('  ],');
  }
  b.writeln('};');

  File(_outPath).writeAsStringSync(b.toString());
  stdout.writeln('Wrote $_outPath  '
      '(animal ${byKind['animal']!.length}, plant ${byKind['plant']!.length}, '
      'landmark ${byKind['landmark']!.length}).');
}
