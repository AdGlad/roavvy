import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../procedural/design_dna.dart';

/// Bundled aggregated-DNA asset. Regenerated from the reference library by the
/// dev tool (test/.../reference/rebuild_design_dna_test.dart); if absent or
/// unparseable the engine falls back to the principled default. This is how the
/// house style "improves as the reference library grows" without a code change.
const String kDesignDnaAssetPath =
    'assets/design_engine/roavvy_design_dna.json';

/// Loads the Roavvy Design DNA at runtime (local, no network). Never throws —
/// any problem returns [kRoavvyDesignDnaDefault].
Future<RoavvyDesignDna> loadRoavvyDesignDna() async {
  try {
    final raw = await rootBundle.loadString(kDesignDnaAssetPath);
    return RoavvyDesignDna.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return kRoavvyDesignDnaDefault;
  }
}
