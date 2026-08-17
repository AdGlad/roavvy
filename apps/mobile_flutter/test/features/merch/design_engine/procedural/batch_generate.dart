import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

import 'regression_fixtures.dart';

/// DEVELOPMENT-ONLY batch generator (Part 1). Not a product test — it is the
/// authoring workflow that produces hundreds of deterministic recipes across
/// representative contexts and archives them for critique.
///
/// Run:  flutter test test/.../procedural/batch_generate.dart
/// Out:  design_studio/generated_batches/batch_v<engine>/{batch.json,index.html}
///
/// Each batch archives engine version, seed, DesignContext, DesignRecipe and
/// quality score. The contact sheet (index.html) is a parameter-level visual
/// review surface; raster thumbnails plug in later via CardRenderThumbnailer
/// (needs a widget harness) — see the limitations note in the completion report.
void main() {
  const gen = ProceduralDesignGenerator();
  const seeds = [1, 2, 3, 4, 5, 6]; // 8 contexts × 6 seeds × 8 = 384 recipes
  const perRun = 8;

  test('generate + archive development batch', () {
    // Experiment provenance (Design Studio optimisation framework). Set by the
    // runner (design_studio/tools/run_experiment.sh); defaults keep the plain
    // `flutter test` behaviour byte-identical.
    final env = Platform.environment;
    final label = (env['EXPERIMENT_LABEL'] ?? '').trim();
    final experimentId = (env['EXPERIMENT_ID'] ?? '').trim().isEmpty
        ? 'baseline-v$kProceduralEngineVersion'
        : env['EXPERIMENT_ID']!.trim();
    final batchSuffix = label.isEmpty ? '' : '_$label';

    final contexts = representativeContexts();
    final designsJson = <Map<String, dynamic>>[];
    final rows = StringBuffer();

    contexts.forEach((name, ctx) {
      rows.writeln('<h2>$name <small>${ctx.scopeKey}</small></h2>');
      rows.writeln('<div class="grid">');
      for (final seed in seeds) {
        final result = gen.generate(ctx, seed: seed, count: perRun);
        for (final d in result.designs) {
          designsJson.add({
            'context': name,
            'scopeKey': ctx.scopeKey,
            'seed': seed,
            'quality': d.quality.total,
            'qualityBreakdown': d.quality.breakdown,
            'recipe': d.recipe.toJson(),
          });
          rows.writeln(_card(name, seed, d));
        }
      }
      rows.writeln('</div>');
    });

    final batch = {
      'batchId': 'batch_v$kProceduralEngineVersion$batchSuffix',
      'experimentId': experimentId,
      'engineVersion': kProceduralEngineVersion,
      'grammarVersion': kProceduralGrammarVersion,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'seeds': seeds,
      'contexts': [
        for (final e in contexts.entries)
          {'name': e.key, 'scopeKey': e.value.scopeKey, 'countries': e.value.countryCount}
      ],
      'designCount': designsJson.length,
      'designs': designsJson,
    };

    final dir = Directory(
        '../../design_studio/generated_batches/batch_v$kProceduralEngineVersion$batchSuffix');
    dir.createSync(recursive: true);
    File('${dir.path}/batch.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(batch));
    File('${dir.path}/index.html').writeAsStringSync(_html(rows.toString(),
        designsJson.length, contexts.length, seeds.length));

    // ignore: avoid_print
    print('[batch] archived ${designsJson.length} recipes → ${dir.path}');
    expect(designsJson.length, greaterThan(200));
  });
}

const _familyColors = {
  'singleHero': '#2F80ED',
  'dominantAccent': '#9B51E0',
  'repetitionField': '#219653',
  'negativeSpaceCutout': '#F2994A',
  'radialEmblem': '#EB5757',
  'typographicIntegration': '#2D9CDB',
  'chronoSequence': '#BB6BD9',
  'splitField': '#6FCF97',
  'duoBlend': '#56CCF2',
  'statementCount': '#F2C94C',
};

String _card(String ctx, int seed, GeneratedDesign d) {
  final r = d.recipe;
  final color = _familyColors[r.family.name] ?? '#888';
  final qpct = (d.quality.total * 100).round();
  return '''
<div class="card" style="border-top:4px solid $color">
  <div class="fam" style="color:$color">${r.family.name}</div>
  <div class="meta">${r.template.name} · ${r.mask.name}${r.heroCode != null ? ' · ★${r.heroCode}' : ''}</div>
  <div class="meta">${r.printStyle.name} · ${r.colourTreatment.name} · ${r.imageSize.name}${r.isPortrait ? ' · portrait' : ''}</div>
  <div class="qbar"><span style="width:$qpct%;background:$color"></span></div>
  <div class="q">q ${d.quality.total.toStringAsFixed(3)} · seed $seed</div>
</div>''';
}

String _html(String body, int n, int contexts, int seeds) => '''
<!doctype html><html><head><meta charset="utf-8"><title>Procedural batch</title>
<style>
  body{font:13px -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
  h1{font-size:18px} h2{margin:24px 0 8px;font-size:15px} small{color:#888;font-weight:400}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px}
  .card{background:#1b1b1b;border-radius:8px;padding:10px}
  .fam{font-weight:700;font-size:12px}
  .meta{color:#aaa;font-size:11px;margin-top:3px}
  .qbar{height:6px;background:#333;border-radius:3px;margin:8px 0 4px;overflow:hidden}
  .qbar span{display:block;height:100%}
  .q{color:#888;font-size:11px}
</style></head><body>
<h1>Procedural design batch — $n recipes · $contexts contexts × $seeds seeds</h1>
<p style="color:#888">Parameter-level contact sheet (dev only). Colours encode composition family.</p>
$body
</body></html>''';
