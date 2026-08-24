import 'dart:convert';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
// Flutter also exports an `Orientation` (portrait/landscape) from MediaQuery;
// hide it so `Orientation` here means the engine's square/portrait/landscape.
import 'package:flutter/material.dart' hide Orientation;

import 'lab_generator.dart';
import 'lab_styles.dart';
import 'render_service.dart';

/// How the flags are laid out: one hero, a two-flag blend, a uniform grid of
/// instances, or a mixed-size mosaic.
enum LabPattern { single, blend, multi }

/// A mutable draft of a [DesignRecipe] for live editing. Groups are toggled on
/// with the `*On` flags; [toRecipe] only includes enabled, non-identity groups.
class RecipeDraft {
  RecipeDraft(DesignRecipe r)
      : seed = r.seed,
        family = r.composition.family,
        entries = r.content.entries,
        meta = r.content.meta,
        baseFlags = _distinct(r.content.flags),
        perCountry = (r.content.flags.length / _distinct(r.content.flags).length)
            .round()
            .clamp(1, 24),
        pattern = _patternOf(r),
        algorithm = r.composition.fillAlgorithm ?? FillAlgorithm.grid,
        source = r.content.source,
        orientation = r.composition.orientation,
        // combination
        comboMode = r.flagCombination?.mode ?? FlagCombineMode.diagonalSplit,
        weightA = r.flagCombination?.weightA ?? 0.5,
        // clip
        clipOn = r.clip != null && r.clip!.shapeId != 'none',
        clipShapeId = (r.clip == null || r.clip!.shapeId == 'none')
            ? 'heart'
            : r.clip!.shapeId,
        clipCode = r.clip?.code,
        clipText = r.clip?.text,
        clipScale = r.clip?.scale ?? 1.0,
        clipRotation = r.clip?.rotationDeg ?? 0.0,
        clipCornerRadius = r.clip?.cornerRadius ?? 0.0,
        feather = r.clip?.feather ?? 0.0,
        clipScatter = r.clip?.scatter ?? 0.5,
        clipInk = r.clip?.ink ?? 'flag',
        // edge treatment
        edgeOn = r.edgeTreatment != null,
        tearStyle = r.edgeTreatment?.style ?? TearStyle.ragged,
        edgeDamage = r.edgeTreatment?.edgeDamage ?? 0.6,
        maxDepth = r.edgeTreatment?.maxDepth ?? 0.2,
        frayAmount = r.edgeTreatment?.frayAmount ?? 0.5,
        cornerDamage = r.edgeTreatment?.cornerDamage ?? 0.3,
        asymmetry = r.edgeTreatment?.asymmetry ?? 0.6,
        // effects
        fxOn = r.effects != null,
        distress = r.effects?.distress ?? 0.0,
        grain = r.effects?.grain ?? 0.0,
        fade = r.effects?.fade ?? 0.0,
        halftone = r.effects?.halftone ?? 0.0,
        halftoneScale = r.effects?.halftoneScale ?? 6.0,
        rippleAmp = r.effects?.rippleAmp ?? 0.0,
        rippleFreq = r.effects?.rippleFreq ?? 8.0,
        tieDye = r.effects?.tieDye ?? 0.0,
        shatter = r.effects?.shatter ?? 0.0,
        shatterSpikes = r.effects?.shatterSpikes ?? 0.0,
        // palette
        paletteOn = r.palette != null,
        strategy = r.palette?.strategy ?? ColourStrategy.flagDerived,
        vintageGrade = r.palette?.vintageGrade ?? 0.0,
        garment = r.palette?.garmentColour;

  int seed;

  /// Preserved so data-driven designs (timeline/journeys/wordCloud) reproduce
  /// exactly when inspected/edited, instead of collapsing to a plain flag.
  final DesignFamily family;
  final List<RecipeEntry> entries;
  final Map<String, Object?> meta;

  static const _dataFamilies = {
    DesignFamily.timeline,
    DesignFamily.journeys,
    DesignFamily.wordCloud,
    DesignFamily.badge,
    DesignFamily.frontRibbon,
    DesignFamily.achievements,
    DesignFamily.stats,
  };
  bool get isDataFamily => _dataFamilies.contains(family) && entries.isNotEmpty;

  /// The distinct flags in play; a multi grid repeats each [perCountry] times.
  List<FlagRef> baseFlags;
  int perCountry;
  LabPattern pattern;
  FillAlgorithm algorithm;
  String? source;
  Orientation orientation;

  static List<FlagRef> _distinct(List<FlagRef> flags) {
    final seen = <String>{};
    final out = <FlagRef>[];
    for (final f in flags) {
      if (seen.add(f.code)) out.add(FlagRef(f.code));
    }
    return out.isEmpty ? [const FlagRef('us')] : out;
  }

  static LabPattern _patternOf(DesignRecipe r) {
    final f = r.composition.family;
    if (f == DesignFamily.grid) return LabPattern.multi;
    if (f == DesignFamily.duoBlend || r.flagCombination != null) {
      return LabPattern.blend;
    }
    return LabPattern.single;
  }

