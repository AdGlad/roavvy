import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Trip t(String cc, int y, int m, int d, int stay) => Trip(
      countryCode: cc,
      startedOn: DateTime(y, m, d),
      endedOn: DateTime(y, m, d + stay));

  final trips = [
    t('sc', 2024, 3, 12, 6),
    t('sc', 2022, 7, 2, 7),
    t('au', 2023, 11, 5, 15),
    t('gb', 2023, 9, 1, 13),
  ];

  test('generator builds each data template from travel history', () {
    final ctx = DesignContext.fromTrips(trips);
    for (final fam in [
      DesignFamily.timeline,
      DesignFamily.journeys,
      DesignFamily.wordCloud,
    ]) {
      final gen = LabShowcaseGenerator(
          template: fam, countryNames: const {'sc': 'Seychelles', 'au': 'Australia'});
      final r = gen.generate(ctx, seed: 1, count: 1).first;
      expect(r.composition.family, fam);
      expect(r.content.entries, isNotEmpty, reason: '$fam needs entries');
      expect(r.provenance?.generator, 'lab:template:${fam.name}');
    }
  });

  test('timeline/journeys carry one dated entry per trip; wordCloud per country',
      () {
    final ctx = DesignContext.fromTrips(trips);
    final timeline = LabShowcaseGenerator(template: DesignFamily.timeline)
        .generate(ctx, seed: 1, count: 1)
        .first;
    // 4 trips → 4 dated timeline entries.
    expect(timeline.content.entries, hasLength(4));
    expect(timeline.content.entries.every((e) => e.start != null), isTrue);

    final cloud = LabShowcaseGenerator(template: DesignFamily.wordCloud)
        .generate(ctx, seed: 1, count: 1)
        .first;
    // 3 distinct countries; SC visited twice → weight 2.
    expect(cloud.content.entries, hasLength(3));
    final sc = cloud.content.entries.firstWhere((e) => e.code == 'sc');
    expect(sc.weight, 2);
  });

  test('recipe with entries round-trips through JSON', () {
    final ctx = DesignContext.fromTrips(trips);
    final r = LabShowcaseGenerator(template: DesignFamily.timeline)
        .generate(ctx, seed: 3, count: 1)
        .first;
    expect(DesignRecipe.fromJson(r.toJson()).toJson(), r.toJson());
  });

  testWidgets('each data template renders non-blank', (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());
    final ctx = DesignContext.fromTrips(trips);
    await tester.runAsync(() async {
      for (final fam in [
        DesignFamily.timeline,
        DesignFamily.journeys,
        DesignFamily.wordCloud,
      ]) {
        final r = LabShowcaseGenerator(
                template: fam, countryNames: source.countryNames())
            .generate(ctx, seed: 1, count: 1)
            .first;
        final res = await renderer.render(r, RenderTarget.preview(size: 300));
        expect(res.pngBytes.length, greaterThan(1000), reason: '$fam blank');
      }
    });
  });
}
