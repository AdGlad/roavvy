import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../cards/card_image_renderer.dart';
import 'local_mockup_painter.dart';
import 'local_mockup_preview_screen.dart';
import '../cards/card_editor_screen.dart';
import 'merch_variant_lookup.dart';
import 'product_mockup_specs.dart';
import 'pulse_merch_option.dart';

// ── List item types ────────────────────────────────────────────────────────────

sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  _HeaderItem(this.label);
  final String label;
}

class _OptionItem extends _ListItem {
  _OptionItem(this.option);
  final PulseMerchOption option;
}

class _CustomiseItem extends _ListItem {
  _CustomiseItem({required this.template, required this.label});
  final CardTemplateType template;
  final String label;
}

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Shown between "Print on a t-shirt" (Daily Memory Pulse) and
/// [LocalMockupPreviewScreen].
///
/// Displays ~15 pre-scoped merch options grouped by card type (Passport, Flags,
/// Tour Dates), each pre-rendered with matching front + back shirt mockups.
/// Each option uses a consistent scope for both artwork sides, fixing the
/// scope-mismatch bug.
class PulseMerchOptionScreen extends StatelessWidget {
  const PulseMerchOptionScreen({
    super.key,
    required this.hero,
    required this.allTrips,
    required this.allVisits,
  });

  final HeroImage hero;
  final List<TripRecord> allTrips;
  final List<EffectiveVisitedCountry> allVisits;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _templateLabel(CardTemplateType t) => switch (t) {
        CardTemplateType.passport => 'Passport',
        CardTemplateType.grid => 'Flags',
        CardTemplateType.timeline => 'Tour Dates',
        CardTemplateType.heart => 'Heart Flags',
        CardTemplateType.frontRibbon => 'Ribbon',
      };

  /// Auto-tunes for passport templates based on **stamp count**
  /// (trips × 2 for entry+exit, or trips × 1 for entryOnly).
  ///
  /// Small counts get smaller stamps to avoid 100 % overlap on the
  /// fixed-ceiling radius (100 px). Large counts pack tightly.
  static ({double jitter, double size}) _autoTuneStamps(int stampCount) {
    if (stampCount <= 2) return (jitter: 0.05, size: 0.60);
    if (stampCount <= 4) return (jitter: 0.15, size: 0.75);
    if (stampCount <= 8) return (jitter: 0.25, size: 0.85);
    if (stampCount <= 16) return (jitter: 0.35, size: 0.90);
    return (jitter: 0.40, size: 0.75);
  }

  /// Auto-tunes for grid / flags / timeline based on **country/code count**.
  static ({double jitter, double size}) _autoTuneCodes(int codeCount) {
    if (codeCount <= 3) return (jitter: 0.15, size: 1.00);
    if (codeCount <= 8) return (jitter: 0.25, size: 0.90);
    if (codeCount <= 20) return (jitter: 0.35, size: 0.80);
    return (jitter: 0.40, size: 0.65);
  }

