import 'dart:math' as math;

import 'package:shared_models/shared_models.dart' show CardTemplateType;

import '../../../cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import '../../bundled_silhouette_manifest.dart';
import '../../print_style/print_style.dart' show ColorTreatment, PrintStyleId;
import '../../product_mockup_specs.dart' show ImageSize;
import '../../merch_preset.dart'
    show MerchCountrySource, MerchDensity, MerchStampMode;
import 'composition_family.dart';
import 'design_context.dart';
import 'procedural_recipe.dart';

/// Curated "exemplar" recipes — proven looks (distilled from the reference
/// library) injected into the generator's candidate pool so they compete with
/// grammar-sampled designs on quality + diversity. Retargeted to the context's
/// countries/garment and varied by seed; scored + selected like any candidate
/// (never forced). Same pipeline as everything else: printable by construction,
/// deterministic, 100% local.
List<ProceduralDesignRecipe> curatedExemplars(
  DesignContext context,
  int seed, {
  required String engineVersion,
  required String grammarVersion,
}) {
  final codes = context.countryCodes;
  if (codes.isEmpty) return const [];
  final n = codes.length;
  final cc = codes.first;
  final garment = context.garmentIsDark ? 'Black' : 'White';
  final source = n == 1
      ? MerchCountrySource.singleCountry
      : MerchCountrySource.allTime;

  ProceduralDesignRecipe build({
    required CompositionFamily family,
    required HierarchyMode hierarchy,
    CardTemplateType template = CardTemplateType.grid,
    FlagGridLayoutMode layoutMode = FlagGridLayoutMode.packedRow,
    GridClipShape mask = GridClipShape.none,
    String? maskCode,
    int rowCount = 1,
    String? hero,
    MerchDensity density = MerchDensity.balanced,
    double jitter = 0.1,
    bool isPortrait = false,
    ImageSize imageSize = ImageSize.large,
    FlagTreatment flagTreatment = FlagTreatment.fullColour,
    ColorTreatment colour = ColorTreatment.none,
    PrintStyleId style = PrintStyleId.clean,
    double heroScale = 0.7,
    FlagCombination combination = FlagCombination.none,
    double weightA = 0.5,
    double distress = 0,
    double grain = 0,
    double halftone = 0,
    double fade = 0,
    required int salt,
  }) =>
      ProceduralDesignRecipe(
        engineVersion: engineVersion,
        grammarVersion: grammarVersion,
        seed: (seed ^ salt) & 0x7fffffff,
        scopeKey: context.scopeKey,
        generator: 'curated',
        family: family,
        hierarchy: hierarchy,
        template: template,
        layoutMode: layoutMode,
        mask: mask,
        maskCode: maskCode,
        rowCount: rowCount,
        countryCodes: codes,
        heroCode: hero,
        source: source,
        density: density,
        jitter: jitter,
        stampMode: MerchStampMode.entryExit,
        isPortrait: isPortrait,
        imageSize: imageSize,
        garmentColour: garment,
        flagTreatment: flagTreatment,
        colourTreatment: colour,
        printStyle: style,
        heroScale: heroScale,
        placement: PlacementAnchor.center,
        placementOffset: 0,
        cropMode: CropMode.bleed,
        rotationDeg: 0,
        layerMode: LayerMode.flat,
        combination: combination,
        weightA: weightA,
        distress: distress,
        grain: grain,
        halftone: halftone,
        fade: fade,
      );

  final out = <ProceduralDesignRecipe>[];

  // ── Single country ─────────────────────────────────────────────────────────
  if (n == 1) {
    // Torn flag — full colour.
    out.add(build(
        family: CompositionFamily.singleHero,
        hierarchy: HierarchyMode.singleFocal,
        hero: cc,
        heroScale: 0.85,
        style: PrintStyleId.edgeTear,
        distress: 0.45,
        grain: 0.22,
        salt: 0x7011));
    // Torn flag — mono tattered.
    out.add(build(
        family: CompositionFamily.singleHero,
        hierarchy: HierarchyMode.singleFocal,
        hero: cc,
        heroScale: 0.9,
        flagTreatment: FlagTreatment.monochrome,
        colour: ColorTreatment.monoInk,
        style: PrintStyleId.edgeTear,
        distress: 0.62,
        grain: 0.30,
        salt: 0x7022));
    // Country-outline flag (souvenir look).
    out.add(build(
        family: CompositionFamily.singleHero,
        hierarchy: HierarchyMode.singleFocal,
        mask: GridClipShape.countryOutline,
        maskCode: cc,
        hero: cc,
        heroScale: 0.9,
        style: PrintStyleId.vintage,
        distress: 0.2,
        grain: 0.18,
        fade: 0.3,
        salt: 0x7044));
    // Ripped-through-fabric flag — the flag shows through a vertical torn gash
    // (portrait), rest transparent so the garment shows around it.
    out.add(build(
        family: CompositionFamily.singleHero,
        hierarchy: HierarchyMode.singleFocal,
        hero: cc,
        isPortrait: true,
        heroScale: 0.9,
        style: PrintStyleId.rippedFlag,
        distress: 0.40,
        grain: 0.25,
        salt: 0x7099));
    // National-animal flag — only when a bundled silhouette exists (local).
    final slug = kBundledSilhouetteSlugs[cc.toUpperCase()];
    if (slug != null) {
      out.add(build(
          family: CompositionFamily.singleHero,
          hierarchy: HierarchyMode.singleFocal,
          mask: GridClipShape.animalSilhouette,
          maskCode: '${cc.toUpperCase()}|$slug',
          hero: cc,
          heroScale: 0.9,
          style: PrintStyleId.clean,
          salt: 0x7055));
    }
  }

  // ── Two countries — dual heritage split ────────────────────────────────────
  if (n == 2) {
    out.add(build(
        family: CompositionFamily.duoBlend,
        hierarchy: HierarchyMode.dualZone,
        hero: cc,
        combination: FlagCombination.diagonal,
        style: PrintStyleId.clean,
        salt: 0x7066));
  }

  // ── Several+ — heart of flags ──────────────────────────────────────────────
  if (n >= 5) {
    final rows = math.sqrt(n * 1.3).round().clamp(2, 8);
    out.add(build(
        family: CompositionFamily.repetitionField,
        hierarchy: HierarchyMode.uniform,
        mask: GridClipShape.heart,
        layoutMode: FlagGridLayoutMode.montage,
        rowCount: rows,
        density: MerchDensity.balanced,
        jitter: 0.2,
        style: PrintStyleId.clean,
        salt: 0x7077));
  }

  // ── Large collections — flag mosaic wall ───────────────────────────────────
  if (n >= 12) {
    final rows = math.sqrt(n * 0.7).round().clamp(3, 10);
    out.add(build(
        family: CompositionFamily.repetitionField,
        hierarchy: HierarchyMode.uniform,
        layoutMode: FlagGridLayoutMode.treemap,
        rowCount: rows,
        density: MerchDensity.dense,
        style: PrintStyleId.vintage,
        distress: 0.2,
        grain: 0.2,
        fade: 0.25,
        salt: 0x7088));
  }

  return out;
}
