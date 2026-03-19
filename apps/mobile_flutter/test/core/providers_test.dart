import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';

void main() {
  group('currentUidProvider', () {
    test('returns non-null uid when auth state has a signed-in user', () async {
      final mockUser = MockUser(isAnonymous: true, uid: 'test-anonymous-uid');
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);

      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith(
          (ref) => mockAuth.authStateChanges(),
        ),
      ]);
      addTearDown(container.dispose);

      // Wait for the StreamProvider to receive its first emission.
      await container.read(authStateProvider.future);

      final uid = container.read(currentUidProvider);
      expect(uid, 'test-anonymous-uid');
    });

    test('returns null when auth state has no user', () async {
      final mockAuth = MockFirebaseAuth();

      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith(
          (ref) => mockAuth.authStateChanges(),
        ),
      ]);
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);

      final uid = container.read(currentUidProvider);
      expect(uid, isNull);
    });
  });
}
