// Development-only scaffolder for reference analysis records.
//
// Walks design_studio/reference_images/{liked,disliked} and, for every image
// that has no matching reference_analysis/<stem>.json, writes a STUB record
// (verdict inferred from the folder, provenance pre-filled, features left blank
// for you to complete). Idempotent: existing records are never overwritten.
//
// Pure Dart — no packages, no Flutter, no image decoding. For machine-filled
// objective features (dominant colour, focal hierarchy, legibility) run the
// analyzer instead:
//   flutter test test/features/merch/design_engine/reference/analyze_references_test.dart
//
// Run from the repo root:
//   dart run design_studio/tools/scaffold_references.dart

import 'dart:convert';
import 'dart:io';

const _imageExts = {'.png', '.jpg', '.jpeg', '.webp', '.heic'};

void main(List<String> args) {
  // Resolve the design_studio root relative to this script so it works from
  // anywhere.
  final scriptDir = File.fromUri(Platform.script).parent.path; // .../tools
  final studioRoot = Directory(scriptDir).parent.path; // .../design_studio
  final analysisDir = Directory('$studioRoot/reference_analysis')
    ..createSync(recursive: true);

  var created = 0, skipped = 0, images = 0;
  for (final verdict in const ['liked', 'disliked']) {
    final dir = Directory('$studioRoot/reference_images/$verdict');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final ext = entity.path
          .substring(entity.path.lastIndexOf('.'))
          .toLowerCase();
      if (!_imageExts.contains(ext)) continue;
      images++;
      final stem = _stem(entity.path);
      final out = File('${analysisDir.path}/$stem.json');
      if (out.existsSync()) {
        skipped++;
        continue;
      }
      out.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(_stub(stem, verdict)));
      created++;
      stdout.writeln('  + $stem.json ($verdict)');
    }
  }

  stdout.writeln('scaffold_references: $images image(s) — '
      '$created stub(s) created, $skipped already had a record.');
  if (images == 0) {
    stdout.writeln('Drop images into '
        'design_studio/reference_images/{liked,disliked} first.');
  }
}

Map<String, dynamic> _stub(String stem, String verdict) => {
      'schemaVersion': 1,
      'imageStem': stem,
      'verdict': verdict,
      'reasons': <String>[],
      'features': {
        'template': null,
        'layoutMode': null,
        'density': null,
        'clipShape': null,
        'printStyleFeel': null,
        'dominantColors': <String>[],
        'focalHierarchy': null,
        'legibility': null,
        'tags': <String>[],
      },
      'nearestRecipeId': null,
      'provenance': {
        'source': 'own-render',
        'rightsCleared': false,
        'notes': 'TODO: confirm rights + fill subjective features.',
      },
    };

String _stem(String path) {
  final base = path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
  final dot = base.lastIndexOf('.');
  return dot < 0 ? base : base.substring(0, dot);
}
