// M177 — the disclosure contract, enforced.
//
// The experience definition's "appears when" column is the difference between
// depth and clutter: a passport control on a flag design, or a chest-side
// choice on a full-front print, is noise the customer must read past. Nothing
// enforced these predicates, so a leak would regress in silence — no test
// fails when a control merely appears in the wrong place.
//
// Table-driven on purpose: adding a category to the menu without deciding its
// predicate should fail here, not ship.
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(String code,
          {required int width, required int height}) =>
      throw UnimplementedError();
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

void main() {
  final trips = [
    Trip(
        countryCode: 'fr',
        startedOn: DateTime(2025, 6, 1),
        endedOn: DateTime(2025, 6, 9)),
  ];

  StudioController make({bool withTrips = false}) => StudioController(
        generator: LabShowcaseGenerator(
          silhouettesByShape: {
            ClipShape.passportStampOutline: const ['fr_entry', 'fr_exit'],
            ClipShape.animalSilhouette: const ['fr_rooster'],
          },
          countryNames: const {},
        ),
        service: RenderService(_NoopResolver()),
        designContext: DesignContext(
          flagCodes: const ['fr', 'us'],
          scopeKey: 'test:contract',
          trips: withTrips ? trips : const [],
        ),
        initialSeed: 6,
      );

  int indexOfSubject(LabGenre g) =>
      StudioController.subjects.indexWhere((s) => s.$1 == g);

  group('Travels — only when there is trip history', () {
    test('a traveller with dated trips gets the step', () {
      expect(make(withTrips: true).hasTrips, isTrue);
    });

    test('a flat country list does not', () {
      // Offering a year filter to someone with no dates is a control that can
      // never do anything.
      expect(make().hasTrips, isFalse);
    });
  });

  group('Detail — only under Flags', () {
    test('Flags offers it', () {
      final c = make();
      c.selectSubject(indexOfSubject(LabGenre.flags));
      expect(c.detailApplies, isTrue);
    });

    test('every other subject does not', () {
      for (var i = 0; i < StudioController.subjects.length; i++) {
        final (genre, _, label) = StudioController.subjects[i];
        if (genre == LabGenre.flags) continue;
        final c = make();
        c.selectSubject(i);
        expect(c.detailApplies, isFalse,
            reason: '$label is not a shape choice for flags');
      }
    });
  });

  group('Fine Tune — categories are contextual', () {
    /// The categories that must be present regardless of the design.
    const always = {
      RefineCategory.finish,
      RefineCategory.colour,
      RefineCategory.edges,
      RefineCategory.effects,
      RefineCategory.print,
    };

    test('the always-on categories are always on', () {
      for (var i = 0; i < StudioController.subjects.length; i++) {
        final c = make();
        c.selectSubject(i);
        expect(c.refineCategories().toSet(), containsAll(always),
            reason: '${StudioController.subjects[i].$3} lost a core category');
      }
    });

    test('Layout appears for Flags and nowhere else', () {
      for (var i = 0; i < StudioController.subjects.length; i++) {
        final (genre, _, label) = StudioController.subjects[i];
        final c = make();
        c.selectSubject(i);
        final has = c.refineCategories().contains(RefineCategory.layout);
        expect(has, genre == LabGenre.flags,
            reason: 'Layout is a flag-field control; $label is not one');
      }
    });

    test('Text appears for Words and nowhere else', () {
      for (var i = 0; i < StudioController.subjects.length; i++) {
        final (genre, _, label) = StudioController.subjects[i];
        final c = make();
        c.selectSubject(i);
        final has = c.refineCategories().contains(RefineCategory.text);
        expect(has, genre == LabGenre.typography,
            reason: 'there is no word to edit on $label');
      }
    });

    test('Graphic appears for Passport', () {
      final c = make();
      c.selectSubject(indexOfSubject(LabGenre.passport));
      expect(c.refineCategories(), contains(RefineCategory.graphic));
    });

    test('Graphic appears once a design is clipped, and not before', () {
      final c = make();
      c.selectSubject(indexOfSubject(LabGenre.flags));
      c.applyDetail(StudioDetail.grid); // no shape
      expect(c.refineCategories().contains(RefineCategory.graphic), isFalse);
      c.applyDetail(StudioDetail.heart); // a shape
      expect(c.refineCategories(), contains(RefineCategory.graphic));
    });

    test('every category in the menu has a rule', () {
      // If a category can never appear for any subject, its predicate is wrong
      // or it has been orphaned — either way it should not be in the enum.
      final seen = <RefineCategory>{};
      for (var i = 0; i < StudioController.subjects.length; i++) {
        final c = make();
        c.selectSubject(i);
        seen.addAll(c.refineCategories());
        c.applyDetail(StudioDetail.heart);
        seen.addAll(c.refineCategories());
      }
      expect(seen, containsAll(RefineCategory.values),
          reason: 'a category exists that no design can ever surface');
    });
  });

  group('Front print — controls follow the fit', () {
    test('a chest fit has a side; full and blank do not', () {
      final c = make();
      c.setFrontFit(FrontFit.chest);
      expect(c.frontLabel, anyOf('Left chest', 'Right chest'));
      c.setFrontFit(FrontFit.full);
      expect(c.frontLabel, 'Full');
      c.setFrontFit(FrontFit.none);
      expect(c.frontLabel, 'Blank');
    });

    test('a blank front has no print rect at all', () {
      final c = make();
      c.setFrontFit(FrontFit.none);
      expect(c.frontPrintRect(), Rect.zero);
    });

    test('ribbon coverage only means something for a ribbon front', () {
      final c = make();
      c.setFrontArt(FrontArt.ribbon);
      final selected = c.frontFace.content.flags.length;
      c.setRibbonCoverage(true);
      expect(c.frontFace.content.flags.length, greaterThanOrEqualTo(selected));
      // Away from the ribbon the front is a different design entirely, so
      // coverage has nothing to act on.
      c.setFrontArt(FrontArt.matchBack);
      expect(c.frontFace.composition.family,
          isNot(DesignFamily.frontRibbon));
    });
  });
}
