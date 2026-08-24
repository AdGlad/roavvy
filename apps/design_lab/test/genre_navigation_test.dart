import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:design_lab/lab_styles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlagSource source;
  setUpAll(() => source = FlagSource.locate()!);

  LabShowcaseGenerator gen(LabGenre g) => LabShowcaseGenerator(
        genre: g,
        silhouettesByShape: {
          ClipShape.animalSilhouette: source.silhouettesByKind()['animal'] ?? const [],
          ClipShape.plantSilhouette: source.silhouettesByKind()['plant'] ?? const [],
          ClipShape.landmarkSilhouette:
              source.silhouettesByKind()['landmark'] ?? const [],
          ClipShape.passportStampOutline: source.passportStampSlugs(),
        },
        continents: source.continents(),
        countryNames: source.countryNames(),
        countryContinents: source.continentOfCountry(),
      );

  DesignContext ctx(List<String> codes) => DesignContext(
        flagCodes: codes,
        trips: [
          for (final c in codes)
            Trip(countryCode: c, startedOn: DateTime(2023, 1, 1), endedOn: DateTime(2023, 1, 8)),
        ],
      );

  const nonFlag = {
    'animalSilhouette', 'plantSilhouette', 'landmarkSilhouette',
    'countryOutline', 'continentOutline', 'text',
    'passportStampOutline', 'passportPage',
  };

  test('Flags genre never emits other genres\' subjects', () {
    // sc HAS silhouettes + passport available, yet Flags must exclude them.
    final rs = gen(LabGenre.flags).generate(ctx(['sc']), seed: 1, count: 40);
    for (final r in rs) {
      final id = r.clip?.shapeId;
      if (id != null) expect(nonFlag.contains(id), isFalse, reason: '$id leaked into Flags');
    }
  });

  test('subject genres emit only their subjects', () {
    void check(LabGenre g, List<String> codes, Set<String> allowed) {
      final rs = gen(g).generate(ctx(codes), seed: 1, count: 20);
      final ids = rs.map((r) => r.clip?.shapeId).whereType<String>().toSet();
      expect(ids, isNotEmpty, reason: '$g produced no clips');
      expect(ids.difference(allowed), isEmpty, reason: '$g emitted $ids');
    }

    check(LabGenre.passport, ['sc'], {'passportPage', 'passportStampOutline'});
    check(LabGenre.animalsNature, ['sc'], {'animalSilhouette', 'plantSilhouette'});
    check(LabGenre.landmarks, ['fr'], {'landmarkSilhouette'});
    check(LabGenre.maps, ['sc'], {'countryOutline', 'continentOutline'});
    check(LabGenre.typography, ['sc'], {'text'});
  });

  test('data genres emit only their families', () {
    for (final (g, fams) in [
      (LabGenre.travelLog, {DesignFamily.timeline, DesignFamily.journeys, DesignFamily.wordCloud}),
      (LabGenre.milestones, {
        DesignFamily.badge,
        DesignFamily.frontRibbon,
        DesignFamily.achievements,
        DesignFamily.stats,
      }),
    ]) {
      final rs = gen(g).generate(ctx(['sc', 'au', 'gb']), seed: 1, count: 24);
      final fam = rs.map((r) => r.composition.family).toSet();
      expect(fam.difference(fams), isEmpty, reason: '$g emitted $fam');
      expect(fam.length, greaterThan(1), reason: '$g should rotate its families');
    }
  });

  test('data genre with a pinned Type emits only that family', () {
    final rs = LabShowcaseGenerator(genre: LabGenre.milestones, template: DesignFamily.badge)
        .generate(ctx(['sc', 'au']), seed: 1, count: 10);
    expect(rs.every((r) => r.composition.family == DesignFamily.badge), isTrue);
  });
}
