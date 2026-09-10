// M24 — Saved Designs & Design Persistence.
//
// The whole wardrobe rests on one promise: a saved design comes back as the
// SAME design, never as a similar one. A deterministic recipe gets most of the
// way there on its own — it reproduces the print exactly — but the recipe is a
// picture, and a customer saves a session. Which Direction they were on, which
// countries and years they had narrowed to, how the front was configured: none
// of that is in the artwork, and without it the design survives reopening only
// until the first edit that regenerates.
//
// So these cover both halves — the artwork round-trips byte for byte, and the
// editor behind it comes back too — plus what must happen when it can't: a
// record this build cannot read, a store that will not write, a wardrobe with
// one bad entry in it. Nothing here may ever answer a failed restore by
// generating a fresh design.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/saved_designs_sheet.dart';
import 'package:mobile_flutter/features/studio_v2/widgets/shirt_preview.dart';

class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) => throw UnimplementedError();
  @override
  Future<ui.Image?> resolveClipMask(
    ClipShape shape,
    String? code, {
    required int width,
    required int height,
  }) async => null;
  @override
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async => null;
}

/// An in-memory store that outlives the library holding it — which is what "the
/// app was closed and opened again" actually means.
class _MemoryStore implements DesignStore {
  _MemoryStore([this.contents]);
  String? contents;
  int writes = 0;

