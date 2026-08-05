import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

import 'regression_fixtures.dart';

/// Deterministic regression suite. Runs the generator over fixed
/// (context, seed) fixtures, computes stable metrics, and compares them to a
/// preserved baseline so every generator change is measurable.
///
/// To accept new numbers as the baseline (after an intentional, reviewed
/// change): `REGEN_BASELINE=1 flutter test .../regression_test.dart`.
void main() {
  const gen = ProceduralDesignGenerator();
  final baselineFile = File(
      '../../design_studio/regression_tests/baselines/procedural_baseline.json');

  // How far a context's mean quality may fall before it's a regression.
  const qualityTolerance = 0.03;

  test('deterministic regression vs preserved baseline', () {
    final current = computeRegressionMetrics(gen);
    final regen = Platform.environment['REGEN_BASELINE'] == '1';

    if (!baselineFile.existsSync() || regen) {
      baselineFile.parent.createSync(recursive: true);
      baselineFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(current));
      // ignore: avoid_print
      print('[regression] baseline written to ${baselineFile.path} '
          '(${regen ? "REGEN" : "bootstrap"}). Re-run to compare.');
      return;
    }

    final baseline =
        jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
    final basePer = baseline['perContext'] as Map<String, dynamic>;
    final curPer = current['perContext'] as Map<String, dynamic>;

    final regressions = <String>[];
    final improvements = <String>[];
    final table = StringBuffer('\n[regression] per-context meanQuality:\n');

    for (final name in curPer.keys) {
      final cur = (curPer[name] as Map)['meanQuality'] as double;
      final base = ((basePer[name] as Map?)?['meanQuality'] as double?) ?? cur;
      final delta = cur - base;
      table.writeln('  ${name.padRight(20)} '
          'base=${base.toStringAsFixed(3)} cur=${cur.toStringAsFixed(3)} '
          'Δ=${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(3)}');
      if (delta < -qualityTolerance) regressions.add('$name (Δ${delta.toStringAsFixed(3)})');
      if (delta > qualityTolerance) improvements.add('$name (+${delta.toStringAsFixed(3)})');

      // Diversity must not silently collapse.
      final curDiv = (curPer[name] as Map)['familyDiversity'] as int;
      final baseDiv =
          ((basePer[name] as Map?)?['familyDiversity'] as int?) ?? curDiv;
      if (curDiv < baseDiv - 1) {
        regressions.add('$name family diversity $baseDiv→$curDiv');
      }
    }
    // ignore: avoid_print
    print(table.toString());
    if (improvements.isNotEmpty) {
      // ignore: avoid_print
      print('[regression] improvements: ${improvements.join(', ')}');
    }

    expect(
      regressions,
      isEmpty,
      reason: 'Unexplained regressions (make the tradeoff explicit + '
          'REGEN_BASELINE=1 if intended): ${regressions.join('; ')}',
    );
  });
}
