import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../cards/card_image_renderer.dart';
import '../cards/country_path_service.dart';
import '../cards/flag_grid_layout_engine.dart';
import 'animal_silhouette_service.dart';
import 'grid_clip_shape_orientation.dart';
import 'local_mockup_painter.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_option_list_widgets.dart';
import 'merch_variant_lookup.dart';
import 'product_mockup_specs.dart';

// ── Smart defaults ─────────────────────────────────────────────────────────────

/// Row count for a single-country grid design's densest packing — the
/// slider's max. Shared with the Shop's "Best Match" preview thumbnail
/// ([MerchDesignCarousel]) so the two stay visually consistent.
const int kSoloGridRowCount = 10;

/// Returns the recommended repeat count for [codeCount] unique countries
/// and [shape]. Heart/circle clip shapes lose ~35% effective area, so the
/// count is bumped by 1 to keep the shirt looking full.
int merchDefaultRepeatCount(int codeCount, GridClipShape shape) {
  final base = switch (codeCount) {
    1 => 9,
    2 => 6,
    <= 4 => 4,
    <= 8 => 2,
    _ => 1,
  };
  final clipBoost =
      (shape != GridClipShape.none &&
              shape != GridClipShape.countryOutline &&
              shape != GridClipShape.continentOutline)
          ? 1
          : 0;
  return math.min(50, base + clipBoost);
}

// ── FlagShapeCustomiseScreen ───────────────────────────────────────────────────

/// Intermediate screen between the design carousel and [LocalMockupPreviewScreen]
/// for the grid flag template (M170).
///
/// Presents a [PageView] of shirt mockups — one per clip shape — and a [Slider]
/// to set the flag repeat count. Swiping selects the shape; the slider updates
/// repeat count with a 400 ms debounce.
class FlagShapeCustomiseScreen extends StatefulWidget {
  const FlagShapeCustomiseScreen({
    super.key,
    required this.codes,
    required this.allCodes,
    required this.trips,
    this.continentKey,
    this.titleOverride,
    this.subtitleOverride,
    this.initialColour,
    this.initialShape,
  });

  /// Country codes included in this design.
  final List<String> codes;

  /// All visited country codes (for front ribbon).
  final List<String> allCodes;

  final List<TripRecord> trips;

  /// Non-null for continent-scoped collections (M171 will use this).
  final String? continentKey;

  final String? titleOverride;
  final String? subtitleOverride;
  final String? initialColour;

  /// When non-null, the carousel opens directly on the page matching this shape.
  final GridClipShape? initialShape;

  @override
  State<FlagShapeCustomiseScreen> createState() =>
      _FlagShapeCustomiseScreenState();
}

// ── Page definition ────────────────────────────────────────────────────────────

typedef _PageDef = ({GridClipShape shape, String label, String? clipCode});

/// Continent display names from continent key.
const _kContinentDisplayNames = {
  'africa': 'Africa',
  'asia': 'Asia',
  'europe': 'Europe',
  'north_america': 'North America',
  'oceania': 'Oceania',
  'south_america': 'South America',
};

