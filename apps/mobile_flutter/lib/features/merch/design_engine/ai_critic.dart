import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'design_engine_contracts.dart';
import 'optimization_loop.dart';

/// RemoteConfig flag gating the cloud AI critic. Default false until validated
/// (cost/latency) — see [RemoteConfigService] defaults.
const String kAiDesignCriticFlag = 'ai_design_critic_enabled';

/// Transport for the `critiqueDesigns` cloud call, abstracted so tests can
/// inject a fake without needing Firebase. Returns the raw `results` list.
typedef CritiqueCaller =
    Future<List<Map<String, dynamic>>> Function(
      List<Map<String, dynamic>> designs,
      Duration timeout,
    );

/// The optional cloud "art director" (architecture §6.4 / §16). Given the 3
/// on-device finalists, it asks a vision model to re-score them and returns a
/// re-ranked list. It is:
///
/// * **Gated** by the [kAiDesignCriticFlag] RemoteConfig flag (default off).
/// * **Bounded** by a strict caller-supplied timeout inside the ≤5 s budget.
/// * **Thumbnail-only** — it sends the rendered design thumbnail + minimal
///   genome metadata; never a photo or any PII.
/// * **Never-throwing** — on flag-off, timeout, error, or missing thumbnails it
///   returns the input list unchanged, so the heuristic result always stands.
class AiCritic {
  AiCritic({bool Function()? isEnabled, CritiqueCaller? caller})
    : _isEnabled = isEnabled ?? _remoteFlagEnabled,
      _caller = caller ?? _defaultCaller;

  final bool Function() _isEnabled;
  final CritiqueCaller _caller;

  /// How much the art director's score displaces the heuristic aesthetic when
  /// re-ranking (0 = ignore critic, 1 = trust critic fully).
  static const double _aiWeight = 0.5;

  /// Whether the critic is currently enabled (flag on). Cheap; safe to read for
  /// telemetry ("was the critic used?").
  bool get isEnabled {
    try {
      return _isEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Re-ranks [finalists] using the cloud critic, within [timeout]. Returns the
  /// input unchanged on flag-off, empty input, no usable thumbnails, timeout, or
  /// any error. The heuristic ordering is therefore never made worse.
  Future<List<DesignCandidate>> refine(
    List<DesignCandidate> finalists, {
    required Duration timeout,
  }) async {
    if (!isEnabled || finalists.isEmpty || timeout <= Duration.zero) {
      return finalists;
    }

    // Build the thumbnail-only payload; drop candidates without a thumbnail.
    final payload = <Map<String, dynamic>>[];
    final indexMap = <int>[]; // payload position → finalists index
    for (var i = 0; i < finalists.length; i++) {
      final c = finalists[i];
      final thumb = c.thumbnail;
      if (thumb == null || thumb.isEmpty) continue;
      payload.add({
        'paramsHash': c.params.contentHash,
        'thumbnailBase64': base64Encode(thumb),
        'template': c.params.template.name,
        'countryCount': c.params.countryCodes.length,
        'shirtColour': c.params.shirtColour,
      });
      indexMap.add(i);
    }
    if (payload.isEmpty) return finalists;

    try {
      final results = await _caller(payload, timeout).timeout(timeout);
      return _applyVerdicts(finalists, indexMap, results);
    } catch (e) {
      // Timeout / network / model error — silently keep the heuristic order.
      if (kDebugMode) debugPrint('[ai-critic] skipped: $e');
      return finalists;
    }
  }

  /// Rescores the finalists from the critic's verdicts and returns them sorted
  /// best-first. Verdicts are matched by their `index` into the payload; any
  /// missing verdict leaves that candidate's score untouched.
  List<DesignCandidate> _applyVerdicts(
    List<DesignCandidate> finalists,
    List<int> indexMap,
    List<Map<String, dynamic>> results,
  ) {
    final updated = [...finalists];
    for (final raw in results) {
      final payloadIdx = (raw['index'] as num?)?.toInt();
      if (payloadIdx == null ||
          payloadIdx < 0 ||
          payloadIdx >= indexMap.length) {
        continue;
      }
      final score = (raw['aestheticScore'] as num?)?.toDouble();
      if (score == null) continue;
      final target = indexMap[payloadIdx];
      final current = updated[target];
      final blended = ((1 - _aiWeight) * current.score.aesthetic +
              _aiWeight * score)
          .clamp(0.0, 1.0);
      updated[target] = current.copyWith(
        score: DesignScore(
          printable: current.score.printable,
          aesthetic: blended,
          profileFit: current.score.profileFit,
          printabilityMargin: current.score.printabilityMargin,
          rejectionReason: current.score.rejectionReason,
        ),
      );
    }
    updated.sort((a, b) => b.total.compareTo(a.total));
    return updated;
  }

  // ── Defaults ────────────────────────────────────────────────────────────────

  static bool _remoteFlagEnabled() {
    try {
      return FirebaseRemoteConfig.instance.getBool(kAiDesignCriticFlag);
    } catch (_) {
      return false; // fail-closed: no critic if RC is unavailable
    }
  }

  static Future<List<Map<String, dynamic>>> _defaultCaller(
    List<Map<String, dynamic>> designs,
    Duration timeout,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'critiqueDesigns',
      options: HttpsCallableOptions(timeout: timeout),
    );
    final res = await callable.call<Map<String, dynamic>>({'designs': designs});
    final results = res.data['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}
