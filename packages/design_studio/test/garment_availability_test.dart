// M175 — the studio may show a colour it cannot sell, but never silently.
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
  StudioController make({Set<String> unavailable = const {}}) =>
      StudioController(
        generator: LabShowcaseGenerator(
          silhouettesByShape: const {},
          countryNames: const {},
        ),
        service: RenderService(_NoopResolver()),
        designContext: const DesignContext(
          flagCodes: ['us', 'fr'],
          scopeKey: 'test:availability',
        ),
        initialSeed: 2,
        unavailableGarments: unavailable,
      );

  test('with nothing declared unavailable, the whole palette is orderable', () {
    final c = make();
    for (final (_, name) in StudioController.garments) {
      expect(c.canOrderGarment(name), isTrue, reason: '$name should be orderable');
    }
  });

  test('a declared colour is not orderable, but stays in the palette', () {
    final c = make(unavailable: {'Orange', 'Royal'});
    expect(c.canOrderGarment('Orange'), isFalse);
    expect(c.canOrderGarment('Royal'), isFalse);
    expect(c.canOrderGarment('Black'), isTrue);
    // Still offered — seeing a design on it is fine; being sold it is not.
    final names = [for (final (_, n) in StudioController.garments) n];
    expect(names, containsAll(['Orange', 'Royal']));
  });

  test('the current design knows whether it can be bought as it stands', () {
    final c = make(unavailable: {'Orange'});
    c.setGarment('#0E0E0E'); // Black
    expect(c.canOrderCurrent, isTrue);
    c.setGarment('#FF5723'); // Orange
    expect(c.canOrderCurrent, isFalse);
  });

  test('garment labels resolve from hex, case-insensitively', () {
    final c = make();
    expect(c.garmentLabelFor('#FF5723'), 'Orange');
    expect(c.garmentLabelFor('#ff5723'), 'Orange');
    expect(c.garmentLabelFor('#123456'), isNull);
    expect(c.garmentLabelFor(null), isNull);
  });

  test('the package knows nothing about a store', () {
    // Availability is injected, never inferred here — design_studio must stay
    // supplier-agnostic, which is why this is a constructor argument.
    expect(make().unavailableGarments, isEmpty);
  });
}
