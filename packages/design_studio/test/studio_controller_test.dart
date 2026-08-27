import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless [StudioController] tests — the portable session behaviour that both
/// hosts (macOS Lab, mobile V2) rely on. Migrated/adapted from the Lab's widget
/// tests (studio_canvas_test.dart / studio_canvas_learning_test.dart) to the
/// shared package so the session logic is verified independently of any UI.
///
/// Rendering is never exercised here, so a no-op [AssetResolver] suffices.
class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(String code,
          {required int width, required int height}) =>
      throw UnimplementedError('rendering is not exercised in controller tests');
  @override
  Future<ui.Image?> resolveClipMask(ClipShape shape, String? code,
          {required int width, required int height}) async =>
      null;
  @override
  Future<ui.Image?> resolvePassportCollage(List<PassportStampRef> stamps,
          {required int width,
          required int height,
          int seed = 0,
          double scatter = 0.5,
          double stampScale = 1.0,
          PassportInk ink = PassportInk.flag}) async =>
      null;
}

/// In-memory [DesignStore] so the reproducible library persists without disk.
class _MemoryStore implements DesignStore {
  String? _data;
  @override
  Future<String?> read() async => _data;
  @override
  Future<void> write(String contents) async => _data = contents;
}

void main() {
  late LabShowcaseGenerator generator;
  late RenderService service;

  setUp(() {
    generator = LabShowcaseGenerator(
      silhouettesByShape: {for (final s in ClipShape.values) s: const <String>[]},
      countryNames: const {},
    );
    service = RenderService(_NoopResolver());
  });

  StudioController make(DesignContext ctx,
          {int seed = 7, PersistentDesignLibrary? library}) =>
      StudioController(
        generator: generator,
        service: service,
        designContext: ctx,
        initialSeed: seed,
        library: library,
      );

  const single = DesignContext(flagCodes: ['us'], scopeKey: 'studio:us');
  const multi =
      DesignContext(flagCodes: ['us', 'fr', 'jp'], scopeKey: 'studio:multi');

  test('opening hero is deterministic for a given seed', () {
    final a = make(single);
    final b = make(single);
    expect(a.current.recipeId, b.current.recipeId);
  });

  test('an axis re-roll commits + pushes undo history; undo restores it', () {
    final c = make(single);
    final id0 = c.current.recipeId;
    c.onChipTap(DesignAxis.focus);
    expect(c.current.recipeId, isNot(id0));
    expect(c.history.length, 1);
    c.undo();
    expect(c.current.recipeId, id0);
    expect(c.history, isEmpty);
  });

  test('lock pins an axis; remix (surprise) still evolves the design', () {
    final c = make(single);
    c.toggleLock(DesignAxis.vibe);
    expect(c.locked, contains(DesignAxis.vibe));
    final before = c.current.recipeId;
    c.surprise();
    expect(c.current.recipeId, isNot(before));
    c.toggleLock(DesignAxis.vibe);
    expect(c.locked, isEmpty);
  });

  test('front is a distinct, independently-editable face', () {
    final c = make(single);
    final heroId = c.current.recipeId; // back = hero, the default view
    c.setSide(true); // front defaults to a flag ribbon
    expect(c.current.recipeId, isNot(heroId));
    // Editing the front leaves the hero untouched.
    c.setGarment('#6B7350');
    expect(c.current.palette?.garmentColour, '#6B7350');
    c.setSide(false);
    expect(c.current.recipeId, heroId);
  });

  test('front art Match-back mirrors the hero; ribbon All covers the context',
      () {
    final c = make(multi);
    final heroId = c.current.recipeId;
    c.setSide(true);
    c.setFrontArt(FrontArt.matchBack);
    expect(c.current.recipeId, heroId);
    c.setFrontArt(FrontArt.ribbon);
    c.setRibbonCoverage(true);
    expect(c.current.composition.family, DesignFamily.frontRibbon);
    expect(c.current.content.flags.length, 3);
  });

  test('front fit maps to the mobile print rects', () {
    final c = make(single);
    c.setFrontFit(FrontFit.chest);
    c.setChestSide(false);
    expect(c.frontPrintRect(), const ui.Rect.fromLTWH(0.55, 0.25, 0.18, 0.25));
    c.setChestSide(true);
    expect(c.frontPrintRect(), const ui.Rect.fromLTWH(0.27, 0.25, 0.18, 0.25));
    c.setFrontFit(FrontFit.full);
    expect(c.frontPrintRect(), const ui.Rect.fromLTWH(0.25, 0.22, 0.50, 0.40));
    c.setFrontFit(FrontFit.none);
    expect(c.frontPrintRect(), ui.Rect.zero);
  });

  test('travel Source (Countries vs Trips) + year filter re-derive the context',
      () {
    final trips = [
      Trip(countryCode: 'us', startedOn: DateTime(2020, 6, 1), endedOn: DateTime(2020, 6, 8)),
      Trip(countryCode: 'fr', startedOn: DateTime(2021, 4, 1), endedOn: DateTime(2021, 4, 9)),
      Trip(countryCode: 'us', startedOn: DateTime(2021, 9, 1), endedOn: DateTime(2021, 9, 5)),
    ];
    final c = make(DesignContext.fromTrips(trips, scopeKey: 'studio:trips'));
    expect(c.context.flagCodes.length, 2); // Countries (distinct)
    c.setSource(true);
    expect(c.context.flagCodes.length, 3); // Trips (per-visit)
    // Narrow to 2020 → only the single us trip survives.
    c.previewYear(2020, 2020);
    c.rebuildContext();
    expect(c.context.flagCodes.length, 1);
  });

  // M2 — travel selection. One shared selection set drives the design; Map and
  // List both mutate it, so they stay in sync by construction.
  List<Trip> tripsFixture() => [
        Trip(countryCode: 'us', startedOn: DateTime(2020, 6, 1), endedOn: DateTime(2020, 6, 8)),
        Trip(countryCode: 'fr', startedOn: DateTime(2021, 3, 1), endedOn: DateTime(2021, 3, 9)),
        Trip(countryCode: 'jp', startedOn: DateTime(2021, 8, 1), endedOn: DateTime(2021, 8, 5)),
      ];

  test('selection subsets the context; Select-All / Clear behave', () {
    final c = make(DesignContext.fromTrips(tripsFixture(), scopeKey: 's'));
    expect(c.availableCountryCodes, ['us', 'fr', 'jp']);
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'});

    c.toggleCountry('fr'); // deselect
    expect(c.selectedCountryCodes, {'us', 'jp'});
    expect(c.context.flagCodes, ['us', 'jp']);

    c.clearCountries(); // never leaves the design empty…
    expect(c.selectedCountryCodes, isEmpty);
    expect(c.context.flagCodes, ['us', 'jp']); // …last valid art retained

    c.selectAllCountries();
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'});
    expect(c.context.flagCodes.toSet(), {'us', 'fr', 'jp'});
  });

  test('the same selection deterministically yields the same design', () {
    final c = make(DesignContext.fromTrips(tripsFixture(), scopeKey: 's'));
    c.setSelectedCountries(['us', 'jp']);
    final id = c.hero.recipeId;
    c.toggleCountry('fr'); // add fr
    c.toggleCountry('fr'); // remove fr → back to {us, jp}
    expect(c.selectedCountryCodes, {'us', 'jp'});
    expect(c.hero.recipeId, id); // reproducible regardless of the path taken
  });

  test('a travel change preserves garment colour + front/back side', () {
    final c = make(DesignContext.fromTrips(tripsFixture(), scopeKey: 's'));
    c.setGarment('#6B7350'); // edits the hero (back)
    c.setSide(true); // move to the front face
    expect(c.onFront, isTrue);
    c.toggleCountry('fr'); // travel change regenerates the hero
    expect(c.onFront, isTrue); // side preserved
    expect(c.hero.palette?.garmentColour, '#6B7350'); // garment preserved
  });

  test('flat visited-country data (no dated trips) still selects', () {
    final c = make(const DesignContext(
        flagCodes: ['us', 'fr', 'jp'], scopeKey: 'flat'));
    expect(c.hasTrips, isFalse);
    expect(c.availableCountryCodes, ['us', 'fr', 'jp']);
    c.toggleCountry('fr');
    expect(c.context.flagCodes, ['us', 'jp']);
  });

  test('Direction: selectSubject switches subject deterministically, carrying '
      'garment + resetting Detail off Flags', () {
    final a = make(multi);
    a.setGarment('#6B7350'); // Olive
    a.applyDetail(StudioDetail.heart);
    expect(a.subjectIndex, 0); // Flags
    expect(a.detailApplies, isTrue);

    // Switch to a non-Flags subject (index 5 = Milestones).
    a.selectSubject(5);
    expect(a.subjectIndex, 5);
    expect(a.subjectLabel, 'Milestones');
    expect(a.detailApplies, isFalse);
    expect(a.detail, StudioDetail.grid); // reset off Flags
    expect(a.current.palette?.garmentColour, '#6B7350'); // garment preserved

    // Travel selection is untouched by a Direction change.
    expect(a.selectedCountryCodes, {'us', 'fr', 'jp'});

    // Deterministic: two controllers with identical prior state land on the
    // same design for the same subject.
    final b = make(multi)..selectSubject(5);
    final d = make(multi)..selectSubject(5);
    expect(b.current.recipeId, d.current.recipeId);
  });

  test('allSilhouetteOptions exposes the full bundled inventory (unscoped)', () {
    final gen = LabShowcaseGenerator(
      silhouettesByShape: const {
        ClipShape.animalSilhouette: ['us_bison', 'jp_crane'],
        ClipShape.landmarkSilhouette: ['fr_eiffel_tower'],
      },
      countryNames: const {},
    );
    final c = StudioController(
      generator: gen,
      service: service,
      designContext: single, // only 'us' selected
      initialSeed: 7,
    );
    // Scoped options are limited to the design's countries…
    expect(c.silhouetteOptions().map((o) => o.$2), ['us_bison']);
    // …but the full inventory stays reachable.
    expect(c.allSilhouetteOptions().map((o) => o.$2),
        containsAll(['us_bison', 'jp_crane', 'fr_eiffel_tower']));
  });

  test('authoring emits preference signals; Save likes into the library', () {
    final library = PersistentDesignLibrary(_MemoryStore());
    final c = make(single, library: library);
    final before = c.preferences.sampleCount;
    c.markViewed();
    expect(c.preferences.sampleCount, greaterThan(before));
    final saved = c.current;
    expect(library.library.isLiked(saved.recipeId), isFalse);
    c.save();
    expect(library.library.isLiked(saved.recipeId), isTrue);
  });
}
