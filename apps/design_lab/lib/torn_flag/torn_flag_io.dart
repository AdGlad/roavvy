import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../render_service.dart';

/// Disk side of the Torn Flag studio: presets, exports, contact sheets and the
/// reference image. Host-only (dart:io) — the recipe, preset format and
/// renderer it drives are the shared engine the mobile app uses.
///
/// Layout, relative to the repo root:
///   design_studio/recipes/portrait_torn_flag/SLUG.preset.json   (committed)
///   design_studio/reference_images/liked/us-flag-torn.jpg          (ignored)
///   design_studio/generated_batches/lab_export/torn_flag/          (ignored)
class TornFlagIO {
  TornFlagIO(this.repoRoot);

  /// Finds the repo root from the Lab's flag directory
  /// (`<repo>/apps/mobile_flutter/assets/flags/svg`).
  factory TornFlagIO.fromFlagDir(Directory flagDir) {
    var repo = flagDir;
    for (var i = 0; i < 5; i++) {
      repo = repo.parent;
    }
    return TornFlagIO(repo);
  }

  final Directory repoRoot;

  /// Default print export: 12 × 15 in at 300 dpi.
  static const int printLongSide = 4500;

  Directory get presetsDir => _ensure(
      '${repoRoot.path}/design_studio/recipes/$kPortraitTornFlagRecipeType');

  Directory get exportsDir => _ensure(
      '${repoRoot.path}/design_studio/generated_batches/lab_export/torn_flag');

  File get defaultReference => File(
      '${repoRoot.path}/design_studio/reference_images/liked/us-flag-torn.jpg');

  static Directory _ensure(String path) =>
      Directory(path)..createSync(recursive: true);

  /// `"US — Classic!"` → `us-classic`.
  static String slug(String name) {
    final s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'preset' : s;
  }

  // ---- presets ------------------------------------------------------------

  List<File> listPresets() {
    final files = presetsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.preset.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  TornFlagPreset loadPreset(File file) {
    final json = (jsonDecode(file.readAsStringSync()) as Map)
        .cast<String, Object?>();
    final stem = file.uri.pathSegments.last.replaceAll('.preset.json', '');
    return TornFlagPreset.fromJson(json, fallbackName: stem);
  }

  File savePreset(TornFlagPreset preset) {
    final file = File('${presetsDir.path}/${slug(preset.name)}.preset.json');
    file.writeAsStringSync(_pretty(preset.toJson()));
    return file;
  }

  // ---- exports ------------------------------------------------------------

  /// Renders [preset] as a transparent print PNG through the SAME call the
  /// mobile app uses for print files ([RenderService.renderArtwork]), and
  /// writes `<stem>.png` plus a `<stem>.json` sidecar carrying the full preset
  /// (flag, seed, parameters, engine versions) and the render dimensions.
  Future<File> exportArtwork(
    RenderService service,
    TornFlagPreset preset, {
    int longSide = printLongSide,
  }) async {
    final result =
        await service.renderArtwork(preset.recipe, longSide: longSide);
    final stem = '${slug(preset.name)}_${_flag(preset)}_seed${preset.recipe.seed}'
        '_${result.image.width}x${result.image.height}';
    final png = File('${exportsDir.path}/$stem.png')
      ..writeAsBytesSync(result.pngBytes);
    File('${exportsDir.path}/$stem.json').writeAsStringSync(_pretty({
      'png': '$stem.png',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'render': {
        'call': 'RenderService.renderArtwork',
        'longSide': longSide,
        'width': result.image.width,
        'height': result.image.height,
        'background': 'transparent',
        'quality': 'print',
      },
      'recipeId': result.recipeId,
      'imageHash': result.imageHash,
      'preset': preset.toJson(),
    }));
    return png;
  }

  /// A labelled grid of variations on [background] (null = transparent),
  /// plus a sidecar listing every cell's preset.
  Future<File> exportContactSheet(
    RenderService service,
    List<TornFlagPreset> cells, {
    required String title,
    ui.Color? background = const ui.Color(0xFFFFFFFF),
    int cellLongSide = 900,
    int columns = 3,
    String? labelFontFamily,
  }) async {
    final (cw, ch) = RenderService.dimsFor(Orientation.portrait, cellLongSide);
    const labelH = 44, pad = 16;
    final rows = (cells.length / columns).ceil();
    final w = columns * (cw + pad) + pad;
    final h = rows * (ch + labelH + pad) + pad;

    final images = <ui.Image>[];
    for (final c in cells) {
      images.add(await service.imageFor(c.recipe, cellLongSide, transparent: true));
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (background != null) {
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..color = background);
    }
    final ink = background != null && background.computeLuminance() < 0.4
        ? const ui.Color(0xFFEEEEEE)
        : const ui.Color(0xFF222222);
    for (var i = 0; i < cells.length; i++) {
      final x = pad + (i % columns) * (cw + pad);
      final y = pad + (i ~/ columns) * (ch + labelH + pad);
      canvas.drawImage(images[i], ui.Offset(x.toDouble(), y.toDouble()), ui.Paint());
      final pb = ui.ParagraphBuilder(
          ui.ParagraphStyle(fontSize: 22, fontFamily: labelFontFamily))
        ..pushStyle(ui.TextStyle(color: ink))
        ..addText('${cells[i].name} · ${_flag(cells[i])} · seed ${cells[i].recipe.seed}');
      final para = pb.build()..layout(ui.ParagraphConstraints(width: cw.toDouble()));
      canvas.drawParagraph(para, ui.Offset(x.toDouble(), (y + ch + 8).toDouble()));
    }
    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    final stem = 'contact_${slug(title)}_${_stamp()}';
    final png = File('${exportsDir.path}/$stem.png')
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    File('${exportsDir.path}/$stem.json').writeAsStringSync(_pretty({
      'png': '$stem.png',
      'cellLongSide': cellLongSide,
      'cells': [for (final c in cells) c.toJson()],
    }));
    return png;
  }

  /// The reference beside the generated design, both scaled to [height], on
  /// white — for an at-a-glance review record.
  Future<File> exportComparison(
    RenderService service,
    TornFlagPreset preset,
    File reference, {
    int height = 1200,
  }) async {
    final codec =
        await ui.instantiateImageCodec(reference.readAsBytesSync());
    final ref = (await codec.getNextFrame()).image;
    final art = await service.imageFor(preset.recipe, height, transparent: true);
    final refW = (ref.width * height / ref.height).round();
    const pad = 24;
    final w = refW + art.width + pad * 3;
    final h = height + pad * 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.drawImageRect(
        ref,
        ui.Rect.fromLTWH(0, 0, ref.width.toDouble(), ref.height.toDouble()),
        ui.Rect.fromLTWH(pad.toDouble(), pad.toDouble(), refW.toDouble(),
            height.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high);
    canvas.drawImage(art, ui.Offset((refW + pad * 2).toDouble(), pad.toDouble()),
        ui.Paint());
    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final stem = 'compare_${slug(preset.name)}_seed${preset.recipe.seed}_${_stamp()}';
    final png = File('${exportsDir.path}/$stem.png')
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    File('${exportsDir.path}/$stem.json').writeAsStringSync(_pretty({
      'png': '$stem.png',
      'reference': reference.path,
      'preset': preset.toJson(),
    }));
    return png;
  }

  static String _flag(TornFlagPreset p) =>
      p.recipe.content.flags.isEmpty ? 'none' : p.recipe.content.flags.first.code;

  static String _stamp() {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  static String _pretty(Object json) =>
      '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
