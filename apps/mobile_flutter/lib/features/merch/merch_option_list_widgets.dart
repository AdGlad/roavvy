import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'merch_exclusive_design.dart';
import 'shopify_pricing_repository.dart';

import '../cards/card_editor_screen.dart';
import '../cards/card_image_renderer.dart';
import '../cards/landmark_image_service.dart';
import 'local_mockup_painter.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_share_exporter.dart';
import 'merch_template_ranker.dart';
import 'merch_variant_lookup.dart';
import 'product_mockup_specs.dart';
import 'pulse_merch_option.dart';

// ── List item types ────────────────────────────────────────────────────────────

/// Base type for items in the merch option list.
///
/// Used by both [PulseMerchOptionScreen] (Memory Pulse entry) and
/// [AchievementMerchOptionScreen] (achievement entry) — ADR-149.
sealed class MerchOptionListItem {}

class MerchOptionHeaderItem extends MerchOptionListItem {
  MerchOptionHeaderItem(this.label);
  final String label;
}

class MerchOptionEntry extends MerchOptionListItem {
  MerchOptionEntry(this.option);
  final PulseMerchOption option;
}

class MerchOptionCustomiseEntry extends MerchOptionListItem {
  MerchOptionCustomiseEntry({required this.template, required this.label});
  final CardTemplateType template;
  final String label;
}

/// The top-ranked option, rendered as a larger [MerchOptionFeaturedCard].
class MerchOptionFeaturedEntry extends MerchOptionListItem {
  MerchOptionFeaturedEntry(this.option);
  final PulseMerchOption option;
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

/// Human-readable label for a [CardTemplateType].
String merchTemplateLabel(CardTemplateType t) => switch (t) {
  CardTemplateType.passport => 'Passport',
  CardTemplateType.grid => 'Flags',
  CardTemplateType.timeline => 'Tour Dates',
  CardTemplateType.heart => 'Heart Flags',
  CardTemplateType.frontRibbon => 'Ribbon',
  CardTemplateType.typography => 'Typography',
  CardTemplateType.badge => 'Explorer Badge',
  CardTemplateType.wordCloud => 'Word Cloud',
  CardTemplateType.landmark => 'Landmark',
};

/// Suggests a suitable shirt colour for a given template and density (ADR-154).
///
/// Returned strings match entries in [tshirtColors] from `merch_variant_lookup.dart`.
/// The optional [density] param enables density-aware colour selection; callers
/// that don't supply it default to [MerchDensityClass.medium] behaviour.
String merchSuggestShirtColor(
  CardTemplateType template, {
  MerchDensityClass density = MerchDensityClass.medium,
}) {
  final isSoloOrSmall =
      density == MerchDensityClass.solo || density == MerchDensityClass.small;
  final isLargeOrMassive =
      density == MerchDensityClass.large ||
      density == MerchDensityClass.massive;

  return switch (template) {
    CardTemplateType.passport => isSoloOrSmall ? 'White' : 'Black',
    CardTemplateType.grid => isLargeOrMassive ? 'Navy' : 'Black',
    CardTemplateType.badge => 'Navy',
    _ => 'Black',
  };
}

/// Auto-tunes jitter + size for passport templates based on stamp count
/// (trips × 2 for entry+exit, or trips × 1 for entryOnly) — 5-tier model
/// matching [MerchDensityClass] (ADR-154).
({double jitter, double size}) merchAutoTuneStamps(int stampCount) {
  if (stampCount <= 2) return (jitter: 0.00, size: 0.55);
  if (stampCount <= 6) return (jitter: 0.12, size: 0.70);
  if (stampCount <= 14) return (jitter: 0.22, size: 0.82);
  if (stampCount <= 30) return (jitter: 0.33, size: 0.88);
  return (jitter: 0.40, size: 0.72);
}

/// Auto-tunes jitter + size for grid / flags / timeline based on country count
/// — 5-tier model matching [MerchDensityClass] (ADR-154).
({double jitter, double size}) merchAutoTuneCodes(int codeCount) {
  if (codeCount <= 1) return (jitter: 0.00, size: 1.20);
  if (codeCount <= 5) return (jitter: 0.15, size: 1.00);
  if (codeCount <= 15) return (jitter: 0.28, size: 0.85);
  if (codeCount <= 50) return (jitter: 0.38, size: 0.72);
  return (jitter: 0.42, size: 0.58);
}

/// Aspect ratio for the back-card artwork based on template type.
///
/// Flag-based (grid) and horizontal timeline designs render better in landscape
/// so they fill the shirt back correctly without excess letterboxing.
/// Passport designs remain portrait to match stamp page proportions.
double merchBackCardAspectRatio(CardTemplateType template) =>
    switch (template) {
      CardTemplateType.grid || CardTemplateType.timeline => 3.0 / 2.0,
      CardTemplateType.badge ||
      CardTemplateType.typography ||
      CardTemplateType.wordCloud => 1.0,
      _ => 2.0 / 3.0, // passport, heart, frontRibbon — portrait
    };

// ── Constants ──────────────────────────────────────────────────────────────────

const double kMerchThumbW = 72.0;
const double kMerchThumbH = 92.0;

// ── Section header ─────────────────────────────────────────────────────────────

/// Section header label for grouped merch option lists.
class MerchOptionSectionHeader extends StatelessWidget {
  const MerchOptionSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Option card ────────────────────────────────────────────────────────────────

enum _MerchGenState { loading, ready, error }

/// Renders a single [PulseMerchOption] as a tappable card with front + back
/// shirt mockup thumbnails. Navigates to [LocalMockupPreviewScreen] on tap.
///
/// Used by both the Memory Pulse and Achievement merch option screens (ADR-149).
class MerchOptionCard extends StatefulWidget {
  const MerchOptionCard({
    super.key,
    required this.option,
    required this.allCodes,
    this.index = 0,
  });

