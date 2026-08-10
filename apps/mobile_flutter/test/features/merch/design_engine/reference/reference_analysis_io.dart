import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:mobile_flutter/features/merch/design_engine/reference/reference_style_analyzer.dart';

const _imageExts = {'.png', '.jpg', '.jpeg', '.webp'};

bool _isImage(String path) =>
    _imageExts.contains(path.substring(path.lastIndexOf('.')).toLowerCase());

String _stem(String filename) {
  final base = filename.substring(filename.lastIndexOf(Platform.pathSeparator) + 1);
  final dot = base.lastIndexOf('.');
  return dot < 0 ? base : base.substring(0, dot);
}

/// Decode [file] via Skia (dart:ui) and analyse it into objective features.
Future<ReferenceFeatures?> analyzeImageFile(File file) async {
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  try {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return analyzeReferenceRgba(
        data.buffer.asUint8List(), img.width, img.height);
  } finally {
    img.dispose();
  }
}

/// Merge machine features into an existing (or new) record, preserving any
/// human-authored fields (verdict override, reasons, tags, template feel…).
Map<String, dynamic> mergeRecord(
  Map<String, dynamic>? existing,
  String stem,
  String verdict,
  ReferenceFeatures f,
) {
  final record = Map<String, dynamic>.of(existing ?? {});
  record['schemaVersion'] = 1;
  record['imageStem'] = stem;
  record['verdict'] = record['verdict'] ?? verdict;
  record['reasons'] = record['reasons'] ?? <String>[];

  final feats = Map<String, dynamic>.of(
      (record['features'] as Map?)?.cast<String, dynamic>() ?? {});
  // Only overwrite the objective, machine-measured fields.
  feats.addAll(f.toFeaturesJson());
  record['features'] = feats;

  final prov = Map<String, dynamic>.of(
      (record['provenance'] as Map?)?.cast<String, dynamic>() ?? {});
  prov['source'] = prov['source'] ?? 'own-render';
  prov['rightsCleared'] = prov['rightsCleared'] ?? false;
  record['provenance'] = prov;

  record['analysis'] = f.toAnalysisJson();
  return record;
}

/// Analyse every image in [imagesDir] and write/merge its record into
/// [analysisDir]. Returns the number of images processed. Missing dirs → 0.
Future<int> analyzeReferenceFolder({
  required Directory imagesDir,
  required Directory analysisDir,
  required String verdict,
}) async {
  if (!imagesDir.existsSync()) return 0;
  analysisDir.createSync(recursive: true);
  var count = 0;
  for (final entity in imagesDir.listSync()) {
    if (entity is! File || !_isImage(entity.path)) continue;
    final features = await analyzeImageFile(entity);
    if (features == null) continue;
    final stem = _stem(entity.path);
    final out = File('${analysisDir.path}/$stem.json');
    Map<String, dynamic>? existing;
    if (out.existsSync()) {
      existing =
          jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    }
    final record = mergeRecord(existing, stem, verdict, features);
    out.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(record));
    count++;
  }
  return count;
}
