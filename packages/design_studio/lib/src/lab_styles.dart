import 'package:design_forge/design_forge.dart';

/// Named **style presets** for the Lab. A style is an aesthetic direction —
/// Beachwear, Grunge, Streetwear … — that flavours a whole batch coherently,
/// rather than the per-tile randomness of a raw showcase. Each [LabStyle]
/// resolves to a [StyleSpec] describing:
///   • a **rotation** of [ClipArchetype]s (the clip/subject of each tile,
///     front-loaded so the style's signature looks appear first), and
///   • a **finish** builder (edge treatment + effects + palette) applied on top.
///
/// The generator picks the archetype (→ a [Clip]) then layers the finish, so a
/// "grunge silhouette" or a "beachwear sunset" reads as one intentional look.
///
/// Adding a style = one enum value + one [StyleSpec] entry. No renderer changes.

/// The clip/subject of a tile. Maps to a shape-catalog id (or no clip).
enum ClipArchetype {
  basicFlag, // no clip — the plain flag
  animalSilhouette,
  plantSilhouette,
  landmarkSilhouette,
  countryOutline,
  continentOutline,
  circle,
  oval,
  arch,
  roundedRect,
  diamond,
  triangle,
  hexagon,
  shield,
  heart,
  star,
  lightning,
  mountain,
  island,
  sunset,
  wave,
  mapPin,
  ticket,
  luggageTag,
  postageStamp,
  passportStamp,
  entryStamp,
  passportStampReal, // the country's real entry/exit stamp (resolver mask)
  passportPage, // both entry + exit stamps overlaid at angles
  compass,
  badge, // circular/emblem composition (circle / stamp / shield)
  text, // typography hero — flag fills the letters
}

/// The finish layered over a tile's subject: edges, effects, colour grade.
class Finish {
  const Finish({this.edge, this.fx, this.palette});
  final EdgeTreatment? edge;
  final Effects? fx;
  final Palette? palette;
}

/// One style's data: subject rotation, orientation bias, clip-size range and a
/// finish builder. Pure data + a deterministic function — no I/O.
class StyleSpec {
  const StyleSpec({
    required this.rotation,
    required this.orientationWeights,
    required this.clipScale,
    required this.finish,
    this.tornOnClip = false,
  });

  /// Front-loaded subjects. The generator round-robins through the *available*
  /// entries (silhouettes/outlines drop out for multi-country designs).
  final List<ClipArchetype> rotation;

  /// Weights for `[square, portrait, landscape]`.
  final List<double> orientationWeights;

  /// Min/max clip scale (negative space vs. oversized graphics).
  final (double, double) clipScale;

  /// Builds the finish for one tile. [hasClip] lets a style avoid tearing a
  /// clipped shape (unless [tornOnClip]).
  final Finish Function(DeterministicRng r, bool hasClip) finish;

  /// When true the style may apply a torn edge even to clipped shapes
  /// (grunge grit on silhouettes etc.); the engine supports torn-on-clip.
  final bool tornOnClip;
}

/// Selectable Lab styles. [showcase] is the broad "everything" default.
enum LabStyle {
  showcase('Showcase'),
  extreme('Extreme'),
  maximal('Maximal'),
  beachwear('Beachwear'),
  surf('Surf'),
  grunge('Grunge'),
  minimalist('Minimalist'),
  streetwear('Streetwear'),
  vintage('Vintage'),
  retro('Retro'),
  outdoor('Outdoor'),
  premium('Premium'),
  typography('Typography');

  const LabStyle(this.label);
  final String label;

  StyleSpec get spec => _specs[this]!;
}

/// Recover the [LabStyle] a recipe was generated in from its provenance
/// `generator` string (the generator stamps `lab:<style>`). Returns null for
/// non-Lab or unknown generators so callers can pick their own default.
LabStyle? labStyleFromProvenance(String? generator) {
  if (generator == null || !generator.startsWith('lab:')) return null;
  final name = generator.substring(4);
  for (final s in LabStyle.values) {
    if (s.name == name) return s;
  }
  return null;
}

// ── finish helpers ─────────────────────────────────────────────────────────

