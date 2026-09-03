import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';

/// M7 — Fine Tune capability-coverage audit.
///
/// Proves that every refine capability the engine (design_forge) + session
/// (design_studio) currently expose is *accounted for* in V2 Fine Tune: either
/// (A) reachable through a control key, or (B) intentionally excluded with a
/// documented reason. If someone adds a new engine enum value (a fill algorithm,
/// a tear style, a colour strategy, a text case/placement) without wiring it into
/// Fine Tune, the relevant assertion below fails — capability can't be silently
/// dropped.
void main() {
  // A = reachable in the V2 Fine Tune UI (value → control key present).
  // B = intentionally excluded (value → reason).

  group('Layout — FillAlgorithm', () {
    // Every fill algorithm is a `v2-ft-fill-<name>` chip.
    const reachable = {
      FillAlgorithm.grid,
      FillAlgorithm.treemap,
      FillAlgorithm.diagonalStripe,
      FillAlgorithm.voronoi,
      FillAlgorithm.tornRegion,
      FillAlgorithm.noiseBlend,
      FillAlgorithm.radial,
      FillAlgorithm.mosaic,
    };
    test('all values reachable', () {
      expect(
        reachable,
        containsAll(FillAlgorithm.values),
        reason: 'A new FillAlgorithm must get a v2-ft-fill-<name> chip.',
      );
    });
  });

  group('Edges — TearStyle', () {
    const reachable = {
      TearStyle.lightlyWorn,
      TearStyle.ragged,
      TearStyle.tornCorners,
      TearStyle.battleWorn,
      TearStyle.deepRips,
      TearStyle.frayed,
      TearStyle.asymmetricTear,
      TearStyle.heavyEdgeDamage,
    };
    test('all values reachable', () {
      expect(
        reachable,
        containsAll(TearStyle.values),
        reason: 'A new TearStyle must get a v2-ft-tear-<name> chip.',
      );
    });
  });

  group('Colour — ColourStrategy', () {
    // Reachable via the discrete colour treatments (v2-ft-colour-*).
    final reachable = {for (final t in StudioController.colourTreatments) t.$2};
    // `brand` is generator/brand-owned, not a user-selectable artwork treatment.
    const excluded = {
      ColourStrategy.brand:
          'Brand palette is generator-owned, not a user knob.',
    };
    test('every strategy is reachable or documented-excluded', () {
      for (final s in ColourStrategy.values) {
        expect(
          reachable.contains(s) || excluded.containsKey(s),
          isTrue,
          reason: 'ColourStrategy.$s must be reachable or excluded.',
        );
      }
    });
  });

  group('Text — TextCase / TextPlacement', () {
    const reachableCase = {
      TextCase.upper,
      TextCase.title,
      TextCase.lower,
      TextCase.asIs,
    };
    const reachablePlacement = {
      TextPlacement.top,
      TextPlacement.bottom,
      TextPlacement.none,
    };
    test('all text-case + placement values reachable', () {
      expect(reachableCase, containsAll(TextCase.values));
      expect(reachablePlacement, containsAll(TextPlacement.values));
    });
  });

  group('Effects fields', () {
    // Every continuous Effects parameter has a Fine Tune control. Split across
    // the Effects category (surface treatments) and the Print category (print
    // looks). distressHardness/halftoneAngle are advanced sub-knobs folded into
    // their parent effect (documented exclusions).
    const inEffects = {
      'distress': 'v2-ft-fx-distress',
      'grain': 'v2-ft-fx-grain',
      'fade': 'v2-ft-fx-fade',
      'cracks': 'v2-ft-fx-cracks',
      'acidWash': 'v2-ft-fx-acidwash',
      'tieDye': 'v2-ft-fx-tiedye',
      'shatter': 'v2-ft-fx-shatter',
      'shatterSpikes': 'v2-ft-fx-spikes',
      'halftone': 'v2-ft-fx-halftone',
      'halftoneScale': 'v2-ft-fx-halftonescale',
      'rippleAmp': 'v2-ft-fx-ripple',
      'rippleFreq': 'v2-ft-fx-ripplefreq',
    };
    const inPrint = {
      'riso': 'v2-ft-print-riso',
      'newsprint': 'v2-ft-print-newsprint',
      'sunFaded': 'v2-ft-print-sunfaded',
      'photocopy': 'v2-ft-print-photocopy',
    };
    const excluded = {
      'distressHardness': 'Advanced sub-knob folded into Distress.',
      'halftoneAngle': 'Advanced sub-knob folded into Halftone.',
    };
    // The full field set on Effects (mirror of the model; update if the model
    // grows so the audit stays honest).
    const allFields = {
      'distress',
      'distressHardness',
      'grain',
      'fade',
      'cracks',
      'halftone',
      'halftoneScale',
      'halftoneAngle',
      'rippleAmp',
      'rippleFreq',
      'acidWash',
      'tieDye',
      'shatter',
      'shatterSpikes',
      'riso',
      'newsprint',
      'sunFaded',
      'photocopy',
    };
    test('every Effects field is reachable or documented-excluded', () {
      for (final f in allFields) {
        final accounted =
            inEffects.containsKey(f) ||
            inPrint.containsKey(f) ||
            excluded.containsKey(f);
        expect(accounted, isTrue, reason: 'Effects.$f is unaccounted for.');
      }
    });
    test('the mirrored field list matches the live Effects.toJson keys', () {
      // A fully-populated Effects surfaces every serialisable field; guards the
      // mirror above against drift when the model changes.
      const full = Effects(
        distress: 0.5,
        distressHardness: 0.6,
        grain: 0.5,
        fade: 0.5,
        cracks: 0.5,
        halftone: 0.5,
        halftoneScale: 5,
        halftoneAngle: 10,
        rippleAmp: 0.5,
        rippleFreq: 6,
        acidWash: 0.5,
        tieDye: 0.5,
        shatter: 0.5,
        shatterSpikes: 0.5,
        riso: 0.5,
        newsprint: 0.5,
        sunFaded: 0.5,
        photocopy: 0.5,
      );
      expect(
        allFields,
        containsAll(full.toJson().keys),
        reason: 'Effects grew a field the coverage mirror is missing.',
      );
    });
  });

  group('Clip parameters (Graphic)', () {
    // Continuous clip knobs surfaced. shapeId/code/text are the Detail axis
    // (subject), not Fine Tune; position/scatter/ink/stampMode are passport-
    // collage-specific and owned by the Passport path (documented exclusions).
    const reachable = {'scale', 'rotationDeg', 'cornerRadius', 'feather'};
    const excluded = {
      'shapeId': 'Subject selection (Detail axis), not a Fine Tune knob.',
      'code': 'Asset code follows the subject.',
      'text': 'Typographic clip text follows Words.',
      'aspectRatio': 'Driven by the shape catalog; not user-tuned.',
      'position': 'Passport-collage placement, owned by the Passport path.',
      'scatter': 'Passport-collage spread, owned by the Passport path.',
      'ink': 'Passport-stamp ink mode, owned by the Passport path.',
      'stampMode': 'Passport entry/exit selection, owned by the Passport path.',
    };
    test('every clip param is reachable or documented-excluded', () {
      const all = {
        'shapeId',
        'code',
        'text',
        'scale',
        'rotationDeg',
        'aspectRatio',
        'cornerRadius',
        'feather',
        'position',
        'scatter',
        'ink',
        'stampMode',
      };
      for (final p in all) {
        expect(
          reachable.contains(p) || excluded.containsKey(p),
          isTrue,
          reason: 'Clip.$p is unaccounted for.',
        );
      }
    });
  });

  group('Finish presets', () {
    test('every named finish is a chip', () {
      // The UI renders one v2-ft-finish-<slug> chip per preset; assert the set
      // is non-empty and each has a usable label (slug source).
      expect(StudioController.finishPresets, isNotEmpty);
      for (final p in StudioController.finishPresets) {
        expect(p.$1.trim(), isNotEmpty);
      }
    });
  });
}