  /// The concrete flag list to render for the current pattern + tile count.
  List<FlagRef> effectiveFlags() {
    if (baseFlags.isEmpty) return [const FlagRef('us')];
    switch (pattern) {
      case LabPattern.single:
        return [baseFlags.first];
      case LabPattern.blend:
        return baseFlags.length >= 2 ? baseFlags.take(2).toList() : [baseFlags.first];
      case LabPattern.multi:
        final copies = perCountry.clamp(1, 24);
        // `copies` of each country, e.g. 2 → [us, gb, us, gb] (2 from each).
        return [for (var c = 0; c < copies; c++) ...baseFlags];
    }
  }

  FlagCombineMode comboMode;
  double weightA;

  bool clipOn;
  String clipShapeId;
  String? clipCode;
  String? clipText;
  double clipScale;
  double clipRotation;
  double clipCornerRadius;
  double feather;
  double clipScatter;
  String clipInk;

  bool edgeOn;
  TearStyle tearStyle;
  double edgeDamage, maxDepth, frayAmount, cornerDamage, asymmetry;

  bool fxOn;
  double distress, grain, fade, halftone, halftoneScale, rippleAmp, rippleFreq;
  double tieDye;
  double shatter, shatterSpikes;

  bool paletteOn;
  ColourStrategy strategy;
  double vintageGrade;
  String? garment;

  DesignRecipe toRecipe() {
    // Data-driven designs (timeline/journeys/wordCloud) are reproduced from the
    // preserved family + entries + orientation/palette, so the editor preview
    // matches the grid instead of collapsing to a single flag. A colour grade
    // (palette) is still editable; other flag/clip controls don't apply.
    if (isDataFamily) {
      return DesignRecipe(
        seed: seed,
        content: RecipeContent(
            flags: baseFlags, source: source, entries: entries, meta: meta),
        composition: Composition(family: this.family, orientation: orientation),
        palette: paletteOn
            ? Palette(strategy: strategy, vintageGrade: vintageGrade)
            : null,
        provenance: const RecipeProvenance(generator: 'labEdit'),
      );
    }
    final fx = Effects(
      distress: distress,
      grain: grain,
      fade: fade,
      halftone: halftone,
      halftoneScale: halftoneScale,
      rippleAmp: rippleAmp,
      rippleFreq: rippleFreq,
      tieDye: tieDye,
      shatter: shatter,
      shatterSpikes: shatterSpikes,
    );
    final flags = effectiveFlags();
    final family = switch (pattern) {
      LabPattern.single => DesignFamily.singleHero,
      LabPattern.blend => DesignFamily.duoBlend,
      LabPattern.multi => DesignFamily.grid,
    };
    return DesignRecipe(
      seed: seed,
      content: RecipeContent(flags: flags, source: source),
      composition: Composition(
        family: family,
        orientation: orientation,
        fillAlgorithm: pattern == LabPattern.multi ? algorithm : null,
      ),
      flagCombination: (pattern == LabPattern.blend && flags.length >= 2)
          ? FlagCombination(mode: comboMode, weightA: weightA)
          : null,
      clip: clipOn
          ? () {
              final meta = clipShapeMetaById(clipShapeId);
              final isAsset = meta?.source == ClipShapeSource.resolver ||
                  meta?.source == ClipShapeSource.svgAsset;
              final isText = meta?.source == ClipShapeSource.text;
              final isPassportPage = meta?.resolverKind == ClipShape.passportPage;
              return Clip(
                shapeId: clipShapeId,
                code: isAsset ? clipCode : null,
                text: isText ? clipText : null,
                scale: clipScale,
                rotationDeg: clipRotation,
                cornerRadius: clipCornerRadius,
                feather: feather,
                scatter: clipScatter,
                ink: isPassportPage ? clipInk : null,
              );
            }()
          : null,
      edgeTreatment: edgeOn
          ? EdgeTreatment(
              style: tearStyle,
              edgeDamage: edgeDamage,
              maxDepth: maxDepth,
              frayAmount: frayAmount,
              cornerDamage: cornerDamage,
              asymmetry: asymmetry,
            )
          : null,
      effects: (fxOn && !fx.isIdentity) ? fx : null,
      palette: paletteOn
          ? Palette(
              strategy: strategy,
              vintageGrade: vintageGrade,
              garmentColour: garment,
            )
          : null,
      provenance: const RecipeProvenance(generator: 'labEdit'),
    );
  }
}

/// The live parameter-editor panel. Every control mutates the [RecipeDraft] and
/// re-renders the preview immediately. [onExportPng] / [onVariations] bubble up.
/// A one-tap **finish** (effects + palette) applied on top of the SAME image —
/// the Configure step's non-destructive swaps (Vintage → Tie-dye, etc.).
class FinishPreset {
  const FinishPreset(this.name, {this.effects, this.palette});
  final String name;
  final Effects? effects;
  final Palette? palette;
}