EdgeTreatment _torn(DeterministicRng r,
        {double min = 0.4, double max = 0.85, double asym = 0.6}) =>
    EdgeTreatment(
      style: r.pick(TearStyle.values),
      edgeDamage: r.nextRange(min, max),
      maxDepth: r.nextRange(0.12, 0.3),
      frayAmount: r.nextRange(0.3, 0.95),
      cornerDamage: r.nextRange(0.1, 0.6),
      asymmetry: r.nextRange(asym, 0.95),
    );

Effects? _fx(Effects e) => e.isIdentity ? null : e;

// ── the presets ────────────────────────────────────────────────────────────

final Map<LabStyle, StyleSpec> _specs = {
  // Broad "show me everything" — mixes clean flags, torn, vintage, halftone,
  // tie-dye and clips. Keeps the favoured subjects (basic/silhouette/outline)
  // up front, per the batch-variety brief.
  LabStyle.showcase: StyleSpec(
    rotation: const [
      ClipArchetype.basicFlag,
      ClipArchetype.animalSilhouette,
      ClipArchetype.countryOutline,
      ClipArchetype.basicFlag,
      ClipArchetype.plantSilhouette,
      ClipArchetype.circle,
      ClipArchetype.landmarkSilhouette,
      ClipArchetype.heart,
      ClipArchetype.animalSilhouette,
      ClipArchetype.countryOutline,
      ClipArchetype.hexagon,
      ClipArchetype.shield,
      ClipArchetype.basicFlag,
      ClipArchetype.star,
      ClipArchetype.passportStampReal,
      ClipArchetype.postageStamp,
      ClipArchetype.plantSilhouette,
      ClipArchetype.mountain,
      ClipArchetype.passportPage,
      ClipArchetype.continentOutline,
      ClipArchetype.landmarkSilhouette,
      ClipArchetype.text,
      ClipArchetype.mapPin,
      ClipArchetype.passportStamp,
      ClipArchetype.entryStamp,
      ClipArchetype.passportStampReal,
      ClipArchetype.sunset,
      ClipArchetype.diamond,
    ],
    orientationWeights: const [0.7, 0.18, 0.12],
    clipScale: (0.82, 1.0),
    finish: (r, hasClip) {
      final roll = r.nextDouble();
      if (roll < 0.28) {
        return Finish(
            fx: r.chance(0.4) ? _fx(Effects(grain: r.nextRange(0.08, 0.2))) : null);
      }
      if (roll < 0.5 && !hasClip) return Finish(edge: _torn(r));
      if (roll < 0.64) {
        return Finish(
            palette: Palette(
                strategy: ColourStrategy.flagDerived,
                vintageGrade: r.nextRange(0.45, 0.85)));
      }
      if (roll < 0.78) {
        return Finish(
            fx: Effects(
                halftone: r.nextRange(0.6, 1.0), halftoneScale: r.nextRange(3, 7)));
      }
      if (roll < 0.88) return Finish(fx: Effects(tieDye: r.nextRange(0.7, 1.0)));
      return Finish(
          fx: Effects(
              distress: r.nextRange(0.2, 0.45), grain: r.nextRange(0.15, 0.35)));
    },
  ),

  // Abstract "shattered/exploded flag" — the flag blown into radial zigzag
  // shards (shatter warp) with deep torn silhouettes and heavy grit. Mostly the
  // bare flag as subject so the burst reads; a few bold clips for variety.
  LabStyle.extreme: StyleSpec(
    rotation: const [
      ClipArchetype.basicFlag,
      ClipArchetype.basicFlag,
      ClipArchetype.star,
      ClipArchetype.basicFlag,
      ClipArchetype.animalSilhouette,
      ClipArchetype.basicFlag,
      ClipArchetype.heart,
      ClipArchetype.basicFlag,
      ClipArchetype.countryOutline,
      ClipArchetype.basicFlag,
      ClipArchetype.shield,
      ClipArchetype.basicFlag,
    ],
    orientationWeights: const [0.74, 0.16, 0.1],
    clipScale: (0.9, 1.1),
    tornOnClip: true,
    finish: (r, hasClip) {
      final fx = Effects(
        shatter: r.nextRange(0.65, 0.95),
        shatterSpikes: r.nextRange(0.0, 1.0),
        distress: r.nextRange(0.35, 0.65),
        grain: r.nextRange(0.3, 0.55),
      );
      // Deep, high-frequency tears for a shredded silhouette.
      final edge = r.chance(0.7)
          ? EdgeTreatment(
              style: r.pick(TearStyle.values),
              edgeDamage: r.nextRange(0.7, 0.95),
              maxDepth: r.nextRange(0.2, 0.35),
              frayAmount: r.nextRange(0.7, 0.98),
              cornerDamage: r.nextRange(0.3, 0.7),
              asymmetry: r.nextRange(0.6, 0.95),
            )
          : null;
      final palette = r.chance(0.3)
          ? Palette(
              strategy: ColourStrategy.flagDerived,
              vintageGrade: r.nextRange(0.3, 0.6))
          : null;
      return Finish(edge: edge, fx: _fx(fx), palette: palette);
    },
  ),

  // Everything, loud, on every tile — torn + distress + grain + halftone +
  // colour grade stacked together. Reproduces (and exceeds) the old dense
  // "stack-everything" look; edge-to-edge, high texture, strong contrast.
  LabStyle.maximal: StyleSpec(
    rotation: const [
      ClipArchetype.basicFlag,
      ClipArchetype.star,
      ClipArchetype.animalSilhouette,
      ClipArchetype.diamond,
      ClipArchetype.heart,
      ClipArchetype.countryOutline,
      ClipArchetype.hexagon,
      ClipArchetype.basicFlag,
      ClipArchetype.shield,
      ClipArchetype.mountain,
      ClipArchetype.plantSilhouette,
      ClipArchetype.star,
      ClipArchetype.sunset,
      ClipArchetype.landmarkSilhouette,
      ClipArchetype.postageStamp,
      ClipArchetype.basicFlag,
      ClipArchetype.triangle,
      ClipArchetype.text,
      ClipArchetype.continentOutline,
      ClipArchetype.circle,
    ],
    orientationWeights: const [0.78, 0.14, 0.08],
    clipScale: (0.9, 1.12),
    tornOnClip: true,
    finish: (r, hasClip) {
      // Almost always torn, heavily. Grit on clips too (tornOnClip).
      final edge = r.chance(0.85) ? _torn(r, min: 0.6, max: 0.95, asym: 0.7) : null;
      // Stack multiple textures — never identity.
      final fx = Effects(
        distress: r.nextRange(0.45, 0.75),
        grain: r.nextRange(0.35, 0.6),
        halftone: r.chance(0.55) ? r.nextRange(0.6, 1.0) : 0.0,
        halftoneScale: r.nextRange(3, 7),
        fade: r.chance(0.35) ? r.nextRange(0.1, 0.3) : 0.0,
        tieDye: r.chance(0.2) ? r.nextRange(0.6, 1.0) : 0.0,
        cracks: r.chance(0.4) ? r.nextRange(0.2, 0.5) : 0.0,
      );
      // Always a colour grade too: mono / duotone / heavy vintage.
      final pr = r.nextDouble();
      final palette = pr < 0.3
          ? const Palette(strategy: ColourStrategy.monochrome)
          : pr < 0.5
              ? const Palette(
                  strategy: ColourStrategy.duotone, accents: ['#141414', '#E63946'])
              : Palette(
                  strategy: ColourStrategy.flagDerived,
                  vintageGrade: r.nextRange(0.4, 0.85));
      return Finish(edge: edge, fx: _fx(fx), palette: palette);
    },
  ),

  // Faded colours, waves, sunsets, relaxed spacing, light distress.
  LabStyle.beachwear: StyleSpec(
    rotation: const [
      ClipArchetype.sunset,
      ClipArchetype.wave,
      ClipArchetype.island,
      ClipArchetype.circle,
      ClipArchetype.basicFlag,
      ClipArchetype.sunset,
      ClipArchetype.plantSilhouette,
      ClipArchetype.wave,
      ClipArchetype.oval,
      ClipArchetype.heart,
      ClipArchetype.animalSilhouette,
      ClipArchetype.sunset,
      ClipArchetype.circle,
      ClipArchetype.wave,
      ClipArchetype.island,
      ClipArchetype.countryOutline,
      ClipArchetype.basicFlag,
      ClipArchetype.star,
      ClipArchetype.oval,
      ClipArchetype.sunset,
    ],
    orientationWeights: const [0.4, 0.15, 0.45],
    clipScale: (0.82, 1.0),
    finish: (r, hasClip) {
      final palette = Palette(
          strategy: ColourStrategy.flagDerived, vintageGrade: r.nextRange(0.25, 0.5));
      final Effects fx = r.chance(0.3)
          ? Effects(tieDye: r.nextRange(0.5, 0.8), fade: r.nextRange(0.1, 0.25))
          : Effects(fade: r.nextRange(0.15, 0.35), grain: r.nextRange(0.08, 0.2));
      final edge =
          (!hasClip && r.chance(0.25)) ? _torn(r, min: 0.2, max: 0.45) : null;
      return Finish(edge: edge, fx: _fx(fx), palette: palette);
    },
  ),

  // Bold waves, retro type, sun-faded palettes, circular/badge compositions.
  LabStyle.surf: StyleSpec(
    rotation: const [
      ClipArchetype.wave,
      ClipArchetype.badge,
      ClipArchetype.circle,
      ClipArchetype.sunset,
      ClipArchetype.wave,
      ClipArchetype.badge,
      ClipArchetype.oval,
      ClipArchetype.wave,
      ClipArchetype.circle,
      ClipArchetype.sunset,
      ClipArchetype.badge,
      ClipArchetype.wave,
      ClipArchetype.star,
      ClipArchetype.circle,
      ClipArchetype.wave,
      ClipArchetype.badge,
      ClipArchetype.island,
      ClipArchetype.sunset,
    ],
    orientationWeights: const [0.55, 0.15, 0.3],
    clipScale: (0.85, 1.05),
    finish: (r, hasClip) {
      final palette = Palette(
          strategy: ColourStrategy.flagDerived, vintageGrade: r.nextRange(0.35, 0.6));
      final Effects fx = r.chance(0.4)
          ? Effects(
              halftone: r.nextRange(0.5, 0.85),
              halftoneScale: r.nextRange(4, 8),
              fade: r.nextRange(0.1, 0.25))
          : Effects(fade: r.nextRange(0.15, 0.3), grain: r.nextRange(0.1, 0.25));
      return Finish(fx: _fx(fx), palette: palette);
    },
  ),

  // Torn edges, scratches, heavy distress, asymmetry. Grit even on clips.
  LabStyle.grunge: StyleSpec(
    rotation: const [
      ClipArchetype.basicFlag,
      ClipArchetype.shield,
      ClipArchetype.basicFlag,
      ClipArchetype.star,
      ClipArchetype.hexagon,
      ClipArchetype.basicFlag,
      ClipArchetype.diamond,
      ClipArchetype.animalSilhouette,
      ClipArchetype.star,
      ClipArchetype.shield,
      ClipArchetype.basicFlag,
      ClipArchetype.triangle,
      ClipArchetype.countryOutline,
      ClipArchetype.basicFlag,
      ClipArchetype.hexagon,
      ClipArchetype.star,
    ],
    orientationWeights: const [0.68, 0.22, 0.1],
    clipScale: (0.85, 1.08),
    tornOnClip: true,
    finish: (r, hasClip) {
      final mono = r.chance(0.5);
      final palette = Palette(
          strategy: mono ? ColourStrategy.monochrome : ColourStrategy.flagDerived,
          vintageGrade: r.nextRange(0.3, 0.6));
      final fx = Effects(
        distress: r.nextRange(0.45, 0.75),
        grain: r.nextRange(0.3, 0.6),
        cracks: r.chance(0.6) ? r.nextRange(0.25, 0.6) : 0.0,
        halftone: r.chance(0.35) ? r.nextRange(0.5, 0.9) : 0.0,
        halftoneScale: r.nextRange(3, 6),
      );
      final edge = r.chance(0.8) ? _torn(r, min: 0.6, max: 0.95, asym: 0.6) : null;
      return Finish(edge: edge, fx: _fx(fx), palette: palette);
    },
  ),

  // Few elements, lots of negative space, clean. Small clips, no effects.
  LabStyle.minimalist: StyleSpec(
    rotation: const [
      ClipArchetype.circle,
      ClipArchetype.hexagon,
      ClipArchetype.arch,
      ClipArchetype.roundedRect,
      ClipArchetype.oval,
      ClipArchetype.circle,
      ClipArchetype.diamond,
      ClipArchetype.triangle,
      ClipArchetype.basicFlag,
      ClipArchetype.circle,
      ClipArchetype.arch,
      ClipArchetype.hexagon,
      ClipArchetype.oval,
      ClipArchetype.countryOutline,
      ClipArchetype.circle,
      ClipArchetype.roundedRect,
    ],
    orientationWeights: const [0.62, 0.3, 0.08],
    clipScale: (0.5, 0.72),
    finish: (r, hasClip) =>
        Finish(palette: r.chance(0.3) ? Palette(strategy: ColourStrategy.monochrome) : null),
  ),

  // Oversized graphics, bold type, asymmetry, strong contrast.
  LabStyle.streetwear: StyleSpec(
    rotation: const [
      ClipArchetype.star,
      ClipArchetype.text,
      ClipArchetype.shield,
      ClipArchetype.lightning,
      ClipArchetype.hexagon,
      ClipArchetype.star,
      ClipArchetype.text,
      ClipArchetype.diamond,
      ClipArchetype.basicFlag,
      ClipArchetype.star,
      ClipArchetype.shield,
      ClipArchetype.text,
      ClipArchetype.lightning,
      ClipArchetype.star,
      ClipArchetype.hexagon,
      ClipArchetype.postageStamp,
    ],
    orientationWeights: const [0.6, 0.3, 0.1],
    clipScale: (0.95, 1.18),
    finish: (r, hasClip) {
      Palette? palette;
      final pr = r.nextDouble();
      if (pr < 0.45) {
        palette = const Palette(
            strategy: ColourStrategy.duotone, accents: ['#141414', '#E63946']);
      } else if (pr < 0.65) {
        palette = const Palette(strategy: ColourStrategy.monochrome);
      }
      final roll = r.nextDouble();
      final Effects? fx = roll < 0.55
          ? Effects(halftone: r.nextRange(0.6, 1.0), halftoneScale: r.nextRange(3, 6))
          : roll < 0.75
              ? Effects(distress: r.nextRange(0.2, 0.45), grain: r.nextRange(0.15, 0.35))
              : null;
      final edge =
          (!hasClip && r.chance(0.3)) ? _torn(r, min: 0.5, max: 0.85, asym: 0.7) : null;
      return Finish(edge: edge, fx: fx == null ? null : _fx(fx), palette: palette);
    },
  ),

  // Muted palette, grain, screen-print wear, heritage type.
  LabStyle.vintage: StyleSpec(
    rotation: const [
      ClipArchetype.postageStamp,
      ClipArchetype.passportStampReal,
      ClipArchetype.passportPage,
      ClipArchetype.circle,
      ClipArchetype.entryStamp,
      ClipArchetype.arch,
      ClipArchetype.passportStamp,
      ClipArchetype.oval,
      ClipArchetype.passportStampReal,
      ClipArchetype.star,
      ClipArchetype.countryOutline,
      ClipArchetype.ticket,
      ClipArchetype.basicFlag,
      ClipArchetype.circle,
      ClipArchetype.arch,
      ClipArchetype.postageStamp,
      ClipArchetype.continentOutline,
      ClipArchetype.oval,
      ClipArchetype.basicFlag,
    ],
    orientationWeights: const [0.7, 0.2, 0.1],
    clipScale: (0.8, 0.98),
    finish: (r, hasClip) {
      final palette = Palette(
          strategy: ColourStrategy.flagDerived, vintageGrade: r.nextRange(0.5, 0.85));
      final fx = Effects(
        grain: r.nextRange(0.2, 0.45),
        fade: r.nextRange(0.15, 0.4),
        distress: r.chance(0.5) ? r.nextRange(0.15, 0.4) : 0.0,
        halftone: r.chance(0.3) ? r.nextRange(0.4, 0.7) : 0.0,
        halftoneScale: r.nextRange(4, 7),
      );
      final edge =
          (!hasClip && r.chance(0.25)) ? _torn(r, min: 0.2, max: 0.5) : null;
      return Finish(edge: edge, fx: _fx(fx), palette: palette);
    },
  ),

  // 60s–90s palettes, arches, sunsets, halftones.
  LabStyle.retro: StyleSpec(
    rotation: const [
      ClipArchetype.arch,
      ClipArchetype.sunset,
      ClipArchetype.circle,
      ClipArchetype.oval,
      ClipArchetype.arch,
      ClipArchetype.sunset,
      ClipArchetype.star,
      ClipArchetype.circle,
      ClipArchetype.arch,
      ClipArchetype.sunset,
      ClipArchetype.oval,
      ClipArchetype.wave,
      ClipArchetype.arch,
      ClipArchetype.circle,
      ClipArchetype.sunset,
      ClipArchetype.badge,
    ],
    orientationWeights: const [0.6, 0.22, 0.18],
    clipScale: (0.82, 1.0),
    finish: (r, hasClip) {
      final palette = Palette(
        strategy: r.chance(0.35) ? ColourStrategy.duotone : ColourStrategy.flagDerived,
        accents: const ['#3A2E6E', '#F2A65A'],
        vintageGrade: r.nextRange(0.3, 0.55),
      );
      final fx = Effects(
        halftone: r.nextRange(0.55, 0.95),
        halftoneScale: r.nextRange(4, 8),
        fade: r.chance(0.4) ? r.nextRange(0.1, 0.25) : 0.0,
      );
      return Finish(fx: _fx(fx), palette: palette);
    },
  ),

  // Mountains, badges, earth tones, exploration motifs.
  LabStyle.outdoor: StyleSpec(
    rotation: const [
      ClipArchetype.mountain,
      ClipArchetype.badge,
      ClipArchetype.mountain,
      ClipArchetype.compass,
      ClipArchetype.shield,
      ClipArchetype.mountain,
      ClipArchetype.island,
      ClipArchetype.badge,
      ClipArchetype.mountain,
      ClipArchetype.hexagon,
      ClipArchetype.animalSilhouette,
      ClipArchetype.mountain,
      ClipArchetype.star,
      ClipArchetype.badge,
      ClipArchetype.mountain,
      ClipArchetype.countryOutline,
      ClipArchetype.compass,
      ClipArchetype.mountain,
    ],
    orientationWeights: const [0.5, 0.2, 0.3],
    clipScale: (0.85, 1.05),
    finish: (r, hasClip) {
      final palette = Palette(
          strategy: ColourStrategy.flagDerived, vintageGrade: r.nextRange(0.3, 0.55));
      final fx = Effects(
        grain: r.nextRange(0.12, 0.3),
        fade: r.chance(0.4) ? r.nextRange(0.1, 0.25) : 0.0,
        distress: r.chance(0.3) ? r.nextRange(0.15, 0.35) : 0.0,
      );
      return Finish(fx: _fx(fx), palette: palette);
    },
  ),

  // Restrained effects, strong hierarchy, simple composition.
  LabStyle.premium: StyleSpec(
    rotation: const [
      ClipArchetype.circle,
      ClipArchetype.basicFlag,
      ClipArchetype.arch,
      ClipArchetype.shield,
      ClipArchetype.oval,
      ClipArchetype.countryOutline,
      ClipArchetype.circle,
      ClipArchetype.hexagon,
      ClipArchetype.basicFlag,
      ClipArchetype.roundedRect,
      ClipArchetype.circle,
      ClipArchetype.arch,
      ClipArchetype.shield,
      ClipArchetype.basicFlag,
      ClipArchetype.oval,
      ClipArchetype.circle,
    ],
    orientationWeights: const [0.65, 0.25, 0.1],
    clipScale: (0.7, 0.9),
    finish: (r, hasClip) {
      final Palette? palette = r.chance(0.35)
          ? const Palette(strategy: ColourStrategy.monochrome)
          : (r.chance(0.4)
              ? Palette(
                  strategy: ColourStrategy.flagDerived,
                  vintageGrade: r.nextRange(0.15, 0.35))
              : null);
      final fx = r.chance(0.3) ? _fx(Effects(grain: r.nextRange(0.06, 0.15))) : null;
      return Finish(fx: fx, palette: palette);
    },
  ),

  // Text as the hero; the flag fills the letters.
  LabStyle.typography: StyleSpec(
    rotation: const [
      ClipArchetype.text,
      ClipArchetype.text,
      ClipArchetype.basicFlag,
      ClipArchetype.text,
      ClipArchetype.text,
      ClipArchetype.star,
      ClipArchetype.text,
      ClipArchetype.text,
      ClipArchetype.circle,
      ClipArchetype.text,
      ClipArchetype.text,
      ClipArchetype.basicFlag,
      ClipArchetype.text,
      ClipArchetype.text,
      ClipArchetype.shield,
      ClipArchetype.text,
    ],
    orientationWeights: const [0.55, 0.3, 0.15],
    clipScale: (0.95, 1.15),
    finish: (r, hasClip) {
      final Palette? palette =
          r.chance(0.3) ? const Palette(strategy: ColourStrategy.monochrome) : null;
      final Effects? fx = r.chance(0.35)
          ? Effects(halftone: r.nextRange(0.4, 0.8), halftoneScale: r.nextRange(4, 7))
          : (r.chance(0.3) ? _fx(Effects(grain: r.nextRange(0.1, 0.25))) : null);
      final edge = (!hasClip && r.chance(0.15)) ? _torn(r) : null;
      return Finish(edge: edge, fx: fx, palette: palette);
    },
  ),
};