class _FlagShapeCustomiseScreenState extends State<FlagShapeCustomiseScreen> {
  late final PageController _pageCtrl;
  late List<_PageDef> _pages;
  int _currentPage = 0;
  int _rowCount = 3;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages(animalName: null, plantName: null, landmarkName: null);
    // Jump to the requested shape page if provided.
    if (widget.initialShape != null) {
      final idx = _pages.indexWhere((p) => p.shape == widget.initialShape);
      if (idx >= 0) _currentPage = idx;
    }
    _pageCtrl = PageController(initialPage: _currentPage);
    // Default rows: a single country repeats its one flag into a full
    // mosaic, so it reads best packed at the slider's max rather than the
    // sparse 3 rows used for a handful of distinct flags. 3 for small sets,
    // 2 for medium, 1 for large otherwise.
    _rowCount = widget.codes.length == 1
        ? kSoloGridRowCount
        : widget.codes.length <= 3
            ? 3
            : widget.codes.length <= 8
                ? 2
                : 1;
    // Preload outline paths in background.
    _preloadOutlinePaths();
    // Load animal + plant + landmark names for single-country designs to show as page labels.
    if (widget.codes.length == 1) {
      final cc = widget.codes.first.toUpperCase();
      Future.wait([
        AnimalSilhouetteService.animalNameFor(cc),
        AnimalSilhouetteService.plantNameFor(cc),
        AnimalSilhouetteService.landmarkNameFor(cc),
      ]).then((names) {
        if (mounted) {
          setState(() => _pages = _buildPages(
            animalName: names[0],
            plantName: names[1],
            landmarkName: names[2],
          ));
        }
      });
    }
  }

  List<_PageDef> _buildPages({
    required String? animalName,
    String? plantName,
    String? landmarkName,
  }) {
    final pages = <_PageDef>[
      (shape: GridClipShape.none, label: 'Grid', clipCode: null),
      (shape: GridClipShape.heart, label: 'Heart', clipCode: null),
      (shape: GridClipShape.circle, label: 'Circle', clipCode: null),
    ];
    // Country outline — only for single-country designs.
    if (widget.codes.length == 1) {
      final code = widget.codes.first.toUpperCase();
      final countryName = kCountryNames[code] ?? code;
      pages.add((
        shape: GridClipShape.countryOutline,
        label: countryName,
        clipCode: widget.codes.first.toLowerCase(),
      ));
      // Animal silhouette
      pages.add((
        shape: GridClipShape.animalSilhouette,
        label: animalName ?? 'Animal',
        clipCode: code,
      ));
      // Plant silhouette
      pages.add((
        shape: GridClipShape.plantSilhouette,
        label: plantName ?? 'Plant',
        clipCode: code,
      ));
      // Landmark silhouette
      pages.add((
        shape: GridClipShape.landmarkSilhouette,
        label: landmarkName ?? 'Landmark',
        clipCode: code,
      ));
    }
    // Continent outline — only when a continent key is provided.
    if (widget.continentKey != null) {
      final key = widget.continentKey!;
      final displayName = _kContinentDisplayNames[key] ?? key;
      pages.add((
        shape: GridClipShape.continentOutline,
        label: displayName,
        clipCode: key,
      ));
    }
    return pages;
  }

  void _preloadOutlinePaths() {
    const approxSize = ui.Size(800, 533);
    final codes = <String>[];
    if (widget.codes.length == 1) codes.add(widget.codes.first.toLowerCase());
    if (widget.continentKey != null) codes.add(widget.continentKey!);
    if (codes.isNotEmpty) {
      CountryPathService.preload(codes, approxSize);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _onSliderChanged(double val) {
    setState(() => _rowCount = val.round());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {}); // triggers rebuild → pages re-render
    });
  }

  void _navigateToPreview() {
    final page = _pages[_currentPage];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => LocalMockupPreviewScreen(
              selectedCodes: widget.codes,
              allCodes: widget.allCodes,
              trips: widget.trips,
              initialTemplate: CardTemplateType.grid,
              confirmedAspectRatio: merchBackCardAspectRatio(
                CardTemplateType.grid,
              ),
              transparentBackground: true,
              initialColour: widget.initialColour,
              titleOverride: widget.titleOverride,
              subtitleOverride: widget.subtitleOverride,
              clipShape: page.shape,
              flagRepeatCount: _rowCount,
              clipCode: page.clipCode,
              rowCount: _rowCount,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentShape = _pages[_currentPage].shape;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose your style')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Carousel ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return _ClipVariantCard(
                    key: ValueKey(
                      '${page.shape.name}_${_rowCount}_${widget.codes.hashCode}_${widget.initialColour}',
                    ),
                    codes: widget.codes,
                    trips: widget.trips,
                    clipShape: page.shape,
                    flagRepeatCount: _rowCount,
                    rowCount: _rowCount,
                    clipCode: page.clipCode,
                    titleOverride: widget.titleOverride,
                    subtitleOverride: widget.subtitleOverride,
                    colour: widget.initialColour,
                  );
                },
              ),
            ),

            // ── Page dots ───────────────────────────────────────────────────
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          i == _currentPage
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),

            // ── Shape label ─────────────────────────────────────────────────
            const SizedBox(height: 6),
            Text(
              _pages[_currentPage].label,
              style: theme.textTheme.labelLarge,
            ),

            // ── Rows slider ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Rows', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  Text(
                    '$_rowCount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _rowCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: _onSliderChanged,
                    ),
                  ),
                ],
              ),
            ),

            // ── CTA ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _navigateToPreview,
                  child: Text(
                    'Design This Shirt →',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),

            // ── Invisible shape label used by M171 sentinel ──────────────────
            // Note: when M171 appends pages for countryOutline/continentOutline,
            // this Text is used to identify the current selection.
            Text(
              currentShape.name,
              style: const TextStyle(fontSize: 0, height: 0),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ClipVariantCard ─────────────────────────────────────────────────────────

enum _CardState { loading, ready, error }

/// A single page in the [FlagShapeCustomiseScreen] carousel.
///
/// Renders the flag grid artwork with [clipShape] applied and composites it
/// onto a shirt mockup. Re-renders when [flagRepeatCount] changes (the parent
/// passes a new key via ValueKey).
class _ClipVariantCard extends StatefulWidget {
  const _ClipVariantCard({
    super.key,
    required this.codes,
    required this.trips,
    required this.clipShape,
    required this.flagRepeatCount,
    required this.rowCount,
    this.clipCode,
    this.titleOverride,
    this.subtitleOverride,
    this.colour,
  });

  final List<String> codes;
  final List<TripRecord> trips;
  final GridClipShape clipShape;
  final int flagRepeatCount;
  final int rowCount;
  final String? clipCode;
  final String? titleOverride;
  final String? subtitleOverride;
  /// Shirt colour used for the preview mockup. Defaults to 'Black'.
  final String? colour;

  @override
  State<_ClipVariantCard> createState() => _ClipVariantCardState();
}

class _ClipVariantCardState extends State<_ClipVariantCard> {
  _CardState _state = _CardState.loading;
  ui.Image? _artImage;
  ui.Image? _shirtImage;
  int _renderedRepeatCount = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _artImage?.dispose();
    _shirtImage?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!mounted) return;
    final ctx = context;
    final repeatCount = widget.flagRepeatCount;

    if (repeatCount == _renderedRepeatCount && _state == _CardState.ready) {
      return; // already rendered for this repeat count
    }

    setState(() => _state = _CardState.loading);

    try {
      // Each shape page (Grid, Heart, Circle, country outline, animal /
      // plant / landmark silhouette) has its own natural proportions for the
      // same country — a tall kangaroo and a wide opera house shouldn't
      // share one fixed landscape canvas. Fall back to the template default
      // for shapes with no country-specific image (none/heart/circle).
      final isPortrait = await isPortraitForClipShape(
        widget.clipShape,
        widget.clipCode,
      );
      if (!mounted) return;
      final aspectRatio = isPortrait == null
          ? merchBackCardAspectRatio(CardTemplateType.grid)
          : (isPortrait ? kPortraitCardAspectRatio : kLandscapeCardAspectRatio);
      final artResult = await CardImageRenderer.render(
        ctx,
        CardTemplateType.grid,
        codes: widget.codes,
        trips: widget.trips,
        transparentBackground: true,
        pixelRatio: 2.0,
        cardAspectRatio: aspectRatio,
        clipShape: widget.clipShape,
        flagRepeatCount: repeatCount,
        clipCode: widget.clipCode,
        rowCount: widget.rowCount,
        textColor: Colors.white,
        titleOverride: widget.titleOverride,
        subtitleOverride: widget.subtitleOverride,
      );
      if (!mounted) return;

      final spec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: widget.colour ?? 'Black',
        placement: 'back',
      );
      final shirtData = await rootBundle.load(spec.assetPath);
      if (!mounted) return;

      Future<ui.Image> decode(Uint8List bytes) async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }

      final art = await decode(artResult.bytes);
      final shirt = await decode(shirtData.buffer.asUint8List());
      if (!mounted) {
        art.dispose();
        shirt.dispose();
        return;
      }

      setState(() {
        _artImage?.dispose();
        _artImage = art;
        _shirtImage?.dispose();
        _shirtImage = shirt;
        _renderedRepeatCount = repeatCount;
        _state = _CardState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _CardState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: switch (_state) {
        _CardState.loading => const Center(child: CircularProgressIndicator()),
        _CardState.error => Center(
          child: Text(
            'Failed to render',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        _CardState.ready => _buildMockup(context),
      },
    );
  }

  Widget _buildMockup(BuildContext context) {
    final art = _artImage;
    final shirt = _shirtImage;
    if (art == null || shirt == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final spec = ProductMockupSpecs.specsFor(
      MerchProduct.tshirt,
      colour: 'Black',
      placement: 'back',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: LocalMockupPainter(
            productImage: shirt,
            artworkImage: art,
            spec: spec,
            artworkBlendMode: BlendMode.srcOver,
          ),
        );
      },
    );
  }
}
