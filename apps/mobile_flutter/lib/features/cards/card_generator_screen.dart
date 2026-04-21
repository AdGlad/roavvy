import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../merch/local_mockup_preview_screen.dart';
import 'artwork_confirmation_screen.dart';
import 'artwork_confirmation_service.dart';
import 'card_image_renderer.dart';
import 'card_templates.dart';
import 'front_ribbon_card.dart';
import 'heart_layout_engine.dart';
import 'timeline_card.dart';
import 'stamp_preview_screen.dart';
import 'travel_card_service.dart';

const _kAmber = Color(0xFFD4A017);

// ── Re-confirmation snapshot (M51-E3) ─────────────────────────────────────────

/// Snapshot of the params used for the last confirmed artwork.
///
/// Equality is used to decide whether re-confirmation is needed when the user
/// presses "Print your card" again (ADR-103 / M51-E3).
class _CardParams {
  const _CardParams({
    required this.templateType,
    required this.countryCodes,
    required this.aspectRatio,
    required this.entryOnly,
    required this.heartOrder,
    this.yearStart,
    this.yearEnd,
    this.titleOverride,
    this.stampColor,
    this.dateColor,
    this.transparentBackground = true,
  });

  final CardTemplateType templateType;
  final List<String> countryCodes;
  final double aspectRatio;
  final bool entryOnly;
  final HeartFlagOrder heartOrder;
  final int? yearStart;
  final int? yearEnd;
  final String? titleOverride;
  final Color? stampColor;
  final Color? dateColor;
  final bool transparentBackground;

  @override
  bool operator ==(Object other) {
    if (other is! _CardParams) return false;
    return templateType == other.templateType &&
        listEquals(countryCodes, other.countryCodes) &&
        aspectRatio == other.aspectRatio &&
        entryOnly == other.entryOnly &&
        heartOrder == other.heartOrder &&
        yearStart == other.yearStart &&
        yearEnd == other.yearEnd &&
        titleOverride == other.titleOverride &&
        stampColor == other.stampColor &&
        dateColor == other.dateColor &&
        transparentBackground == other.transparentBackground;
  }

  @override
  int get hashCode => Object.hash(
        templateType,
        Object.hashAll(countryCodes),
        aspectRatio,
        entryOnly,
        heartOrder,
        yearStart,
        yearEnd,
        titleOverride,
        stampColor,
        dateColor,
        transparentBackground,
      );
}

// ── Card generator screen ─────────────────────────────────────────────────────

/// Full-screen card generator: pick a template, configure options, preview, share.
class CardGeneratorScreen extends ConsumerStatefulWidget {
  const CardGeneratorScreen({super.key});

  @override
  ConsumerState<CardGeneratorScreen> createState() =>
      _CardGeneratorScreenState();
}

class _CardGeneratorScreenState extends ConsumerState<CardGeneratorScreen> {
  CardTemplateType _selected = CardTemplateType.grid;
  HeartFlagOrder _heartOrder = HeartFlagOrder.randomized;
  bool _entryOnly = false;
  bool _portrait = true; // Default to Portrait (ADR-117)
  RangeValues? _yearSelection; // null = full range

  // Country-level deselection: codes in this set are excluded from the card.
  Set<String> _deselectedCodes = {};

  // Passport customization (ADR-117)
  String? _titleOverride;
  Color? _stampColor;
  Color? _dateColor;
  bool _transparentBackground = true;

  final _previewKey = GlobalKey();
  final _transformController = TransformationController();
  bool _sharing = false;
  bool _printing = false;

  // All-time country codes cached from the last build, used when navigating to
  // LocalMockupPreviewScreen to support the front-ribbon mode toggle (M74-T5).
  List<String> _cachedAllCodes = const [];

  // M51 re-confirmation state (ADR-103)
  _CardParams? _lastConfirmedParams;
  String? _artworkConfirmationId;
  Uint8List? _artworkImageBytes;

