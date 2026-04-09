import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/firestore_sync_service.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';

/// Signs in with Google, linking to the current anonymous user if one exists,
/// then flushes dirty local records to Firestore.
///
/// Throws [GoogleSignInCanceledException] (or returns without signing in) if
/// the user cancels. Throws [FirebaseAuthException] on credential errors.
/// Callers are responsible for presenting error UI.
Future<void> signInWithGoogle({
  required VisitRepository repo,
  SyncService? syncService,
  TripRepository? tripRepo,
}) async {
  final googleUser = await GoogleSignIn().signIn();
  if (googleUser == null) {
    // User cancelled the sign-in flow.
    return;
  }

  final googleAuth = await googleUser.authentication;
  final oauthCredential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      await currentUser.linkWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // Google account already linked to a prior Firebase account.
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