  List<PulseMerchOption> _optionsFor(
    CardTemplateType template, {
    required String countryName,
    required int year,
    required TripRecord? heroTrip,
    required List<TripRecord> yearTrips,
    required List<String> yearCodes,
    required List<TripRecord> countryTrips,
    required List<String> allCodes,
  }) {
    final prefix = _templateLabel(template);
    final isPassport = template == CardTemplateType.passport;

    // Helper: pick the right tuning function for this template type.
    ({double jitter, double size}) tune(
        List<TripRecord> trips, List<String> codes) {
      if (isPassport) {
        // Stamp count = entry + exit per trip (entryOnly defaults to false).
        return _autoTuneStamps(trips.length * 2);
      }
      return _autoTuneCodes(codes.length);
    }

    final options = <PulseMerchOption>[];

    // 1. This trip
    final tripList = heroTrip != null ? [heroTrip] : const <TripRecord>[];
    final t1 = tune(tripList, [hero.countryCode]);
    options.add(PulseMerchOption(
      id: '${template.name}_trip',
      title: '$prefix — $countryName $year',
      description: 'Your $countryName trip',
      scope: PulseMerchScope.pulseTrip,
      template: template,
      codes: [hero.countryCode],
      trips: tripList,
      jitter: t1.jitter,
      stampSizeMultiplier: t1.size,
    ));

    // 2. Year in review (only when multiple countries that year)
    if (yearCodes.length > 1) {
      final t2 = tune(yearTrips, yearCodes);
      options.add(PulseMerchOption(
        id: '${template.name}_year',
        title: '$prefix — $year Travels',
        description: '${yearCodes.length} countries visited in $year',
        scope: PulseMerchScope.pulseYear,
        template: template,
        codes: yearCodes,
        trips: yearTrips,
        jitter: t2.jitter,
        stampSizeMultiplier: t2.size,
      ));
    }

    // 3. All visits to this country
    final t3 = tune(countryTrips, [hero.countryCode]);
    options.add(PulseMerchOption(
      id: '${template.name}_country',
      title: '$prefix — $countryName Memories',
      description: countryTrips.isEmpty
          ? 'All your $countryName stamps'
          : '${countryTrips.length} '
              '${countryTrips.length == 1 ? "trip" : "trips"} to $countryName',
      scope: PulseMerchScope.allVisitsToCountry,
      template: template,
      codes: [hero.countryCode],
      trips: countryTrips,
      jitter: t3.jitter,
      stampSizeMultiplier: t3.size,
    ));

    // 4. All-time collection (only when more than one country exists)
    if (allCodes.length > 1) {
      final t4 = tune(allTrips, allCodes);
      options.add(PulseMerchOption(
        id: '${template.name}_alltime',
        title: '$prefix — World Collection',
        description: '${allCodes.length} countries across all your travels',
        scope: PulseMerchScope.allTime,
        template: template,
        codes: allCodes,
        trips: allTrips,
        jitter: t4.jitter,
        stampSizeMultiplier: t4.size,
      ));
    }

    return options;
  }