  // M55-E: trip list captured at confirmation time; threaded to
  // LocalMockupPreviewScreen so template re-renders use the same trips (ADR-107).
  List<TripRecord>? _lastConfirmedTrips;

  double get _aspectRatio => _portrait ? 2.0 / 3.0 : 3.0 / 2.0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() => _transformController.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'European stamps preview',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StampPreviewScreen(),
              ),
            ),
          ),
        ],
      ),
      body: visitsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (visits) {
          if (visits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Scan your photos to generate a card',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white54),
                ),
              ),
            );
          }

          final allCodes = visits.map((v) => v.countryCode).toList()..sort();
          _cachedAllCodes = allCodes; // cache for _goToProductBrowser callback
          final allTrips = tripsAsync.valueOrNull
                  ?.where((t) => allCodes.contains(t.countryCode))
                  .toList() ??
              [];

          // ── Date range ────────────────────────────────────────────────────
          final tripYears = allTrips.map((t) => t.startedOn.year).toSet();
          final yearMin = tripYears.isEmpty
              ? null
              : tripYears.reduce(math.min).toDouble();
          final yearMax = tripYears.isEmpty
              ? null
              : tripYears.reduce(math.max).toDouble();
          final showDateSlider =
              yearMin != null && yearMax != null && yearMax > yearMin;

          final effectiveRange = _yearSelection ??
              (showDateSlider ? RangeValues(yearMin, yearMax) : null);

          final filteredTrips = (effectiveRange == null || !showDateSlider)
              ? allTrips
              : allTrips
                  .where((t) =>
                      t.startedOn.year >= effectiveRange.start.round() &&
                      t.startedOn.year <= effectiveRange.end.round())
                  .toList();

          final isDateFiltered = showDateSlider &&
              effectiveRange != null &&
              (effectiveRange.start > yearMin ||
                  effectiveRange.end < yearMax);

          final displayedCodes = isDateFiltered
              ? (filteredTrips.map((t) => t.countryCode).toSet().toList()
                ..sort())
              : allCodes;

          // Country-level filter: exclude any codes the user has deselected.
          final activeDeselected =
              _deselectedCodes.intersection(displayedCodes.toSet());
          final selectedCodes = activeDeselected.isEmpty
              ? displayedCodes
              : displayedCodes
                  .where((c) => !activeDeselected.contains(c))
                  .toList();
          final selectedTrips = activeDeselected.isEmpty
              ? filteredTrips
              : filteredTrips
                  .where((t) => !activeDeselected.contains(t.countryCode))
                  .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              _TemplatePicker(
                selected: _selected,
                onChanged: (t) => setState(() {
                  _selected = t;
                  if (t != CardTemplateType.heart) {
                    _heartOrder = HeartFlagOrder.randomized;
                  }
                  _resetZoom();
                }),
              ),
              const SizedBox(height: 8),
              // Template-specific controls
              if (_selected == CardTemplateType.heart)
                _HeartOrderPicker(
                  selected: _heartOrder,
                  onChanged: (o) => setState(() => _heartOrder = o),
                ),
              if (_selected == CardTemplateType.passport)
                _ChipRow(
                  children: [
                    _OptionChip(
                      label: 'Entry + Exit',
                      selected: !_entryOnly,
                      onTap: () => setState(() => _entryOnly = false),
                    ),
                    _OptionChip(
                      label: 'Entry only',
                      selected: _entryOnly,
                      onTap: () => setState(() => _entryOnly = true),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              _SharedTitleEditor(
                titleOverride: _titleOverride,
                onTitleChanged: (v) => setState(() => _titleOverride = v),
                countryCount: selectedCodes.length,
                dateLabel: _computeDateLabel(selectedTrips),
              ),
              if (_selected == CardTemplateType.passport)
                _PassportCustomizer(
                  stampColor: _stampColor,
                  onStampColorChanged: (c) => setState(() => _stampColor = c),
                  dateColor: _dateColor,
                  onDateColorChanged: (c) => setState(() => _dateColor = c),
                  transparentBackground: _transparentBackground,
                  onTransparentBackgroundChanged: (v) =>
                      setState(() => _transparentBackground = v),
                ),
              const SizedBox(height: 4),
              // Global controls: orientation
              _ChipRow(
                children: [
                  _OptionChip(
                    label: 'Landscape',
                    selected: !_portrait,
                    onTap: () => setState(() {
                      _portrait = false;
                      _resetZoom();
                    }),
                  ),
                  _OptionChip(
                    label: 'Portrait',
                    selected: _portrait,
                    onTap: () => setState(() {
                      _portrait = true;
                      _resetZoom();
                    }),
                  ),
                ],
              ),
              // Date range slider (only when trips span multiple years)
              if (showDateSlider && effectiveRange != null) ...[
                const SizedBox(height: 4),
                _DateRangeRow(
                  yearMin: yearMin,
                  yearMax: yearMax,
                  values: effectiveRange,
                  countryCount: selectedCodes.length,
                  onChanged: (v) => setState(() {
                    _yearSelection = v;
                    _deselectedCodes = {}; // reset per-country filter on year change
                  }),
                ),
              ],
              // Per-country toggle: shown whenever there are 2+ countries.
              if (displayedCodes.length > 1) ...[
                const SizedBox(height: 6),
                _CountryChipSelector(
                  codes: displayedCodes,
                  deselected: activeDeselected,
                  onToggle: (code) {
                    setState(() {
                      if (_deselectedCodes.contains(code)) {
                        _deselectedCodes = Set.of(_deselectedCodes)..remove(code);
                      } else if (selectedCodes.length > 1) {
                        // Prevent removing the last selected country.
                        _deselectedCodes = {..._deselectedCodes, code};
                      }
                    });
                  },
                  onReset: () => setState(() => _deselectedCodes = {}),
                ),
              ],
              const SizedBox(height: 8),
              // Card preview
              // Constrained to 340 px max width so PassportLayoutEngine sees the
              // same canvas dimensions as CardImageRenderer (ADR-113 / M57-02).
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 6.0,
                        child: RepaintBoundary(
                          key: _previewKey,
                          child: _buildTemplate(selectedCodes, selectedTrips),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionBar(
                sharing: _sharing,
                printing: _printing,
                onShare: () => _onShare(context, selectedCodes),
                onPrint: () => _onPrint(
                  context,
                  selectedCodes,
                  selectedTrips,
                  effectiveRange,
                  showDateSlider,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTemplate(List<String> codes, List<TripRecord> trips) {
    final dateLabel = _computeDateLabel(trips);
    switch (_selected) {
      case CardTemplateType.grid:
        return GridFlagsCard(
          countryCodes: codes,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
        );
      case CardTemplateType.heart:
        return HeartFlagsCard(
          countryCodes: codes,
          trips: trips,
          flagOrder: _heartOrder,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
        );
      case CardTemplateType.passport:
        // forPrint: true matches the CardImageRenderer render so the live
        // preview is pixel-consistent with the Confirm Your Artwork image
        // (ADR-113 / M57-02).
        return PassportStampsCard(
          countryCodes: codes,
          trips: trips,
          entryOnly: _entryOnly,
          forPrint: true,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
          stampColor: _stampColor,
          dateColor: _dateColor,
          transparentBackground: _transparentBackground,
        );
      case CardTemplateType.timeline:
        return TimelineCard(
          trips: trips,
          countryCodes: codes,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
        );
      case CardTemplateType.frontRibbon:
        return FrontRibbonCard(
          countryCodes: codes,
          travelerLevel: 'Explorer',
        );
    }
  }

  /// Computes a date range label from a list of trips.
  ///
  /// Single year → `"2024"`, multi-year → `"2018–2024"`, no trips → `""`.
  static String _computeDateLabel(List<TripRecord> trips) {
    if (trips.isEmpty) return '';
    final years = trips.map((t) => t.startedOn.year).toSet();
    final minYear = years.reduce(math.min);
    final maxYear = years.reduce(math.max);
    return minYear == maxYear ? '$minYear' : '$minYear\u2013$maxYear';
  }

  Future<void> _onShare(BuildContext context, List<String> codes) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roavvy_travel_card.png');
      await file.writeAsBytes(bytes);

      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        final card = TravelCard(
          cardId: 'card-${DateTime.now().microsecondsSinceEpoch}',
          userId: uid,
          templateType: _selected,
          countryCodes: codes,
          countryCount: codes.length,
          createdAt: DateTime.now().toUtc(),
        );
        unawaited(TravelCardService(FirebaseFirestore.instance).create(card));
      }

      if (!context.mounted) return;
      final size = MediaQuery.sizeOf(context);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My Roavvy travel card',
        sharePositionOrigin:
            Rect.fromLTWH(size.width / 2 - 22, size.height - 88, 44, 44),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _onPrint(
    BuildContext context,
    List<String> codes,
    List<TripRecord> trips,
    RangeValues? effectiveRange,
    bool showDateSlider,
  ) {
    if (_sharing || _printing) return;
    unawaited(_navigateToPrint(
      context, codes, trips, effectiveRange, showDateSlider));
  }

  Future<void> _navigateToPrint(
    BuildContext context,
    List<String> codes,
    List<TripRecord> trips,
    RangeValues? effectiveRange,
    bool showDateSlider,
  ) async {
    final int? yearStart = showDateSlider && effectiveRange != null
        ? effectiveRange.start.round()
        : null;
    final int? yearEnd = showDateSlider && effectiveRange != null
        ? effectiveRange.end.round()
        : null;

    final currentParams = _CardParams(
      templateType: _selected,
      countryCodes: codes,
      aspectRatio: _aspectRatio,
      entryOnly: _entryOnly,
      heartOrder: _heartOrder,
      yearStart: yearStart,
      yearEnd: yearEnd,
      titleOverride: _titleOverride,
      stampColor: _stampColor,
      dateColor: _dateColor,
      transparentBackground: _transparentBackground,
    );

    // M51-E3: same params — skip re-confirmation (ADR-103)
    if (currentParams == _lastConfirmedParams &&
        _artworkConfirmationId != null) {
      if (!context.mounted) return;
      _goToProductBrowser(context, codes);
      return;
    }

    // ADR-112: Pre-render the card once, using the exact current state
    // (entryOnly, aspectRatio, heartOrder, dateLabel), before pushing
    // ArtworkConfirmationScreen. This ensures the user confirms and purchases
    // exactly the image they selected — no silent re-render inside the
    // confirmation screen.
    setState(() => _printing = true);
    CardRenderResult? preRender;
    try {
      if (!context.mounted) return;
      final dateLabel = _computeDateLabel(trips);
      preRender = await CardImageRenderer.render(
        context,
        _selected,
        codes: codes,
        trips: trips,
        forPrint: _selected == CardTemplateType.passport,
        entryOnly: _entryOnly,
        cardAspectRatio: _aspectRatio,
        heartOrder: _heartOrder,
        dateLabel: dateLabel,
        titleOverride: _titleOverride,
        stampColor: _stampColor,
        dateColor: _dateColor,
        transparentBackground: _transparentBackground,
      );
    } catch (_) {
      // Non-fatal: fall back to in-screen render inside ArtworkConfirmationScreen.
      preRender = null;
    } finally {
      if (mounted) setState(() => _printing = false);
    }

    // Route through ArtworkConfirmationScreen
    final showUpdatedBanner = _artworkConfirmationId != null;
    final dateRangeStart =
        yearStart != null ? DateTime(yearStart) : null;
    final dateRangeEnd =
        yearEnd != null ? DateTime(yearEnd, 12, 31) : null;

    if (!context.mounted) return;
    final result =
        await Navigator.of(context).push<ArtworkConfirmResult?>(
      MaterialPageRoute(
        builder: (_) => ArtworkConfirmationScreen(
          templateType: _selected,
          countryCodes: codes,
          filteredTrips: trips,
          dateRangeStart: dateRangeStart,
          dateRangeEnd: dateRangeEnd,
          aspectRatio: _aspectRatio,
          entryOnly: _entryOnly,
          showUpdatedBanner: showUpdatedBanner,
          preRenderedResult: preRender,
          titleOverride: _titleOverride,
          stampColor: _stampColor,
          dateColor: _dateColor,
          transparentBackground: _transparentBackground,
        ),
      ),
    );

    if (result == null || !mounted) return;

    // M54-G2: Archive superseded confirmation fire-and-forget (ADR-106).
    final priorId = _artworkConfirmationId;
    if (priorId != null && priorId != result.confirmationId) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        unawaited(ArtworkConfirmationService(FirebaseFirestore.instance)
            .archive(uid, priorId));
      }
    }

    // Store confirmation so same-params shortcut works next time.
    // Capture filteredTrips here so LocalMockupPreviewScreen receives the trip
    // list that corresponds to the confirmed artwork (ADR-107 / M55-E).
    setState(() {
      _lastConfirmedParams = currentParams;
      _artworkConfirmationId = result.confirmationId;
      _artworkImageBytes = result.bytes;
      _lastConfirmedTrips = trips;
    });

    if (!context.mounted) return;
    _goToProductBrowser(context, codes);
  }

  void _goToProductBrowser(BuildContext context, List<String> codes) {
    final uid = ref.read(currentUidProvider);
    String? cardId;
    if (uid != null) {
      cardId = 'card-${DateTime.now().microsecondsSinceEpoch}';
      final card = TravelCard(
        cardId: cardId,
        userId: uid,
        templateType: _selected,
        countryCodes: codes,
        countryCount: codes.length,
        createdAt: DateTime.now().toUtc(),
      );
      unawaited(TravelCardService(FirebaseFirestore.instance).create(card));
    }

    // M55-E / ADR-112: Push LocalMockupPreviewScreen.
    // artworkImageBytes and artworkConfirmationId are always non-null here —
    // guarded by _navigateToPrint which sets them before calling this method.
    // Pass confirmedAspectRatio and confirmedEntryOnly so any template-change
    // re-render inside LocalMockupPreviewScreen uses consistent params.
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LocalMockupPreviewScreen(
        selectedCodes: codes,
        allCodes: _cachedAllCodes,
        trips: _lastConfirmedTrips ?? const [],
        artworkImageBytes: _artworkImageBytes!,
        artworkConfirmationId: _artworkConfirmationId!,
        initialTemplate: _selected,
        confirmedAspectRatio: _aspectRatio,
        confirmedEntryOnly: _entryOnly,
        cardId: cardId,
        titleOverride: _titleOverride,
        stampColor: _stampColor,
        dateColor: _dateColor,
        transparentBackground: _transparentBackground,
      ),
    ));
  }
}

