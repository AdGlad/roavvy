import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

import '../cards/card_image_renderer.dart';
import '../cards/flag_grid_layout_engine.dart';
import 'local_mockup_painter.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_option_list_widgets.dart';
import 'merch_variant_lookup.dart';
import 'product_mockup_specs.dart';

// ── Smart defaults ─────────────────────────────────────────────────────────────

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
  return math.min(9, base + clipBoost);
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

  @override
  State<FlagShapeCustomiseScreen> createState() =>
      _FlagShapeCustomiseScreenState();
}

// ── Page definition ────────────────────────────────────────────────────────────

const _kPages = [
  (shape: GridClipShape.none, label: 'Grid'),
  (shape: GridClipShape.heart, label: 'Heart'),
  (shape: GridClipShape.circle, label: 'Circle'),
];

class _FlagShapeCustomiseScreenState extends State<FlagShapeCustomiseScreen> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  double _repeatCount = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    // Set smart default based on initial shape (none).
    _repeatCount = merchDefaultRepeatCount(
      widget.codes.length,
      GridClipShape.none,
    ).toDouble();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      // Recalculate smart default for new shape.
      final newShape = _kPages[page].shape;
      final defaultRepeat = merchDefaultRepeatCount(
        widget.codes.length,
        newShape,
      ).toDouble();
      // Only auto-update if the user hasn't moved the slider
      // from the previous page's default.
      final prevDefault = merchDefaultRepeatCount(
        widget.codes.length,
        _currentPage < _kPages.length ? _kPages[_currentPage].shape : newShape,
      ).toDouble();
      if (_repeatCount == prevDefault) {
        _repeatCount = defaultRepeat;
      }
    });
  }

  void _onSliderChanged(double val) {
    setState(() => _repeatCount = val.roundToDouble());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {}); // triggers rebuild → pages re-render
    });
  }

  void _navigateToPreview() {
    final shape = _kPages[_currentPage].shape;
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
              clipShape: shape,
              flagRepeatCount: _repeatCount.round(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeatInt = _repeatCount.round();
    final currentShape = _kPages[_currentPage].shape;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose your style')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Carousel ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _kPages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, i) {
                  final page = _kPages[i];
                  return _ClipVariantCard(
                    key: ValueKey(
                      '${page.shape.name}_${repeatInt}_${widget.codes.hashCode}',
                    ),
                    codes: widget.codes,
                    trips: widget.trips,
                    clipShape: page.shape,
                    flagRepeatCount: repeatInt,
                    titleOverride: widget.titleOverride,
                    subtitleOverride: widget.subtitleOverride,
                  );
                },
              ),
            ),

            // ── Page dots ───────────────────────────────────────────────────
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _kPages.length; i++)
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
              _kPages[_currentPage].label,
              style: theme.textTheme.labelLarge,
            ),

            // ── Flag count slider ────────────────────────────────────────────
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Flag count', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  Text(
                    '×$repeatInt',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _repeatCount,
                      min: 1,
                      max: 9,
                      divisions: 8,
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
    this.titleOverride,
    this.subtitleOverride,
  });

  final List<String> codes;
  final List<TripRecord> trips;
  final GridClipShape clipShape;
  final int flagRepeatCount;
  final String? titleOverride;
  final String? subtitleOverride;

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
      final artResult = await CardImageRenderer.render(
        ctx,
        CardTemplateType.grid,
        codes: widget.codes,
        trips: widget.trips,
        transparentBackground: true,
        pixelRatio: 2.0,
        cardAspectRatio: merchBackCardAspectRatio(CardTemplateType.grid),
        clipShape: widget.clipShape,
        flagRepeatCount: repeatCount,
        titleOverride: widget.titleOverride,
        subtitleOverride: widget.subtitleOverride,
      );
      if (!mounted) return;

      final spec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
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
            artworkBlendMode: BlendMode.multiply,
          ),
        );
      },
    );
  }
}
