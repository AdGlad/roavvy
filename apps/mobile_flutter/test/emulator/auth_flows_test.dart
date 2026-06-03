// T6.6–T6.8 — Authentication flow tests
//
// Tests auth service behaviour using MockFirebaseAuth (firebase_auth_mocks).
// These validate client-side auth flow logic. For full emulator-backed tests
// (real token issuance, credential linking) run against the Auth Emulator:
//   firebase emulators:start --only auth
//   flutter test test/emulator/auth_flows_test.dart
//
// When the emulator is running, swap MockFirebaseAuth for the real
// FirebaseAuth instance after calling configureEmulators() from
// emulator_test_setup.dart.

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/account/account_deletion_service.dart';
import 'package:mobile_flutter/features/sharing/share_token_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockShareTokenService extends Mock implements ShareTokenService {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ── T6.6 — Anonymous sign-in ──────────────────────────────────────────────

  group('T6.6 — Anonymous sign-in', () {
    test('signInAnonymously returns a non-null UserCredential', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final credential = await auth.signInAnonymously();
      expect(credential.user, isNotNull);
    });

    test('signInAnonymously UID is non-empty', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final credential = await auth.signInAnonymously();
      expect(credential.user!.uid, isNotEmpty);
    });

    test('currentUser is non-null after signInAnonymously', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      await auth.signInAnonymously();
      expect(auth.currentUser, isNotNull);
    });

    test('isAnonymous is true after signInAnonymously', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final credential = await auth.signInAnonymously();
      expect(credential.user!.isAnonymous, isTrue);
    });

    test('currentUser UID is stable across calls', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final credential = await auth.signInAnonymously();
      final uid = credential.user!.uid;
      // The same session returns the same UID.
      expect(auth.currentUser!.uid, uid);
    });
  });

  // ── T6.7 — Signed-in state ────────────────────────────────────────────────

  group('T6.7 — Signed-in state', () {
    test('user is signed in with correct UID', () async {
      final mockUser = MockUser(uid: 'user-abc', isAnonymous: true);
      final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      expect(auth.currentUser!.uid, 'user-abc');
    });

    test('authStateChanges emits current user when signed in', () async {
      final mockUser = MockUser(uid: 'user-def', isAnonymous: false);
      final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      final user = await auth.authStateChanges().first;
      expect(user?.uid, 'user-def');
    });

    test('authStateChanges emits null when signed out', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final user = await auth.authStateChanges().first;
      expect(user, isNull);
    });
  });

  // ── T6.8 — Account deletion ───────────────────────────────────────────────

  group('T6.8 — Account deletion removes Firestore documents', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth auth;
    late MockShareTokenService shareService;
    late RoavvyDatabase db;
    late VisitRepository repo;
    late AccountDeletionService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeFirestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'user-del', isAnonymous: true),
        signedIn: true,
      );
      shareService = MockShareTokenService();
      db = RoavvyDatabase(NativeDatabase.memory());
      repo = VisitRepository(db);
      service = AccountDeletionService(
        auth: auth,
        firestore: fakeFirestore,
        repo: repo,
        shareTokenService: shareService,
      );

      when(() => shareService.revokeFirestoreOnly(any(), any()))
          .thenAnswer((_) async {});
    });

    tearDown(() async => db.close());

    test('deleteAccount completes without error', () async {
      await expectLater(service.deleteAccount('user-del'), completes);
    });

    test('deleteAccount clears inferred_visits subcollection', () async {
      // Pre-populate inferred_visits.
      await fakeFirestore
          .collection('users')
          .doc('user-del')
          .collection('inferred_visits')
          .doc('GB')
          .set({'inferredAt': '2024-06-01T00:00:00.000Z', 'photoCount': 5});

      await service.deleteAccount('user-del');

      final snap = await fakeFirestore
          .collection('users')
          .doc('user-del')
          .collection('inferred_visits')
          .get();
      expect(snap.docs, isEmpty);
    });

    test('deleteAccount clears unlocked_achievements subcollection', () async {
      await fakeFirestore
          .collection('users')
          .doc('user-del')
          .collection('unlocked_achievements')
          .doc('countries_1')
          .set({'unlockedAt': '2024-01-01T00:00:00.000Z'});

      await service.deleteAccount('user-del');

      final snap = await fakeFirestore
          .collection('users')
          .doc('user-del')
          .collection('unlocked_achievements')
          .get();
      expect(snap.docs, isEmpty);
    });

    test('deleteAccount with shareToken calls revokeFirestoreOnly', () async {
      await service.deleteAccount('user-del', shareToken: 'tok-123');
      verify(() => shareService.revokeFirestoreOnly('tok-123', 'user-del'))
          .called(1);
    });
  });
}
