import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

import '../../data/visit_repository.dart';

/// Generates and persists a stable opaque share token for the current user,
/// publishes their visited countries to Firestore, and supports revocation
/// (ADR-041, ADR-043).
class ShareTokenService {
  const ShareTokenService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  // ── Token management ──────────────────────────────────────────────────────

  /// Returns the cached token, creating and persisting one if none exists.
  ///
  /// Uses UUID v4 generated via [Random.secure] — no additional package needed.
  Future<String> getOrCreateToken(VisitRepository repo) async {
    final stored = await repo.getShareToken();
    if (stored != null) return stored;

    final token = _generateUuidV4();
    await repo.saveShareToken(token);
    return token;
  }

  // ── Firestore publish ─────────────────────────────────────────────────────

  /// Writes a public snapshot to `sharedTravelCards/{token}`.
  ///
  /// Fire-and-forget: logs errors but does not throw (ADR-030).
  Future<void> publishVisits(
    String token,
    String uid,
    List<EffectiveVisitedCountry> visits,
  ) async {
    try {
      final codes = visits.map((v) => v.countryCode).toList();
      await _firestore.collection('sharedTravelCards').doc(token).set({
        'uid': uid,
        'visitedCodes': codes,
        'countryCount': codes.length,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('ShareTokenService.publishVisits error: $e\n$st');
    }
  }

  // ── Revocation ────────────────────────────────────────────────────────────

  /// Deletes `sharedTravelCards/{token}` from Firestore AND clears the local
  /// token record from [repo].
  ///
  /// Fire-and-forget: logs errors but does not throw (ADR-030).
  Future<void> revokeToken(
    String token,
    String uid,
    VisitRepository repo,
  ) async {
    try {
      await _firestore.collection('sharedTravelCards').doc(token).delete();
      await repo.clearShareToken();
    } catch (e, st) {
      // ignore: avoid_print
      print('ShareTokenService.revokeToken error: $e\n$st');
    }
  }

  /// Deletes `sharedTravelCards/{token}` from Firestore only — does NOT clear
  /// the local token record.
  ///
  /// Used by account deletion, which wipes local state atomically via
  /// [VisitRepository.clearAll] (ADR-043).
  ///
  /// Fire-and-forget: logs errors but does not throw (ADR-030).
  Future<void> revokeFirestoreOnly(String token, String uid) async {
    try {
      await _firestore.collection('sharedTravelCards').doc(token).delete();
    } catch (e, st) {
      // ignore: avoid_print
      print('ShareTokenService.revokeFirestoreOnly error: $e\n$st');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Generates a UUID v4 string using [Random.secure].
  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version 4 bits (bits 12-15 of byte 6).
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant bits (bits 6-7 of byte 8).
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}'
        '-${hex.sublist(4, 6).join()}'
        '-${hex.sublist(6, 8).join()}'
        '-${hex.sublist(8, 10).join()}'
        '-${hex.sublist(10, 16).join()}';
  }
}
