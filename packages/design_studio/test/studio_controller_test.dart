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
    // A front-artwork edit leaves the hero (back) untouched.
    c.setFrontArt(FrontArt.complement);
    expect(c.current.recipeId, isNot(heroId));
    c.setSide(false);
    expect(c.current.recipeId, heroId);
  });

  test('garment colour is shared by both faces (one physical shirt), applied '
      'live without rerolling either design', () {
    final c = make(multi);
    c.setFrontArt(FrontArt.complement); // a genuinely different front
    final backLayout = c.hero.composition.orientation;
    final frontLayout = c.frontFace.composition.orientation;
    final histBefore = c.history.length;
    c.setGarment('#6B7350'); // Olive
    expect(c.hero.palette?.garmentColour, '#6B7350');
    expect(c.frontFace.palette?.garmentColour, '#6B7350'); // both faces
    expect(c.hero.composition.orientation, backLayout); // neither rerolled
    expect(c.frontFace.composition.orientation, frontLayout);
    expect(c.history.length, histBefore); // live edit, not a recipe step
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

  test('Vibe: 13 named styles restyle the current design; tap is undoable', () {
    final c = make(multi);
    final options = c.vibeStyleOptions();
    expect(options.length, 13); // every LabStyle
    expect(options.map((o) => o.$1).toSet(), LabStyle.values.toSet());

    final id0 = c.current.recipeId;
    final grunge = options.firstWhere((o) => o.$1 == LabStyle.grunge);
    c.onStyleTap(grunge.$1, grunge.$2);
    expect(c.current.recipeId, isNot(id0)); // live update
    expect(c.currentStyle, LabStyle.grunge); // reflects the chosen vibe
    expect(c.history, isNotEmpty);

    c.undo(); // Vibe change participates in recipe undo/redo
    expect(c.current.recipeId, id0);
  });

  test('a Vibe change preserves Direction, Detail + garment (Tier-1)', () {
    final c = make(multi);
    c.setGarment('#6B7350'); // Olive
    c.applyDetail(StudioDetail.heart);
    expect(c.subjectIndex, 0);
    final opts = c.vibeStyleOptions();
    final vintage = opts.firstWhere((o) => o.$1 == LabStyle.vintage);
    c.onStyleTap(vintage.$1, vintage.$2);
    expect(c.subjectIndex, 0); // Direction preserved
    expect(c.current.clip?.shapeId, ClipShape.heart.id); // Detail preserved
    expect(c.current.palette?.garmentColour, '#6B7350'); // garment preserved
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'}); // travel preserved
  });

  test('alternatives are deterministic per axis; More rolls fresh; dismiss '
      'rejects', () {
    // Same prior state → identical Vibe alternatives (shared sub-seed stream).
    final a = make(multi)..focusAxis(DesignAxis.vibe);
    final b = make(multi)..focusAxis(DesignAxis.vibe);
    expect(a.activeAxis, DesignAxis.vibe);
    expect(a.alternatives.length, greaterThan(1));
    expect(a.alternatives.map((r) => r.recipeId).toList(),
        b.alternatives.map((r) => r.recipeId).toList());

    // Committing an alternative is undoable and selects it.
    final id0 = a.current.recipeId;
    final chosen = a.alternatives[1];
    a.onAlternativeTap(1, chosen);
    expect(a.current.recipeId, chosen.recipeId);
    a.undo();
    expect(a.current.recipeId, id0);

    // "More" yields a fresh set (advances the deterministic seed stream).
    final firstSet = a.alternatives.map((r) => r.recipeId).toList();
    a.focusAxis(DesignAxis.vibe);
    expect(a.alternatives.map((r) => r.recipeId).toList(), isNot(firstSet));

    // Dismiss removes the option and records a reject signal.
    final n = a.alternatives.length;
    final before = a.preferences.sampleCount;
    a.dismissAlternative(0);
    expect(a.alternatives.length, n - 1);
    expect(a.preferences.sampleCount, greaterThan(before));
  });

  test('Focus is the composition axis; its alternatives re-roll + commit', () {
    final c = make(multi)..focusAxis(DesignAxis.focus);
    expect(c.activeAxis, DesignAxis.focus);
    expect(c.alternatives, isNotEmpty);
    final id0 = c.current.recipeId;
    c.onAlternativeTap(0, c.alternatives.first);
    expect(c.current.recipeId, isNot(id0)); // composition changed + committed
  });

  test('Remix respects locks: a locked axis is held while the rest evolves', () {
    final c = make(multi);
    // Give the Vibe axis distinctive, non-trivial finish fields to watch.
    final grunge =
        c.vibeStyleOptions().firstWhere((o) => o.$1 == LabStyle.grunge);
    c.onStyleTap(grunge.$1, grunge.$2);
    final fx0 = c.current.effects; // Vibe owns Effects (+ edge/palette grade)
    expect(fx0, isNotNull);

    c.toggleLock(DesignAxis.vibe);
    final id0 = c.current.recipeId;
    c.surprise();
    expect(c.current.recipeId, isNot(id0)); // unlocked axes evolved
    expect(c.current.effects?.distress, fx0?.distress); // locked Vibe held
    expect(c.current.effects?.grain, fx0?.grain);
    expect(c.locked, contains(DesignAxis.vibe));
  });

  test('Colour: an artwork treatment applies palette-only, preserves layout + '
      'garment, and is undoable', () {
    final c = make(multi);
    c.setGarment('#6B7350'); // Olive garment must survive a treatment change
    final id0 = c.current.recipeId;
    final orient0 = c.current.composition.orientation;
    final clip0 = c.current.clip?.shapeId;

    final mono = StudioController.colourTreatments
        .firstWhere((t) => t.$2 == ColourStrategy.monochrome);
    c.setColourTreatment(mono);
    expect(c.colourStrategy, ColourStrategy.monochrome); // treatment applied
    expect(c.current.recipeId, isNot(id0)); // live update
    expect(c.current.composition.orientation, orient0); // layout untouched
    expect(c.current.clip?.shapeId, clip0);
    expect(c.current.palette?.garmentColour, '#6B7350'); // garment carried

    c.undo(); // Colour change participates in recipe undo/redo
    expect(c.current.recipeId, id0);
    expect(c.colourStrategy, isNot(ColourStrategy.monochrome));

    // The Vintage treatment adds the aged grade (still flag-derived ink).
    final vintage = StudioController.colourTreatments
        .firstWhere((t) => t.$1 == 'Vintage');
    c.setColourTreatment(vintage);
    expect(c.vintageGrade, greaterThan(0.3));
  });

  test('Colour alternatives are deterministic per state (M4 tray pattern)', () {
    final a = make(multi)..focusAxis(DesignAxis.colour);
    final b = make(multi)..focusAxis(DesignAxis.colour);
    expect(a.activeAxis, DesignAxis.colour);
    expect(a.alternatives, isNotEmpty);
    expect(a.alternatives.map((r) => r.recipeId).toList(),
        b.alternatives.map((r) => r.recipeId).toList());
  });

  test('changing garment colour is independent + never rerolls the layout', () {
    final c = make(multi);
    final orient0 = c.current.composition.orientation;
    final clip0 = c.current.clip?.shapeId;
    final histBefore = c.history.length;
    c.setGarment('#22303A'); // Navy
    expect(c.current.palette?.garmentColour, '#22303A');
    expect(c.current.composition.orientation, orient0); // no layout reroll
    expect(c.current.clip?.shapeId, clip0);
    expect(c.history.length, histBefore); // a live edit, not a recipe step
  });

  test('Colour lock is respected by Remix (palette held byte-identical)', () {
    final c = make(multi);
    final mono = StudioController.colourTreatments
        .firstWhere((t) => t.$2 == ColourStrategy.monochrome);
    c.setColourTreatment(mono);
    c.toggleLock(DesignAxis.colour);
    final id0 = c.current.recipeId;
    c.surprise();
    expect(c.current.recipeId, isNot(id0)); // unlocked axes evolved
    expect(c.colourStrategy, ColourStrategy.monochrome); // locked Colour held
    expect(c.locked, contains(DesignAxis.colour));
  });

  test('Words: manual edit + removal are undoable; suggestions are local + '
      'deterministic', () {
    final c = make(multi);
    final id0 = c.current.recipeId;
    c.commitTitle('Wanderlust'); // manual edit
    expect(c.currentTitle, 'Wanderlust');
    expect(c.current.recipeId, isNot(id0));
    c.undo(); // participates in recipe undo/redo
    expect(c.currentTitle, isNot('Wanderlust'));

    // Same state → same ideas (no network, no randomness).
    final a = make(multi)..focusWords();
    final b = make(multi)..focusWords();
    expect(a.titleIdeas, b.titleIdeas);

    if (a.titleIdeas.isNotEmpty) {
      a.commitTitle(a.titleIdeas.first); // tap-to-apply
      expect(a.currentTitle, a.titleIdeas.first);
      final first = a.titleIdeas.toList();
      a.suggestTitles(); // "More" re-rolls a fresh set
      expect(a.titleIdeas, isNot(first));
    }
    a.commitTitle('Set'); // removal clears the title
    a.commitTitle('');
    expect(a.currentTitle, isEmpty);
  });

  test('Fine Tune setters (edges / typography / vintage) edit the active face '
      'live — no history, routed by front/back', () {
    final c = make(multi);
    final backId = c.hero.recipeId;
    final histLen = c.history.length;

    // Edges: live edit of the outer torn-edge treatment on the (back) hero.
    c.setEdges(c.edges.copyWith(style: TearStyle.frayed, edgeDamage: 0.8));
    expect(c.current.edgeTreatment?.style, TearStyle.frayed);
    expect(c.edges.edgeDamage, 0.8);

    // Vintage grade: live palette-only edit.
    c.setVintageGrade(0.7);
    expect(c.current.palette?.vintageGrade, 0.7);

    // All of the above are live: nothing was pushed to undo history.
    expect(c.history.length, histLen);

    // Typography routes to whichever face is active. Switch to the front and
    // edit there; the hero (back) must stay byte-identical.
    c.setSide(true);
    c.setTypography(const Typography(textCase: TextCase.upper));
    expect(c.current.typography?.textCase, TextCase.upper);
    c.setSide(false);
    expect(c.hero.edgeTreatment?.style, TearStyle.frayed); // back kept its edit
    expect(c.hero.recipeId, isNot(backId)); // (the back's own live edits applied)
    expect(c.history.length, histLen); // still no history churn
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

  test('Review saveGarment persists BOTH faces as one reproducible garment; '
      'repeated Save is idempotent (no duplicates)', () {
    final library = PersistentDesignLibrary(_MemoryStore());
    final c = make(multi, library: library);
    c.setFrontArt(FrontArt.complement); // a genuinely distinct front face

    // The composed garment carries both real faces + the shared garment colour.
    final g = c.garment;
    expect(g.back!.recipeId, c.hero.recipeId);
    expect(g.front!.recipeId, c.frontFace.recipeId);
    expect(g.garmentColour, c.hero.palette?.garmentColour);

    c.saveGarment();
    c.saveGarment(); // repeated Save must not create a duplicate
    expect(library.library.garments.length, 1);

    final saved = library.library.get(g.garmentId)!;
    expect(saved.garment!.back!.recipeId, c.hero.recipeId);
    expect(saved.garment!.front!.recipeId, c.frontFace.recipeId);
  });

  test('M9: a saved garment reopens identically after a serialize round-trip',
      () {
    final c = make(multi);
    c.setFrontArt(FrontArt.complement); // a genuinely distinct front face
    final savedGarment = c.garment;

    // Persist as save → leave Studio would: through JSON and back.
    final reopened = GarmentDesign.fromJson(savedGarment.toJson());

    // Reopen into a FRESH Studio session.
    final c2 = make(multi);
    c2.loadGarment(reopened);

    // Both printed faces + the garment identity reproduce exactly, so the
    // reopened design renders the same front/back print as when it was saved.
    expect(c2.garment.garmentId, savedGarment.garmentId);
    expect(c2.hero.recipeId, savedGarment.back!.recipeId);
    expect(c2.frontFace.recipeId, savedGarment.front!.recipeId);
    expect(c2.onFront, isFalse); // lands on the back (main) face, like Review
  });
}
