import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/firestore_sync_service.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';

/// Signs in with Apple, linking to the current anonymous user if one exists,
/// then flushes dirty local records to Firestore.
///
/// Throws [SignInWithAppleAuthorizationException] if the user cancels or Apple
/// returns an error. Throws [FirebaseAuthException] on credential errors.
/// Callers are responsible for presenting error UI.
Future<void> signInWithApple({
  required VisitRepository repo,
  SyncService? syncService,
  TripRepository? tripRepo,
}) async {
  final rawNonce = _generateNonce();
  final nonce = _sha256ofString(rawNonce);

  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: nonce,
  );

  final oauthCredential = OAuthProvider('apple.com').credential(
    idToken: appleCredential.identityToken,
    rawNonce: rawNonce,
  );

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      await currentUser.linkWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // Apple ID already linked to a prior Firebase account (e.g. after reinstall).
        // Sign in directly — UID may change; Firestore migration deferred (ADR-028).
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

/// Generates a cryptographically random nonce for use in the Apple sign-in flow.
String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

/// Returns the SHA-256 hex digest of [input], used as the nonce sent to Apple.
String _sha256ofString(String input) =>
    sha256.convert(utf8.encode(input)).toString();
