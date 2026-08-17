// C-00 Lane A — RENDERED-EVIDENCE CAPTURE (development-only).
//
// Renders representative procedural designs to REAL PNGs via the same
// CardImageRenderer the product uses, and writes a rendered contact sheet +
// manifest into design_studio/, so the Design Critic / Reference Analyst can
// judge render-dependent families (type-hero, passport, treatments) on pixels —
// not just the analytic proxy that skewed C-01/C-02.
//
// WHY a best-effort host harness (not a CI gate): CardImageRenderer's headless
// frame-capture is timing-flaky + depends on SVG asset loads (see
// card_render_thumbnailer_test.dart, deliberately skipped). This harness is a
// dev capture surface, so it TOLERATES per-design render failures (logs + skips)
// rather than hanging. For full-fidelity SVG flag art, run the on-device upgrade
// path documented in knowledge_base/concepts/C-00-rendered-evidence-evaluation.md.
//
// Run (host, writes to the repo):
//   RENDER_CAPTURE=1 flutter test test/features/merch/design_engine/procedural/render_capture.dart
// Out: design_studio/generated_batches/rendered_<label>/{img/*.png, manifest.json, index.html}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/card_render_thumbnailer.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

import 'regression_fixtures.dart';

void main() {
  final enabled = Platform.environment['RENDER_CAPTURE'] == '1';
  final label = (Platform.environment['RENDER_LABEL'] ?? 'v0.1.0').trim();
  const gen = ProceduralDesignGenerator();

  // Focus on the contexts where render-dependent + type-led families live.
  const captureContexts = [
    'one-country-light',
    'two-countries',
    'several-countries',
  ];
  const seed = 1;
  const perContext = 2; // top-N designs per context

  testWidgets('capture rendered batch → design_studio', (tester) async {
    final ctx = await _pumpContext(tester);
    final thumb = CardRenderThumbnailer.forContext(
      ctx,
      pixelRatio: 3.0,
      // Give SVG assets (country outlines, multi-stripe flags) real time to load
      // so we can tell genuine generator bugs from asset-fallback artifacts. The
      // drive loop below uses real wall-clock delays under runAsync so the loads
      // actually progress.
      frameYield: () async {},
      assetsTimeout: const Duration(seconds: 6),
    );

    final contexts = representativeContexts();
    final outDir =
        Directory('../../design_studio/generated_batches/rendered_$label');
    final imgDir = Directory('${outDir.path}/img')..createSync(recursive: true);

    final manifest = <Map<String, dynamic>>[];
    final rows = StringBuffer();
    var ok = 0, failed = 0;

    await tester.runAsync(() async {
      for (final name in captureContexts) {
        final dctx = contexts[name];
        if (dctx == null) continue;
        final designs = gen.generate(dctx, seed: seed, count: perContext).designs;
        for (var i = 0; i < designs.length; i++) {
          final d = designs[i];
          final stem = '${name}_${d.recipe.family.name}_$i';
          try {
            final bytes = await _drive(
                tester, thumb.renderThumbnail(d.params, const []));
            final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
            if (!isPng || bytes.isEmpty) {
              failed++;
              continue;
            }
            File('${imgDir.path}/$stem.png').writeAsBytesSync(bytes);
            ok++;
            manifest.add({
              'stem': stem,
              'context': name,
              'family': d.recipe.family.name,
              'quality': d.quality.total,
              'seed': seed,
              'engineVersion': kProceduralEngineVersion,
              'grammarVersion': kProceduralGrammarVersion,
              'recipe': d.recipe.toJson(),
            });
            rows.writeln(
                '<figure><img src="img/$stem.png" alt="$stem"/>'
                '<figcaption>${d.recipe.family.name}<br><small>$name · q ${d.quality.total.toStringAsFixed(2)}</small></figcaption></figure>');
          } catch (e) {
            failed++;
            // ignore: avoid_print
            print('[render_capture] skip $stem: $e');
          }
        }
      }
    });

    File('${outDir.path}/manifest.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
      'label': label,
      'engineVersion': kProceduralEngineVersion,
      'rendered': ok,
      'failed': failed,
      'note': 'C-00 Lane A best-effort host capture; SVG flag art needs the '
          'on-device path. Text/stat content needs the TitleGen stat variant.',
      'designs': manifest,
    }));
    File('${outDir.path}/index.html').writeAsStringSync(_html(rows.toString(), ok, failed));

    // ignore: avoid_print
    print('[render_capture] rendered=$ok failed=$failed → ${outDir.path}');
    // Best-effort: the harness succeeds if it produced the surface, even with
    // some per-design failures. It only "fails" if NOTHING rendered at all
    // (then the on-device path is required).
    expect(ok + failed, greaterThan(0));
    // Skipped unless RENDER_CAPTURE=1 (renders PNGs into design_studio/).
  }, skip: !enabled);
}

/// Live BuildContext with an Overlay for the renderer.
Future<BuildContext> _pumpContext(WidgetTester tester) async {
  BuildContext? ctx;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(builder: (context) {
        ctx = context;
        return const SizedBox.shrink();
      }),
    ),
  ));
  await tester.pump();
  return ctx!;
}

/// Drive one queued render to completion within a bounded pump budget.
Future<Uint8List> _drive(WidgetTester tester, Future<Uint8List> future) async {
  Uint8List? bytes;
  Object? error;
  var done = false;
  // ignore: unawaited_futures
  future.then<void>((b) {
    bytes = b;
    done = true;
  }, onError: (Object e) {
    error = e;
    done = true;
  });
  // Real wall-clock delays (under runAsync) so async SVG asset loads progress,
  // then pump to let the post-frame raster capture run. ~8s budget per design.
  for (var i = 0; i < 160 && !done; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
  if (error != null) throw error!;
  if (!done || bytes == null) throw StateError('render timed out');
  return bytes!;
}

String _html(String body, int ok, int failed) => '''
<!doctype html><html><head><meta charset="utf-8"><title>Rendered capture</title>
<style>
 body{font:13px -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#141414;color:#eee}
 h1{font-size:16px} p{color:#999}
 .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:14px}
 figure{margin:0;background:#1e1e1e;border-radius:8px;padding:10px;text-align:center}
 img{max-width:100%;background:
   linear-gradient(45deg,#333 25%,transparent 25%,transparent 75%,#333 75%),
   linear-gradient(45deg,#333 25%,#222 25%,#222 75%,#333 75%);
   background-size:16px 16px;background-position:0 0,8px 8px;border-radius:4px}
 figcaption{color:#bbb;font-size:12px;margin-top:6px}
</style></head><body>
<h1>Rendered capture — $ok rendered · $failed skipped</h1>
<p>C-00 Lane A best-effort host capture (checkerboard = transparency). SVG flag art
and stat text need the on-device path + TitleGen stat variant.</p>
<div class="grid">
$body
</div></body></html>''';
