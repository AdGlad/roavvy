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
import '../print_style/print_style_pipeline.dart';
import 'preference_store.dart';
import 'procedural/procedural.dart';
import 'procedural_design_service.dart';
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
  int _seed = 1;
  CardRenderThumbnailer? _thumbnailer;
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
    _thumbnailer ??= CardRenderThumbnailer.forContext(context);
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

  void _toggleSave(_ProcItem it) {
    setState(() => it.saved = !it.saved);
    if (it.saved) {
      ref
          .read(preferenceProfileProvider.notifier)
          .record(it.design.recipe, PreferenceSignal.saved);
    }
  }

  void _openDesign(_ProcItem it) {
    final params = it.design.params;
    ref
        .read(preferenceProfileProvider.notifier)
        .record(it.design.recipe, PreferenceSignal.selectedForMockup);
    // Merged (two-flag) designs: render the merged artwork at print resolution
    // and hand it to the EXISTING preview as pre-rendered artwork (ADR-147), so
    // it flows to checkout / the Printful print file unchanged.
    if (it.design.recipe.isMerged) {
      unawaited(_openMerged(it));
      return;
    }
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
  /// fully orderable. Falls back to the preview dialog if the shader is off.
  Future<void> _openMerged(_ProcItem it) async {
    final r = it.design.recipe;
    Uint8List? art;
    if (_merged != null) {
      art = await _merged!.renderPng(r, size: 1024);
      if (art != null && r.hasTreatment) {
        art = await PrintStylePipeline.instance
            .applyToBytes(art, r.toPrintStyleParams());
      }
    }
    if (!mounted) return;
    if (art == null) {
      _openMergedPreview(it); // couldn't render → non-purchasable preview
      return;
    }
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

  void _openMergedPreview(_ProcItem it) {
    final r = it.design.recipe;
    final codes = r.countryCodes.take(2).join(' + ').toUpperCase();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$codes · ${r.combination.name} blend',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: Colors.white)),
              const SizedBox(height: 12),
              if (it.thumb != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(it.thumb!, fit: BoxFit.contain),
                )
              else
                const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator())),
              const SizedBox(height: 12),
              Text(
                'This blend couldn’t be prepared for ordering on this device. '
                'Tap ♥ to help tune the blends you like.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
  const _ProcCard({required this.item, required this.onTap, required this.onSave});
  final _ProcItem item;
  final VoidCallback onTap;
  final VoidCallback onSave;

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
              child: IconButton(
                iconSize: 20,
                icon: Icon(
                  item.saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: item.saved ? const Color(0xFFFF6B6B) : Colors.white70,
                ),
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