// ── Template picker ────────────────────────────────────────────────────────────

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.selected, required this.onChanged});

  final CardTemplateType selected;
  final ValueChanged<CardTemplateType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Tile(
          label: 'Grid',
          type: CardTemplateType.grid,
          selected: selected == CardTemplateType.grid,
          onTap: () => onChanged(CardTemplateType.grid),
        ),
        const SizedBox(width: 12),
        _Tile(
          label: 'Heart',
          type: CardTemplateType.heart,
          selected: selected == CardTemplateType.heart,
          onTap: () => onChanged(CardTemplateType.heart),
        ),
        const SizedBox(width: 12),
        _Tile(
          label: 'Passport',
          type: CardTemplateType.passport,
          selected: selected == CardTemplateType.passport,
          onTap: () => onChanged(CardTemplateType.passport),
        ),
        const SizedBox(width: 12),
        _Tile(
          label: 'Timeline',
          type: CardTemplateType.timeline,
          selected: selected == CardTemplateType.timeline,
          onTap: () => onChanged(CardTemplateType.timeline),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final CardTemplateType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _kAmber : onSurface.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color:
              selected ? _kAmber.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _kAmber : onSurface.withValues(alpha: 0.75),
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Shared chip row ────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children
          .expand((w) => [w, const SizedBox(width: 6)])
          .toList()
        ..removeLast(),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _kAmber : onSurface.withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? _kAmber.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? _kAmber : onSurface.withValues(alpha: 0.65),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Heart order picker ─────────────────────────────────────────────────────────

class _HeartOrderPicker extends StatelessWidget {
  const _HeartOrderPicker({required this.selected, required this.onChanged});

  final HeartFlagOrder selected;
  final ValueChanged<HeartFlagOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChipRow(
      children: [
        _OptionChip(
          label: 'Shuffle',
          selected: selected == HeartFlagOrder.randomized,
          onTap: () => onChanged(HeartFlagOrder.randomized),
        ),
        _OptionChip(
          label: 'By date',
          selected: selected == HeartFlagOrder.chronological,
          onTap: () => onChanged(HeartFlagOrder.chronological),
        ),
        _OptionChip(
          label: 'A→Z',
          selected: selected == HeartFlagOrder.alphabetical,
          onTap: () => onChanged(HeartFlagOrder.alphabetical),
        ),
        _OptionChip(
          label: 'By region',
          selected: selected == HeartFlagOrder.geographic,
          onTap: () => onChanged(HeartFlagOrder.geographic),
        ),
      ],
    );
  }
}

