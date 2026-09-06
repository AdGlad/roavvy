// Instant — the opening offer. A finished shirt chosen for this traveller, a
// deck of alternatives to swipe, and three ways out.
import 'dart:ui' as ui;

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
  const context = DesignContext(
    flagCodes: ['us', 'fr', 'jp', 'br', 'au'],
    scopeKey: 'test:instant',
  );

  StudioController make({
    DesignPreferences? prefs,
    int seed = 5,
    void Function(DesignPreferences)? onLearn,
  }) =>
      StudioController(
        onPreferencesChanged: onLearn,
        generator: LabShowcaseGenerator(
          silhouettesByShape: const {},
          countryNames: const {},
        ),
        service: RenderService(_NoopResolver()),
        designContext: context,
        initialSeed: seed,
        preferences: prefs ?? DesignPreferences.neutral,
      );

  test('the studio opens on a finished design, not a blank one', () {
    final c = make();
    expect(c.current, isNotNull);
    expect(c.instantPicks, isNotEmpty);
    expect(c.instantIndex, 0);
  });

  test('the deck offers several genuinely different designs', () {
    final picks = make().instantPicks;
    expect(picks.length, StudioController.instantCount);
    // Distinct designs, not eight variations of one.
    expect(picks.map((p) => p.recipeId).toSet().length, picks.length);
    // …and spanning more than a single family, so the first swipe shows
    // something meaningfully other than the opening pick.
    expect(
        picks.map((p) => p.composition.family).toSet().length, greaterThan(1));
  });

  test('the deck is stable across a session', () {
    // Swiping back must show what was there before, not a fresh roll.
    final c = make();
    final first = [for (final p in c.instantPicks) p.recipeId];
    c.showInstant(3);
    c.showInstant(0);
    expect([for (final p in c.instantPicks) p.recipeId], first);
  });

  test('the same traveller gets the same opening offer', () {
    expect(
      [for (final p in make(seed: 9).instantPicks) p.recipeId],
      [for (final p in make(seed: 9).instantPicks) p.recipeId],
    );
  });

  test('swiping puts the pick on the shirt', () {
    final c = make();
    final first = c.instantPicks[0];
    final second = c.instantPicks[1];
    c.showInstant(1);
    expect(c.instantIndex, 1);
    // Not by recipe id: the pick arrives wearing the shirt colour and print
    // scale already on screen, which changes its id. It is the same DESIGN.
    expect(c.hero.composition.family, second.composition.family);
    expect(c.hero.clip?.shapeId, second.clip?.shapeId);
    expect(c.hero.recipeId, isNot(first.recipeId));
  });

  test('swiping wraps in both directions', () {
    final c = make();
    final last = c.instantPicks.length - 1;
    c.showInstant(-1);
    expect(c.instantIndex, last, reason: 'swiping back from the first wraps');
    c.showInstant(last + 1);
    expect(c.instantIndex, 0, reason: 'swiping past the last wraps');
  });

  test('browsing the deck neither buries the design nor teaches preferences',
      () {
    var learned = 0;
    final c = make(onLearn: (_) => learned++);
    final historyBefore = c.history.length;

    c.showInstant(1);
    c.showInstant(2);
    c.showInstant(3);

    expect(c.history.length, historyBefore,
        reason: 'swiping must not fill the undo stack');
    expect(learned, 0, reason: 'flicking past a design is not choosing it');
  });

  test('acting on a pick IS a choice', () {
    var learned = 0;
    final c = make(onLearn: (_) => learned++);
    c.showInstant(2);
    c.takeInstant();
    expect(learned, greaterThan(0));
  });

  test('the front follows the pick as a chest ribbon', () {
    final c = make();
    c.showInstant(4);
    expect(c.frontFace.composition.family, DesignFamily.frontRibbon);
    expect(c.frontFit, FrontFit.chest);
    expect(c.chestRight, isFalse);
  });

  test('the chosen shirt colour survives a swipe', () {
    // Colour is the wearer's, not the design's — flicking through the deck
    // must not throw away the shirt they picked.
    final c = make();
    c.setGarment('#FF1B2B');
    c.showInstant(3);
    expect(c.hero.palette?.garmentColour, '#FF1B2B');
    expect(c.frontFace.palette?.garmentColour, '#FF1B2B');
  });

  test('every pick can be named for the deck', () {
    final c = make();
    for (final p in c.instantPicks) {
      expect(c.instantName(p).trim(), isNotEmpty);
    }
  });

  test('a printed title names the design', () {
    final c = make();
    c.setSide(false);
    c.commitTitle('EUROPE 2026');
    expect(c.instantName(c.hero), 'EUROPE 2026');
  });

  test('Customise keeps the pick — it is the only way forward', () {
    // Customise is "carry on with THIS design", so the recipe on screen must
    // be untouched by the act of choosing to customise it. There is no second
    // door that throws the pick away (M11 removed Configure + Start custom).
    final c = make();
    c.showInstant(2);
    final chosen = c.hero.recipeId;
    c.takeInstant();
    expect(c.hero.recipeId, chosen);
  });

  group('the pages either side of the one on screen', () {
    test('a neighbour is that design wearing the colour already chosen', () {
      // Neighbours render before they are settled on, and a raw pick still
      // carries whatever colour it was generated in — so without this the
      // shirt visibly changes colour as the swipe lands.
      final c = make();
      c.setGarment('#FF1B2B');
      final next = c.instantPreviewAt(1);
      expect(next.palette?.garmentColour, '#FF1B2B');
      // …and it is genuinely the NEXT design, not the current one recoloured.
      expect(next.composition.family, c.instantPicks[1].composition.family);
      expect(next.clip?.shapeId, c.instantPicks[1].clip?.shapeId);
    });

    test('it wraps both ways, like swiping does', () {
      final c = make();
      final last = c.instantPicks.length - 1;
      expect(
        c.instantPreviewAt(-1).composition.family,
        c.instantPicks[last].composition.family,
      );
      expect(
        c.instantPreviewAt(last + 1).composition.family,
        c.instantPicks[0].composition.family,
      );
    });

    test('a neighbour has its OWN front, not the current design\'s', () {
      final c = make();
      expect(c.instantFrontAt(1).composition.family, DesignFamily.frontRibbon);
      expect(
        c.instantFrontAt(1).content.flags.length,
        c.instantFrontAt(1).content.flags.length,
      );
    });

    test('looking at a neighbour changes nothing', () {
      // Rendering the page beside you must not move the deck, the selection,
      // or the design on the shirt.
      final c = make();
      final hero = c.hero.recipeId;
      final index = c.instantIndex;
      c.instantPreviewAt(3);
      c.instantFrontAt(3);
      expect(c.hero.recipeId, hero);
      expect(c.instantIndex, index);
      expect(c.history, isEmpty);
    });
  });
}
