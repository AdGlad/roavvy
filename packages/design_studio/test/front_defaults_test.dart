// The shirt FRONT defaults: a left-chest ribbon — the app's original front
// artwork — with the other fronts still reachable as variations.
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
  const context = DesignContext(
    flagCodes: ['us', 'fr', 'jp'],
    scopeKey: 'test:front',
  );

  StudioController make() => StudioController(
        generator: LabShowcaseGenerator(
          silhouettesByShape: const {},
          countryNames: const {},
        ),
        service: RenderService(_NoopResolver()),
        designContext: context,
        initialSeed: 3,
      );

  test('the front opens as a left-chest ribbon', () {
    final c = make();
    expect(c.frontArt, FrontArt.ribbon);
    expect(c.frontFit, FrontFit.chest);
    expect(c.chestRight, isFalse);
    expect(c.frontLabel, 'Left chest');
    expect(c.frontFace.composition.family, DesignFamily.frontRibbon);
  });

  test('left chest prints on the wearer\'s left — the viewer\'s right', () {
    final c = make();
    // Mobile parity: the left-chest rect sits in the RIGHT half of the image.
    expect(c.frontPrintRect().left, greaterThan(0.5));
    c.setChestSide(true);
    expect(c.frontPrintRect().left, lessThan(0.5));
  });

  test('the ribbon carries no printed title', () {
    final c = make();
    c.setSide(false); // the hero (back) is where a title belongs
    c.commitTitle('EUROPE 2026');
    // The back wears the title; a chest badge is the wordmark and the flags.
    expect(c.hero.content.meta['title'], 'EUROPE 2026');
    expect(c.frontFace.content.meta.containsKey('title'), isFalse);
  });

  test('the other fronts remain available as variations', () {
    final c = make();
    for (final art in FrontArt.values) {
      c.setFrontArt(art);
      expect(c.frontArt, art);
    }
    c.setFrontArt(FrontArt.ribbon);
    expect(c.frontFace.composition.family, DesignFamily.frontRibbon);

    for (final fit in FrontFit.values) {
      c.setFrontFit(fit);
      expect(c.frontFit, fit);
    }
    // A blank front is expressed as an empty print rect.
    c.setFrontFit(FrontFit.none);
    expect(c.frontPrintRect(), Rect.zero);
  });

  test('ribbon coverage switches between selected and all countries', () {
    final c = make();
    final selected = c.frontFace.content.flags.length;
    c.setRibbonCoverage(true);
    expect(c.frontFace.content.flags.length, greaterThanOrEqualTo(selected));
    c.setRibbonCoverage(false);
    expect(c.frontFace.content.flags.length, selected);
  });

  test('the front keeps the garment colour the design carries', () {
    final c = make();
    c.setGarment('#FF1B2B');
    expect(c.frontFace.palette?.garmentColour, '#FF1B2B');
  });
}
