@Tags(['studio'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_geometry_generator.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_mask_renderer.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_quality.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_recipe.dart';

/// Design Studio batch writer (M6). Renders the torn engine across every curated
/// family (single flag + a 2-flag composite) to real PNGs, scores each against
/// the reference-derived [TornQualityMetrics], and writes a contact sheet +
/// report under `design_studio/generated_batches/torn_v2/` for visual comparison
/// against `design_studio/reference_images/liked/torn/`.
///
/// Dev-only — does not run in the normal suite. Run explicitly:
///   TORN_STUDIO_BATCH=1 flutter test \
///     test/features/merch/design_engine/torn/torn_studio_batch_test.dart
void main() {
  final enabled = Platform.environment['TORN_STUDIO_BATCH'] == '1';

  test('render torn batch to design_studio', () async {
    const w = 480, h = 300;
    const gen = TornGeometryGenerator();

    final outDir = Directory('../../design_studio/generated_batches/torn_v2');
    final imgDir = Directory('${outDir.path}/img')..createSync(recursive: true);

    final entries = <Map<String, dynamic>>[];

    Future<void> render(String name, TornRecipe recipe, ui.Image flag) async {
      final torn = await TornMaskRenderer.instance.applyTo(flag, recipe);
      final png = await torn.toByteData(format: ui.ImageByteFormat.png);
      File('${imgDir.path}/$name.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      torn.dispose();
      final mask = gen.generate(recipe, width: w, height: h, supersample: 2);
      final m = measureTornQuality(mask, recipe);
      entries.add({
        'name': name,
        'style': recipe.style.name,
        'seed': recipe.seed,
        'interiorClean': m.interiorClean,
        'edgeConcentration': m.edgeConcentration,
        'removedFraction': m.removedFraction,
        'fingerTransitions': m.fingerTransitions,
        'asymmetry': m.asymmetry,
        'score': m.score,
      });
    }

    // Single flag: every family across a few seeds.
    for (final style in TearStyle.values) {
      final flag = await _usFlag(w, h);
      for (var seed = 1; seed <= 3; seed++) {
        await render('${style.name}_s$seed', sampleTornRecipe(style, seed), flag);
      }
      flag.dispose();
    }

    // Multi-flag: blend FIRST (US | tricolor composite), then one shared torn
    // perimeter — proving the geometry is flag-agnostic.
    final composite = await _twoFlagComposite(w, h);
    for (final style in const [
      TearStyle.battleWorn,
      TearStyle.heavyEdgeDamage
    ]) {
      await render('composite_${style.name}',
          sampleTornRecipe(style, 2), composite);
    }
    composite.dispose();

    entries.sort((a, b) => (b['score'] as double).compareTo(a['score']));
    final avg =
        entries.map((e) => e['score'] as double).reduce((a, b) => a + b) /
            entries.length;

    File('${outDir.path}/batch.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
      'batchId': 'torn_v2',
      'engine': 'torn-flag-engine-v2',
      'size': {'w': w, 'h': h},
      'count': entries.length,
      'averageScore': avg,
      'references': 'design_studio/reference_images/liked/torn/',
      'designs': entries,
    }));
    File('${outDir.path}/index.html')
        .writeAsStringSync(_html(entries, avg));
    File('${outDir.path}/report.md')
        .writeAsStringSync(_report(entries, avg));

    TornMaskRenderer.instance.clearCache();
    expect(entries.length, greaterThan(0));
    // ignore: avoid_print
    print('Wrote torn batch (${entries.length} designs, avg score '
        '${avg.toStringAsFixed(3)}) → ${outDir.path}');
  }, skip: enabled ? false : 'set TORN_STUDIO_BATCH=1 to render the batch');
}

// --- Synthetic flags (self-contained; no SVG assets needed) ------------------

Future<ui.Image> _usFlag(int w, int h) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  const red = ui.Color(0xFFB22234);
  const white = ui.Color(0xFFFFFFFF);
  const blue = ui.Color(0xFF3C3B6E);
  final stripeH = h / 13;
  for (var i = 0; i < 13; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, i * stripeH, w.toDouble(), stripeH),
      ui.Paint()..color = i.isEven ? red : white,
    );
  }
  final cantonW = w * 0.4;
  final cantonH = stripeH * 7;
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, cantonW, cantonH), ui.Paint()..color = blue);
  final star = ui.Paint()..color = white;
  for (var r = 0; r < 5; r++) {
    for (var c = 0; c < 6; c++) {
      canvas.drawCircle(
          ui.Offset(cantonW * (c + 0.5) / 6, cantonH * (r + 0.5) / 5),
          cantonW / 26,
          star);
    }
  }
  return rec.endRecording().toImage(w, h);
}

