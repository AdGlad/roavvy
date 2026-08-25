/// The independent creative **axes** of a [DesignRecipe] — the levers the Studio
/// Canvas lets a user lock, branch and re-roll one at a time.
///
/// Each axis "owns" a disjoint set of the recipe's generative draws so that
/// re-rolling one axis perturbs only that axis's fields and leaves every other
/// axis byte-identical (see `LabShowcaseGenerator.reroll`). Per-axis seeds are
/// carried on the recipe (`DesignRecipe.axisSeeds`); an absent seed falls back
/// to the master [DesignRecipe.seed], so an untouched recipe reproduces its
/// original output exactly.
///
/// Append-only: new axes may be added at the end; [name] is the stable key used
/// in `axisSeeds` and MUST NOT change for existing values.
enum DesignAxis {
  /// **Subject** — what the artwork depicts. Owns the design *family* and the
  /// [Clip] (the silhouette / outline / stamp / procedural shape and its
  /// geometry). Re-rolling this changes the subject the flag(s) fill.
  direction,

  /// **Vibe / finish** — the surface treatment. Owns [EdgeTreatment] (torn
  /// edges), [Effects] (distress / grain / halftone / …) and [Palette] grading
  /// (the finish's colour choices). Re-rolling this restyles without changing
  /// the subject or layout.
  vibe,

  /// **Composition** — how the frame is organised. Owns [Composition]
  /// orientation, density, layout mode and the fill algorithm, plus the
  /// [FlagCombination] (how multiple flags merge).
  focus,

  /// **Colour / garment** — the palette strategy and garment colour. Overlaps
  /// with [vibe] on [Palette]; reserved as a first-class axis so colour can be
  /// re-rolled independently of the rest of the finish as the generator grows a
  /// dedicated colour draw.
  colour,

  /// **Words** — typographic treatment and any text subject. Owns [Typography]
  /// and the text of a typographic [Clip].
  words;

  /// Stable key used in [DesignRecipe.axisSeeds]. Equal to [name] today; kept as
  /// a named getter so the storage key is explicit and future-proof.
  String get key => name;

  static DesignAxis? fromKey(String? key) {
    for (final a in DesignAxis.values) {
      if (a.name == key) return a;
    }
    return null;
  }
}
