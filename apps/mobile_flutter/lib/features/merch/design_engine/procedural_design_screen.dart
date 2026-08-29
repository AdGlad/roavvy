import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../cards/flag_grid_layout_engine.dart' show GridClipShape;
import '../local_mockup_preview_screen.dart';
import '../merch_option_list_widgets.dart' show merchBackCardAspectRatio;
import '../merch_preset.dart';
import 'card_render_thumbnailer.dart';
import 'design_params.dart';
import '../print_style/card_text_layer.dart';
import '../print_style/print_style_pipeline.dart';
import 'preference_store.dart';
import 'procedural/procedural.dart';
import 'procedural_design_service.dart';
import '../variation_grid_screen.dart';
import 'reference/design_dna_loader.dart';
import 'rendering/merged_flag_renderer.dart';

/// "Auto designs" — the procedural design engine's user surface. Builds a
/// [DesignContext] from the user's travel selection, asks the procedural
/// generator for strong, diverse recipes (personalised by learned preference),
/// renders thumbnails with the EXISTING renderer, and hands a chosen design to
/// the EXISTING [LocalMockupPreviewScreen]. The purchase flow is untouched.
///
/// It personalises two ways: immediately from behaviour (view/save/select →
/// preference profile) and, over time, from the reference library (the bundled
/// Design DNA asset). Multi-country selections produce combined compositions
/// (dominant + accent, silhouette cut-outs, split fields) — the closest the
/// current renderer gets to "merged flags"; a literal blend is a future
/// renderer capability (see design_engine/docs/capability_matrix.md).
class ProceduralDesignScreen extends ConsumerStatefulWidget {
  const ProceduralDesignScreen({
    super.key,
    required this.codes,
    required this.allCodes,
    required this.trips,
  });

  final List<String> codes;
  final List<String> allCodes;
  final List<TripRecord> trips;

  @override
  ConsumerState<ProceduralDesignScreen> createState() =>
      _ProceduralDesignScreenState();
}

class _ProcItem {
  _ProcItem(this.design);
  final RankedDesign design;
  Uint8List? thumb;
  bool saved = false;
}