  List<_ListItem> _buildItems() {
    final year = hero.capturedAt.year;
    final countryName = kCountryNames[hero.countryCode] ?? hero.countryCode;
    final heroTrip = allTrips.where((t) => t.id == hero.tripId).firstOrNull;
    final yearTrips = allTrips.where((t) => t.startedOn.year == year).toList();
    final yearCodes = yearTrips.map((t) => t.countryCode).toSet().toList();
    final countryTrips =
        allTrips.where((t) => t.countryCode == hero.countryCode).toList();
    final allCodes = allVisits.map((v) => v.countryCode).toList();

    const groups = [
      (label: 'Passport', template: CardTemplateType.passport),
      (label: 'Flags', template: CardTemplateType.grid),
      (label: 'Tour Dates', template: CardTemplateType.timeline),
    ];

    final items = <_ListItem>[];
    for (final g in groups) {
      items.add(_HeaderItem(g.label));
      for (final opt in _optionsFor(
        g.template,
        countryName: countryName,
        year: year,
        heroTrip: heroTrip,
        yearTrips: yearTrips,
        yearCodes: yearCodes,
        countryTrips: countryTrips,
        allCodes: allCodes,
      )) {
        items.add(_OptionItem(opt));
      }
      items.add(_CustomiseItem(
        template: g.template,
        label: 'Customise ${g.label}',
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final allCodes = allVisits.map((v) => v.countryCode).toList();
    final year = hero.capturedAt.year;
    final countryName = kCountryNames[hero.countryCode] ?? hero.countryCode;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Text('Your travel shirt ideas'),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Inspired by $countryName · $year',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return switch (item) {
                  _HeaderItem() => _SectionHeader(item.label),
                  _OptionItem() => _OptionCard(
                      option: item.option,
                      allCodes: allCodes,
                    ),
                  _CustomiseItem() => _CustomOptionCard(
                      hero: hero,
                      allTrips: allTrips,
                      allCodes: allCodes,
                      template: item.template,
                      label: item.label,
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Constants ──────────────────────────────────────────────────────────────────

const double _kThumbW = 72.0;
const double _kThumbH = 92.0;

// ── Option card ────────────────────────────────────────────────────────────────

enum _GenState { loading, ready, error }

/// Aspect ratio for the back-card artwork based on template type.
///
/// Flag-based (grid) and horizontal timeline designs render better in
/// landscape so they fill the shirt back correctly without excess letterboxing.
/// Passport designs remain portrait to match the stamp page proportions.
double _backCardAspectRatio(CardTemplateType template) =>
    (template == CardTemplateType.grid || template == CardTemplateType.timeline)
        ? 3.0 / 2.0  // landscape
        : 2.0 / 3.0; // portrait

class _OptionCard extends StatefulWidget {
  const _OptionCard({required this.option, required this.allCodes});

  final PulseMerchOption option;
  final List<String> allCodes;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  _GenState _state = _GenState.loading;
  Uint8List? _artworkBytes;
  ui.Image? _backArtImage;
  ui.Image? _frontRibbonImage;
  ui.Image? _backShirtImage;
  ui.Image? _frontShirtImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _backArtImage?.dispose();
    _frontRibbonImage?.dispose();
    _backShirtImage?.dispose();
    _frontShirtImage?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!mounted) return;
    final opt = widget.option;

    // Debug log: layout parameters for this option.
    final stampCount = opt.template == CardTemplateType.passport
        ? opt.trips.length * (opt.entryOnly ? 1 : 2)
        : opt.codes.length;
    final aspectRatio = _backCardAspectRatio(opt.template);
    final orientation = aspectRatio > 1.0 ? 'landscape(3:2)' : 'portrait(2:3)';
    debugPrint(
      '[pulse_merch] ${opt.id}'
      ' | template=${opt.template.name}'
      ' | scope=${opt.scope.name}'
      ' | items=$stampCount'
      ' | size=${opt.stampSizeMultiplier.toStringAsFixed(2)}'
      ' | jitter=${opt.jitter.toStringAsFixed(2)}'
      ' | orientation=$orientation',
    );

    try {
      // Kick off both artwork renders concurrently.
      // Aspect ratio depends on template: flag grid + timeline use landscape
      // (3:2) so the design fills the shirt back width; passport stays portrait.
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
        _state = _GenState.ready;
      });
    } catch (e) {
      debugPrint('[pulse_merch] ${opt.id} failed: $e');
      if (!mounted) return;
      setState(() => _state = _GenState.error);
    }
  }

  void _navigate() {
    final bytes = _artworkBytes;
    if (bytes == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LocalMockupPreviewScreen(
        selectedCodes: widget.option.codes,
        allCodes: widget.allCodes,
        trips: widget.option.trips,
        artworkImageBytes: bytes,
        initialTemplate: widget.option.template,
        // Aspect ratio must match what was rendered in _generate() so the
        // Printful upload uses the same orientation as the local preview.
        confirmedAspectRatio: _backCardAspectRatio(widget.option.template),
        confirmedEntryOnly: widget.option.entryOnly,
        transparentBackground: true,
        stampJitterFactor: widget.option.jitter,
        stampSizeMultiplier: widget.option.stampSizeMultiplier,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A3550),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _state == _GenState.ready ? _navigate : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildThumbnailPair(),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo()),
              if (_state == _GenState.ready)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPair() {
    return switch (_state) {
      _GenState.loading => _loadingThumbs(),
      _GenState.error => _errorThumb(),
      _GenState.ready => _readyThumbs(),
    };
  }

  Widget _loadingThumbs() {
    return SizedBox(
      width: _kThumbW * 2 + 8,
      height: _kThumbH,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
        ),
      ),
    );
  }

  Widget _errorThumb() {
    return SizedBox(
      width: _kThumbW * 2 + 8,
      height: _kThumbH,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.white30, size: 22),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                setState(() => _state = _GenState.loading);
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _generate());
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
              width: _kThumbW,
              height: _kThumbH,
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
              width: _kThumbW,
              height: _kThumbH,
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
              width: _kThumbW,
              child: const Center(
                child: Text('Back',
                    style: TextStyle(color: Colors.white30, fontSize: 9)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _kThumbW,
              child: const Center(
                child: Text('Front',
                    style: TextStyle(color: Colors.white30, fontSize: 9)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfo() {
    if (_state == _GenState.loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Generating shirt idea...',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    if (_state == _GenState.error) {
      return const Text(
        'Could not generate preview',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.option.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.option.description,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.option.templateLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

// ── Custom option card ─────────────────────────────────────────────────────────

class _CustomOptionCard extends StatelessWidget {
  const _CustomOptionCard({
    required this.hero,
    required this.allTrips,
    required this.allCodes,
    required this.template,
    required this.label,
  });

  final HeroImage hero;
  final List<TripRecord> allTrips;
  final List<String> allCodes;
  final CardTemplateType template;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A3550),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navigate to the card editor for this specific card type so the user
          // can fully customise before entering the t-shirt design flow.
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CardEditorScreen(templateType: template),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white54, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose countries, years, and layout',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
