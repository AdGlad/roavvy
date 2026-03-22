import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/firestore_sync_service.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/map/map_screen.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

VisitRepository _makeRepo() => VisitRepository(_makeDb());

/// Pumps a [MapScreen] with all required providers overridden.
///
/// [mockUser] defaults to an anonymous user. Pass [signInWithAppleOverride]
/// to intercept the sign-in flow in tests (avoids platform channel).
/// [NoOpSyncService] is always injected to prevent real Firestore calls.
Widget _pumpMapScreen(
  VisitRepository repo, {
  MockUser? mockUser,
  Future<void> Function()? signInWithAppleOverride,
}) {
  final user = mockUser ?? MockUser(isAnonymous: true, uid: 'anon-test-uid');
  final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(repo),
      achievementRepositoryProvider.overrideWithValue(
        AchievementRepository(_makeDb()),
      ),
      xpRepositoryProvider.overrideWithValue(XpRepository(_makeDb())),
      polygonsProvider.overrideWithValue(const []),
      authStateProvider.overrideWith((_) => mockAuth.authStateChanges()),
    ],
    child: MaterialApp(
      home: MapScreen(
        signInWithAppleOverride: signInWithAppleOverride,
        syncService: const NoOpSyncService(),
      ),
    ),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('MapScreen renders with empty repository; no crash', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('MapScreen shows loading indicator before data resolves', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });
  // Note: tap-through-FlutterMap tests are not reliable in the test runner
  // because flutter_map's internal gesture recognizer does not respond to
  // tester.tap(). The tap → bottom sheet → display name flow is covered by
  // country_detail_sheet_test.dart, which exercises CountryDetailSheet directly.

  // ── Task 15: Map empty state ───────────────────────────────────────────────

  testWidgets('shows empty state overlay when no visits exist', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    expect(
      find.text("Scan your photos to see where you've been"),
      findsOneWidget,
    );
    expect(find.text('Scan Photos'), findsOneWidget);
  });

  testWidgets('hides empty state when visits exist', (tester) async {
    final repo = _makeRepo();
    await repo.clearAndSaveAllInferred([
      InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2024),
        photoCount: 5,
      ),
    ]);

    await tester.pumpWidget(_pumpMapScreen(repo));
    await tester.pumpAndSettle();

    expect(
      find.text("Scan your photos to see where you've been"),
      findsNothing,
    );
  });

  // ── Task 14: Delete travel history ────────────────────────────────────────

  testWidgets('overflow menu is visible after map loads', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('tapping overflow shows Clear travel history item', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Clear travel history'), findsOneWidget);
  });

  testWidgets('confirming delete clears visits and shows empty state', (tester) async {
    final repo = _makeRepo();
    await repo.clearAndSaveAllInferred([
      InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2024),
        photoCount: 5,
      ),
    ]);

    await tester.pumpWidget(_pumpMapScreen(repo));
    await tester.pumpAndSettle();

    expect(find.text("Scan your photos to see where you've been"), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear travel history'));
    await tester.pumpAndSettle();

    expect(find.text('Delete all travel history?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text("Scan your photos to see where you've been"), findsOneWidget);
  });

  // ── Task 18: Sign in with Apple ───────────────────────────────────────────

  testWidgets('overflow menu shows Sign in with Apple when anonymous', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Apple'), findsOneWidget);
  });

  testWidgets('overflow menu shows Signed in with Apple when not anonymous', (tester) async {
    final signedInUser = MockUser(isAnonymous: false, uid: 'apple-uid');
    await tester.pumpWidget(_pumpMapScreen(_makeRepo(), mockUser: signedInUser));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Signed in with Apple'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsNothing);
  });

  testWidgets('tapping Sign in with Apple invokes sign-in callback', (tester) async {
    var invoked = false;
    await tester.pumpWidget(
      _pumpMapScreen(
        _makeRepo(),
        signInWithAppleOverride: () async => invoked = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    expect(invoked, isTrue);
  });

  // ── Task 26: Sign out ──────────────────────────────────────────────────────

  testWidgets('overflow menu shows Sign out item', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
  });

  // ── Task 28: Share travel card ─────────────────────────────────────────────

  testWidgets('overflow menu shows Share travel card when visits exist',
      (tester) async {
    final repo = _makeRepo();
    await repo.clearAndSaveAllInferred([
      InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2024),
        photoCount: 1,
      ),
    ]);

    await tester.pumpWidget(_pumpMapScreen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Share travel card'), findsOneWidget);
  });

  testWidgets('overflow menu hides Share travel card when no visits', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Share travel card'), findsNothing);
  });

  // ── Task 31: Privacy & account ────────────────────────────────────────────

  testWidgets('overflow menu shows Privacy & account item', (tester) async {
    await tester.pumpWidget(_pumpMapScreen(_makeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & account'), findsOneWidget);
  });

  testWidgets('Share my map link is no longer in the overflow menu',
      (tester) async {
    final repo = _makeRepo();
    await repo.clearAndSaveAllInferred([
      InferredCountryVisit(
        countryCode: 'GB',
        inferredAt: DateTime.utc(2024),
        photoCount: 1,
      ),
    ]);
    final signedInUser = MockUser(isAnonymous: false, uid: 'apple-uid');

    await tester.pumpWidget(_pumpMapScreen(repo, mockUser: signedInUser));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Share my map link'), findsNothing);
  });
}
