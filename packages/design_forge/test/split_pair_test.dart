import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _pair(String a, String b,
        {SplitPair split = const SplitPair(),
        Orientation orientation = Orientation.portrait}) =>
    DesignRecipe(
      seed: 7,
      content: RecipeContent(flags: [FlagRef(a), FlagRef(b)]),
      composition:
          Composition(family: DesignFamily.splitPair, orientation: orientation),
      splitPair: split,
    );

const _samplePairs = [
  'id+mc', 'ro+td', 'nl+lu', 'ie+ci', 'fr+it', 'us+gb', 'co+ec', 'de+be', //
  'mx+pt', 'es+cr', 'py+dz', 'br+ar', 'sa+ae', 'np+ch', 'bt+np', 'co+us',
  'hu+us', 'mx+us', 'ca+us', 'gr+cy', 'au+nz', 'jm+cu', 'ly+cy', 'jp+kr',
  'pk+in', 've+pr', 'us+co', 'dz+py', 'gb-eng+pt', 'fi+se', 'za+gb', 'sc+mu',
];

void main() {
  group('SplitPair JSON', () {
    test('round-trips every field', () {
      const s = SplitPair(
        seam: SplitSeam.diagonal,
        seamPosition: 0.51,
        seamSlant: 0.8,
        seamCurve: 0.2,
        seamFlip: true,
        seamGap: 0.03,
        autoGap: 0,
        blockAspect: 0.6,
        margin: 0.05,
        rotateFlags: true,
        shadow: 0,
        edge: SplitEdge.brush,
        edgeWear: 0.4,
        distress: 0.3,
        distressScale: 0.2,
        scratches: 0.1,
        fade: 0.05,
      );
      final back = SplitPair.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
    });

    test('rides on DesignRecipe and changes its id; absent = old id', () {
      final with_ = _pair('us', 'co');
      final json = with_.toJson();
      expect(json['splitPair'], isA<Map>());
      expect(DesignRecipe.fromJson(json).recipeId, with_.recipeId);
      final without = DesignRecipe(
        seed: 7,
        content: const RecipeContent(flags: [FlagRef('us'), FlagRef('co')]),
        composition: const Composition(
            family: DesignFamily.splitPair, orientation: Orientation.portrait),
      );
      expect(without.toJson().containsKey('splitPair'), isFalse);
      expect(without.recipeId, isNot(with_.recipeId));
    });
  });

  group('SplitPairLayout', () {
    test('is deterministic', () {
      final a = SplitPairLayout.of(_pair('mx', 'pt'), 800, 1000)!;
      final b = SplitPairLayout.of(_pair('mx', 'pt'), 800, 1000)!;
      expect(a.seamPoints, b.seamPoints);
      for (var i = 0; i < 2; i++) {
        expect(a.flags[i].left, b.flags[i].left);
        expect(a.flags[i].width, b.flags[i].width);
      }
    });

    test('the top goes to the canton flag, on either side', () {
      final usA = SplitPairLayout.of(_pair('us', 'co'), 800, 1000)!;
      final usB = SplitPairLayout.of(_pair('co', 'us'), 800, 1000)!;
      expect(usA.seamAt(0), greaterThan(usA.seamAt(1)));
      expect(usB.seamAt(0), lessThan(usB.seamAt(1)));
    });

    test('seamFlip decides when no flag needs the top', () {
      final a = SplitPairLayout.of(_pair('co', 'de'), 800, 1000)!;
      final b = SplitPairLayout.of(
          _pair('co', 'de', split: const SplitPair(seamFlip: true)),
          800,
          1000)!;
      expect(a.slant, -b.slant);
    });

    test('two cantons: straight seam and a wider block', () {
      final l = SplitPairLayout.of(_pair('au', 'nz'), 800, 1000)!;
      expect(l.slant, 0);
      expect(l.blockWidth / l.blockHeight, greaterThanOrEqualTo(1.1 - 1e-9));
    });

    test('flags cover their half unless shrunk to fit an emblem', () {
      final l = SplitPairLayout.of(_pair('fr', 'it'), 800, 1000)!;
      for (final f in l.flags) {
        expect(f.top, closeTo(l.blockTop, 1e-6));
        expect(f.height, closeTo(l.blockHeight, 1e-6));
      }
      // Nepal's pennant is too wide for half a block: it is shrunk whole.
      final np = SplitPairLayout.of(_pair('np', 'ch'), 800, 1000)!.flags[0];
      expect(np.height, lessThan(l.blockHeight));
    });

    test('quarter-turned flags (Diagonal Split) swap the drawn box', () {
      final l = SplitPairLayout.of(
          _pair('dz', 'py',
              split: const SplitPair(
                  seam: SplitSeam.diagonal, seamSlant: 0.8, rotateFlags: true)),
          800,
          1000)!;
      for (final f in l.flags) {
        expect(f.rotated, isTrue);
        expect(f.height / f.width, closeTo(SplitPairLayout.flagAspect, 1e-6));
      }
    });
  });

  group('PairGeometry for splitPair', () {
    test('reports both crops and a seam in render space', () {
      final g = PairGeometry.of(_pair('us', 'co'))!;
      expect(g.crops.map((c) => c.code), ['us', 'co']);
      expect(g.seam!.points.first.$2, greaterThan(0));
      expect(g.seam!.points.last.$2, lessThan(1));
      expect(g.seam!.gap, 0);
    });

    test('not reported for other families or turned designs', () {
      final single = DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us')]),
        composition: const Composition(family: DesignFamily.singleHero),
      );
      expect(PairGeometry.of(single), isNull);
      final turned = DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us'), FlagRef('co')]),
        composition:
            const Composition(family: DesignFamily.splitPair, rotation: 90),
        splitPair: const SplitPair(),
      );
      expect(PairGeometry.of(turned), isNull);
    });

    test('every sample pair keeps ≥70% of each emblem, in both orders', () {
      for (final key in _samplePairs) {
        final p = SignaturePair.parse(key);
        for (final (a, b) in [(p.a, p.b), (p.b, p.a)]) {
          for (final slant in [0.18, 0.27, 0.3]) {
            final g = PairGeometry.of(
                _pair(a, b, split: SplitPair(seamSlant: slant)))!;
            for (final c in g.crops) {
              expect(c.emblemVisible, greaterThanOrEqualTo(0.7),
                  reason: '$a+$b slant $slant: ${c.code}');
            }
          }
        }
      }
    });
  });

  group('Diagonal Split (M212)', () {
    const diagonal = SplitPair(
      seam: SplitSeam.diagonal,
      seamSlant: 0.78,
      seamFlip: true,
      seamGap: 0.035,
      blockAspect: 0.66,
      rotateFlags: true,
      edge: SplitEdge.brush,
      brush: BrushStroke(bristles: 18, dryness: 0.6, leadClean: 0.2),
    );
    SplitPairLayout layout(String a, String b) =>
        SplitPairLayout.of(_pair(a, b, split: diagonal), 800, 1000)!;

    test('brush is written only when set (curtain ids unchanged)', () {
      expect(const SplitPair().toJson().containsKey('brush'), isFalse);
      final back = SplitPair.fromJson(diagonal.toJson());
      expect(back.brush!.bristles, 18);
      expect(back.brush!.leadClean, 0.2);
      expect(back.toJson(), diagonal.toJson());
    });

    test('a canton flag turns so its hoist lands where its half is wide', () {
      // Seam runs top-left → bottom-right: A is wide at the bottom, B at the
      // top.
      final usA = layout('us', 'co');
      expect(usA.slant, lessThan(0));
      expect(usA.flags[0].ccw, isTrue, reason: 'US as A: hoist at the bottom');
      expect(usA.flags[1].ccw, isFalse);
      expect(layout('co', 'us').flags[1].ccw, isFalse,
          reason: 'US as B: hoist at the top');
      // Plain and centred-emblem flags always turn clockwise.
      expect(layout('dz', 'py').flags.map((f) => f.ccw), [false, false]);
    });

    test('anticlockwise flag space maps back correctly', () {
      const f = SplitFlagPlacement(
          slot: 0,
          code: 'us',
          left: 0,
          top: 0,
          width: 100,
          height: 200,
          rotated: true,
          ccw: true,
          region: []);
      // The drawn bottom-left corner is the flag's top-left (the canton).
      final (u, v) = f.toFlag((0, 200));
      expect(u, closeTo(0, 1e-9));
      expect(v, closeTo(0, 1e-9));
    });

    test('a shrunk flag (Nepal) sits where its half is widest', () {
      final l = layout('np', 'ch');
      final np = l.flags[0];
      expect(np.width, greaterThan(l.blockWidth / 3));
      expect(
          np.top + np.height / 2, greaterThan(l.blockTop + l.blockHeight / 2));
      expect(np.left, greaterThanOrEqualTo(l.blockLeft - 1));
    });

    test('every sample pair keeps ≥70% of each emblem, in both orders', () {
      for (final key in _samplePairs) {
        final p = SignaturePair.parse(key);
        for (final (a, b) in [(p.a, p.b), (p.b, p.a)]) {
          for (final slant in [0.7, 0.78, 0.82]) {
            final g = PairGeometry.of(_pair(a, b,
                split: SplitPair.fromJson(
                    {...diagonal.toJson(), 'seamSlant': slant})))!;
            for (final c in g.crops) {
              expect(c.emblemVisible, greaterThanOrEqualTo(0.7),
                  reason: '$a+$b slant $slant: ${c.code}');
            }
          }
        }
      }
    });
  });
}
