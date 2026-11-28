import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _recipe(HeartPair p, String a, String b,
        {Orientation o = Orientation.square}) =>
    DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef(a), FlagRef(b)]),
      composition: Composition(
          family: DesignFamily.singleHero,
          orientation: o,
          sizeClass: SizeClass.large),
      heartPair: p,
    );

void main() {
  group('HeartPair', () {
    test('round-trips every field', () {
      const p = HeartPair(
        layout: HeartPair.twin,
        heartScale: 0.7,
        seamPosition: 0.45,
        seamCurve: -0.2,
        seamLean: 0.3,
        gap: 0.02,
        tilt: 5,
        squeeze: 0.6,
        hatchAngle: -10,
        hatchWidth: 0.06,
        spill: 0.4,
        tails: 0.2,
        streaks: 0.6,
        scratches: 0.1,
        frayed: true,
        crossHatch: 0.3,
      );
      final back = HeartPair.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
    });

    test('rejects an unknown layout and out-of-range sizes', () {
      expect(() => HeartPair.fromJson({'layout': 'triple'}),
          throwsFormatException);
      expect(
          () => HeartPair.fromJson({'hatchWidth': 0.5}), throwsFormatException);
      expect(() => HeartPair.fromJson({'seamPosition': 0.9}),
          throwsFormatException);
    });

    test('is part of the recipe (and its id) only when present', () {
      final plain = DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us'), FlagRef('co')]),
        composition: const Composition(family: DesignFamily.singleHero),
      );
      expect(plain.toJson().containsKey('heartPair'), isFalse);
      final with_ = plain.copyWith(heartPair: const HeartPair());
      expect(with_.recipeId == plain.recipeId, isFalse);
      final back = DesignRecipe.fromJson(with_.toJson());
      expect(back.recipeId, with_.recipeId);
      expect(back.heartPair!.layout, HeartPair.shared);
    });
  });

  group('HeartPairLayout', () {
    test('shared: one heart, A left of the seam, B right', () {
      final l = HeartPairLayout.compute(const HeartPair(),
          width: 1000, height: 1000, a: 've', b: 'pr');
      expect(l.slots, hasLength(2));
      expect(l.gap, 0);
      final a = l.slots[0], b = l.slots[1];
      expect(identical(a.heart, b.heart) || a.heart == b.heart, isTrue);
      expect(a.visibleBox.right, lessThanOrEqualTo(b.visibleBox.left));
      // The seam runs top to bottom near the middle of the heart.
      final xs = [for (final (x, _) in l.seam) x];
      for (final x in xs) {
        expect((x - 500).abs(), lessThan(80));
      }
    });

    test('twin: two hearts that lean apart, never overlapping', () {
      final l = HeartPairLayout.compute(
          const HeartPair(layout: HeartPair.twin, tilt: 10, gap: 0.0),
          width: 1250,
          height: 1000,
          a: 'us',
          b: 'co');
      final a = l.slots[0], b = l.slots[1];
      expect(a.rotationDeg, -10);
      expect(b.rotationDeg, 10);
      expect(a.heartBox.right, lessThan(b.heartBox.left));
      expect(l.gap, 0);
    });

    test('every flag keeps its emblem in view, in both slots and layouts', () {
      for (final p in const [
        HeartPair(),
        HeartPair(layout: HeartPair.twin, tilt: 7),
      ]) {
        for (final code in FlagFocus.knownCodes) {
          final other = code == 'fr' ? 'de' : 'fr';
          for (final (a, b) in [(code, other), (other, code)]) {
            final g = PairGeometry.of(_recipe(p, a, b,
                o: p.isTwin ? Orientation.landscape : Orientation.square))!;
            for (final c in g.crops) {
              expect(c.emblemVisible, greaterThanOrEqualTo(0.7),
                  reason: '${p.layout} $a+$b slot ${c.slot}');
            }
          }
        }
      }
    });

    test('a hoist emblem is fitted inside the heart, not cropped away', () {
      // Puerto Rico's star triangle sits at the hoist: on the right half of
      // a shared heart the hoist faces the seam and stays in view.
      final g = PairGeometry.of(_recipe(const HeartPair(), 've', 'pr'))!;
      expect(g.crops[1].code, 'pr');
      expect(g.crops[1].emblemVisible, greaterThanOrEqualTo(0.8));
    });

    test('PairGeometry reports twin hearts with a gap (seam check skipped)',
        () {
      final g = PairGeometry.of(_recipe(
          const HeartPair(layout: HeartPair.twin, gap: 0.03), 'us', 'co',
          o: Orientation.landscape))!;
      expect(g.seam!.gap, greaterThan(0));
      expect(g.seam!.xAt(0.5), closeTo(0.5, 1e-9));
    });

    test('is deterministic', () {
      HeartPairLayout l() => HeartPairLayout.compute(const HeartPair(),
          width: 800, height: 800, a: 'mx', b: 'pt');
      expect(
          l().slots[1].flagDest.toString(), l().slots[1].flagDest.toString());
    });

    test('no geometry without heartPair or with one flag', () {
      expect(
          HeartPairLayout.ofRecipe(DesignRecipe(
              seed: 1,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition: const Composition(family: DesignFamily.singleHero),
              heartPair: const HeartPair())),
          isNull);
      expect(
          PairGeometry.of(DesignRecipe(
              seed: 1,
              content:
                  const RecipeContent(flags: [FlagRef('us'), FlagRef('co')]),
              composition: const Composition(family: DesignFamily.singleHero))),
          isNull);
    });
  });
}
