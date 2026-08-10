import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

/// DEVELOPMENT tool (Part of the reference→DNA loop). Aggregates the Roavvy
/// Design DNA from the reference-analysis records and writes the bundled asset
/// the app loads at runtime. Run after adding/analysing references:
///
///   flutter test test/features/merch/design_engine/reference/rebuild_design_dna_test.dart
///
/// With too few liked references it writes the principled default (so the asset
/// always exists and the app has a valid DNA to load).
void main() {
  const minLikedForAggregate = 3;

  test('rebuild bundled Design DNA from the reference library', () {
    final recordsDir = Directory('../../design_studio/reference_analysis');
    final styles = <StyleDna>[];

    if (recordsDir.existsSync()) {
      for (final f in recordsDir.listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        if (f.path.contains('schema')) continue;
        try {
          final rec = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
          styles.add(_styleFromRecord(rec));
        } catch (_) {
          // ignore malformed records
        }
      }
    }

    final likedCount = styles.where((s) => s.liked).length;
    final dna = likedCount >= minLikedForAggregate
        ? RoavvyDesignDna.aggregate(styles)
        : kRoavvyDesignDnaDefault;

    final out = File('assets/design_engine/roavvy_design_dna.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(dna.toJson()));

    // ignore: avoid_print
    print('[rebuild-dna] ${styles.length} record(s), $likedCount liked → '
        '${likedCount >= minLikedForAggregate ? "aggregated" : "default"} DNA '
        'written to ${out.path}');

    // The asset must round-trip cleanly (the app parses it at startup).
    final reparsed = RoavvyDesignDna.fromJson(
        jsonDecode(out.readAsStringSync()) as Map<String, dynamic>);
    expect(reparsed.targets.length, dna.targets.length);
  });
}

/// Map a reference-analysis record to a [StyleDna]. Unmeasured axes are seeded
/// from the default centres so they don't get dragged toward 0.5 during
/// aggregation; measured axes come from the analyzer's `analysis` block.
StyleDna _styleFromRecord(Map<String, dynamic> rec) {
  final values = <DesignPrinciple, double>{
    for (final p in DesignPrinciple.values)
      p: kRoavvyDesignDnaDefault.targets[p]!.centre,
  };
  final a = (rec['analysis'] as Map?)?.cast<String, dynamic>();
  if (a != null) {
    final focal = (a['focalConcentration'] as num?)?.toDouble();
    final vd = (a['visualDensityHint'] as num?)?.toDouble();
    final col = (a['colourfulness'] as num?)?.toDouble();
    if (focal != null) {
      values[DesignPrinciple.visualHierarchy] =
          ((focal - 0.1) / 0.5).clamp(0.0, 1.0);
    }
    if (vd != null) {
      values[DesignPrinciple.visualDensity] = vd;
      values[DesignPrinciple.negativeSpace] = (1 - vd).clamp(0.0, 1.0);
    }
    if (col != null) values[DesignPrinciple.colourRelationships] = col;
  }
  return StyleDna(
    values: values,
    liked: (rec['verdict'] as String?) != 'disliked',
    sourceId: rec['imageStem'] as String?,
  );
}
