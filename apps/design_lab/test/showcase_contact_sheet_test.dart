import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:design_lab/lab_styles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the Lab's real generate → render → contact-sheet loop headlessly
/// (the GUI runs the same code). Writes a sheet PNG when OUT is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('showcase generator + contact sheet', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull, reason: 'flag SVGs must be discoverable');

    // Built with the same silhouette/continent data the GUI supplies, so the
    // rotation offers the country's own silhouettes + outline.
    final byKind = source!.silhouettesByKind();
    final gen = LabShowcaseGenerator(
      silhouettesByShape: {
        ClipShape.animalSilhouette: byKind['animal'] ?? const [],
        ClipShape.plantSilhouette: byKind['plant'] ?? const [],
        ClipShape.landmarkSilhouette: byKind['landmark'] ?? const [],
      },
      continents: source.continents(),
    );

    // Single-country (Seychelles) Flags genre — a broad, varied spread of
    // flag/shape subjects (silhouettes/outlines/passport now live in their own
    // genres, so they must NOT appear here).
    const scCtx = DesignContext(flagCodes: ['sc'], scopeKey: 'lab:sc');
    final sc = gen.generate(scCtx, seed: 1, count: 48);
    expect(sc, hasLength(48));

    const nonFlag = {
      'animalSilhouette', 'plantSilhouette', 'landmarkSilhouette',
      'countryOutline', 'continentOutline', 'text',
      'passportStampOutline', 'passportPage',
    };
    expect(sc.where((r) => nonFlag.contains(r.clip?.shapeId)), isEmpty,
        reason: 'Flags genre must not leak other genres\' subjects');
    // A plain flag appears, and the batch is broadly varied.
    expect(sc.where((r) => r.clip == null && r.edgeTreatment == null), isNotEmpty,
        reason: 'a plain flag should appear');
    expect(sc.map((r) => r.recipeId).toSet().length, greaterThan(40));

    // Deterministic: same seed reproduces the same recipe ids.
    final again = gen.generate(scCtx, seed: 1, count: 48);
    expect([for (final r in sc) r.recipeId],
        [for (final r in again) r.recipeId]);

    final out = Platform.environment['OUT'];
    if (out != null) {
      await tester.runAsync(() async {
        final renderer = CanvasRenderer(assets: source.resolver());
        final scSheet = await const ContactSheetBuilder(columns: 6, cell: 200)
            .build(sc, renderer);
        File('$out/lab_contact_sheet_sc.png').writeAsBytesSync(scSheet);
        // Multi-country spread too.
        final multi = gen.generate(
          const DesignContext(
              flagCodes: ['us', 'gb', 'jp', 'br'], scopeKey: 'lab'),
          seed: 1,
          count: 24,
        );
        final mSheet = await const ContactSheetBuilder(columns: 6, cell: 200)
            .build(multi, renderer);
        File('$out/lab_contact_sheet_multi.png').writeAsBytesSync(mSheet);
      });
      // ignore: avoid_print
      print('wrote sheets to $out');
    }
  });

  testWidgets('every style preset generates + renders', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    final byKind = source!.silhouettesByKind();
    Map<ClipShape, List<String>> sil() => {
          ClipShape.animalSilhouette: byKind['animal'] ?? const [],
          ClipShape.plantSilhouette: byKind['plant'] ?? const [],
          ClipShape.landmarkSilhouette: byKind['landmark'] ?? const [],
        };
    const scCtx = DesignContext(flagCodes: ['sc'], scopeKey: 'lab:sc');
    final out = Platform.environment['OUT'];

    for (final style in LabStyle.values) {
      final gen = LabShowcaseGenerator(
        style: style,
        silhouettesByShape: sil(),
        continents: source.continents(),
      );
      final recipes = gen.generate(scCtx, seed: 1, count: 24);
      expect(recipes, hasLength(24), reason: '${style.name} must generate');
      // Each style must yield distinct designs (no single-look collapse).
      expect(recipes.map((r) => r.recipeId).toSet().length, greaterThan(16),
          reason: '${style.name} should be varied');
      // Provenance carries the style name so favourites/exports are traceable.
      expect(recipes.first.provenance?.generator, 'lab:${style.name}');

      if (out != null) {
        await tester.runAsync(() async {
          final renderer = CanvasRenderer(assets: source.resolver());
          final sheet = await const ContactSheetBuilder(columns: 6, cell: 180)
              .build(recipes, renderer);
          File('$out/style_${style.name}.png').writeAsBytesSync(sheet);
        });
      }
    }
    if (out != null) {
      // ignore: avoid_print
      print('wrote per-style sheets to $out');
    }
  });

  testWidgets('typography offers the country name as text', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    final gen = LabShowcaseGenerator(
      genre: LabGenre.typography,
      countryNames: const {'sc': 'Seychelles'},
    );
    final recipes = gen.generate(
      const DesignContext(flagCodes: ['sc'], scopeKey: 'lab:sc'),
      seed: 1,
      count: 60,
    );
    final texts = recipes.map((r) => r.clip?.text).whereType<String>().toSet();
    expect(texts, contains('SEYCHELLES'),
        reason: 'the full country name must be an available text subject');
  });

  testWidgets('passport designs use REAL trip dates from the context',
      (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    final gen = LabShowcaseGenerator(
      genre: LabGenre.passport,
      silhouettesByShape: {
        ClipShape.passportStampOutline: source!.passportStampSlugs(),
      },
    );
    // A context carrying a real trip (12–18 Mar 2024) → the stamp date must be
    // the trip's date, not a synthesised one.
    final ctx = DesignContext.fromTrips([
      Trip(
        countryCode: 'sc',
        startedOn: DateTime(2024, 3, 12),
        endedOn: DateTime(2024, 3, 18),
      ),
    ]);
    final recipes = gen.generate(ctx, seed: 1, count: 60);
    final passportCodes = recipes
        .map((r) => r.clip?.code)
        .whereType<String>()
        .where((c) => c.contains('|'))
        .toList();
    expect(passportCodes, isNotEmpty,
        reason: 'passport stamps should appear for a single-country context');
    expect(passportCodes.any((c) => c.contains('12 MAR 24')), isTrue,
        reason: 'entry date must come from the real trip');
    expect(passportCodes.any((c) => c.contains('18 MAR 24')), isTrue,
        reason: 'exit date must come from the real trip');
  });
}
