import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_geometry_generator.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_quality.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_recipe.dart';

const _gen = TornGeometryGenerator();

void main() {
  test('every curated family meets reference-quality gates across seeds', () {
    for (final s in TearStyle.values) {
      for (var seed = 0; seed < 6; seed++) {
        final mask =
            _gen.generate(sampleTornRecipe(s, seed), width: 200, height: 200);
        final m = measureTornQuality(mask, sampleTornRecipe(s, seed));
        final where = '${s.name}@$seed';

        // Hard requirements (the user's prime directive).
        expect(m.interiorClean, 1.0, reason: 'interior breached: $where');
        expect(m.edgeConcentration, 1.0,
            reason: 'centre hole (not edge-originated): $where');
        // Every family must actually tear something and stay recognisable.
        expect(m.removedFraction, greaterThan(0.002), reason: 'no tear: $where');
        expect(m.removedFraction, lessThan(0.45),
            reason: 'flag destroyed: $where');
        // Fingers, not a solid coastline. Only the reliably-deep finger-centric
        // families are gated on separation count; deep-rips/asymmetric are about
        // depth/direction (few deep tears), frayed's fibres are fine and shallow,
        // and lightly/corners are subtle or local — all covered by the score.
        const fingerFamilies = {
          TearStyle.ragged,
          TearStyle.battleWorn,
          TearStyle.heavyEdgeDamage,
        };
        if (fingerFamilies.contains(s)) {
          expect(m.fingerTransitions, greaterThanOrEqualTo(6),
              reason: 'not enough separated fingers: $where');
        }
        expect(m.score, greaterThan(0.55), reason: 'low quality: $where');
      }
    }
  });

  test('directional families read as clearly one-sided', () {
    // Asymmetric-tear should be strongly lopsided; heavy-edge-damage balanced.
    var asym = 0.0;
    var heavy = 0.0;
    for (var seed = 0; seed < 6; seed++) {
      asym += measureTornQuality(
              _gen.generate(sampleTornRecipe(TearStyle.asymmetricTear, seed),
                  width: 200, height: 200),
              sampleTornRecipe(TearStyle.asymmetricTear, seed))
          .asymmetry;
      heavy += measureTornQuality(
              _gen.generate(sampleTornRecipe(TearStyle.heavyEdgeDamage, seed),
                  width: 200, height: 200),
              sampleTornRecipe(TearStyle.heavyEdgeDamage, seed))
          .asymmetry;
    }
    expect(asym / 6, greaterThan(heavy / 6),
        reason: 'asymmetric should be more lopsided than heavy-all-edges');
  });
}