  final PulseMerchOption option;
  final List<String> allCodes;

  /// List position used to stagger the entry animation (ADR-155).
  final int index;

  @override
  State<MerchOptionCard> createState() => _MerchOptionCardState();
}

class _MerchOptionCardState extends State<MerchOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  _MerchGenState _state = _MerchGenState.loading;
  Uint8List? _artworkBytes;
  ui.Image? _backArtImage;
  ui.Image? _frontRibbonImage;
  ui.Image? _backShirtImage;
  ui.Image? _frontShirtImage;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _animCtrl.forward();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _backArtImage?.dispose();
    _frontRibbonImage?.dispose();
    _backShirtImage?.dispose();
    _frontShirtImage?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!mounted) return;
    final opt = widget.option;

    // For the Landmark template, always open Image Playground so the user can
    // generate (or regenerate) the collage before the shirt preview renders.
    // Cancel keeps any existing cached image; confirm replaces it.
    if (opt.template == CardTemplateType.landmark &&
        await LandmarkImageService.isAvailable()) {
      if (!mounted) return;
      await LandmarkImageService.generateCollage(opt.codes);
      if (!mounted) return;
    }

    final stampCount =
        opt.template == CardTemplateType.passport
            ? opt.trips.length * (opt.entryOnly ? 1 : 2)
            : opt.codes.length;
    final aspectRatio = merchBackCardAspectRatio(opt.template);
    final orientation = aspectRatio > 1.0 ? 'landscape(3:2)' : 'portrait(2:3)';
    debugPrint(
      '[merch_option] ${opt.id}'
      ' | template=${opt.template.name}'
      ' | scope=${opt.scope.name}'
      ' | items=$stampCount'
      ' | size=${opt.stampSizeMultiplier.toStringAsFixed(2)}'
      ' | jitter=${opt.jitter.toStringAsFixed(2)}'
      ' | orientation=$orientation',
    );