const List<FinishPreset> kFinishPresets = [
  FinishPreset('None'),
  FinishPreset('Vintage',
      effects: Effects(grain: 0.3, fade: 0.2),
      palette: Palette(strategy: ColourStrategy.flagDerived, vintageGrade: 0.6)),
  FinishPreset('Tie-dye', effects: Effects(tieDye: 0.9)),
  FinishPreset('Halftone', effects: Effects(halftone: 0.9, halftoneScale: 5)),
  FinishPreset('Distress', effects: Effects(distress: 0.55, grain: 0.4)),
  FinishPreset('Shatter',
      effects: Effects(shatter: 0.85, distress: 0.35, grain: 0.3)),
  FinishPreset('Mono', palette: Palette(strategy: ColourStrategy.monochrome)),
  FinishPreset('Retro',
      effects: Effects(halftone: 0.7, halftoneScale: 6),
      palette: Palette(strategy: ColourStrategy.flagDerived, vintageGrade: 0.4)),
];

class RecipeEditorPanel extends StatefulWidget {
  const RecipeEditorPanel({
    super.key,
    required this.recipe,
    required this.service,
    required this.onExportPng,
    required this.onVariations,
    required this.onClose,
    this.silhouettesByShape = const {},
    this.continents = const [],
    this.countryNames = const {},
  });

  final DesignRecipe recipe;
  final RenderService service;
  final void Function(DesignRecipe) onExportPng;
  final void Function(DesignRecipe) onVariations;
  final VoidCallback onClose;

  /// Silhouette slugs available per silhouette [ClipShape] (animal / plant /
  /// landmark), e.g. `{ ClipShape.animalSilhouette: ['af_snow_leopard', …] }`.
  final Map<ClipShape, List<String>> silhouettesByShape;

  /// Continent outline ids available (e.g. 'europe', 'asia').
  final List<String> continents;

  /// Lowercase ISO-2 → display name, for the country-name text option.
  final Map<String, String> countryNames;

  @override
  State<RecipeEditorPanel> createState() => _RecipeEditorPanelState();
}

class _RecipeEditorPanelState extends State<RecipeEditorPanel> {
  late RecipeDraft _draft;
  late LabStyle _style;

  @override
  void initState() {
    super.initState();
    _draft = RecipeDraft(widget.recipe);
    _style = _styleOf(widget.recipe);
  }

  @override
  void didUpdateWidget(covariant RecipeEditorPanel old) {
    super.didUpdateWidget(old);
    // Re-seed the draft when a different design is selected.
    if (old.recipe.recipeId != widget.recipe.recipeId) {
      _draft = RecipeDraft(widget.recipe);
      _style = _styleOf(widget.recipe);
    }
  }

  void _change(VoidCallback mutate) => setState(mutate);

  // ── Configure: non-destructive finish swapping (keeps the same image) ────────

  /// Apply a finish preset to the draft — sets the effect/palette fields and
  /// clears the rest, leaving the SUBJECT (clip/pattern/flags/seed) untouched.
  void _applyFinish(FinishPreset p) {
    _change(() {
      final fx = p.effects;
      _draft.fxOn = fx != null;
      _draft.distress = fx?.distress ?? 0;
      _draft.grain = fx?.grain ?? 0;
      _draft.fade = fx?.fade ?? 0;
      _draft.halftone = fx?.halftone ?? 0;
      _draft.halftoneScale = fx?.halftoneScale ?? 6;
      _draft.rippleAmp = fx?.rippleAmp ?? 0;
      _draft.tieDye = fx?.tieDye ?? 0;
      _draft.shatter = fx?.shatter ?? 0;
      _draft.shatterSpikes = fx?.shatterSpikes ?? 0;
      final pal = p.palette;
      _draft.paletteOn = pal != null;
      _draft.strategy = pal?.strategy ?? ColourStrategy.flagDerived;
      _draft.vintageGrade = pal?.vintageGrade ?? 0;
    });
  }

  /// The current design with [p]'s finish swapped in — for the chip previews.
  DesignRecipe _finishVariant(DesignRecipe base, FinishPreset p) => DesignRecipe(
        seed: base.seed,
        content: base.content,
        composition: base.composition,
        flagCombination: base.flagCombination,
        clip: base.clip,
        edgeTreatment: base.edgeTreatment,
        effects: p.effects,
        palette: p.palette,
        provenance: base.provenance,
      );

  /// Index of the finish preset the draft currently matches, or -1 (custom).
  int _activeFinishIndex() {
    for (var i = 0; i < kFinishPresets.length; i++) {
      final p = kFinishPresets[i];
      final fx = p.effects;
      final effOk = (_draft.fxOn == (fx != null)) &&
          _draft.distress == (fx?.distress ?? 0) &&
          _draft.grain == (fx?.grain ?? 0) &&
          _draft.fade == (fx?.fade ?? 0) &&
          _draft.halftone == (fx?.halftone ?? 0) &&
          _draft.tieDye == (fx?.tieDye ?? 0) &&
          _draft.shatter == (fx?.shatter ?? 0);
      final pal = p.palette;
      final palOk = (_draft.paletteOn == (pal != null)) &&
          (pal == null ||
              (_draft.strategy == pal.strategy &&
                  _draft.vintageGrade == pal.vintageGrade));
      if (effOk && palOk) return i;
    }
    return -1;
  }

