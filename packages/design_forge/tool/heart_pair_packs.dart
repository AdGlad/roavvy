// Writes the Shared Heart and Twin Hearts draft packs (M210/M211) from
// code, in canonical form. Run from packages/design_forge:
//
//   dart run tool/heart_pair_packs.dart ../design_studio/assets/signature
//
// Re-running resets envelope/base to these values (keeping nothing from the
// existing files); locks are refreshed afterwards by the Lab or the
// `UPDATE_LOCKS` test.
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
  ];
  for (final raw in packs) {
    // Lock the hero of each lock pair (the Lab's defaultLockPairs).
    final p = raw.copyWith(locks: {
      for (final k in lockPairs) k: SignatureResolver.heroFor(raw, k).recipeId,
    });
    File('$dir/${p.id}.pack.json')
        .writeAsStringSync(SignaturePackCodec.encode(p));
    // ignore: avoid_print
    print('wrote $dir/${p.id}.pack.json');
  }
}