// ── Date range row ─────────────────────────────────────────────────────────────

class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({
    required this.yearMin,
    required this.yearMax,
    required this.values,
    required this.countryCount,
    required this.onChanged,
  });

  final double yearMin;
  final double yearMax;
  final RangeValues values;
  final int countryCount;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final startYear = values.start.round();
    final endYear = values.end.round();
    final isFullRange =
        startYear == yearMin.round() && endYear == yearMax.round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_outlined,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                isFullRange ? 'All time' : '$startYear – $endYear',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const Spacer(),
              Text(
                '$countryCount ${countryCount == 1 ? 'country' : 'countries'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _kAmber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAmber,
              thumbColor: _kAmber,
              inactiveTrackColor: Colors.white24,
              overlayColor: _kAmber.withValues(alpha: 0.15),
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 2,
            ),
            child: RangeSlider(
              values: values,
              min: yearMin,
              max: yearMax,
              divisions: (yearMax - yearMin).round(),
              labels: RangeLabels(startYear.toString(), endYear.toString()),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedTitleEditor extends StatelessWidget {
  const _SharedTitleEditor({
    required this.titleOverride,
    required this.onTitleChanged,
    required this.countryCount,
    required this.dateLabel,
  });

  final String? titleOverride;
  final ValueChanged<String?> onTitleChanged;
  final int countryCount;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final defaultTitle = '$countryCount Countries \u00B7 $dateLabel';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Card Title',
          hintText: defaultTitle,
          isDense: true,
          prefixIcon: const Icon(Icons.edit, size: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          suffixIcon: titleOverride != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onTitleChanged(null),
                )
              : null,
        ),
        style: const TextStyle(fontSize: 13),
        controller: TextEditingController(text: titleOverride)
          ..selection = TextSelection.fromPosition(
              TextPosition(offset: (titleOverride ?? '').length)),
        onChanged: (v) => onTitleChanged(v.isEmpty ? null : v),
      ),
    );
  }
}