    try {
      final artFuture = CardImageRenderer.render(
        context,
        opt.template,
        codes: opt.codes,
        trips: opt.trips,
        transparentBackground: true,
        entryOnly: opt.entryOnly,
        stampJitterFactor: opt.jitter,
        stampSizeMultiplier: opt.stampSizeMultiplier,
        pixelRatio: 2.0,
        cardAspectRatio: aspectRatio,
        titleOverride: opt.title,
        subtitleOverride: opt.artworkSubtitle,
      );
      final ribbonFuture = CardImageRenderer.render(
        context,
        CardTemplateType.frontRibbon,
        codes: opt.codes,
        pixelRatio: 2.0,
      );

      final artResult = await artFuture;
      if (!mounted) return;
      final ribbonResult = await ribbonFuture;
      if (!mounted) return;

      // Load shirt assets directly from bundle (not the singleton cache, to
      // avoid lifecycle issues when LocalMockupPreviewScreen later disposes it).
      final backSpec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'back',
      );
      final frontSpec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'front',
        frontPosition: 'center',
      );

      final backData = await rootBundle.load(backSpec.assetPath);
      if (!mounted) return;
      final frontData = await rootBundle.load(frontSpec.assetPath);
      if (!mounted) return;

      Future<ui.Image> decode(Uint8List bytes) async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }

      final backArt = await decode(artResult.bytes);
      final frontRib = await decode(ribbonResult.bytes);
      final backShirt = await decode(backData.buffer.asUint8List());
      final frontShirt = await decode(frontData.buffer.asUint8List());

      if (!mounted) {
        backArt.dispose();
        frontRib.dispose();
        backShirt.dispose();
        frontShirt.dispose();
        return;
      }

      setState(() {
        _artworkBytes = artResult.bytes;
        _backArtImage?.dispose();
        _backArtImage = backArt;
        _frontRibbonImage?.dispose();
        _frontRibbonImage = frontRib;
        _backShirtImage?.dispose();
        _backShirtImage = backShirt;
        _frontShirtImage?.dispose();
        _frontShirtImage = frontShirt;
        _state = _MerchGenState.ready;
      });
    } catch (e) {
      debugPrint('[merch_option] ${opt.id} failed: $e');
      if (!mounted) return;
      setState(() => _state = _MerchGenState.error);
    }
  }

  void _navigate() {
    final enabled = ProviderScope.containerOf(context)
        .read(purchasingEnabledForTemplateProvider(widget.option.template));
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The store is temporarily unavailable. Check back soon.',
          ),
        ),
      );
      return;
    }
    final bytes = _artworkBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => LocalMockupPreviewScreen(
              selectedCodes: widget.option.codes,
              allCodes: widget.allCodes,
              trips: widget.option.trips,
              artworkImageBytes: bytes,
              initialTemplate: widget.option.template,
              confirmedAspectRatio: merchBackCardAspectRatio(
                widget.option.template,
              ),
              confirmedEntryOnly: widget.option.entryOnly,
              transparentBackground: true,
              stampJitterFactor: widget.option.jitter,
              stampSizeMultiplier: widget.option.stampSizeMultiplier,
              initialColour: widget.option.suggestedShirtColor,
              titleOverride: widget.option.title,
              subtitleOverride: widget.option.artworkSubtitle,
            ),
      ),
    );
  }

  Future<void> _shareDesign() async {
    final bytes = _artworkBytes;
    if (bytes == null) return;
    final n = widget.option.codes.length;
    final shareText =
        '${widget.option.title} — $n '
        '${n == 1 ? "country" : "countries"} I\'ve visited, designed with Roavvy 🌍';
    await MerchShareExporter.share(
      bytes,
      title: widget.option.title,
      shareText: shareText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _state == _MerchGenState.ready ? _navigate : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildThumbnailPair(),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfo()),
                  if (_state == _MerchGenState.ready)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPair() {
    return switch (_state) {
      _MerchGenState.loading => _loadingThumbs(),
      _MerchGenState.error => _errorThumb(),
      _MerchGenState.ready => _readyThumbs(),
    };
  }

  Widget _loadingThumbs() {
    return SizedBox(
      width: kMerchThumbW * 2 + 8,
      height: kMerchThumbH,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _errorThumb() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: kMerchThumbW * 2 + 8,
      height: kMerchThumbH,
      child: Container(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: cs.onSurface.withValues(alpha: 0.30),
              size: 22,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                setState(() => _state = _MerchGenState.loading);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _generate(),
                );
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readyThumbs() {
    final backSpec = ProductMockupSpecs.specsFor(
      MerchProduct.tshirt,
      colour: 'Black',
      placement: 'back',
    );
    final frontSpec = ProductMockupSpecs.specsFor(
      MerchProduct.tshirt,
      colour: 'Black',
      placement: 'front',
      frontPosition: 'center',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: kMerchThumbW,
              height: kMerchThumbH,
              child: CustomPaint(
                painter: LocalMockupPainter(
                  artworkImage: _backArtImage,
                  productImage: _backShirtImage,
                  spec: backSpec,
                  artworkBlendMode: ui.BlendMode.srcOver,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: kMerchThumbW,
              height: kMerchThumbH,
              child: CustomPaint(
                painter: LocalMockupPainter(
                  artworkImage: _frontRibbonImage,
                  productImage: _frontShirtImage,
                  spec: frontSpec,
                  artworkBlendMode: ui.BlendMode.srcOver,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: kMerchThumbW,
              child: const Center(
                child: Text(
                  'Back',
                  style: TextStyle(color: Colors.white30, fontSize: 9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: kMerchThumbW,
              child: const Center(
                child: Text(
                  'Front',
                  style: TextStyle(color: Colors.white30, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfo() {
    final cs = Theme.of(context).colorScheme;
    if (_state == _MerchGenState.loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Generating shirt idea...',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.54),
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (_state == _MerchGenState.error) {
      return Text(
        'Could not generate preview',
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.54),
          fontSize: 12,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.option.title,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.option.description,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.60),
            fontSize: 11,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.option.contextLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.option.contextLabel!,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.38),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.option.templateLabel,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.54),
                  fontSize: 10,
                ),
              ),
            ),
            const Spacer(),
            if (_state == _MerchGenState.ready)
              GestureDetector(
                onTap: _shareDesign,
                child: Icon(
                  Icons.ios_share_rounded,
                  color: cs.onSurface.withValues(alpha: 0.38),
                  size: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const _MerchFromPriceText(fontSize: 10),
      ],
    );
  }
}

// ── Featured option card ───────────────────────────────────────────────────────

/// Larger, highlighted card for the top-ranked merch option (ADR-155).
///
/// Uses a 2:3 artwork preview instead of the thumbnail pair, with the
/// identity-driven title prominently displayed.
class MerchOptionFeaturedCard extends StatefulWidget {
  const MerchOptionFeaturedCard({
    super.key,
    required this.option,
    required this.allCodes,
  });

  final PulseMerchOption option;
  final List<String> allCodes;

  @override
  State<MerchOptionFeaturedCard> createState() =>
      _MerchOptionFeaturedCardState();
}

class _MerchOptionFeaturedCardState extends State<MerchOptionFeaturedCard>
    with SingleTickerProviderStateMixin {
  _MerchGenState _state = _MerchGenState.loading;
  Uint8List? _artworkBytes;
  ui.Image? _backArtImage;
  ui.Image? _backShirtImage;

  late final AnimationController _animCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _backArtImage?.dispose();
    _backShirtImage?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!mounted) return;
    final opt = widget.option;
    final aspectRatio = merchBackCardAspectRatio(opt.template);
    try {
      final artResult = await CardImageRenderer.render(
        context,
        opt.template,
        codes: opt.codes,
        trips: opt.trips,
        transparentBackground: true,
        entryOnly: opt.entryOnly,
        stampJitterFactor: opt.jitter,
        stampSizeMultiplier: opt.stampSizeMultiplier,
        pixelRatio: 2.5,
        cardAspectRatio: aspectRatio,
        titleOverride: opt.title,
        subtitleOverride: opt.artworkSubtitle,
      );
      if (!mounted) return;

      final backSpec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: opt.suggestedShirtColor ?? 'Black',
        placement: 'back',
      );
      final backData = await rootBundle.load(backSpec.assetPath);
      if (!mounted) return;

      Future<ui.Image> decode(Uint8List bytes) async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }

      final backArt = await decode(artResult.bytes);
      final backShirt = await decode(backData.buffer.asUint8List());

      if (!mounted) {
        backArt.dispose();
        backShirt.dispose();
        return;
      }

      setState(() {
        _artworkBytes = artResult.bytes;
        _backArtImage?.dispose();
        _backArtImage = backArt;
        _backShirtImage?.dispose();
        _backShirtImage = backShirt;
        _state = _MerchGenState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _MerchGenState.error);
    }
  }

  void _navigate() {
    final enabled = ProviderScope.containerOf(context)
        .read(purchasingEnabledForTemplateProvider(widget.option.template));
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The store is temporarily unavailable. Check back soon.',
          ),
        ),
      );
      return;
    }
    final bytes = _artworkBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => LocalMockupPreviewScreen(
              selectedCodes: widget.option.codes,
              allCodes: widget.allCodes,
              trips: widget.option.trips,
              artworkImageBytes: bytes,
              initialTemplate: widget.option.template,
              confirmedAspectRatio: merchBackCardAspectRatio(
                widget.option.template,
              ),
              confirmedEntryOnly: widget.option.entryOnly,
              transparentBackground: true,
              stampJitterFactor: widget.option.jitter,
              stampSizeMultiplier: widget.option.stampSizeMultiplier,
              initialColour: widget.option.suggestedShirtColor,
              titleOverride: widget.option.title,
              subtitleOverride: widget.option.artworkSubtitle,
            ),
      ),
    );
  }

  Future<void> _shareDesign() async {
    final bytes = _artworkBytes;
    if (bytes == null) return;
    final n = widget.option.codes.length;
    final shareText =
        '${widget.option.title} — $n '
        '${n == 1 ? "country" : "countries"} I\'ve visited, designed with Roavvy 🌍';
    await MerchShareExporter.share(
      bytes,
      title: widget.option.title,
      shareText: shareText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _state == _MerchGenState.ready ? _navigate : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreview(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Builder(
                    builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFD700,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  '✦ Best Match',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.option.title,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.option.description,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.60),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          const _MerchFromPriceText(fontSize: 11),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.onSurface.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Design This Shirt',
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    const h = 160.0;
    final cs = Theme.of(context).colorScheme;
    if (_state == _MerchGenState.loading) {
      return Container(
        height: h,
        color: cs.onSurface.withValues(alpha: 0.04),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_state == _MerchGenState.error) {
      return Container(
        height: h,
        color: cs.onSurface.withValues(alpha: 0.04),
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: cs.onSurface.withValues(alpha: 0.30),
            size: 28,
          ),
        ),
      );
    }
    final backSpec = ProductMockupSpecs.specsFor(
      MerchProduct.tshirt,
      colour: widget.option.suggestedShirtColor ?? 'Black',
      placement: 'back',
    );
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: LocalMockupPainter(
              artworkImage: _backArtImage,
              productImage: _backShirtImage,
              spec: backSpec,
              artworkBlendMode: ui.BlendMode.srcOver,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _shareDesign,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.ios_share_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom option card ─────────────────────────────────────────────────────────

/// "Customise" row that opens [CardEditorScreen] for a given template.
///
/// The `hero`, `allTrips`, and `allCodes` params from the original
/// `_CustomOptionCard` were never read inside `onTap` (which only used
/// `template`), so they are removed here (ADR-149).
class MerchOptionCustomCard extends StatelessWidget {
  const MerchOptionCustomCard({
    super.key,
    required this.template,
    required this.label,
  });

  final CardTemplateType template;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CardEditorScreen(templateType: template),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: cs.onSurface.withValues(alpha: 0.54),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose countries, years, and layout',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.54),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Alternatives strip ─────────────────────────────────────────────────────────

/// Horizontally scrollable row of compact shirt thumbnails shown below the
/// featured card — one per alternative [PulseMerchOption] (M139).
///
/// Each thumb renders the back-shirt mockup only (80×100 px) with the template
/// label below. Tapping navigates to [LocalMockupPreviewScreen].
class MerchOptionAlternativesStrip extends StatelessWidget {
  const MerchOptionAlternativesStrip({
    super.key,
    required this.options,
    required this.allCodes,
  });

  final List<PulseMerchOption> options;
  final List<String> allCodes;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder:
            (ctx, i) =>
                _AlternativeThumb(option: options[i], allCodes: allCodes),
      ),
    );
  }
}

class _AlternativeThumb extends StatefulWidget {
  const _AlternativeThumb({required this.option, required this.allCodes});

  final PulseMerchOption option;
  final List<String> allCodes;

  @override
  State<_AlternativeThumb> createState() => _AlternativeThumbState();
}

class _AlternativeThumbState extends State<_AlternativeThumb> {
  _MerchGenState _state = _MerchGenState.loading;
  Uint8List? _artworkBytes;
  ui.Image? _backArtImage;
  ui.Image? _backShirtImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _backArtImage?.dispose();
    _backShirtImage?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!mounted) return;
    final opt = widget.option;
    try {
      final aspectRatio = merchBackCardAspectRatio(opt.template);
      final artResult = await CardImageRenderer.render(
        context,
        opt.template,
        codes: opt.codes,
        trips: opt.trips,
        transparentBackground: true,
        entryOnly: opt.entryOnly,
        stampJitterFactor: opt.jitter,
        stampSizeMultiplier: opt.stampSizeMultiplier,
        pixelRatio: 1.5,
        cardAspectRatio: aspectRatio,
        titleOverride: opt.title,
        subtitleOverride: opt.artworkSubtitle,
      );
      if (!mounted) return;

      final backSpec = ProductMockupSpecs.specsFor(
        MerchProduct.tshirt,
        colour: 'Black',
        placement: 'back',
      );
      final backData = await rootBundle.load(backSpec.assetPath);
      if (!mounted) return;

      Future<ui.Image> decode(Uint8List bytes) async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }

      final backArt = await decode(artResult.bytes);
      final backShirt = await decode(backData.buffer.asUint8List());

      if (!mounted) {
        backArt.dispose();
        backShirt.dispose();
        return;
      }

      setState(() {
        _artworkBytes = artResult.bytes;
        _backArtImage?.dispose();
        _backArtImage = backArt;
        _backShirtImage?.dispose();
        _backShirtImage = backShirt;
        _state = _MerchGenState.ready;
      });
    } catch (e) {
      debugPrint('[alt_thumb] ${opt.id} failed: $e');
      if (!mounted) return;
      setState(() => _state = _MerchGenState.error);
    }
  }

  void _navigate() {
    final enabled = ProviderScope.containerOf(context)
        .read(purchasingEnabledForTemplateProvider(widget.option.template));
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The store is temporarily unavailable. Check back soon.',
          ),
        ),
      );
      return;
    }
    final bytes = _artworkBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => LocalMockupPreviewScreen(
              selectedCodes: widget.option.codes,
              allCodes: widget.allCodes,
              trips: widget.option.trips,
              artworkImageBytes: bytes,
              initialTemplate: widget.option.template,
              confirmedAspectRatio: merchBackCardAspectRatio(
                widget.option.template,
              ),
              confirmedEntryOnly: widget.option.entryOnly,
              transparentBackground: true,
              stampJitterFactor: widget.option.jitter,
              stampSizeMultiplier: widget.option.stampSizeMultiplier,
              initialColour: widget.option.suggestedShirtColor,
              titleOverride: widget.option.title,
              subtitleOverride: widget.option.artworkSubtitle,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const w = 80.0;
    const h = 100.0;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _state == _MerchGenState.ready ? _navigate : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: w,
              height: h,
              child: switch (_state) {
                _MerchGenState.loading => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
                ),
                _MerchGenState.error => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.error_outline,
                    color: cs.onSurface.withValues(alpha: 0.24),
                    size: 20,
                  ),
                ),
                _MerchGenState.ready => CustomPaint(
                  painter: LocalMockupPainter(
                    artworkImage: _backArtImage,
                    productImage: _backShirtImage,
                    spec: ProductMockupSpecs.specsFor(
                      MerchProduct.tshirt,
                      colour: 'Black',
                      placement: 'back',
                    ),
                    artworkBlendMode: ui.BlendMode.srcOver,
                  ),
                ),
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            merchTemplateLabel(widget.option.template),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.38),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── MerchLockedDesignCard ─────────────────────────────────────────────────────

