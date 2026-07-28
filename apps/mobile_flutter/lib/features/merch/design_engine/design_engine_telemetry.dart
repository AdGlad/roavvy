import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Anonymised telemetry for the AI design engine (architecture §11/§16.5): logs
/// which designs get chosen so scoring weights can be tuned. Records ONLY the
/// genome's [DesignParams.contentHash] + template + whether the critic was used
/// — never photos, GPS, or PII.
///
/// Best-effort and never-throwing: a debug-safe no-op on any failure, so it can
/// never affect the user flow. Injectable [sink] for tests.
class DesignEngineTelemetry {
  DesignEngineTelemetry({TelemetrySink? sink})
      : _sink = sink ?? const FirestoreTelemetrySink();

  final TelemetrySink _sink;

  /// Logged when a user picks one of the presented designs to customise/order.
  Future<void> logDesignChosen({
    required String contentHash,
    required String template,
    required bool criticUsed,
  }) =>
      _log('design_chosen', {
        'contentHash': contentHash,
        'template': template,
        'criticUsed': criticUsed,
      });

  Future<void> _log(String event, Map<String, Object?> data) async {
    try {
      await _sink.write(event, data);
    } catch (e) {
      if (kDebugMode) debugPrint('[design-engine] telemetry skipped: $e');
    }
  }
}

/// Where telemetry events go. The default writes to Firestore; tests inject a
/// capturing fake.
abstract class TelemetrySink {
  Future<void> write(String event, Map<String, Object?> data);
}

/// Writes an anonymised event doc to `design_engine_events`. No PII: only the
/// (optional) anonymous uid, the genome hash, template, and a boolean.
class FirestoreTelemetrySink implements TelemetrySink {
  const FirestoreTelemetrySink();

  @override
  Future<void> write(String event, Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('design_engine_events').add({
      'event': event,
      'uid': uid,
      'ts': FieldValue.serverTimestamp(),
      ...data,
    });
  }
}
