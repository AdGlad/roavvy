import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/visit_repository.dart';
import '../sharing/share_token_service.dart';

/// Orchestrates permanent account deletion per ADR-043.
///
/// Deletion sequence:
///   1. Delete Firebase Auth credential — rethrows on failure (including
///      requires-recent-login so the caller can surface re-auth copy).
///   2. Revoke the Firestore share document (fire-and-forget).
///   3. Clear local SQLite visit data via [VisitRepository.clearAll].
///   4. Batch-delete all four Firestore subcollections under `users/{uid}`.
///      Batch failures are logged and do not abort the sequence.
class AccountDeletionService {
  AccountDeletionService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required VisitRepository repo,
    required ShareTokenService shareTokenService,
  })  : _auth = auth,
        _firestore = firestore,
        _repo = repo,
        _shareTokenService = shareTokenService;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final VisitRepository _repo;
  final ShareTokenService _shareTokenService;

  /// Deletes the user account and all associated data.
  ///
  /// Throws if the auth delete fails — notably re-throws
  /// `FirebaseAuthException` with code `requires-recent-login` so the UI
  /// can surface a re-authentication prompt.
  Future<void> deleteAccount(String uid, {String? shareToken}) async {
    // Step 1: delete Firebase Auth credential.
    await _auth.currentUser!.delete();

    // Step 2: revoke Firestore share document (fire-and-forget).
    if (shareToken != null) {
      unawaited(_shareTokenService.revokeFirestoreOnly(shareToken, uid));
    }

    // Step 3: clear local SQLite data.
    await _repo.clearAll();

    // Step 4: batch-delete Firestore subcollections.
    for (final sub in _subcollections) {
      try {
        await _deleteSubcollection(uid, sub);
      } catch (e, st) {
        // ignore: avoid_print
        print('AccountDeletionService._deleteSubcollection($sub) error: $e\n$st');
      }
    }
  }

  static const _subcollections = [
    'inferred_visits',
    'user_added',
    'user_removed',
    'unlocked_achievements',
  ];

  /// Deletes all documents in `users/{uid}/{subcollectionName}` in batches of
  /// up to 500 — the Firestore write-batch maximum.
  Future<void> _deleteSubcollection(String uid, String subcollectionName) async {
    const batchSize = 500;
    final collRef = _firestore
        .collection('users')
        .doc(uid)
        .collection(subcollectionName);

    while (true) {
      final snapshot = await collRef.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
    }
  }
}