/// Displays an exclusive design that is locked or unlocked for the current user.
///
/// Locked: dimmed silhouette, lock icon, progress bar, "N more to unlock" label.
/// Unlocked: gold border, "✦ Unlocked for you" badge, tappable to design.
///
/// The caller must supply [onUnlockedTap] so this widget does not need provider
/// access (navigation context lives in the option screen).
class MerchLockedDesignCard extends StatelessWidget {
  const MerchLockedDesignCard({
    super.key,
    required this.design,
    required this.ctx,
    this.onUnlockedTap,
  });

  final MerchExclusiveDesign design;
  final MerchUnlockContext ctx;

  /// Called when the user taps an unlocked design. Null for locked designs
  /// (tapping a locked design shows a SnackBar instead).
  final VoidCallback? onUnlockedTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = design.isUnlocked(ctx);
    final theme = Theme.of(context);
    final remaining = design.remaining(ctx);

    return GestureDetector(
      onTap: () {
        if (unlocked) {
          onUnlockedTap?.call();
        } else {
          final unit = design.unlockCondition is ContinentCountCondition
              ? (remaining == 1 ? 'continent' : 'continents')
              : (remaining == 1 ? 'country' : 'countries');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Visit $remaining more $unit to unlock "${design.label}"',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: unlocked
              ? Border.all(color: const Color(0xFFFFD700), width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon/lock + label + unlocked badge
              Row(
                children: [
                  Text(design.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      design.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: unlocked
                            ? null
                            : theme.colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                  if (unlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        '✦ Unlocked for you',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Description
              Text(
                design.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!unlocked) ...[
                const SizedBox(height: 10),
                // Progress bar
                Builder(
                  builder: (context) {
                    final condition = design.unlockCondition;
                    final target = condition is CountryCountCondition
                        ? condition.target
                        : (condition as ContinentCountCondition).target;
                    final current = target - remaining;
                    final progress = (current / target).clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFFFD700),
                          ),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$current/$target — $remaining more to unlock',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared price display ───────────────────────────────────────────────────────

/// Displays the "from `price`" label for the t-shirt in the buyer's currency.
///
/// Fetches live pricing from Shopify via [shopifyPricingProvider] and falls
/// back to the hardcoded GBP price while loading or on error.
class _MerchFromPriceText extends ConsumerWidget {
  const _MerchFromPriceText({required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(shopifyPricingProvider);
    final priceStr = prices.whenOrNull(data: (p) => p.tshirtFromPrice) ??
        MerchProduct.tshirt.fromPrice;
    return Text(
      'from $priceStr',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        fontSize: fontSize,
      ),
    );
  }
}