  /// Read the style back from provenance (`lab:<style>`), defaulting to showcase.
  static LabStyle _styleOf(DesignRecipe r) =>
      labStyleFromProvenance(r.provenance?.generator) ?? LabStyle.showcase;

  /// Re-derive the design in [style] using the current seed + flags, then load
  /// it into the draft so every control reflects the preset (and stays editable).
  void _applyStyle(LabStyle style) {
    final gen = LabShowcaseGenerator(
      style: style,
      silhouettesByShape: widget.silhouettesByShape,
      continents: widget.continents,
      countryNames: widget.countryNames,
    );
    final codes = _draft.baseFlags.map((f) => f.code).toList();
    final r = gen.generate(
      DesignContext(flagCodes: codes, scopeKey: _draft.source),
      seed: _draft.seed,
      count: 1,
    ).first;
    setState(() {
      _style = style;
      _draft = RecipeDraft(r);
    });
  }

  /// Advance the seed and re-apply the current style, to browse other subjects
  /// (silhouette → outline → shape …) the style rotates through.
  void _rerollStyle() {
    _draft.seed += 1;
    _applyStyle(_style);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _draft.toRecipe();
    return SizedBox(
      width: 380,
      child: Container(
        color: const Color(0xFF16181D),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live preview.
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('EDIT',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Export PNG',
                    icon: const Icon(Icons.download, size: 18),
                    onPressed: () => widget.onExportPng(recipe),
                  ),
                  IconButton(
                    tooltip: 'Variations',
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    onPressed: () => widget.onVariations(recipe),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // Preview + controls all scroll below the pinned header, so the
            // panel never overflows on short windows.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: const Color(0xFFF2F2F2),
                      child: _LivePreview(
                          service: widget.service, recipe: recipe, size: 356),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('seed ${recipe.seed} · ${recipe.recipeId}',
                        style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ),
                  const Divider(height: 12),
                  _finishSection(recipe),
                  _styleRow(),
                  _seedRow(),
                  _patternRow(),
                  // Copies-per-country drives the flag count; hidden only for the
                  // 2-flag Blend (which merges rather than tiles).
                  if (_draft.pattern != LabPattern.blend) _copiesRow(),
                  if (_draft.pattern == LabPattern.multi)
                    _dropdown<FillAlgorithm>(
                      'Algorithm',
                      _draft.algorithm,
                      FillAlgorithm.values,
                      (v) => _change(() => _draft.algorithm = v),
                    ),
                  _orientationRow(),
                  if (_draft.pattern == LabPattern.blend) _combineSection(),
                  _clipSection(),
                  _edgeSection(),
                  _effectsSection(),
                  _paletteSection(),
                  const SizedBox(height: 12),
                  _jsonView(recipe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patternRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 90, child: Text('Pattern')),
          Expanded(
            child: SegmentedButton<LabPattern>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: LabPattern.single, label: Text('Single')),
                ButtonSegment(value: LabPattern.blend, label: Text('Blend')),
                ButtonSegment(value: LabPattern.multi, label: Text('Multi')),
              ],
              selected: {_draft.pattern},
              onSelectionChanged: (s) => _change(() {
                _draft.pattern = s.first;
                // Single/Blend imply 1 copy; Multi needs at least 2 to be a grid.
                if (_draft.pattern != LabPattern.multi) {
                  _draft.perCountry = 1;
                } else if (_draft.perCountry < 2) {
                  _draft.perCountry = _draft.baseFlags.length > 1 ? 2 : 4;
                }
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Copies-per-country slider. Total instances = copies × distinct countries.
  /// Dragging above 1 turns the design into a Multi grid.
  Widget _copiesRow() {
    final countries = _draft.baseFlags.length;
    final total = _draft.perCountry * countries;
    final totalLabel = countries > 1
        ? '${_draft.perCountry}×$countries = $total'
        : '$total';
    return Row(
      children: [
        const SizedBox(
            width: 90,
            child: Text('Copies /\ncountry', style: TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(
            value: _draft.perCountry.clamp(1, 24).toDouble(),
            min: 1,
            max: 24,
            divisions: 23,
            label: '${_draft.perCountry}',
            onChanged: (v) => _change(() {
              _draft.perCountry = v.round();
              // More than one copy ⇒ it's a grid.
              if (_draft.perCountry > 1 && _draft.pattern != LabPattern.multi) {
                _draft.pattern = LabPattern.multi;
              }
              if (_draft.perCountry == 1 &&
                  _draft.pattern == LabPattern.multi &&
                  countries < 3) {
                // Back to a plain design when a single/2-country set drops to 1.
                _draft.pattern =
                    countries == 2 ? LabPattern.blend : LabPattern.single;
              }
            }),
          ),
        ),
        SizedBox(
            width: 66,
            child: Text(totalLabel,
                textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
      ],
    );
  }

  Widget _orientationRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 90, child: Text('Orientation')),
          Expanded(
            child: SegmentedButton<Orientation>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                    value: Orientation.square,
                    icon: Icon(Icons.crop_square, size: 16)),
                ButtonSegment(
                    value: Orientation.portrait,
                    icon: Icon(Icons.crop_portrait, size: 16)),
                ButtonSegment(
                    value: Orientation.landscape,
                    icon: Icon(Icons.crop_landscape, size: 16)),
              ],
              selected: {_draft.orientation},
              onSelectionChanged: (s) =>
                  _change(() => _draft.orientation = s.first),
            ),
          ),
        ],
      ),
    );
  }

