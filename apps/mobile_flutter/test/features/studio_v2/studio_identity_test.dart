// M25.1 — who a saved design belongs to, and what that must not touch.
import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/host/prefs_persistence.dart';
import 'package:mobile_flutter/features/studio_v2/host/studio_identity.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roavvy_integration_test.dart' show liveContext, roavvyTrips;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a Roavvy account, as the Studio stores it', () {
    test('the same account is the same scope, every time', () {
      expect(
        StudioOwner.of('firebase-uid-abc').storageScope,
        StudioOwner.of('firebase-uid-abc').storageScope,
      );
      expect(StudioOwner.of('firebase-uid-abc').isSignedIn, isTrue);
    });

    test('two accounts are two scopes', () {
      expect(
        StudioOwner.of('uid-a').storageScope,
        isNot(StudioOwner.of('uid-b').storageScope),
      );
    });

    test('the raw account id is not the key', () {
      final scope = StudioOwner.of('firebase-uid-abc').storageScope;
      expect(scope.contains('firebase-uid-abc'), isFalse);
      expect(
        StudioOwner.of('uid-a').storageKey(kStudioLibraryKey),
        startsWith('$kStudioLibraryKey:'),
      );
    });

    test('no account falls back to the device, and says so', () {
      expect(StudioOwner.of(null), StudioOwner.signedOut);
      expect(StudioOwner.of(''), StudioOwner.signedOut);
      expect(StudioOwner.signedOut.isSignedIn, isFalse);
      expect(
        StudioOwner.signedOut.storageScope,
        isNot(StudioOwner.of('uid-a').storageScope),
      );
    });
  });

  group('the wardrobe belongs to an account', () {
    Future<PersistentDesignLibrary> wardrobeFor(StudioOwner owner) async {
      final lib = await openDesignLibrary(owner);
      return lib;
    }

    Future<GarmentDesign> saveOne(StudioOwner owner) async {
      final c = openStudioSession(
        liveContext(),
        library: await wardrobeFor(owner),
        owner: owner,
      );
      addTearDown(c.dispose);
      await c.saveGarment();
      return c.garment;
    }

    test('a design saved signed in comes back to the same account', () async {
      final alice = StudioOwner.of('uid-alice');
      final saved = await saveOne(alice);

      // A fresh launch: nothing in memory, everything read back off disk.
      final reopened = await wardrobeFor(alice);
      expect(reopened.library.entries, hasLength(1));
      expect(reopened.library.entries.single.garment?.garmentId, saved.garmentId);
    });

    test('another account on the same phone sees none of it', () async {
      await saveOne(StudioOwner.of('uid-alice'));
      final bob = await wardrobeFor(StudioOwner.of('uid-bob'));
      expect(
        bob.library.entries,
        isEmpty,
        reason: "one traveller's designs are not another's",
      );
    });

    test('signing out does not hand the designs to the device', () async {
      await saveOne(StudioOwner.of('uid-alice'));
      expect((await wardrobeFor(StudioOwner.signedOut)).library.entries, isEmpty);
    });

    test('designs saved before accounts follow the first account in', () async {
      // The wardrobe written under the old unscoped key: nothing recorded who
      // made it, so the first account through the door inherits it…
      final legacy = openStudioSession(
        liveContext(),
        library: PersistentDesignLibrary(
          PrefsDesignStore(key: kStudioLibraryKey),
        ),
      );
      addTearDown(legacy.dispose);
      await legacy.saveGarment();

      final alice = await wardrobeFor(StudioOwner.of('uid-alice'));
      expect(alice.library.entries, hasLength(1));

      // …and only that account: the legacy key is gone, not copied around.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kStudioLibraryKey), isNull);
      expect((await wardrobeFor(StudioOwner.of('uid-bob'))).library.entries, isEmpty);
    });

    test('an account that already has a wardrobe keeps its own', () async {
      final alice = StudioOwner.of('uid-alice');
      final mine = await saveOne(alice);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStudioLibraryKey, '{"version":2,"designs":[]}');

      final reopened = await wardrobeFor(alice);
      expect(reopened.library.entries.single.garment?.garmentId, mine.garmentId);
    });
  });

  group('who owns a design is not what a design IS', () {
    test('the same travel makes the same design for anybody', () {
      // The account decides where a design is kept. It must not reach the
      // recipe: scopeKey is baked into recipeId, so an id in there would
      // change every design at sign-in and break M24's reproduction.
      final a = openStudioSession(
        liveContext(),
        owner: StudioOwner.of('uid-alice'),
      );
      final b = openStudioSession(
        liveContext(),
        owner: StudioOwner.of('uid-bob'),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(a.current.recipeId, b.current.recipeId);
      expect(a.garment.garmentId, b.garment.garmentId);
    });

    test('an account id never reaches the travel context', () {
      final ctx = liveContext();
      expect(ctx.scopeKey, 'studio_v2');
      expect(ctx.scopeKey.contains('uid'), isFalse);
      expect(
        openStudioSession(ctx, owner: StudioOwner.of('uid-alice'))
          ..dispose()
          ..toString(),
        isNotNull,
      );
    });

    test('two sessions for one account stay separate designs', () {
      final owner = StudioOwner.of('uid-alice');
      final one = openStudioSession(liveContext(), owner: owner);
      final two = openStudioSession(liveContext(), owner: owner);
      addTearDown(one.dispose);
      addTearDown(two.dispose);

      final untouched = two.current.recipeId;
      one.setSelectedCountries(const ['pt']);
      one.setGarment('#FF1B2B');

      expect(two.selectedCountryCodes, {'pt', 'ma'});
      expect(two.current.palette?.garmentColour, isNot('#FF1B2B'));
      expect(one.current.recipeId, isNot(two.current.recipeId));
      expect(
        two.current.recipeId,
        untouched,
        reason: 'one account, two sessions — each its own design',
      );
      expect(two.history, isEmpty);
    });
  });

  group('the standalone Studio is unaffected', () {
    test('a dev session still opens, on fixtures, under the device', () {
      final c = buildStudioV2Controller();
      addTearDown(c.dispose);
      expect(c.availableCountryCodes, isNotEmpty);
      expect(demoStudioContext.source, StudioTravelSource.fixture);
      expect(roavvyTrips(), isNotEmpty);
    });
  });
}
