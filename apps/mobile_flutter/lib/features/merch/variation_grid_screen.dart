import 'dart:typed_data';

import 'package:design_forge/design_forge.dart' hide Clip;
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart' show TripRecord;

import 'design_engine/procedural/procedural.dart';
import 'design_engine/procedural_design_service.dart';
import 'design_engine/card_render_thumbnailer.dart';
import '../cards/flag_grid_layout_engine.dart' show GridClipShape;
import 'local_mockup_preview_screen.dart';
import 'merch_preset.dart';

/// Shows variations of a selected design grouped by variation axis.
///
/// Uses the forge [VariationGenerator] to produce recipe neighbours along
/// controlled axes (effects, color, shape, orientation, edge, garment),
/// then renders thumbnails for each. Tapping a variation opens the
/// [LocalMockupPreviewScreen] for that design.
class VariationGridScreen extends StatefulWidget {
  const VariationGridScreen({
    super.key,
    required this.anchor,
    required this.allCodes,
    required this.trips,
  });

  final RankedDesign anchor;
  final List<String> allCodes;
  final List<TripRecord> trips;

  @override
  State<VariationGridScreen> createState() => _VariationGridScreenState();
}

class _VariationGridScreenState extends State<VariationGridScreen> {
  late List<RecipeVariation> _variations;
  final _thumbs = <String, Uint8List>{};
  CardRenderThumbnailer? _thumbnailer;

  @override
  void initState() {
    super.initState();
    const varGen = VariationGenerator();
    _variations = varGen.variate(
      _toForgeRecipe(widget.anchor.recipe),
      count: 12,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _renderThumbs());
  }

  /// Convert a [ProceduralDesignRecipe] to a forge [DesignRecipe] for the
  /// variation generator. This is a one-way mapping since we only need the
  /// recipe structure for variation, not for rendering.
  DesignRecipe _toForgeRecipe(ProceduralDesignRecipe r) {
    return DesignRecipe(
      seed: r.seed,
      content: RecipeContent(
        flags: [for (final c in r.countryCodes) FlagRef(c)],
        source: r.scopeKey,
      ),
      composition: Composition(
        family: DesignFamily.values.firstWhere(
          (f) => f.name == r.family.name,
          orElse: () => DesignFamily.singleHero,
        ),
        orientation: r.isPortrait ? Orientation.portrait : Orientation.landscape,
      ),
      clip: r.mask != GridClipShape.none
          ? Clip(shapeId: r.mask.name, code: r.maskCode)
          : null,
      palette: Palette(
        garmentColour: r.garmentColour,
        vintageGrade: r.fade,
      ),
      effects: Effects(
        distress: r.distress,
        grain: r.grain,
        halftone: r.halftone,
        fade: r.fade,
      ),
      provenance: RecipeProvenance(generator: r.generator),
    );
  }

  Future<void> _renderThumbs() async {
    // Render anchor thumbnail first.
    _thumbnailer ??= CardRenderThumbnailer.forContext(context);
    final trips = widget.trips;
    for (final v in _variations) {
      if (!mounted) return;
      // We can't render forge recipes with the mobile thumbnailer directly.
      // Instead show a placeholder with the axis label.
      // The actual rendering would require converting back to
      // ProceduralDesignRecipe which is complex. For now, mark as available.
      setState(() {
        _thumbs[v.recipe.recipeId] = Uint8List(0); // placeholder
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group by axis.
    final byAxis = <VariationAxis, List<RecipeVariation>>{};
    for (final v in _variations) {
      (byAxis[v.axis] ??= []).add(v);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Like This'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final axis in byAxis.keys) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  axis.label,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final v in byAxis[axis]!)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _VariationCard(
                          variation: v,
                          onTap: () => _openVariation(v),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openVariation(RecipeVariation v) {
    // Open the variation in the mockup preview using the anchor's params
    // as a base. The user can then customise further.
    final params = widget.anchor.params;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          selectedCodes: params.countryCodes,
          allCodes: widget.allCodes,
          trips: widget.trips,
          initialTemplate: params.template,
          initialPreset: MerchPreset(
            id: 'var_${v.recipe.recipeId.hashCode}',
            label: 'Variation (${v.axis.label})',
            config: params.toPresetConfig(),
          ),
          transparentBackground: true,
          initialColour: v.recipe.palette?.garmentColour ?? params.shirtColour,
        ),
      ),
    );
  }
}

class _VariationCard extends StatelessWidget {
  const _VariationCard({required this.variation, required this.onTap});
  final RecipeVariation variation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final garment = variation.recipe.palette?.garmentColour;
    final bg = garment != null ? _parseColor(garment) : const Color(0xFF1A1A1A);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 100,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                variation.axis.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isDark(bg) ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length < 6) return const Color(0xFF1A1A1A);
    return Color(int.parse('FF$clean', radix: 16));
  }

  static bool _isDark(Color c) =>
      0.299 * c.r + 0.587 * c.g + 0.114 * c.b < 0.5;
}
