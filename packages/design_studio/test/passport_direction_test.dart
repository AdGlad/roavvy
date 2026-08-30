import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Passport is its own Direction/genre and must stay structurally invariant:
/// every Vibe, every seed and every host inventory must still produce passport
/// stamps / a passport page. It must NEVER silently degrade into a generic flag
/// design (`basicFlag` → a null clip), which is what happened when a host (the
/// mobile app) shipped no `passportStampOutline` inventory.
class _NoopResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(String code,
          {required int width, required int height}) =>
      throw UnimplementedError('rendering is not exercised here');
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
  /// The only shape ids a Passport design may carry.
  const passportShapes = {'passportPage', 'passportStampOutline'};

  const codes = ['au', 'fr', 'gb'];
  final trips = [
    Trip(
        countryCode: 'au',
        startedOn: DateTime(2024, 3, 12),
        endedOn: DateTime(2024, 3, 28)),
    Trip(
        countryCode: 'fr',
        startedOn: DateTime(2025, 6, 4),
        endedOn: DateTime(2025, 6, 11)),
    Trip(
        countryCode: 'gb',
        startedOn: DateTime(2025, 9, 2),
        endedOn: DateTime(2025, 9, 18)),
  ];
  final context =
      DesignContext(flagCodes: codes, scopeKey: 'test:passport', trips: trips);

  /// A generator with a real stamp inventory (what a correctly wired host ships).
  LabShowcaseGenerator stocked({LabStyle style = LabStyle.showcase}) =>
      LabShowcaseGenerator(
        style: style,
        genre: LabGenre.passport,
        silhouettesByShape: {
          ClipShape.passportStampOutline: [
            for (final c in codes) ...['${c}_entry', '${c}_exit'],
          ],
        },
        countryNames: const {},
      );

  /// A generator with NO inventory at all — the failure mode this fix targets.
  LabShowcaseGenerator bare({LabStyle style = LabStyle.showcase}) =>
      LabShowcaseGenerator(
        style: style,
        genre: LabGenre.passport,
        silhouettesByShape: const {},
        countryNames: const {},
      );

  test('Passport has available subjects and never falls back to basicFlag', () {
    for (final gen in [stocked(), bare()]) {
      final rs = gen.generate(context, seed: 1, count: 24);
      for (final r in rs) {
        expect(r.clip, isNotNull,
            reason: 'a null clip IS the basicFlag subject — Passport degraded');
        expect(passportShapes, contains(r.clip!.shapeId));
      }
    }
  });

  test('every Vibe keeps the Passport family (generation)', () {
    for (final style in LabStyle.values) {
      for (final gen in [stocked(style: style), bare(style: style)]) {
        final rs = gen.generate(context, seed: 1, count: 13);
        final ids = rs.map((r) => r.clip?.shapeId).toSet();
        expect(ids.contains(null), isFalse, reason: '$style dropped to a flag');
        expect(ids.difference(passportShapes), isEmpty,
            reason: '$style emitted $ids');
      }
    }
  });

  test('a Vibe change restyles a Passport design without replacing its subject',
      () {
    final controller = StudioController(
      generator: stocked(),
      service: RenderService(_NoopResolver()),
      designContext: context,
      initialSeed: 7,
    );
    // Direction → Passport (index 1 of StudioController.subjects).
    final passportIndex =
        StudioController.subjects.indexWhere((s) => s.$1 == LabGenre.passport);
    controller.selectSubject(passportIndex);
    final before = controller.current.clip;
    expect(passportShapes, contains(before!.shapeId));

    final options = controller.vibeStyleOptions();
    expect(options.length, LabStyle.values.length);
    for (final (style, styled) in options) {
      expect(styled.clip?.shapeId, before.shapeId,
          reason: '$style replaced the Passport subject');
      expect(styled.clip?.code, before.code,
          reason: '$style changed the passport trip content');
    }

    // Applying one keeps the Direction and the passport artwork; only the
    // finish moves.
    final grunge = options.firstWhere((o) => o.$1 == LabStyle.grunge);
    controller.onStyleTap(grunge.$1, grunge.$2);
    expect(controller.subjectIndex, passportIndex);
    expect(passportShapes, contains(controller.current.clip?.shapeId));
    expect(controller.current.clip?.code, before.code);
  });

  test('passport page carries REAL trip entry + exit dates per country', () {
    final rs = stocked().generate(context, seed: 1, count: 24);
    final page = rs.firstWhere((r) => r.clip?.shapeId == 'passportPage');
    final segs = (page.clip!.code ?? '').split(';');
    expect(segs.length, trips.length);
    for (final t in trips) {
      expect(
        segs,
        contains('${t.cc}|${LabShowcaseGenerator.formatDate(t.startedOn)}'
            '|${LabShowcaseGenerator.formatDate(t.endedOn)}'),
      );
    }
  });

  test('with no stamp inventory the page still covers the real trips', () {
    final rs = bare().generate(context, seed: 1, count: 24);
    for (final r in rs.where((r) => r.clip?.shapeId == 'passportPage')) {
      final segs = (r.clip!.code ?? '').split(';');
      expect(segs.length, trips.length);
      for (final t in trips) {
        expect(
          segs,
          contains('${t.cc}|${LabShowcaseGenerator.formatDate(t.startedOn)}'
              '|${LabShowcaseGenerator.formatDate(t.endedOn)}'),
        );
      }
    }
  });

  test('entry/exit stamp generation is deterministic', () {
    for (final gen in [stocked(), bare()]) {
      final a = gen.generate(context, seed: 4, count: 8);
      final b = gen.generate(context, seed: 4, count: 8);
      expect([for (final r in a) r.recipeId], [for (final r in b) r.recipeId]);
      expect(
          [for (final r in a) r.clip?.code], [for (final r in b) r.clip?.code]);
    }
  });

  test('a single-country Passport uses that country\'s real stamp + date', () {
    final ctx = DesignContext(
        flagCodes: const ['au'], scopeKey: 'test:au', trips: [trips.first]);
    final rs = stocked().generate(ctx, seed: 1, count: 12);
    final one = rs.firstWhere((r) => r.clip?.shapeId == 'passportStampOutline',
        orElse: () => rs.first);
    expect(passportShapes, contains(one.clip?.shapeId));
    expect(one.clip!.code, contains('au'));
    expect(one.clip!.code, contains('MAR 24'));
  });

  test('other Directions still fall back to the plain flag', () {
    // Landmarks with no landmark inventory has no subject of its own — the
    // generic flag fallback is correct there and must be untouched.
    final gen = LabShowcaseGenerator(
      genre: LabGenre.landmarks,
      silhouettesByShape: const {},
      countryNames: const {},
    );
    final rs = gen.generate(context, seed: 1, count: 6);
    expect(rs.every((r) => r.clip == null), isTrue);
  });
}