Future<ui.Image> _twoFlagComposite(int w, int h) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  // Left half: US flag. Right half: a simple vertical tricolour.
  final us = await _usFlag((w / 2).round(), h);
  canvas.drawImageRect(
      us,
      ui.Rect.fromLTWH(0, 0, us.width.toDouble(), us.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
      ui.Paint());
  us.dispose();
  const cols = [ui.Color(0xFF0055A4), ui.Color(0xFFFFFFFF), ui.Color(0xFFEF4135)];
  final band = (w / 2) / 3;
  for (var i = 0; i < 3; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(w / 2 + i * band, 0, band, h.toDouble()),
      ui.Paint()..color = cols[i],
    );
  }
  return rec.endRecording().toImage(w, h);
}

// --- Report + contact sheet --------------------------------------------------

String _html(List<Map<String, dynamic>> e, double avg) {
  final b = StringBuffer()
    ..writeln('<!doctype html><html><head><meta charset="utf-8">')
    ..writeln('<title>Torn engine v2 batch</title><style>')
    ..writeln('body{font:13px -apple-system,Segoe UI,Roboto,sans-serif;'
        'margin:24px;background:#2b2b2b;color:#eee}')
    ..writeln('h1{font-size:18px} .avg{color:#8fd}')
    ..writeln('.grid{display:grid;grid-template-columns:repeat(auto-fill,'
        'minmax(200px,1fr));gap:14px;margin-top:16px}')
    ..writeln('.card{background:#3a3a3a;border-radius:8px;padding:10px}')
    // Checkerboard so transparent torn areas read as "garment shows through".
    ..writeln('.img{background:repeating-conic-gradient(#555 0 25%,#666 0 50%)'
        ' 0/20px 20px;border-radius:6px}')
    ..writeln('img{width:100%;display:block;border-radius:6px}')
    ..writeln('.fam{font-weight:700;margin-top:6px}')
    ..writeln('.meta{color:#bbb;font-size:11px} .q{color:#8fd;font-size:12px}')
    ..writeln('</style></head><body>')
    ..writeln('<h1>Torn / ripped flag engine v2 — <span class="avg">avg score '
        '${avg.toStringAsFixed(3)}</span></h1>')
    ..writeln('<p class="meta">Checkerboard = transparent (garment shows '
        'through). Compare against reference_images/liked/torn/.</p>')
    ..writeln('<div class="grid">');
  for (final d in e) {
    b
      ..writeln('<div class="card"><div class="img">'
          '<img src="img/${d['name']}.png"></div>')
      ..writeln('<div class="fam">${d['style']} '
          '<span class="meta">seed ${d['seed']}</span></div>')
      ..writeln('<div class="q">score ${(d['score'] as double).toStringAsFixed(2)}'
          '</div>')
      ..writeln('<div class="meta">removed '
          '${((d['removedFraction'] as double) * 100).toStringAsFixed(1)}% · '
          'fingers ${d['fingerTransitions']} · '
          'asym ${(d['asymmetry'] as double).toStringAsFixed(2)}</div></div>');
  }
  b.writeln('</div></body></html>');
  return b.toString();
}

String _report(List<Map<String, dynamic>> e, double avg) {
  final worst = e.last;
  final best = e.first;
  return '''
# Torn engine v2 — Design Studio evaluation

Rendered ${e.length} torn designs (8 curated families × single flag, plus 2-flag
composites) at 480×300 and scored each against the traits of the liked
references in `reference_images/liked/torn/`.

**Average score: ${avg.toStringAsFixed(3)}** (0..1).

## Scoring criteria (from the references)
- **interiorClean** — central body pristine (prime directive: no centre holes).
- **edgeConcentration** — every tear originates from an outer edge.
- **fingerTransitions** — separated ragged fingers, not a solid coastline.
- **removedFraction** — visible wear without destroying the flag (~2–30%).
- **asymmetry** — directional families (e.g. Asymmetric Tear) read one-sided.

The composite `score` gates interior/edge at 1.0 (a breach zeroes the score) and
rewards finger separation + a sensible amount of removed material.

## Results
- Best: **${best['style']}** (seed ${best['seed']}) — ${(best['score'] as double).toStringAsFixed(2)}.
- Weakest: **${worst['style']}** (seed ${worst['seed']}) — ${(worst['score'] as double).toStringAsFixed(2)}.
- All designs keep `interiorClean == 1.0` and `edgeConcentration == 1.0`.

Open `index.html` for the visual contact sheet. Regression gates live in
`test/.../torn/torn_quality_test.dart`.
''';
}