class _ProceduralDesignScreenState
    extends ConsumerState<ProceduralDesignScreen> {
  List<_ProcItem> _items = const [];
  bool _loading = true;
  bool _opening = false; // guards against double-open while rendering print art
  int _seed = 1;
  CardRenderThumbnailer? _thumbnailer;
  CardRenderThumbnailer? _printRenderer; // higher-res, for the exact print source
  MergedFlagRenderer? _merged;
  int _runToken = 0;

  @override
  void initState() {
    super.initState();
    _seed = _contextFor().baseSeed & 0x7fffffff;
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  DesignContext _contextFor() {
    final codes = widget.codes;
    final scope = codes.length <= 1
        ? DesignScope.singleCountry
        : DesignScope.multiCountry;
    return DesignContext.of(
      scope: scope,
      countryCodes: codes,
      allCountryCodes: widget.allCodes.isEmpty ? codes : widget.allCodes,
      garmentIsDark: true,
    );
  }

  List<TripRecord> _tripsFor(List<String> codes) {
    final set = codes.map((c) => c.toUpperCase()).toSet();
    final scoped = widget.trips
        .where((t) => set.contains(t.countryCode.toUpperCase()))
        .toList();
    return scoped.isEmpty ? widget.trips : scoped;
  }

  Future<void> _run() async {
    final token = ++_runToken;
    setState(() => _loading = true);

    final profile = ref.read(preferenceProfileProvider);
    final dna = await loadRoavvyDesignDna();
    if (!mounted || token != _runToken) return;

    final service = ProceduralDesignService(
      generator: ProceduralDesignGenerator(dna: dna),
    );
    final ranked = service.recommend(
      _contextFor(),
      seed: _seed,
      count: 8,
      exploration: 0.45,
      profile: profile,
      prefBlend: 0.35,
    );

    if (!mounted || token != _runToken) return;
    setState(() {
      _items = ranked.map(_ProcItem.new).toList();
      _loading = false;
    });

    // Weak "viewed" signal for what we surfaced.
    final notifier = ref.read(preferenceProfileProvider.notifier);
    for (final it in _items) {
      notifier.record(it.design.recipe, PreferenceSignal.viewed);
    }

    // Render thumbnails one at a time (the thumbnailer is concurrency-1).
    // Render artwork WITHOUT the baked-in title/footer so the destructive
    // print-style passes can never tear or clip the text; the label is
    // composited back as a separate full layer below (see [_composeText]).
    _thumbnailer ??=
        CardRenderThumbnailer.forContext(context, suppressText: true);
    try {
      _merged ??= await MergedFlagRenderer.load(); // GPU flag-blend renderer
    } catch (_) {
      _merged = null; // fall back to the card thumbnailer if the shader is off
    }
    for (final it in _items) {
      if (!mounted || token != _runToken) return;
      try {
        Uint8List? bytes;
        if (it.design.recipe.isMerged && _merged != null) {
          bytes = await _merged!.renderPng(it.design.recipe, size: 512);
        }
        // Fall back to the normal composition thumbnail if not a merge (or if
        // the merge couldn't render).
        bytes ??= await _thumbnailer!.renderThumbnail(
            it.design.params, _tripsFor(it.design.recipe.countryCodes));
        // Apply the recipe's continuous treatment genes (distress/grain/
        // halftone/fade) so the feed shows the actual look.
        if (it.design.recipe.hasTreatment) {
          bytes = await PrintStylePipeline.instance
              .applyToBytes(bytes, it.design.recipe.toPrintStyleParams());
        }
        // Composite the title/footer as a separate, un-clippable layer on top of
        // the styled artwork (merged/GPU designs carry no card text, so skip).
        if (!it.design.recipe.isMerged) {
          bytes = await _composeText(bytes, it.design.params, it.design.recipe);
        }
        if (!mounted || token != _runToken) return;
        setState(() => it.thumb = bytes);
      } catch (_) {
        // Skip a design that can't render; the rest still show.
      }
    }
  }

  void _regenerate() {
    setState(() {
      _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
      _items = const [];
    });
    _run();
  }

  void _showVariations(_ProcItem it) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VariationGridScreen(
          anchor: it.design,
          allCodes: widget.allCodes,
          trips: _tripsFor(it.design.recipe.countryCodes),
        ),
      ),
    );
  }

  void _toggleSave(_ProcItem it) {
    setState(() => it.saved = !it.saved);
    if (it.saved) {
      ref
          .read(preferenceProfileProvider.notifier)
          .record(it.design.recipe, PreferenceSignal.saved);
    }
  }

  void _openDesign(_ProcItem it) {
    if (_opening) return; // ignore taps while a print render is in flight
    ref
        .read(preferenceProfileProvider.notifier)
        .record(it.design.recipe, PreferenceSignal.selectedForMockup);
    // Merged (two-flag) designs render their artwork on the GPU first; every
    // other design (and any merge that can't render) opens the standard preview.
    if (it.design.recipe.isMerged) {
      unawaited(_openMerged(it));
    } else {
      unawaited(_openStandardPreview(it));
    }
  }

  /// Open the preview showing the EXACT design from the feed: re-render the
  /// composition deterministically at print resolution (same seed ⇒ same
  /// arrangement) + the same treatment, and hand it over as fixed artwork so the
  /// preview/print reproduce the feed pixel-for-pixel (not a fresh regeneration).
  Future<void> _openStandardPreview(_ProcItem it) async {
    final params = it.design.params;
    Uint8List? art;
    setState(() => _opening = true);
    try {
      _printRenderer ??= CardRenderThumbnailer.forContext(context,
          pixelRatio: 5.0, cacheCapacity: 8, suppressText: true);
      art = await _printRenderer!
          .renderThumbnail(params, _tripsFor(params.countryCodes));
      if (it.design.recipe.hasTreatment) {
        art = await PrintStylePipeline.instance
            .applyToBytes(art, it.design.recipe.toPrintStyleParams());
      }
      // Composite the title/footer on top of the styled print artwork so the
      // preview/print reproduce the feed pixel-for-pixel, with legible text.
      art = await _composeText(art, params, it.design.recipe);
    } catch (_) {
      art = null;
    }
    if (!mounted) return;
    setState(() => _opening = false);

    if (art != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LocalMockupPreviewScreen(
            selectedCodes: params.countryCodes,
            allCodes: widget.allCodes,
            trips: _tripsFor(params.countryCodes),
            artworkImageBytes: art, // the exact feed image = the first frame
            // NOT fixedArtwork: the card-rendered artwork can be re-generated, so
            // re-configuring (orientation / flag count / colour / title) works.
            // The recipe's STYLE recipe below is re-applied on every render so it
            // never reverts to the plain template.
            autoStyleParams: it.design.recipe.toPrintStyleParams(),
            autoShowTitle: it.design.recipe.showTitle,
            autoShowFooter: it.design.recipe.showFooter,
            initialTemplate: params.template,
            // Layout genome — so a re-render regenerates the SAME composition.
            initialPreset: MerchPreset(
              id: 'proc_${it.design.recipe.recipeId.hashCode}',
              label: 'Auto design',
              config: params.toPresetConfig(),
            ),
            confirmedAspectRatio: params.isPortrait ? 4 / 5 : 5 / 4,
            transparentBackground: true,
            initialColour: params.shirtColour,
            gridLayoutMode: params.gridLayoutMode,
            clipShape: params.clipShape,
            clipCode: params.clipCode,
            continentKey: params.clipShape == GridClipShape.continentOutline
                ? params.clipCode
                : null,
            flagRepeatCount: params.rowCount,
            rowCount: params.rowCount,
          ),
        ),
      );
      return;
    }
    // Fallback: preset-driven generation (opens even if the exact render fails).
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          selectedCodes: params.countryCodes,
          allCodes: widget.allCodes,
          trips: _tripsFor(params.countryCodes),
          initialTemplate: params.template,
          initialPreset: MerchPreset(
            id: 'proc_${it.design.recipe.recipeId.hashCode}',
            label: 'Auto design',
            config: params.toPresetConfig(),
          ),
          confirmedAspectRatio: merchBackCardAspectRatio(params.template),
          transparentBackground: true,
          initialColour: params.shirtColour,
          gridLayoutMode: params.gridLayoutMode,
          clipShape: params.clipShape,
          clipCode: params.clipCode,
          continentKey: params.clipShape == GridClipShape.continentOutline
              ? params.clipCode
              : null,
          flagRepeatCount: params.rowCount,
          rowCount: params.rowCount,
        ),
      ),
    );
  }

  /// Render the merged flag at print resolution (+ treatment) and open the
  /// existing preview with it as pre-rendered artwork, so merged designs are
  /// fully orderable. If the GPU render is unavailable for ANY reason, fall
  /// back to the standard preview so a tap always reaches the T-shirt screen.
  Future<void> _openMerged(_ProcItem it) async {
    final r = it.design.recipe;
    Uint8List? art;
    setState(() => _opening = true);
    try {
      _merged ??= await MergedFlagRenderer.load();
      art = await _merged!.renderPng(r, size: 1024);
      if (art != null && r.hasTreatment) {
        art = await PrintStylePipeline.instance
            .applyToBytes(art, r.toPrintStyleParams());
      }
    } catch (_) {
      art = null;
    }
    if (!mounted) return;
    if (art == null) {
      // couldn't render the merge → normal preview (manages _opening itself)
      unawaited(_openStandardPreview(it));
      return;
    }
    setState(() => _opening = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMockupPreviewScreen(
          selectedCodes: r.countryCodes,
          allCodes: widget.allCodes,
          trips: _tripsFor(r.countryCodes),
          artworkImageBytes: art, // pre-rendered merged artwork (print source)
          fixedArtwork: true, // never regenerate from a template on colour change
          initialTemplate: CardTemplateType.grid,
          confirmedAspectRatio: 1.0, // square merged flag
          transparentBackground: true,
          initialColour: r.garmentColour,
        ),
      ),
    );
  }

  /// Composites the design's title/footer onto [bytes] as a separate, always
  /// full layer (never part of the destructive print-style pass). Honours the
  /// recipe's independent [ProceduralDesignRecipe.showTitle] /
  /// [ProceduralDesignRecipe.showFooter] toggles and tints the text to match the
  /// print style. Returns [bytes] unchanged when both toggles are off.
  Future<Uint8List> _composeText(
    Uint8List bytes,
    DesignParams params,
    ProceduralDesignRecipe recipe,
  ) {
    if (!recipe.showTitle && !recipe.showFooter) return Future.value(bytes);
    final n = params.countryCodes.length;
    final title = '$n ${n == 1 ? 'Country' : 'Countries'}';
    return CardTextLayer.compose(
      bytes,
      showTitle: recipe.showTitle,
      showFooter: recipe.showFooter,
      title: title,
      countryCount: n,
      textColor: CardRenderThumbnailer.inkColorFor(params.shirtColour),
      tone: recipe.hasTreatment ? recipe.toPrintStyleParams() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Auto designs'),
            actions: [
              if (!_loading)
                IconButton(
                  tooltip: 'Shuffle',
                  icon: const Icon(Icons.auto_awesome_rounded),
                  onPressed: _regenerate,
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _loading && _items.isEmpty
                        ? 'Composing designs from your travels…'
                        : 'Tap to customise & order · ♥ to teach your taste',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody(theme)),
                ],
              ),
            ),
          ),
        ),
        // Preparing the exact print-resolution artwork for the preview.
        if (_opening)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (widget.codes.isEmpty) {
      return Center(
        child: Text('Pick at least one country first.',
            style: theme.textTheme.bodyMedium),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.brush_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text('Couldn’t compose a design from this selection.',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _regenerate, child: const Text('Try again')),
                ],
              ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) => _ProcCard(
        item: _items[i],
        onTap: () => _openDesign(_items[i]),
        onSave: () => _toggleSave(_items[i]),
        onMoreLikeThis: () => _showVariations(_items[i]),
      ),
    );
  }
}

