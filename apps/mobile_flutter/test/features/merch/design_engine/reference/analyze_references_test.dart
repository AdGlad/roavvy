import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'reference_analysis_io.dart';

/// Draw a bright blob on a dark field and encode it as PNG bytes.
Future<List<int>> _blobPng(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF0C0C10));
  canvas.drawCircle(ui.Offset(w / 2, h / 2), w * 0.12,
      ui.Paint()..color = const ui.Color(0xFFFFF0DC));
  final img = await recorder.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('END-TO-END: analyse an image file → write a merged record', () async {
    final tmp = Directory.systemTemp.createTempSync('refanalyze');
    final images = Directory('${tmp.path}/liked')..createSync();
    final analysis = Directory('${tmp.path}/analysis');
    File('${images.path}/sample-blob-01.png')
        .writeAsBytesSync(await _blobPng(240, 300));

    final n = await analyzeReferenceFolder(
      imagesDir: images,
      analysisDir: analysis,
      verdict: 'liked',
    );
    expect(n, 1);

    final record = jsonDecode(
            File('${analysis.path}/sample-blob-01.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(record['imageStem'], 'sample-blob-01');
    expect(record['verdict'], 'liked');
    final feats = record['features'] as Map;
    expect(feats['focalHierarchy'], 'strong'); // the blob is a clear focal point
    expect((feats['dominantColors'] as List), isNotEmpty);
    expect((record['analysis'] as Map)['source'], 'host-dart-ui');
    // Aspect ratio preserved (240/300 = 0.8).
    expect((record['analysis'] as Map)['aspectRatio'], closeTo(0.8, 0.01));

    tmp.deleteSync(recursive: true);
  });

  test('merge preserves human-authored fields on re-analysis', () async {
    final tmp = Directory.systemTemp.createTempSync('refmerge');
    final images = Directory('${tmp.path}/liked')..createSync();
    final analysis = Directory('${tmp.path}/analysis')..createSync();
    File('${images.path}/keep-me.png')
        .writeAsBytesSync(await _blobPng(200, 200));
    // Pre-existing human record with tags + a chosen verdict.
    File('${analysis.path}/keep-me.json').writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'imageStem': 'keep-me',
      'verdict': 'disliked',
      'reasons': ['too busy'],
      'features': {'template': 'grid', 'tags': ['retro']},
    }));

    await analyzeReferenceFolder(
        imagesDir: images, analysisDir: analysis, verdict: 'liked');

    final record = jsonDecode(
            File('${analysis.path}/keep-me.json').readAsStringSync())
        as Map<String, dynamic>;
    // Human fields survive; machine fields are added.
    expect(record['verdict'], 'disliked'); // not overwritten by folder default
    expect((record['reasons'] as List), contains('too busy'));
    expect((record['features'] as Map)['template'], 'grid');
    expect((record['features'] as Map)['tags'], contains('retro'));
    expect((record['features'] as Map)['focalHierarchy'], isNotNull);

    tmp.deleteSync(recursive: true);
  });

  test('APPLY: analyse the real design_studio reference folders (no-op if empty)',
      () async {
    final root = '../../design_studio';
    final liked = await analyzeReferenceFolder(
      imagesDir: Directory('$root/reference_images/liked'),
      analysisDir: Directory('$root/reference_analysis'),
      verdict: 'liked',
    );
    final disliked = await analyzeReferenceFolder(
      imagesDir: Directory('$root/reference_images/disliked'),
      analysisDir: Directory('$root/reference_analysis'),
      verdict: 'disliked',
    );
    // ignore: avoid_print
    print('[analyze-references] wrote $liked liked + $disliked disliked records '
        '(0 = no images dropped yet)');
    expect(liked + disliked, greaterThanOrEqualTo(0));
  });
}
