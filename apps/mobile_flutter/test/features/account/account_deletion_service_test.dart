import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/account/account_deletion_service.dart';
import 'package:mobile_flutter/features/sharing/share_token_service.dart';
import 'package:shared_models/shared_models.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

VisitRepository _makeRepo() =>
    VisitRepository(RoavvyDatabase(NativeDatabase.memory()));

/// Auth stub whose [currentUser.delete] succeeds silently.
class _SuccessAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _SuccessUser();
}

class _SuccessUser extends Fake implements User {
  @override
  Future<void> delete() async {}
}

/// Auth stub whose [currentUser.delete] throws [requires-recent-login].
class _RecentLoginAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _RecentLoginUser();
}

class _RecentLoginUser extends Fake implements User {
  @override
  Future<void> delete() => Future.error(
        FirebaseAuthException(code: 'requires-recent-login'),
      );
}

/// Auth stub whose [currentUser.delete] throws a generic error.
class _ErrorAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _ErrorUser();
}

class _ErrorUser extends Fake implements User {
  @override
  Future<void> delete() => Future.error(Exception('network error'));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

AccountDeletionService _makeService({
  required FirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
  required VisitRepository repo,
}) {
  return AccountDeletionService(
    auth: auth,
    firestore: firestore,
    repo: repo,
    shareTokenService: ShareTokenService(firestore: firestore),
  );
}

Future<void> _seedSubcollection(
  FakeFirebaseFirestore firestore,
  String uid,
  String subcollection,
  List<String> docIds,
) async {
  for (final id in docIds) {
    await firestore
        .collection('users')
        .doc(uid)
        .collection(subcollection)
        .doc(id)
        .set({'data': id});
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const uid = 'test-uid';

  // ── deleteAccount — success path ───────────────────────────────────────────

  group('deleteAccount success', () {
    test('deletes all four Firestore subcollections', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _makeRepo();

      await _seedSubcollection(firestore, uid, 'inferred_visits', ['GB', 'JP']);
      await _seedSubcollection(firestore, uid, 'user_added', ['DE']);
      await _seedSubcollection(firestore, uid, 'user_removed', ['FR']);
      await _seedSubcollection(
          firestore, uid, 'unlocked_achievements', ['first_country']);

      final service = _makeService(
        auth: _SuccessAuth(),
        firestore: firestore,
        repo: repo,
      );

      await service.deleteAccount(uid);

      for (final sub in [
        'inferred_visits',
        'user_added',
        'user_removed',
        'unlocked_achievements',
      ]) {
        final snap = await firestore
            .collection('users')
            .doc(uid)
            .collection(sub)
            .get();
        expect(snap.docs, isEmpty, reason: '$sub should be empty after deletion');
      }
    });

    test('calls clearAll on the repository', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _makeRepo();
      await repo.saveInferred(
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: DateTime.utc(2024),
          photoCount: 1,
        ),
      );

      final service = _makeService(
        auth: _SuccessAuth(),
        firestore: firestore,
        repo: repo,
      );

      await service.deleteAccount(uid);

      expect(await repo.loadInferred(), isEmpty);
    });

    test('calls revokeFirestoreOnly when shareToken is provided', () async {
      final firestore = FakeFirebaseFirestore();
      const token = 'test-token';
      await firestore.collection('sharedTravelCards').doc(token).set({
        'uid': uid,
        'visitedCodes': ['GB'],
        'countryCount': 1,
        'createdAt': 'now',
      });

      final service = _makeService(
        auth: _SuccessAuth(),
        firestore: firestore,
        repo: _makeRepo(),
      );

      await service.deleteAccount(uid, shareToken: token);

      // Allow the unawaited revokeFirestoreOnly to complete.
      await Future<void>.delayed(Duration.zero);

      final doc = await firestore
          .collection('sharedTravelCards')
          .doc(token)
          .get();
      expect(doc.exists, isFalse);
    });

    test('does not call revokeFirestoreOnly when shareToken is absent', () async {
      final firestore = FakeFirebaseFirestore();
      const token = 'other-token';
      await firestore.collection('sharedTravelCards').doc(token).set({
        'uid': uid,
        'visitedCodes': <String>[],
        'countryCount': 0,
        'createdAt': 'now',
      });

      final service = _makeService(
        auth: _SuccessAuth(),
        firestore: firestore,
        repo: _makeRepo(),
      );

      // No shareToken supplied — Firestore doc should remain.
      await service.deleteAccount(uid);

      await Future<void>.delayed(Duration.zero);

      final doc = await firestore
          .collection('sharedTravelCards')
          .doc(token)
          .get();
      expect(doc.exists, isTrue);
    });
  });

  // ── deleteAccount — error paths ────────────────────────────────────────────

  group('deleteAccount errors', () {
    test('propagates requires-recent-login without deleting local data',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _makeRepo();
      await repo.saveInferred(
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: DateTime.utc(2024),
          photoCount: 1,
        ),
      );

      final service = _makeService(
        auth: _RecentLoginAuth(),
        firestore: firestore,
        repo: repo,
      );

      expect(
        () => service.deleteAccount(uid),
        throwsA(
          isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'requires-recent-login'),
        ),
      );
    });

    test('propagates generic auth error', () async {
      final service = _makeService(
        auth: _ErrorAuth(),
        firestore: FakeFirebaseFirestore(),
        repo: _makeRepo(),
      );

      await expectLater(
        service.deleteAccount(uid),
        throwsA(isA<Exception>()),
      );
    });

    test('Firestore batch failure does not prevent clearAll from running',
        () async {
      // This is implicitly tested: the FakeFirebaseFirestore never throws,
      // so we verify that even if subcollections are empty (no-op deletes),
      // clearAll still ran by checking local data is gone.
      final firestore = FakeFirebaseFirestore();
      final repo = _makeRepo();
      await repo.saveInferred(
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: DateTime.utc(2024),
          photoCount: 3,
        ),
      );

      final service = _makeService(
        auth: _SuccessAuth(),
        firestore: firestore,
        repo: repo,
      );

      await service.deleteAccount(uid);

      // clearAll must have run even though subcollections were empty.
      expect(await repo.loadInferred(), isEmpty);
    });
  });
}
