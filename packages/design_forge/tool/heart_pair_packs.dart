// Writes the Shared Heart, Twin Hearts (M210/M211) and Heart Wall (M214)
// draft packs from code, in canonical form, with fresh locks. Run from packages/design_forge:
//
//   dart run tool/heart_pair_packs.dart ../design_studio/assets/signature
//
// Re-running resets each pack to these values (keeping nothing from the
// existing files) and locks its heroes: the Lab's default lock pairs, or
// for Heart Wall the sample lists (3, 6, 12, 24, 48 countries).
import 'dart:io';

import 'package:design_forge/design_forge.dart';

DesignRecipe _base(HeartPair p, Orientation o) => DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [
        FlagRef('{{countryA}}'),
        FlagRef('{{countryB}}'),
      ]),
      composition: Composition(
        family: DesignFamily.singleHero,
        orientation: o,
        sizeClass: SizeClass.large,
      ),
      heartPair: p,
    );

const sharedHeart = HeartPair(
  layout: HeartPair.shared,
  heartScale: 0.8,
  seamPosition: 0.5,
  seamCurve: 0.35,
  seamLean: 0,
  squeeze: 0.35,
  hatchAngle: -38,
  hatchWidth: 0.065,
  spill: 0.45,
  tails: 0.9,
  streaks: 0.4,
  scratches: 0.85,
  crossHatch: 0,
  frayed: false,
);

const twinHearts = HeartPair(
  layout: HeartPair.twin,
  heartScale: 1.0,
  gap: -0.02,
  tilt: 7,
  squeeze: 0.45,
  hatchAngle: -4,
  hatchWidth: 0.07,
  spill: 0.6,
  tails: 0.65,
  streaks: 0.55,
  scratches: 0.25,
  frayed: true,
  crossHatch: 0,
);

const heartWall = HeartWall(
  maxColumns: 6,
  fill: 0.94,
  spacing: 0.08,
  tiltJitter: 3,
  squeeze: 0.5,
  hatchAngle: 0,
  hatchWidth: 0.09,
  spill: 0.3,
  tails: 0.4,
  streaks: 0.25,
  scratches: 0.15,
  frayed: true,
);

const lockPairs = ['us+co', 'fr+it', 'mx+pt', 'jp+kr', 'np+ch', 'id+mc'];

void main(List<String> args) {
  final dir = args.isEmpty ? '../design_studio/assets/signature' : args.first;
  final packs = [
    SignatureRecipe(
      id: 'shared_heart',
      title: 'Shared Heart',
      version: 1,
      status: SignatureStatus.draft,
      countries: 2,
      notes: 'Two countries in one heart (M210, ADR-185): A in the left lobe, '
          'B in the right, scribbled dry-brush edge, light scratches. '
          'Style reference only: ~/Downloads/1-heart-2-countries.jpg.',
      base: _base(sharedHeart, Orientation.square).toJson()..remove('recipeId'),
      envelope: VariationEnvelope.fromJson(const {
        'seed': {'min': 1, 'max': 1000000, 'integer': true},
        'heartPair.seamCurve': {'min': -0.6, 'max': 0.6},
        'heartPair.seamLean': {'min': -0.4, 'max': 0.4},
        'heartPair.hatchAngle': {'min': -48, 'max': -32},
        'heartPair.spill': {'min': 0.5, 'max': 0.8},
        'heartPair.scratches': {'min': 0.7, 'max': 1.0},
      }),
    ),
    SignatureRecipe(
      id: 'twin_hearts',
      title: 'Twin Hearts',
      version: 1,
      status: SignatureStatus.draft,
      countries: 2,
      notes: 'Two hearts side by side, one flag each (M211, ADR-185), '
          'brushed edges and dry streaks. Style reference only: '
          '~/Downloads/two-hearts-1.jpeg.',
      base: _base(twinHearts, Orientation.landscape).toJson()
        ..remove('recipeId'),
      envelope: VariationEnvelope.fromJson(const {
        'seed': {'min': 1, 'max': 1000000, 'integer': true},
        'heartPair.tilt': {'min': 3, 'max': 11},
        'heartPair.hatchAngle': {'min': -8, 'max': 8},
        'heartPair.streaks': {'min': 0.35, 'max': 0.7},
        'heartPair.spill': {'min': 0.45, 'max': 0.75},
      }),
      layout: const {
        'front': {'zone': 'fullFront', 'scale': 0.8},
      },
    ),
    SignatureRecipe(
      id: 'heart_wall',
      title: 'Heart Wall',
      version: 1,
      status: SignatureStatus.draft,
      countries: SignatureRecipe.anyCount,
      notes: 'Every country in its own small brushed heart, in rows of up to '
          'six, in the order given (M214). Style reference only: '
          '~/Downloads/multi-hearts.jpeg.',
      base: (DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: []),
        composition: const Composition(
          family: DesignFamily.singleHero,
          orientation: Orientation.portrait,
          sizeClass: SizeClass.large,
        ),
        heartWall: heartWall,
      ).toJson()
        ..remove('recipeId'))
        ..['content'] = {'flags': SignatureRecipe.countriesToken},
      envelope: VariationEnvelope.fromJson(const {
        'seed': {'min': 1, 'max': 1000000, 'integer': true},
        'heartWall.tiltJitter': {'min': 0, 'max': 5},
        'heartWall.hatchAngle': {'min': -6, 'max': 6},
        'heartWall.streaks': {'min': 0.15, 'max': 0.35},
      }),
    ),
  ];
  for (final raw in packs) {
    // Lock the hero of each lock key.
    final keys =
        raw.isList ? [for (final l in SignatureList.samples) l.key] : lockPairs;
    final p = raw.copyWith(locks: {
      for (final k in keys) k: SignatureResolver.heroFor(raw, k).recipeId,
    });
    File('$dir/${p.id}.pack.json')
        .writeAsStringSync(SignaturePackCodec.encode(p));
    // ignore: avoid_print
    print('wrote $dir/${p.id}.pack.json');
  }
}