const Map<String, Color> _shirtSwatch = {
  'Black': Color(0xFF1A1A1A),
  'White': Color(0xFFF5F5F5),
  'Blue': Color(0xFF2B4C7E),
  'Grey': Color(0xFF9E9E9E),
  'Red': Color(0xFFB23A3A),
};

class _ProcCard extends StatelessWidget {
  const _ProcCard({
    required this.item,
    required this.onTap,
    required this.onSave,
    this.onMoreLikeThis,
  });
  final _ProcItem item;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback? onMoreLikeThis;

  @override
  Widget build(BuildContext context) {
    final params = item.design.params;
    final bg = _shirtSwatch[params.shirtColour] ?? const Color(0xFF1A1A1A);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                  child: item.thumb == null
                      ? const CircularProgressIndicator()
                      : Image.memory(item.thumb!,
                          fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMoreLikeThis != null)
                    IconButton(
                      iconSize: 18,
                      tooltip: 'More like this',
                      icon: const Icon(Icons.auto_awesome,
                          color: Colors.white70, size: 18),
                      onPressed: onMoreLikeThis,
                    ),
                  IconButton(
                    iconSize: 20,
                    icon: Icon(
                      item.saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color:
                          item.saved ? const Color(0xFFFF6B6B) : Colors.white70,
                    ),
                    onPressed: onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