  /// Apply a whole style preset as a starting point, then fine-tune below. The
  /// dice advances the seed to browse the style's other subjects.
  /// Configure step: a one-tap strip of finishes rendered on the SAME image.
  /// Tapping swaps the finish non-destructively; the sliders below fine-tune it.
  Widget _finishSection(DesignRecipe recipe) {
    final active = _activeFinishIndex();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text('FINISH',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
        ),
        const Text('Same image, different treatment — tap to try.',
            style: TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kFinishPresets.length,
            separatorBuilder: (_, i) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = kFinishPresets[i];
              final selected = i == active;
              return GestureDetector(
                onTap: () => _applyFinish(p),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        border: Border.all(
                          color: selected ? Colors.tealAccent : const Color(0xFF2A2D33),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: _LivePreview(
                          service: widget.service,
                          recipe: _finishVariant(recipe, p),
                          size: 68),
                    ),
                    const SizedBox(height: 3),
                    Text(p.name,
                        style: TextStyle(
                            fontSize: 10,
                            color: selected ? Colors.tealAccent : Colors.white70)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _styleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(
              width: 90,
              child: Text('Restyle',
                  style: TextStyle(fontSize: 12),
                  // Distinct from Finish: restyle may recompose the image.
                  semanticsLabel: 'Restyle (changes the image)')),
          Expanded(
            child: DropdownButton<LabStyle>(
              isExpanded: true,
              isDense: true,
              value: _style,
              items: [
                for (final s in LabStyle.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) {
                if (v != null) _applyStyle(v);
              },
            ),
          ),
          IconButton(
            tooltip: 'Reroll within style',
            icon: const Icon(Icons.casino, size: 16),
            onPressed: _rerollStyle,
          ),
        ],
      ),
    );
  }

  Widget _seedRow() {
    return Row(
      children: [
        const SizedBox(width: 90, child: Text('Seed')),
        Expanded(
          child: Slider(
            value: (_draft.seed % 100000).toDouble(),
            min: 0,
            max: 100000,
            onChanged: (v) => _change(() => _draft.seed = v.round()),
          ),
        ),
        SizedBox(width: 54, child: Text('${_draft.seed}', textAlign: TextAlign.right)),
        IconButton(
          tooltip: 'Random seed',
          icon: const Icon(Icons.casino, size: 16),
          onPressed: () => _change(
              () => _draft.seed = DateTime.now().microsecondsSinceEpoch % 100000),
        ),
      ],
    );
  }

  Widget _combineSection() {
    if (_draft.baseFlags.length < 2) {
      return const Card(
        color: Color(0xFF1D2026),
        margin: EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Text('Blend needs 2 flags — select another in the left panel.',
              style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
        ),
      );
    }
    return Card(
      color: const Color(0xFF1D2026),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Flag combination',
                style: TextStyle(fontWeight: FontWeight.w600)),
            _dropdown<FlagCombineMode>('Mode', _draft.comboMode,
                FlagCombineMode.values, (v) => _change(() => _draft.comboMode = v)),
            _slider('Weight A', _draft.weightA, 0, 1,
                (v) => _change(() => _draft.weightA = v)),
          ],
        ),
      ),
    );
  }

  /// True when the design is a single country (one distinct flag, any number of
  /// instances/tiles). Silhouette clips only make sense here — each silhouette
  /// belongs to one country, so they're offered only for a single-country design.
  bool get _isSingleCountry => _draft.baseFlags.length == 1;

  List<String> _slugsFor(ClipShape shape) =>
      widget.silhouettesByShape[shape] ?? const [];

  /// Silhouettes of [shape] belonging to one of the design's flag countries.
  List<String> _countrySlugsFor(ClipShape shape) {
    final codes = _draft.baseFlags.map((f) => f.code.toLowerCase()).toSet();
    return [
      for (final s in _slugsFor(shape))
        if (codes.contains(s.split('_').first)) s,
    ];
  }

  /// Selected countries (lowercase cc) that have a real passport stamp — used
  /// by the passport page (one image with every selected country's stamps).
  List<String> _stampCountryCodes() {
    final slugs =
        widget.silhouettesByShape[ClipShape.passportStampOutline] ?? const [];
    return [
      for (final f in _draft.baseFlags)
        if (slugs.any((s) => s.split('_').first == f.code.toLowerCase()))
          f.code.toLowerCase(),
    ];
  }

  /// Whether a catalog shape is usable for the current design.
  bool _shapeAvailable(ClipShapeMeta m) {
    final kind = m.resolverKind;
    if (kind == ClipShape.continentOutline) return widget.continents.isNotEmpty;
    if (kind == ClipShape.animalSilhouette ||
        kind == ClipShape.plantSilhouette ||
        kind == ClipShape.landmarkSilhouette ||
        kind == ClipShape.passportStampOutline) {
      return _isSingleCountry && _countrySlugsFor(kind!).isNotEmpty;
    }
    // The passport page overlays entry + exit stamps for ALL selected countries
    // that have them — works for one OR many countries.
    if (kind == ClipShape.passportPage) {
      return _stampCountryCodes().isNotEmpty;
    }
    if (m.source == ClipShapeSource.svgAsset) return false; // custom SVG: later
    return true;
  }

  List<ClipShapeMeta> _shapesInFamily(ShapeFamily f) =>
      [for (final m in clipShapesByFamily(f)) if (_shapeAvailable(m)) m];

  List<ShapeFamily> get _availableFamilies => [
        for (final f in ShapeFamily.values)
          if (f != ShapeFamily.custom && _shapesInFamily(f).isNotEmpty) f,
      ];

  Widget _clipSection() {
    final meta = clipShapeMetaById(_draft.clipShapeId) ?? kClipShapeCatalog.first;
    final family = meta.family;
    final familyShapes = _shapesInFamily(family);
    return _section(
      'Clip shape',
      _draft.clipOn,
      (v) => _change(() => _draft.clipOn = v),
      children: [
        _dropdown<ShapeFamily>(
          'Family',
          _availableFamilies.contains(family) ? family : _availableFamilies.first,
          _availableFamilies,
          (f) => _change(() {
            final shapes = _shapesInFamily(f);
            if (shapes.isNotEmpty) {
              _draft.clipShapeId = shapes.first.id;
              _draft.clipCode = _defaultCodeForId(shapes.first);
            }
          }),
          labeler: (f) => _familyLabel(f),
        ),
        _dropdown<String>(
          'Shape',
          familyShapes.any((m) => m.id == _draft.clipShapeId)
              ? _draft.clipShapeId
              : (familyShapes.isEmpty ? meta.id : familyShapes.first.id),
          [for (final m in familyShapes) m.id],
          (id) => _change(() {
            _draft.clipShapeId = id;
            _draft.clipCode = _defaultCodeForId(clipShapeMetaById(id)!);
          }),
          labeler: (id) => clipShapeMetaById(id)?.label ?? id,
        ),
        ..._codePickerForMeta(meta),
        if (meta.cornerRadius)
          _slider('Corner', _draft.clipCornerRadius, 0, 1,
              (v) => _change(() => _draft.clipCornerRadius = v)),
        if (meta.resolverKind == ClipShape.passportPage) ...[
          // Passport collage controls: stamp size, spread, and ink mode.
          _slider('Stamp size', _draft.clipScale, 0.4, 1.4,
              (v) => _change(() => _draft.clipScale = v)),
          _slider('Scatter', _draft.clipScatter, 0, 1,
              (v) => _change(() => _draft.clipScatter = v)),
          _dropdown<String>(
            'Ink',
            _draft.clipInk,
            const ['flag', 'black', 'white'],
            (v) => _change(() => _draft.clipInk = v),
            labeler: (v) => {
              'flag': 'Flag-filled',
              'black': 'Black on transparent',
              'white': 'White on transparent',
            }[v]!,
          ),
        ] else ...[
          _slider('Scale', _draft.clipScale, 0.25, 1.2,
              (v) => _change(() => _draft.clipScale = v)),
          _slider('Rotation', _draft.clipRotation, -45, 45,
              (v) => _change(() => _draft.clipRotation = v)),
          _slider('Feather', _draft.feather, 0, 1,
              (v) => _change(() => _draft.feather = v)),
        ],
      ],
    );
  }

  String _familyLabel(ShapeFamily f) =>
      f.name[0].toUpperCase() + f.name.substring(1);

  String? _defaultCodeForId(ClipShapeMeta m) {
    final kind = m.resolverKind;
    if (kind == ClipShape.countryOutline) return _draft.baseFlags.first.code;
    // passportPage: one `cc|entry|exit` trip per selected country (with real
    // trip dates), joined by ';'.
    if (kind == ClipShape.passportPage) {
      final ccs = _stampCountryCodes();
      if (ccs.isEmpty) return _draft.baseFlags.first.code;
      final r = DeterministicRng(_draft.seed).stream('passport');
      return ccs.map((cc) {
        final (entry, exit) = LabShowcaseGenerator.tripDates(r);
        return '$cc|$entry|$exit';
      }).join(';');
    }
    if (kind == ClipShape.continentOutline) {
      return widget.continents.isEmpty ? null : widget.continents.first;
    }
    if (kind != null && kind.needsCode) return _defaultSlug(kind);
    return null;
  }

  /// The code/text picker appropriate to the current shape (or nothing).
  List<Widget> _codePickerForMeta(ClipShapeMeta m) {
    if (m.source == ClipShapeSource.text) {
      // Quick-fill presets: slogans + the selected country's own name.
      final firstCode = _draft.baseFlags.first.code.toLowerCase();
      final countryName = widget.countryNames[firstCode]?.toUpperCase();
      final presets = <String>[
        'ROAM', 'EXPLORE', 'WANDER', 'WILD',
        ?countryName,
      ];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            key: ValueKey(_draft.clipText),
            controller: TextEditingController(text: _draft.clipText ?? 'ROAM'),
            decoration: const InputDecoration(
                isDense: true, labelText: 'Text (ROAM / EXPLORE / a name)'),
            onChanged: (v) => _draft.clipText = v,
            onSubmitted: (v) => _change(() => _draft.clipText = v),
          ),
        ),
        Wrap(
          spacing: 4,
          children: [
            for (final p in presets)
              ActionChip(
                label: Text(p, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _change(() => _draft.clipText = p),
              ),
          ],
        ),
      ];
    }
    final kind = m.resolverKind;
    if (kind == ClipShape.animalSilhouette ||
        kind == ClipShape.plantSilhouette ||
        kind == ClipShape.landmarkSilhouette ||
        kind == ClipShape.passportStampOutline) {
      return _countrySlugsFor(kind!).isEmpty ? const [] : [_silhouettePicker(kind)];
    }
    if (kind == ClipShape.countryOutline) {
      final codes = _draft.baseFlags.map((f) => f.code).toList();
      if (codes.length < 2) return const []; // implied by the single country
      return [
        _codeDropdown('Country', codes, _draft.clipCode ?? codes.first,
            (v) => _draft.clipCode = v),
      ];
    }
    if (kind == ClipShape.continentOutline) {
      if (widget.continents.isEmpty) return const [];
      return [
        _codeDropdown('Region', widget.continents,
            _draft.clipCode ?? widget.continents.first,
            (v) => _draft.clipCode = v),
      ];
    }
    if (kind == ClipShape.passportPage) {
      // No picker — it uses every selected country's entry + exit stamps.
      final n = _stampCountryCodes().length;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
              n <= 1
                  ? 'Overlays this country’s entry + exit stamps.'
                  : 'Overlays entry + exit stamps for all $n selected countries.',
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ),
      ];
    }
    return const [];
  }

  Widget _codeDropdown(String label, List<String> options, String value,
      ValueChanged<String> onChanged) {
    final safe = options.contains(value) ? value : options.first;
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: DropdownButton<String>(
            value: safe,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 420,
            items: [
              for (final o in options)
                DropdownMenuItem(
                    value: o,
                    child: Text(o.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 11))),
            ],
            onChanged: (v) => _change(() {
              if (v != null) onChanged(v);
            }),
          ),
        ),
      ],
    );
  }

  /// The default silhouette of [shape]'s kind for the design's countries.
  String? _defaultSlug(ClipShape shape) {
    final slugs = _countrySlugsFor(shape);
    return slugs.isEmpty ? null : slugs.first;
  }

  Widget _silhouettePicker(ClipShape shape) {
    // Only silhouettes belonging to the design's countries (each relates to one).
    final ordered = _countrySlugsFor(shape);
    final value = _draft.clipCode ?? ordered.first;
    return Row(
      children: [
        SizedBox(
            width: 96,
            child: Text(_silhouetteKindLabel(shape),
                style: const TextStyle(fontSize: 12))),
        Expanded(
          child: DropdownButton<String>(
            value: ordered.contains(value) ? value : ordered.first,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 420,
            items: [
              for (final s in ordered)
                DropdownMenuItem(
                  value: s,
                  // Drop the country prefix — it's implied by the flag.
                  child: Text(
                      s.contains('_')
                          ? s.substring(s.indexOf('_') + 1).replaceAll('_', ' ')
                          : s,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
            ],
            onChanged: (v) => _change(() => _draft.clipCode = v),
          ),
        ),
      ],
    );
  }

  String _silhouetteKindLabel(ClipShape shape) {
    switch (shape) {
      case ClipShape.plantSilhouette:
        return 'Plant';
      case ClipShape.landmarkSilhouette:
        return 'Landmark';
      case ClipShape.passportStampOutline:
        return 'Stamp';
      default:
        return 'Animal';
    }
  }

  Widget _edgeSection() => _section(
        'Torn / ripped edges',
        _draft.edgeOn,
        (v) => _change(() => _draft.edgeOn = v),
        children: [
          _dropdown<TearStyle>('Style', _draft.tearStyle, TearStyle.values,
              (v) => _change(() => _draft.tearStyle = v)),
          _slider('Edge damage', _draft.edgeDamage, 0, 1,
              (v) => _change(() => _draft.edgeDamage = v)),
          _slider('Max depth', _draft.maxDepth, 0.02, 0.5,
              (v) => _change(() => _draft.maxDepth = v)),
          _slider('Fray', _draft.frayAmount, 0, 1,
              (v) => _change(() => _draft.frayAmount = v)),
          _slider('Corner damage', _draft.cornerDamage, 0, 1,
              (v) => _change(() => _draft.cornerDamage = v)),
          _slider('Asymmetry', _draft.asymmetry, 0, 1,
              (v) => _change(() => _draft.asymmetry = v)),
        ],
      );

  Widget _effectsSection() => _section(
        'Effects',
        _draft.fxOn,
        (v) => _change(() => _draft.fxOn = v),
        children: [
          _slider('Distress', _draft.distress, 0, 1,
              (v) => _change(() => _draft.distress = v)),
          _slider('Grain', _draft.grain, 0, 1, (v) => _change(() => _draft.grain = v)),
          _slider('Fade', _draft.fade, 0, 1, (v) => _change(() => _draft.fade = v)),
          _slider('Halftone', _draft.halftone, 0, 1,
              (v) => _change(() => _draft.halftone = v)),
          _slider('Halftone scale', _draft.halftoneScale, 2, 12,
              (v) => _change(() => _draft.halftoneScale = v)),
          _slider('Ripple amp', _draft.rippleAmp, 0, 1,
              (v) => _change(() => _draft.rippleAmp = v)),
          _slider('Tie-dye', _draft.tieDye, 0, 1,
              (v) => _change(() => _draft.tieDye = v)),
          _slider('Shatter', _draft.shatter, 0, 1,
              (v) => _change(() => _draft.shatter = v)),
          _slider('Shatter spikes', _draft.shatterSpikes, 0, 1,
              (v) => _change(() => _draft.shatterSpikes = v)),
          _slider('Ripple freq', _draft.rippleFreq, 1, 16,
              (v) => _change(() => _draft.rippleFreq = v)),
        ],
      );

  Widget _paletteSection() => _section(
        'Colour',
        _draft.paletteOn,
        (v) => _change(() => _draft.paletteOn = v),
        children: [
          _dropdown<ColourStrategy>('Strategy', _draft.strategy,
              ColourStrategy.values, (v) => _change(() => _draft.strategy = v)),
          _slider('Vintage grade', _draft.vintageGrade, 0, 1,
              (v) => _change(() => _draft.vintageGrade = v)),
        ],
      );

  // ---- reusable control widgets ----

  Widget _section(
    String title,
    bool on,
    ValueChanged<bool> onToggle, {
    required List<Widget> children,
    bool enabled = true,
    String? subtitle,
  }) {
    return Card(
      color: const Color(0xFF1D2026),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(subtitle,
                        style: const TextStyle(fontSize: 10, color: Colors.orangeAccent)),
                  ),
                const Spacer(),
                Switch(
                  value: on && enabled,
                  onChanged: enabled ? onToggle : null,
                ),
              ],
            ),
            if (on && enabled) ...children,
          ],
        ),
      ),
    );
  }

  Widget _slider(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(value.toStringAsFixed(2),
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _dropdown<T>(
      String label, T value, List<T> options, ValueChanged<T> onChanged,
      {String Function(T)? labeler}) {
    String text(T o) => labeler != null ? labeler(o) : '$o'.split('.').last;
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o,
                  child: Text(text(o), style: const TextStyle(fontSize: 12)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }


  Widget _jsonView(DesignRecipe recipe) {
    final json = const JsonEncoder.withIndent('  ').convert(recipe.toJson());
    return ExpansionTile(
      title: const Text('Recipe JSON', style: TextStyle(fontSize: 13)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      children: [
        SelectableText(json,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
      ],
    );
  }
}

/// Renders [recipe] and shows it, ignoring stale results if [recipe] changes
/// again before a render finishes (so fast slider drags don't flicker).
class _LivePreview extends StatefulWidget {
  const _LivePreview(
      {required this.service, required this.recipe, required this.size});
  final RenderService service;
  final DesignRecipe recipe;
  final int size;

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant _LivePreview old) {
    super.didUpdateWidget(old);
    if (old.recipe.recipeId != widget.recipe.recipeId) _render();
  }

  Future<void> _render() async {
    final requested = widget.recipe.recipeId;
    final img = await widget.service.imageFor(widget.recipe, widget.size);
    if (!mounted) return;
    // Drop stale results — only paint if this is still the current recipe.
    if (widget.recipe.recipeId != requested) return;
    setState(() => _image = img);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(
          child: SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return RawImage(image: img, fit: BoxFit.contain);
  }
}