  /// When set, every write fails — a full disk, a revoked container.
  bool failWrites = false;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String c) async {
    if (failWrites) throw StateError('no room');
    contents = c;
    writes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStore store;
  late PersistentDesignLibrary library;

  /// A traveller with DATED history, so the year range and the trips/countries
  /// source are real state that a restore has to put back.
  final context = DesignContext.fromTrips([
    for (final (cc, year) in const [
      ('us', 2018),
      ('fr', 2019),
      ('jp', 2021),
      ('th', 2023),
    ])
      Trip(
        countryCode: cc,
        startedOn: DateTime(year, 6, 1),
        endedOn: DateTime(year, 6, 12),
        photoCount: 20,
      ),
  ], scopeKey: 'test:m24');

  StudioController make({PersistentDesignLibrary? lib}) => StudioController(
    generator: LabShowcaseGenerator(
      silhouettesByShape: const {},
      countryNames: const {},
    ),
    service: RenderService(_NoopResolver()),
    designContext: context,
    initialSeed: 17,
    library: lib ?? library,
  );

  setUp(() {
    store = _MemoryStore();
    library = PersistentDesignLibrary(store);
  });

  /// Save the controller's design, then reopen it in a brand-new Studio over
  /// the same store — the only honest test of persistence.
  Future<StudioController> reopenInFreshStudio(
    StudioController from, {
    void Function(StudioController drifted)? drift,
  }) async {
    await from.saveGarment();
    final reloaded = PersistentDesignLibrary(store);
    await reloaded.load();
    final fresh = make(lib: reloaded);
    // A fresh Studio opens on its own generated design; drifting it further
    // proves the restore replaces whatever was there rather than agreeing
    // with it by accident.
    drift?.call(fresh);
    expect(
      fresh.openSaved(reloaded.library.garments.single),
      isTrue,
      reason: 'the saved design would not reopen',
    );
    return fresh;
  }

  // ───────────────────────────────────────────────────────────────────────────
  group('a saved design comes back as itself', () {
    test('both printed faces reproduce exactly, across a restart', () async {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#2665CC');
      c.commitTitle('LONG WAY ROUND');
      final want = c.garment;

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) {
          d.selectSubject(2);
          d.setGarment('#FFFFFF');
        },
      );
      addTearDown(fresh.dispose);

      expect(fresh.garment.garmentId, want.garmentId);
      expect(fresh.hero.recipeId, want.back!.recipeId);
      expect(fresh.frontFace.recipeId, want.front!.recipeId);
      // Identity is a hash, so prove the CONTENT matches too — a hash that
      // agreed while the recipe differed would be the worse bug.
      expect(fresh.hero.toJson(), want.back!.toJson());
      expect(fresh.frontFace.toJson(), want.front!.toJson());
    });

    test('the words and the shirt colour come back with it', () async {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#FF1B2B');
      c.commitTitle('EIGHT SUMMERS');

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) {
          d.setGarment('#FFFFFF');
          d.commitTitle('SOMETHING ELSE');
        },
      );
      addTearDown(fresh.dispose);

      expect(fresh.currentTitle, 'EIGHT SUMMERS');
      expect(fresh.hero.palette?.garmentColour, '#FF1B2B');
      expect(fresh.garmentName, 'Red');
    });

    test('Fine Tune values survive to the exact number', () async {
      final c = make();
      addTearDown(c.dispose);
      c.applyDetailChoice('heart');
      final dials = {
        for (final control in c.fineTuneControls()) control.id: control,
      };
      expect(dials, isNotEmpty, reason: 'nothing to fine tune on this design');
      // Push every dial off its default, so a restore that quietly reapplied
      // defaults would show up as a difference rather than a coincidence.
      final want = <String, double>{};
      for (final control in dials.values) {
        final at = control.read(c.current);
        final to = at > (control.min + control.max) / 2
            ? control.min + (control.max - control.min) * 0.2
            : control.min + (control.max - control.min) * 0.8;
        c.beginEdit();
        c.applyLive(control.write(c.current, to));
        c.endEdit();
        want[control.id] = control.read(c.current);
      }

      final fresh = await reopenInFreshStudio(c);
      addTearDown(fresh.dispose);

      for (final control in fresh.fineTuneControls()) {
        final expected = want[control.id];
        if (expected == null) continue;
        expect(
          control.read(fresh.current),
          closeTo(expected, 0.0001),
          reason: '${control.id} did not survive the save',
        );
      }
    });

    test('the Vibe rides along in the recipe, not in a second copy', () async {
      final c = make();
      addTearDown(c.dispose);
      final (style, styled) = c.vibeStyleOptions()[LabStyle.retro.index];
      c.onStyleTap(style, styled);
      expect(c.currentStyle, LabStyle.retro);

      final fresh = await reopenInFreshStudio(c);
      addTearDown(fresh.dispose);
      expect(fresh.currentStyle, LabStyle.retro);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('the session behind the design comes back too', () {
    test('Direction and Detail are restored, not re-guessed', () async {
      final c = make();
      addTearDown(c.dispose);
      c.applyDetailChoice('circle');
      final subject = c.subjectIndex;

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) => d.selectSubject(3),
      );
      addTearDown(fresh.dispose);

      expect(fresh.subjectIndex, subject);
      expect(fresh.currentDetailId, 'circle');
    });

    test('the travels — countries, years and source — are restored', () async {
      final c = make();
      addTearDown(c.dispose);
      c.setSource(true);
      c.setYearRange(2019, 2021);
      c.setSelectedCountries(['fr', 'jp']);
      final want = c.selectedCountryCodes;

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) {
          d.setSource(false);
          d.setYearRange(2018, 2023);
          d.selectAllCountries();
        },
      );
      addTearDown(fresh.dispose);

      expect(fresh.selectedCountryCodes, want);
      expect(fresh.sourceTrips, isTrue);
      expect(fresh.yearLo, 2019);
      expect(fresh.yearHi, 2021);
    });

    test('the front configuration is restored', () async {
      final c = make();
      addTearDown(c.dispose);
      c.setFrontFit(FrontFit.full);
      c.setChestSide(true);
      c.setFrontArt(FrontArt.complement);
      c.setRibbonCoverage(true);

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) {
          d.setFrontFit(FrontFit.none);
          d.setFrontArt(FrontArt.matchBack);
        },
      );
      addTearDown(fresh.dispose);

      expect(fresh.frontFit, FrontFit.full);
      expect(fresh.chestRight, isTrue);
      expect(fresh.frontArt, FrontArt.complement);
      expect(fresh.ribbonAllCountries, isTrue);
    });

    test('the next edit builds on the RESTORED travels, not the drift', () async {
      // The whole point of persisting the session. Reopening puts the right
      // artwork on screen either way; only the first regeneration reveals
      // whether the Studio came back with it.
      final c = make();
      addTearDown(c.dispose);
      c.setSelectedCountries(['fr', 'jp']);

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) => d.selectAllCountries(),
      );
      addTearDown(fresh.dispose);

      fresh.applyDetailChoice('heart'); // a real regeneration
      expect(fresh.context.flagCodes, ['fr', 'jp']);
      expect(fresh.current.content.flags.map((f) => f.code), ['fr', 'jp']);
    });

    test('a reopened design starts its own undo history', () async {
      final c = make();
      addTearDown(c.dispose);

      final fresh = await reopenInFreshStudio(
        c,
        drift: (d) {
          d.applyDetailChoice('heart');
          d.commitTitle('THE OTHER SHIRT');
          expect(d.history, isNotEmpty);
        },
      );
      addTearDown(fresh.dispose);

      // Undo belongs to the design on screen. Stepping back into what was
      // being made before it would silently swap one shirt for another.
      expect(fresh.history, isEmpty);
      final reopened = fresh.hero.recipeId;
      fresh.undo();
      expect(fresh.hero.recipeId, reopened);
    });

    test('a country the traveller no longer has is dropped, not forced', () {
      final c = make();
      addTearDown(c.dispose);
      c.restoreSession(
        const StudioSession(selectedCountryCodes: ['fr', 'xx', 'jp']),
      );
      expect(c.selectedCountryCodes, {'fr', 'jp'});
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('saving the same design twice', () {
    test('re-saving updates the one entry rather than piling up', () async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      await c.saveGarment();
      await c.saveGarment();
      expect(library.library.garments, hasLength(1));
    });

    test('an edited design is a new design, and the original stays', () async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final first = c.garment.garmentId;

      c.commitTitle('AND THEN SOME');
      await c.saveGarment();
      final second = c.garment.garmentId;

      expect(second, isNot(first));
      expect(
        library.library.garments.map((e) => e.id),
        containsAll([first, second]),
      );
    });

    test('the session is refreshed on re-save, not frozen at the first', () async {
      final c = make();
      addTearDown(c.dispose);
      c.setFrontFit(FrontFit.chest);
      await c.saveGarment();
      // Front configuration is print state beside the design, so it does not
      // change the garment id — which is exactly why re-saving has to carry
      // the newer session onto the SAME entry.
      c.setFrontFit(FrontFit.none);
      await c.saveGarment();

      final entry = library.library.garments.single;
      expect(StudioSession.fromJson(entry.session!).frontFit, FrontFit.none);
      expect(entry.updatedAtEpochMs, isNotNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('duplicate and delete', () {
    test('a duplicate is the same design under a new name — never a reroll',
        () async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final original = library.library.garments.single;

      final copyId = await library.duplicate(original.id);
      expect(copyId, isNotNull);
      expect(copyId, isNot(original.id));

      final copy = library.library.get(copyId!)!;
      expect(copy.garment!.front!.recipeId, original.garment!.front!.recipeId);
      expect(copy.garment!.back!.recipeId, original.garment!.back!.recipeId);
      expect(copy.garment!.garmentColour, original.garment!.garmentColour);
      expect(copy.session, original.session);
      expect(library.library.garments, hasLength(2));
    });

    test('a duplicate opens as the design it copied', () async {
      final c = make();
      addTearDown(c.dispose);
      c.commitTitle('TWICE OVER');
      await c.saveGarment();
      final want = c.hero.recipeId;
      final copyId = await library.duplicate(library.library.garments.first.id);

      final fresh = make();
      addTearDown(fresh.dispose);
      fresh.selectSubject(2);
      expect(fresh.openSaved(library.library.get(copyId!)!), isTrue);
      expect(fresh.hero.recipeId, want);
      expect(fresh.currentTitle, 'TWICE OVER');
    });

    test('a duplicate has not been ordered, whatever the original did',
        () async {
      final c = make();
      addTearDown(c.dispose);
      c.markOrdered();
      final original = library.library.garments.single;
      expect(original.usedForTshirt, isTrue);

      final copyId = await library.duplicate(original.id);
      expect(library.library.get(copyId!)!.usedForTshirt, isFalse);
    });

    test('deleting takes one design and nothing else', () async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final doomed = c.garment.garmentId;
      c.selectSubject(2);
      await c.saveGarment();
      final keeper = c.garment.garmentId;

      expect(await library.remove(doomed), isTrue);
      expect(library.library.garments.map((e) => e.id), [keeper]);
      // …and the travel history it was built from is untouched.
      expect(c.designContext.trips, hasLength(4));
    });

    test('a delete reaches the disk, not just the screen', () async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      await library.remove(c.garment.garmentId);

      final reloaded = PersistentDesignLibrary(store);
      await reloaded.load();
      expect(reloaded.library.garments, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('what a broken record must not cost you', () {
    test('one unreadable entry does not take the wardrobe with it', () async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final good = c.garment.garmentId;

      final decoded = jsonDecode(store.contents!) as Map<String, Object?>;
      (decoded['designs'] as List).insert(0, {'recipe': 'not a recipe'});
      store.contents = jsonEncode(decoded);

      final reloaded = PersistentDesignLibrary(store);
      await reloaded.load();
      expect(reloaded.library.garments.map((e) => e.id), [good]);
      expect(reloaded.library.unreadableEntries, 1);
    });

    test('a corrupt file is an empty wardrobe, never an invented design',
        () async {
      for (final junk in ['', '   ', 'not json at all', '{"designs":']) {
        final lib = PersistentDesignLibrary(_MemoryStore(junk));
        await lib.load();
        expect(lib.library.garments, isEmpty);
        expect(lib.library.length, 0);
      }
    });

    test('a design saved before sessions existed still opens exactly', () async {
      final c = make();
      addTearDown(c.dispose);
      c.commitTitle('BEFORE THE SCHEMA');
      await c.saveGarment();
      final want = c.garment.garmentId;

      // Rewrite the file as version 1 wrote it: no session, no entry version.
      final decoded = jsonDecode(store.contents!) as Map<String, Object?>;
      decoded['version'] = 1;
      for (final d in (decoded['designs'] as List).cast<Map>()) {
        d.remove('session');
        d.remove('v');
      }
      store.contents = jsonEncode(decoded);

      final reloaded = PersistentDesignLibrary(store);
      await reloaded.load();
      final entry = reloaded.library.garments.single;
      expect(entry.session, isNull);
      expect(entry.version, 1);

      final fresh = make(lib: reloaded);
      addTearDown(fresh.dispose);
      // The artwork is the design, and it is all there. Only the editor state
      // is missing, and its absence costs the filter — never the shirt.
      expect(fresh.openSaved(entry), isTrue);
      expect(fresh.garment.garmentId, want);
      expect(fresh.currentTitle, 'BEFORE THE SCHEMA');
    });

    test('a session from a build we do not know degrades to its defaults', () {
      final s = StudioSession.fromJson({
        'v': 99,
        'subject': 999,
        'detail': 'hexagon-from-the-future',
        'frontFit': 'sleeve',
        'frontArt': 'hologram',
        'countries': ['fr', 7, null],
      });
      expect(s.detail, StudioDetail.grid);
      expect(s.frontFit, FrontFit.chest);
      expect(s.frontArt, FrontArt.ribbon);
      expect(s.selectedCountryCodes, ['fr']);

      final c = make();
      addTearDown(c.dispose);
      // …and an out-of-range Direction lands inside the ones that exist.
      c.restoreSession(s);
      expect(c.subjectIndex, lessThan(StudioController.subjects.length));
    });

    test('a record with no garment refuses to open and changes nothing', () {
      final c = make();
      addTearDown(c.dispose);
      final before = c.garment.garmentId;
      final faceless = SavedDesign(recipe: c.hero, savedAtEpochMs: 1);

      expect(c.openSaved(faceless), isFalse);
      expect(c.garment.garmentId, before);
    });

    test('a session round-trips through JSON unchanged', () {
      const s = StudioSession(
        subjectIndex: 2,
        detail: StudioDetail.landmarks,
        detailFamily: DesignFamily.badge,
        selectedCountryCodes: ['fr', 'jp'],
        sourceTrips: true,
        yearLo: 2019,
        yearHi: 2021,
        frontFit: FrontFit.full,
        chestRight: true,
        frontArt: FrontArt.complement,
        ribbonAllCountries: true,
      );
      expect(StudioSession.fromJson(s.toJson()).toJson(), s.toJson());
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('when the store will not write', () {
    test('the design is still here, and the Studio says so', () async {
      final c = make();
      addTearDown(c.dispose);
      c.commitTitle('UNSINKABLE');
      final want = c.garment.garmentId;
      store.failWrites = true;

      expect(await c.saveGarment(), isFalse);
      expect(library.lastWriteFailed, isTrue);
      // Nothing on screen was torn down by a failed write…
      expect(c.garment.garmentId, want);
      expect(c.currentTitle, 'UNSINKABLE');
      // …and the design is in the wardrobe in memory, so a Retry is a write,
      // not a re-design.
      expect(library.library.garments.single.id, want);

      store.failWrites = false;
      expect(await c.saveGarment(), isTrue);
      expect(library.lastWriteFailed, isFalse);
    });

    test('a wardrobe that cannot be READ opens empty rather than failing',
        () async {
      final lib = PersistentDesignLibrary(_ThrowingStore());
      await lib.load().catchError((_) {});
      expect(lib.library.garments, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('the gallery', () {
    Future<void> pump(
      WidgetTester tester,
      StudioController c, {
      ValueChanged<GarmentDesign>? onOpen,
    }) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedDesignsSheet(controller: c, onOpen: onOpen ?? (_) {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a card leads with the shirt and captions it', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      c.setGarment('#2665CC');
      await c.saveGarment();
      final id = c.garment.garmentId;

      await pump(tester, c);
      expect(find.byKey(Key('v2-saved-thumb-$id')), findsOneWidget);
      expect(find.text(c.instantName(c.hero)), findsOneWidget);
      expect(find.textContaining('Royal'), findsOneWidget);
    });

    testWidgets('thumbnails are thumbnails, not production renders', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();

      await pump(tester, c);
      final thumb = tester.widget<ShirtPreview>(
        find.byKey(Key('v2-saved-thumb-${c.garment.garmentId}')),
      );
      // The Studio hero draws at 1024. Browsing a wardrobe must never cost
      // that, per card, every time the sheet opens.
      expect(thumb.longSide, lessThanOrEqualTo(256));
    });

    testWidgets('a design still decoding shows a shirt-shaped placeholder', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();

      await pump(tester, c);
      // The NoopResolver never produces an image, so this is the unrendered
      // state — the gallery has to be legible in it, not blank.
      expect(find.byIcon(Icons.checkroom_rounded), findsOneWidget);
    });

    testWidgets('the heart is the same like the rest of the app writes', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final id = c.garment.garmentId;
      final back = c.hero.recipeId;

      await pump(tester, c);
      await tester.tap(find.byKey(Key('v2-saved-favourite-$id')));
      await tester.pump();
      await tester.pump();
      expect(library.library.isLiked(back), isTrue);

      // Losing interest in a design is not throwing it away.
      await tester.tap(find.byKey(Key('v2-saved-favourite-$id')));
      await tester.pump();
      await tester.pump();
      expect(library.library.isLiked(back), isFalse);
      expect(library.library.garments.map((e) => e.id), [id]);
      expect(find.byKey(Key('v2-saved-open-$id')), findsOneWidget);
    });

    testWidgets('Delete asks first, and Keep means keep', (tester) async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final id = c.garment.garmentId;

      await pump(tester, c);
      await tester.tap(find.byKey(Key('v2-saved-menu-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Key('v2-saved-delete-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('v2-saved-delete-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('v2-saved-delete-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(library.library.garments, hasLength(1));
      expect(find.byKey(Key('v2-saved-open-$id')), findsOneWidget);
    });

    testWidgets('confirming Delete removes that design from the wardrobe', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final id = c.garment.garmentId;

      await pump(tester, c);
      await tester.tap(find.byKey(Key('v2-saved-menu-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Key('v2-saved-delete-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('v2-saved-delete-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(library.library.garments, isEmpty);
      expect(find.byKey(const Key('v2-saved-empty')), findsOneWidget);
    });

    testWidgets('Duplicate adds a second card without touching the first', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      await c.saveGarment();
      final id = c.garment.garmentId;

      await pump(tester, c);
      await tester.tap(find.byKey(Key('v2-saved-menu-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Key('v2-saved-duplicate-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(library.library.garments, hasLength(2));
      expect(find.byKey(Key('v2-saved-open-$id')), findsOneWidget);
    });

    testWidgets('opening a card restores the whole session, not just the art', (
      tester,
    ) async {
      final c = make();
      addTearDown(c.dispose);
      c.setSelectedCountries(['fr', 'jp']);
      c.setFrontFit(FrontFit.full);
      await c.saveGarment();
      final id = c.garment.garmentId;

      // Drift the live Studio well away from what was saved.
      c.selectAllCountries();
      c.setFrontFit(FrontFit.none);
      c.selectSubject(2);

      GarmentDesign? opened;
      await pump(tester, c, onOpen: (g) => opened = g);
      await tester.tap(find.byKey(Key('v2-saved-open-$id')));
      await tester.pump();

      expect(opened?.garmentId, id);
      expect(c.garment.garmentId, id);
      expect(c.selectedCountryCodes, {'fr', 'jp'});
      expect(c.frontFit, FrontFit.full);
    });
  });
}

/// A store whose disk is simply gone.
class _ThrowingStore implements DesignStore {
  @override
  Future<String?> read() async => throw StateError('unreadable');
  @override
  Future<void> write(String contents) async => throw StateError('unwritable');
}
