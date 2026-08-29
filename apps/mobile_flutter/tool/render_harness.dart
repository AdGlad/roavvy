// macOS render harness — fast, reliable design preview OUTSIDE the app.
//
// Renders procedural designs through the REAL CardImageRenderer on a native
// macOS Flutter window (full Skia/GPU/fonts/SVG — unlike the flaky headless
// `flutter test` path), then writes labelled PNGs + a contact-sheet index.html
// to disk and exits. This is the fast preview engine for the sample-driven,
// human-in-the-loop design loop.
//
// Run:
//   flutter run -d macos -t tool/render_harness.dart
// Output:
//   design_studio/generated_batches/macos_preview/{img/*.png, manifest.json, index.html}
//
// Config via --dart-define (all optional):
//   OUT_DIR   absolute output dir (default below)
//   SEEDS     comma seeds           (default "1,2")
//   PERCTX    designs per context   (default "3")

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/features/merch/design_engine/card_render_thumbnailer.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

const _outDir = String.fromEnvironment('OUT_DIR',
    defaultValue:
        '/Users/adglad/git/roavvy/design_studio/generated_batches/macos_preview');
const _seedsRaw = String.fromEnvironment('SEEDS', defaultValue: '1,2');
const _perCtx = int.fromEnvironment('PERCTX', defaultValue: 3);

void main() => runApp(const _HarnessApp());

class _HarnessApp extends StatelessWidget {
  const _HarnessApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _HarnessHome(),
      );
}

class _HarnessHome extends StatefulWidget {
  const _HarnessHome();
  @override
  State<_HarnessHome> createState() => _HarnessHomeState();
}

class _HarnessHomeState extends State<_HarnessHome> {
  String _status = 'starting…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  // Representative review grid. Kept inline so the harness is self-contained.
  Map<String, DesignContext> _contexts() => {
        'one-country-light': DesignContext.of(
            scope: DesignScope.singleCountry,
            countryCodes: const ['jp'],
            garmentIsDark: false),
        'one-country-dark': DesignContext.of(
            scope: DesignScope.singleCountry,
            countryCodes: const ['jp'],
            garmentIsDark: true),
        'two-countries': DesignContext.of(
            scope: DesignScope.multiCountry,
            countryCodes: const ['fr', 'jp'],
            garmentIsDark: true),
        'several-countries': DesignContext.of(
            scope: DesignScope.multiCountry,
            countryCodes: const ['fr', 'jp', 'us', 'ke', 'br'],
            garmentIsDark: true),
        'region-europe': DesignContext.of(
            scope: DesignScope.region,
            countryCodes: const ['fr', 'de', 'it', 'es', 'gr', 'pt'],
            garmentIsDark: true),
        'lifetime': DesignContext.of(
            scope: DesignScope.lifetime,
            countryCodes: const [
              'fr', 'jp', 'us', 'ke', 'br', 'it', 'es', 'de', 'gr', 'pt',
              'th', 'vn', 'au', 'nz', 'mx', 'ca', 'gb', 'ie', 'nl', 'be',
              'ch', 'at', 'se', 'no', 'fi', 'dk', 'pl', 'cz',
            ],
            garmentIsDark: true),
      };

  Future<void> _run() async {
    try {
      final seeds = _seedsRaw
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      final ctx = context; // mounted, has an Overlay via MaterialApp
      const gen = ProceduralDesignGenerator();
      final thumb = CardRenderThumbnailer.forContext(
        ctx,
        pixelRatio: 3.0,
        assetsTimeout: const Duration(seconds: 12),
      );

      final imgDir = Directory('$_outDir/img')..createSync(recursive: true);
      // Clear stale PNGs so the grid only shows this run.
      for (final f in imgDir.listSync()) {
        if (f.path.endsWith('.png')) f.deleteSync();
      }

      final out = <Map<String, dynamic>>[];
      final contexts = _contexts();
      var done = 0;
      final total = contexts.length * seeds.length * _perCtx;

      for (final entry in contexts.entries) {
        for (final seed in seeds) {
          final designs =
              gen.generate(entry.value, seed: seed, count: _perCtx).designs;
          for (var i = 0; i < designs.length; i++) {
            final d = designs[i];
            final stem = '${entry.key}_s${seed}_${d.recipe.family.name}_$i';
            try {
              final bytes = await thumb.renderThumbnail(d.params, const []);
              if (bytes.isNotEmpty) {
                File('${imgDir.path}/$stem.png').writeAsBytesSync(bytes);
                out.add({
                  'stem': stem,
                  'context': entry.key,
                  'seed': seed,
                  'family': d.recipe.family.name,
                  'quality': d.quality.total,
                  'recipe': d.recipe.toJson(),
                });
              }
            } catch (e) {
              // best-effort; record the failure so we can see gaps
              out.add({'stem': stem, 'context': entry.key, 'error': '$e'});
            }
            done++;
            if (mounted) setState(() => _status = 'rendered $done / $total');
          }
        }
      }

      File('$_outDir/manifest.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
        'engineVersion': kProceduralEngineVersion,
        'grammarVersion': kProceduralGrammarVersion,
        'count': out.length,
        'designs': out,
      }));
      File('$_outDir/index.html').writeAsStringSync(_html(out));

      stdout.writeln(
          '[macos-harness] wrote ${out.where((d) => d.containsKey('quality')).length} PNGs '
          '+ manifest.json + index.html to $_outDir');
      await stdout.flush();
      exit(0);
    } catch (e, st) {
      stderr.writeln('[macos-harness] FAILED: $e\n$st');
      await stderr.flush();
      exit(1);
    }
  }

  String _html(List<Map<String, dynamic>> out) {
    final cells = StringBuffer();
    for (final d in out) {
      if (!d.containsKey('quality')) continue;
      final stem = d['stem'];
      cells.writeln('<figure><img src="img/$stem.png" loading="lazy"/>'
          '<figcaption>$stem<br>q=${(d['quality'] as double).toStringAsFixed(3)}</figcaption></figure>');
    }
    return '''<!doctype html><meta charset="utf-8"><title>macOS design preview</title>
<style>body{background:#222;color:#ddd;font:13px system-ui;margin:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}
figure{margin:0;background:#333;border-radius:8px;padding:8px}
img{width:100%;height:auto;background:#fff;border-radius:4px}
figcaption{margin-top:6px;font-size:11px;color:#aaa;word-break:break-all}</style>
<h1>macOS design preview — ${out.where((d) => d.containsKey('quality')).length} designs</h1>
<div class="grid">${cells.toString()}</div>''';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(_status,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
}
