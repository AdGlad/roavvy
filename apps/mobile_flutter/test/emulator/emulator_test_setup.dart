// T6.0 — Firebase Emulator test setup helpers
//
// These helpers configure the real Firebase SDK to point at the local
// Firebase Emulator Suite instead of production.
//
// Prerequisites:
//   firebase emulators:start --only auth,firestore,functions
//
// Then run:
//   cd apps/mobile_flutter
//   flutter test test/emulator/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const emulatorHost = 'localhost';
const firestorePort = 8080;
const authPort = 9099;
const functionsPort = 5001;

/// Call once inside [setUpAll] to route all Firebase SDK calls to the
/// locally running Firebase Emulator Suite.
///
/// The [FirebaseApp] must already be initialised before calling this.
Future<void> configureEmulators() async {
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
}

/// Returns the base URL for callable Cloud Functions in the emulator.
String functionsEmulatorBaseUrl(String projectId) =>
    'http://$emulatorHost:$functionsPort/$projectId/us-central1';
