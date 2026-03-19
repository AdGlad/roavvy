import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/settings/privacy_account_screen.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());
VisitRepository _makeRepo() => VisitRepository(_makeDb());

Widget _pumpScreen(
  VisitRepository repo, {
  MockUser? mockUser,
  Future<void> Function(String uid, {String? shareToken})? deleteAccountOverride,
}) {
  final user = mockUser ?? MockUser(isAnonymous: false, uid: 'apple-uid');
  final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(repo),
      achievementRepositoryProvider.overrideWithValue(
        AchievementRepository(_makeDb()),
      ),
      polygonsProvider.overrideWithValue(const []),
      effectiveVisitsProvider.overrideWith(
        (_) async => <EffectiveVisitedCountry>[],
      ),
      authStateProvider.overrideWith((_) => mockAuth.authStateChanges()),
    ],
    child: MaterialApp(
      home: PrivacyAccountScreen(
        deleteAccountOverride: deleteAccountOverride,
      ),
    ),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── Sharing section — inactive state ──────────────────────────────────────

  testWidgets('shows Share your map when no token exists', (tester) async {
    final repo = _makeRepo();

    await tester.pumpWidget(_pumpScreen(repo));
    await tester.pumpAndSettle();

    expect(find.text('Share your map'), findsOneWidget);
    expect(find.text('Create link'), findsOneWidget);
    expect(find.text('Your map is shared'), findsNothing);
  });

  // ── Sharing section — active state ────────────────────────────────────────

  testWidgets('shows Your map is shared when token exists', (tester) async {
    final repo = _makeRepo();
    await repo.saveShareToken('abcd1234-efgh-ijkl-mnop-qrstuvwxyz12');

    await tester.pumpWidget(_pumpScreen(repo));
    await tester.pumpAndSettle();

    expect(find.text('Your map is shared'), findsOneWidget);
    expect(find.text('Remove link'), findsOneWidget);
    expect(find.text('Share your map'), findsNothing);
  });

  // ── Remove link confirmation dialog ──────────────────────────────────────

  testWidgets('tapping Remove link shows confirmation dialog', (tester) async {
    final repo = _makeRepo();
    await repo.saveShareToken('abcd1234-efgh-ijkl-mnop-qrstuvwxyz12');

    await tester.pumpWidget(_pumpScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();

    expect(find.text('Remove your sharing link?'), findsOneWidget);
    expect(find.text('Remove Link'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancelling removal keeps the active sharing state',
      (tester) async {
    final repo = _makeRepo();
    await repo.saveShareToken('abcd1234-efgh-ijkl-mnop-qrstuvwxyz12');

    await tester.pumpWidget(_pumpScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Your map is shared'), findsOneWidget);
  });

  testWidgets('confirming removal switches to inactive sharing state',
      (tester) async {
    final repo = _makeRepo();
    await repo.saveShareToken('abcd1234-efgh-ijkl-mnop-qrstuvwxyz12');

    await tester.pumpWidget(_pumpScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove Link'));
    await tester.pumpAndSettle();

    expect(find.text('Share your map'), findsOneWidget);
    expect(find.text('Your map is shared'), findsNothing);
  });

  // ── Account section ───────────────────────────────────────────────────────

  testWidgets('shows Delete account row in Account section', (tester) async {
    await tester.pumpWidget(_pumpScreen(_makeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('tapping Delete account shows first confirmation dialog',
      (tester) async {
    await tester.pumpWidget(_pumpScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.text('Continue to delete…'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('tapping Continue to delete shows second confirmation dialog',
      (tester) async {
    await tester.pumpWidget(_pumpScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to delete…'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });

  testWidgets('tapping Delete Account shows loading dialog', (tester) async {
    // Use a Completer so deleteAccount never resolves during this test —
    // keeping the loading dialog visible for assertion.
    final completer = Completer<void>();

    await tester.pumpWidget(
      _pumpScreen(
        _makeRepo(),
        deleteAccountOverride: (uid, {shareToken}) => completer.future,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to delete…'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Account'));
    await tester.pump(); // one frame to open the loading dialog

    expect(find.text('Deleting your account…'), findsOneWidget);

    // Complete the future so the test can finish cleanly.
    completer.complete();
    await tester.pumpAndSettle();
  });
}