// ── Passport customizer ────────────────────────────────────────────────────────

class _PassportCustomizer extends StatelessWidget {
  const _PassportCustomizer({
    required this.stampColor,
    required this.onStampColorChanged,
    required this.dateColor,
    required this.onDateColorChanged,
    required this.transparentBackground,
    required this.onTransparentBackgroundChanged,
  });

  final Color? stampColor;
  final ValueChanged<Color?> onStampColorChanged;
  final Color? dateColor;
  final ValueChanged<Color?> onDateColorChanged;
  final bool transparentBackground;
  final ValueChanged<bool> onTransparentBackgroundChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Color pickers
          Row(
            children: [
              Expanded(
                child: _ColorSection(
                  label: 'STAMPS',
                  selected: stampColor,
                  onChanged: onStampColorChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ColorSection(
                  label: 'DATES',
                  selected: dateColor,
                  onChanged: onDateColorChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Background toggle
          Row(
            children: [
              const Icon(Icons.layers_outlined, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              const Text('Tinted background',
                  style: TextStyle(fontSize: 12, color: Colors.white60)),
              const Spacer(),
              Switch.adaptive(
                value: !transparentBackground,
                onChanged: (v) => onTransparentBackgroundChanged(!v),
                activeColor: const Color(0xFFD4A017),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSection extends StatelessWidget {
  const _ColorSection(
      {required this.label, required this.selected, required this.onChanged});

  final String label;
  final Color? selected;
  final ValueChanged<Color?> onChanged;

  static const _palette = [
    null, // Multi-color (default)
    Color(0xFF1565C0), // cobaltBlue
    Color(0xFFB71C1C), // vividRed
    Color(0xFF1B5E20), // deepGreen
    Color(0xFF212121), // nearBlack
    Color(0xFFBF360C), // burnedOrange
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _palette.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final color = _palette[i];
              final isSelected = selected == color;

              return GestureDetector(
                onTap: () => onChanged(color),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color ?? Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white24,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: color == null
                      ? const Center(
                          child: Icon(Icons.palette_outlined,
                              size: 14, color: Colors.white70))
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Country chip selector ──────────────────────────────────────────────────────

/// Horizontal scrollable row of country chips; tap to include/exclude a country.
///
/// [codes] is the full list for the current year range (source of truth).
/// [deselected] is the subset currently toggled off.
/// All countries are selected by default; the last selected country cannot be
/// removed (caller enforces this in [onToggle]).
class _CountryChipSelector extends StatelessWidget {
  const _CountryChipSelector({
    required this.codes,
    required this.deselected,
    required this.onToggle,
    required this.onReset,
  });

  final List<String> codes;
  final Set<String> deselected;
  final ValueChanged<String> onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final activeCount = codes.where((c) => !deselected.contains(c)).length;
    final hasDeselected = deselected.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 13, color: Colors.white38),
              const SizedBox(width: 5),
              Text(
                hasDeselected
                    ? '$activeCount of ${codes.length} countries'
                    : '${codes.length} countries',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
              if (hasDeselected) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onReset,
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontSize: 11, color: _kAmber),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: codes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final code = codes[i];
                final isSelected = !deselected.contains(code);
                return GestureDetector(
                  onTap: () => onToggle(code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? _kAmber : Colors.white24,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected
                          ? _kAmber.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _flagEmoji(code),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _shortName(code),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Converts an ISO 3166-1 alpha-2 code to the corresponding flag emoji.
  /// Returns 🌍 for non-standard codes (e.g. 'XX').
  static String _flagEmoji(String code) {
    if (code.length != 2) return '\u{1F30D}';
    final up = code.toUpperCase();
    final a = up.codeUnitAt(0) - 65 + 0x1F1E6;
    final b = up.codeUnitAt(1) - 65 + 0x1F1E6;
    // Regional indicator symbols only cover A–Z (0x1F1E6–0x1F1FF).
    if (a < 0x1F1E6 || a > 0x1F1FF || b < 0x1F1E6 || b > 0x1F1FF) {
      return '\u{1F30D}';
    }
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  static String _shortName(String code) {
    final name = kCountryNames[code] ?? code;
    return name.length > 11 ? '${name.substring(0, 9)}\u2026' : name;
  }
}

// ── Action bar ─────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.sharing,
    required this.printing,
    required this.onShare,
    required this.onPrint,
  });

  final bool sharing;
  final bool printing;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (sharing || printing) ? null : onShare,
              icon: sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (sharing || printing) ? null : onPrint,
              icon: printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: const Text('Print your card'),
            ),
          ),
        ],
      ),
    );
  }
}