/// Top-level **genre** — the subject the design is *about*. Genres own the
/// subject; [LabStyle] and effects are cross-cutting *finishes*. A genre is
/// either a set of clip subjects (rendered by the Showcase generator with the
/// chosen style's finish) or a group of data-driven families.
enum LabGenre {
  flags('Flags'),
  passport('Passport'),
  animalsNature('Animals & Nature'),
  landmarks('Landmarks'),
  maps('Maps'),
  travelLog('Travel Log'),
  typography('Typography'),
  milestones('Milestones');

  const LabGenre(this.label);
  final String label;

  /// Data-driven genres pick a [DesignFamily] rather than a clip subject.
  bool get isData => this == travelLog || this == milestones;

  /// The [DesignFamily]s a data genre offers (Travel Log / Milestones).
  List<DesignFamily> get families {
    switch (this) {
      case travelLog:
        return const [
          DesignFamily.timeline,
          DesignFamily.journeys,
          DesignFamily.wordCloud,
        ];
      case milestones:
        return const [
          DesignFamily.badge,
          DesignFamily.frontRibbon,
          DesignFamily.achievements,
          DesignFamily.stats,
        ];
      default:
        return const [];
    }
  }

  /// The subject to fall back to when NONE of the genre's own subjects are
  /// available for the current selection. A genre must never silently degrade
  /// into another genre's subject: [passport] stays a passport page (the
  /// renderer draws built-in stamp geometry when no stamp artwork is bundled),
  /// everything else falls back to the plain flag.
  List<ClipArchetype> get fallbackRotation => this == passport
      ? const [ClipArchetype.passportPage]
      : const [ClipArchetype.basicFlag];

  /// The clip subjects a (non-data) genre draws from. Empty for [flags], which
  /// reuses the style's rotation minus the other genres' subjects.
  List<ClipArchetype> get rotation {
    switch (this) {
      case passport:
        return const [ClipArchetype.passportPage, ClipArchetype.passportStampReal];
      case animalsNature:
        return const [
          ClipArchetype.animalSilhouette,
          ClipArchetype.plantSilhouette,
        ];
      case landmarks:
        return const [ClipArchetype.landmarkSilhouette];
      case maps:
        return const [
          ClipArchetype.countryOutline,
          ClipArchetype.continentOutline,
        ];
      case typography:
        return const [ClipArchetype.text];
      default:
        return const [];
    }
  }
}

/// Subjects that belong to OTHER genres — excluded from the [LabGenre.flags]
/// genre so it stays flag/shape-only even under a broad style.
const Set<ClipArchetype> kNonFlagArchetypes = {
  ClipArchetype.animalSilhouette,
  ClipArchetype.plantSilhouette,
  ClipArchetype.landmarkSilhouette,
  ClipArchetype.countryOutline,
  ClipArchetype.continentOutline,
  ClipArchetype.text,
  ClipArchetype.passportStampReal,
  ClipArchetype.passportPage,
};
