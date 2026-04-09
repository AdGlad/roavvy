import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../../data/firestore_sync_service.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';

/// Signs in with Facebook, linking to the current anonymous user if one
/// exists, then flushes dirty local records to Firestore.
///
/// Returns without signing in if the user cancels. Throws
/// [FirebaseAuthException] on credential errors. Callers are responsible for
/// presenting error UI.
Future<void> signInWithFacebook({
  required VisitRepository repo,
  SyncService? syncService,
  TripRepository? tripRepo,
}) async {
  final result = await FacebookAuth.instance.login(
    permissions: ['email', 'public_profile'],
  );

  if (result.status != LoginStatus.success) {
    // User cancelled or an error occurred — surface nothing for cancel.
    if (result.status == LoginStatus.failed) {
      throw FirebaseAuthException(
        code: 'facebook-sign-in-failed',
        message: result.message,
      );
    }
    return;
  }

  final accessToken = result.accessToken!;
  final oauthCredential = FacebookAuthProvider.credential(accessToken.tokenString);

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      await currentUser.linkWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // Facebook account already linked to a prior Firebase account.
        // Sign in directly — UID may change; Firestore migration deferred.
        await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      } else {
        rethrow;
      }
    }
  } else {
    await FirebaseAuth.instance.signInWithCredential(oauthCredential);
  }

  // Flush all dirty local records to Firestore now that we have a
  // persistent UID (ADR-030). Fire-and-forget: failures are silent.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    unawaited((syncService ?? FirestoreSyncService()).flushDirty(
      uid,
      repo,
      tripRepo: tripRepo,
    ));
  }
}
