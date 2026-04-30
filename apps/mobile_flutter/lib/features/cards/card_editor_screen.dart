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
import '../scan/hero_providers.dart';
import 'card_image_renderer.dart';
import 'card_templates.dart';
import 'front_ribbon_card.dart';
import 'heart_layout_engine.dart';
import 'timeline_card.dart';
import 'title_generation/title_generation_models.dart';
import 'title_generation/title_generation_provider.dart';
import 'travel_card_service.dart';

// ── Card param snapshot (re-confirmation guard) ────────────────────────────────

/// Snapshot of current editor parameters; equality used to skip re-confirmation
/// when nothing has changed since last confirmation (ADR-103 / ADR-119).
class _CardParams {
  const _CardParams({
    required this.templateType,
    required this.countryCodes,
    required this.aspectRatio,
    required this.entryOnly,
    required this.order,
    this.yearStart,
    this.yearEnd,
    this.titleOverride,
    this.stampLayoutSeed,
    this.stampSizeMultiplier = 1.0,
    this.stampJitterFactor = 0.4,
  });

  final CardTemplateType templateType;
  final List<String> countryCodes;
  final double aspectRatio;
  final bool entryOnly;
  final HeartFlagOrder order;
  final int? yearStart;
  final int? yearEnd;
  final String? titleOverride;
  final int? stampLayoutSeed;
  final double stampSizeMultiplier;
  final double stampJitterFactor;

  @override
  bool operator ==(Object other) {
    if (other is! _CardParams) return false;
    return templateType == other.templateType &&
        listEquals(countryCodes, other.countryCodes) &&
        aspectRatio == other.aspectRatio &&
        entryOnly == other.entryOnly &&
        order == other.order &&
        yearStart == other.yearStart &&
        yearEnd == other.yearEnd &&
        titleOverride == other.titleOverride &&
        stampLayoutSeed == other.stampLayoutSeed &&
        stampSizeMultiplier == other.stampSizeMultiplier &&
        stampJitterFactor == other.stampJitterFactor;
  }

  @override
  int get hashCode => Object.hash(
        templateType,
        Object.hashAll(countryCodes),
        aspectRatio,
        entryOnly,
        order,
        yearStart,
        yearEnd,
        titleOverride,
        stampLayoutSeed,
        stampSizeMultiplier,
        stampJitterFactor,
      );
}

// ── CardEditorScreen ───────────────────────────────────────────────────────────

/// Second screen in the Create Card flow.
///
/// Receives a pre-selected [templateType] from [CardTypePickerScreen] and
/// presents a large live card preview with a compact control strip above it.
/// Share and Print buttons at the bottom drive the subsequent artwork
/// confirmation and commerce flows (ADR-119).
class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({super.key, required this.templateType});

  final CardTemplateType templateType;

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  HeartFlagOrder _order = HeartFlagOrder.randomized;
  int _gridShuffleSeed = 0;
  bool _entryOnly = false;
  bool _portrait = true;
  int? _stampLayoutSeed; // null = deterministic hash default (passport only)
  double _stampSizeMultiplier = 1.0;
  double _stampJitterFactor = 0.4;
  bool _showPassportControls = true;
  RangeValues? _yearSelection;
  /// Country codes manually deselected by the user. Cleared when year range changes.
  Set<String> _manuallyDeselectedCodes = {};
  late TextEditingController _titleController;
  String? _titleOverride;
  bool _isTitleGenerating = false;
  bool _autoGenerateFired = false;
  bool _sharing = false;
  bool _printing = false;

  // Render cache (ADR-103)
  _CardParams? _lastConfirmedParams;
  Uint8List? _artworkImageBytes;
  List<TripRecord>? _lastConfirmedTrips;

  final _previewKey = GlobalKey();
  final _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    // Passport card is always portrait — prevent inheriting landscape state.
    if (widget.templateType == CardTemplateType.passport) {
      _portrait = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  double get _aspectRatio => _portrait ? 2.0 / 3.0 : 3.0 / 2.0;

  void _resetZoom() => _transformController.value = Matrix4.identity();

  String _typeName(CardTemplateType type) => switch (type) {
        CardTemplateType.grid => 'Flag Grid',
        CardTemplateType.heart => 'Heart',
        CardTemplateType.passport => 'Passport',
        CardTemplateType.timeline => 'Timeline',
        CardTemplateType.frontRibbon => 'Front Ribbon',
      };

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(_typeName(widget.templateType))),
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

          final allCodes =
              visits.map((v) => v.countryCode).toList()..sort();
          final allTrips = tripsAsync.valueOrNull
                  ?.where((t) => allCodes.contains(t.countryCode))
                  .toList() ??
              [];

          // ── Date range ──────────────────────────────────────────────────
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
              ? (filteredTrips
                      .map((t) => t.countryCode)
                      .toSet()
                      .toList()
                    ..sort())
              : allCodes;

          // Country multi-select: effectiveCodes = displayedCodes minus
          // any codes the user has manually deselected (M74-T3).
          final effectiveCodes = displayedCodes
              .where((c) => !_manuallyDeselectedCodes.contains(c))
              .toList();
          // Trips for the effective code set.
          final effectiveTrips = filteredTrips
              .where((t) => effectiveCodes.contains(t.countryCode))
              .toList();

          final dateLabel = _computeDateLabel(effectiveTrips);
          final defaultTitle =
              '${effectiveCodes.length} Countries'
              '${dateLabel.isNotEmpty ? ' \u00B7 $dateLabel' : ''}';

          // Auto-generate title on first load when no override is set.
          if (!_autoGenerateFired && _titleOverride == null) {
            _autoGenerateFired = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _generateTitle(effectiveCodes, effectiveTrips, effectiveRange);
            });
          }

          // ── Shared callbacks used by both layout paths ─────────────
          void onCountryToggle(String code) {
            setState(() {
              if (_manuallyDeselectedCodes.contains(code)) {
                _manuallyDeselectedCodes =
                    {..._manuallyDeselectedCodes}..remove(code);
              } else if (effectiveCodes.length > 1) {
                _manuallyDeselectedCodes = {
                  ..._manuallyDeselectedCodes,
                  code
                };
              }
            });
            _generateTitle(
              displayedCodes
                  .where((c) => !_manuallyDeselectedCodes.contains(c))
                  .toList(),
              filteredTrips
                  .where(
                      (t) => !_manuallyDeselectedCodes.contains(t.countryCode))
                  .toList(),
              effectiveRange,
            );
          }

          // ── PASSPORT: full-screen card + floating overlays ─────────────
          if (widget.templateType == CardTemplateType.passport) {
            return Stack(
              children: [
                // Card fills entire body
                Positioned.fill(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 6.0,
                        child: _buildCardPreview(
                          effectiveCodes,
                          effectiveTrips,
                          dateLabel,
                        ),
                      ),
                    ),
                  ),
                ),
                // Top: compact frosted controls (dismissible)
                if (_showPassportControls)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _PassportTopOverlay(
                      titleController: _titleController,
                      titleOverride: _titleOverride,
                      defaultTitle: defaultTitle,
                      isTitleGenerating: _isTitleGenerating,
                      onTitleChanged: (v) => setState(
                          () => _titleOverride = v.isEmpty ? null : v),
                      onTitleCleared: () {
                        setState(() => _titleOverride = null);
                        _titleController.clear();
                      },
                      onGenerateTitle: () => _generateTitle(
                          effectiveCodes, effectiveTrips, effectiveRange),
                      onShuffleStamps: () => setState(() =>
                          _stampLayoutSeed =
                              math.Random().nextInt(0x7FFFFFFF)),
                      stampSizeMultiplier: _stampSizeMultiplier,
                      stampJitterFactor: _stampJitterFactor,
                      onSizeChanged: (v) =>
                          setState(() => _stampSizeMultiplier = v),
                      onJitterChanged: (v) =>
                          setState(() => _stampJitterFactor = v),
                      showDateSlider: showDateSlider,
                      yearMin: yearMin,
                      yearMax: yearMax,
                      effectiveRange: effectiveRange,
                      countryCount: effectiveCodes.length,
                      onYearChanged: (v) => setState(() {
                        _yearSelection = v;
                        _manuallyDeselectedCodes = {};
                      }),
                      onYearChangeEnd: (v) =>
                          _generateTitle(effectiveCodes, effectiveTrips, v),
                      displayedCodes: displayedCodes,
                      deselectedCodes: _manuallyDeselectedCodes,
                      onCountryToggle: onCountryToggle,
                      onDismiss: () =>
                          setState(() => _showPassportControls = false),
                    ),
                  ),
                // Floating show-controls button when overlay is dismissed
                if (!_showPassportControls)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 10,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showPassportControls = true),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            color: Colors.black.withValues(alpha: 0.38),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded,
                                    size: 14, color: Colors.white70),
                                SizedBox(width: 4),
                                Text('Controls',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Bottom: frosted action bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _PassportBottomBar(
                    sharing: _sharing,
                    printing: _printing,
                    bottomPadding: MediaQuery.paddingOf(context).bottom,
                    onShare: () => _onShare(
                        context, effectiveCodes, effectiveTrips, dateLabel),
                    onPrint: () => _onPrint(context, effectiveCodes, allCodes,
                        effectiveTrips, effectiveRange, showDateSlider),
                  ),
                ),
              ],
            );
          }

          // ── NON-PASSPORT: standard column layout ───────────────────────
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Control strip ────────────────────────────────────────
              _ControlStrip(
                titleController: _titleController,
                titleOverride: _titleOverride,
                defaultTitle: defaultTitle,
                portrait: _portrait,
                isTitleGenerating: _isTitleGenerating,
                showOrientationToggle: true,
                showShuffleButton: false,
                onTitleChanged: (v) =>
                    setState(() => _titleOverride = v.isEmpty ? null : v),
                onTitleCleared: () {
                  setState(() => _titleOverride = null);
                  _titleController.clear();
                },
                onGenerateTitle: () => _generateTitle(
                    effectiveCodes, effectiveTrips, effectiveRange),
                onOrientationToggle: () => setState(() {
                  _portrait = !_portrait;
                  _resetZoom();
                }),
                onShuffleStamps: () {},
              ),
              // ── Sort order (Grid + Heart) ────────────────────────────
              if (widget.templateType == CardTemplateType.grid ||
                  widget.templateType == CardTemplateType.heart) ...[
                const SizedBox(height: 4),
                _SortOrderPicker(
                  order: _order,
                  onChanged: (o) => setState(() {
                    if (widget.templateType == CardTemplateType.grid &&
                        o == HeartFlagOrder.randomized) {
                      _gridShuffleSeed++;
                    }
                    _order = o;
                  }),
                ),
              ],
              // ── Year range slider ────────────────────────────────────
              if (showDateSlider && effectiveRange != null) ...[
                const SizedBox(height: 4),
                _YearSlider(
                  yearMin: yearMin,
                  yearMax: yearMax,
                  values: effectiveRange,
                  countryCount: effectiveCodes.length,
                  onChanged: (v) => setState(() {
                    _yearSelection = v;
                    _manuallyDeselectedCodes = {};
                  }),
                  onChangeEnd: (v) =>
                      _generateTitle(effectiveCodes, effectiveTrips, v),
                ),
              ],
              // ── Country filter chips ─────────────────────────────────
              if (displayedCodes.length > 1) ...[
                const SizedBox(height: 4),
                _CountryFilterRow(
                  availableCodes: displayedCodes,
                  deselectedCodes: _manuallyDeselectedCodes,
                  onToggle: onCountryToggle,
                ),
              ],
              const SizedBox(height: 8),
              // ── Card preview ─────────────────────────────────────────
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
                        child: _buildCardPreview(
                          effectiveCodes,
                          effectiveTrips,
                          dateLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Action bar ───────────────────────────────────────────
              _ActionBar(
                sharing: _sharing,
                printing: _printing,
                onShare: () => _onShare(
                    context, effectiveCodes, effectiveTrips, dateLabel),
                onPrint: () => _onPrint(context, effectiveCodes, allCodes,
                    effectiveTrips, effectiveRange, showDateSlider),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        },
      ),
    );
  }

  // ── AI title generation ─────────────────────────────────────────────────────

  /// Reads cached hero labels for [trips] from Riverpod without side-effects.
  ///
  /// Returns null when no hero data is available yet; the generator then falls
  /// back to geography-based titles gracefully (ADR-137).
  List<HeroLabels>? _fetchHeroLabelsForTrips(List<TripRecord> trips) {
    final labels = <HeroLabels>[];
    for (final trip in trips) {
      final heroAsync = ref.read(heroForTripProvider(trip.id));
      final hero = heroAsync.valueOrNull;
      if (hero != null) {
        labels.add(HeroLabels(
          primaryScene: hero.primaryScene,
          secondaryScene: hero.secondaryScene,
          activity: hero.activity,
          mood: hero.mood,
          subjects: hero.subjects,
          landmark: hero.landmark,
          confidence: hero.labelConfidence,
        ));
      }
    }
    return labels.isEmpty ? null : labels;
  }

  Future<void> _generateTitle(
    List<String> codes,
    List<TripRecord> trips,
    RangeValues? effectiveRange,
  ) async {
    if (_isTitleGenerating) return;
    setState(() => _isTitleGenerating = true);

    // Year is intentionally excluded from the request — the card's date label
    // already shows the year range; titles must not repeat it (ADR-125).
    final request = TitleGenerationRequest(
      countryCodes: codes,
      countryNames: codes.map((c) => kCountryNames[c] ?? c).toList(),
      regionNames: codes
          .map((c) => kCountryContinent[c])
          .whereType<String>()
          .toSet()
          .toList(),
      cardType: widget.templateType,
      heroLabels: _fetchHeroLabelsForTrips(trips),
    );

    try {
      final result =
          await ref.read(titleGenerationServiceProvider).generate(request);
      debugPrint('[TitleGen] source=${result.source} title="${result.title}"');
      if (mounted) {
        setState(() {
          _titleOverride = result.title;
          _isTitleGenerating = false;
        });
        _titleController.text = result.title;
      }
    } catch (_) {
      if (mounted) setState(() => _isTitleGenerating = false);
    }
  }

  // ── Template builder ────────────────────────────────────────────────────────

  Widget _buildCardPreview(
    List<String> displayedCodes,
    List<TripRecord> filteredTrips,
    String dateLabel,
  ) {
    final template = _buildTemplate(displayedCodes, filteredTrips, dateLabel);
    final boundary = RepaintBoundary(key: _previewKey, child: template);
    // Timeline is transparent — wrap with white so text is readable on-screen.
    // The RepaintBoundary is inside, so share/export PNGs remain transparent.
    if (widget.templateType == CardTemplateType.timeline) {
      return ColoredBox(color: Colors.white, child: boundary);
    }
    return boundary;
  }

  Widget _buildTemplate(
    List<String> codes,
    List<TripRecord> trips,
    String dateLabel,
  ) {
    switch (widget.templateType) {
      case CardTemplateType.grid:
        // Apply sort order to codes before passing to the stateless widget.
        final sortedCodes = HeartLayoutEngine.sortCodes(
            codes, _order, trips, shuffleSeed: _gridShuffleSeed);
        return GridFlagsCard(
          countryCodes: sortedCodes,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
        );
      case CardTemplateType.heart:
        return HeartFlagsCard(
          countryCodes: codes,
          trips: trips,
          flagOrder: _order,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
        );
      case CardTemplateType.passport:
        return PassportStampsCard(
          countryCodes: codes,
          trips: trips,
          entryOnly: _entryOnly,
          forPrint: false, // preview uses screen layout so sliders take effect
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
          stampColor: null,
          dateColor: null,
          transparentBackground: false,
          seed: _stampLayoutSeed,
          sizeMultiplier: _stampSizeMultiplier,
          jitterFactor: _stampJitterFactor,
        );
      case CardTemplateType.timeline:
        return TimelineCard(
          trips: trips,
          countryCodes: codes,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          transparentBackground: true,
        );
      case CardTemplateType.frontRibbon:
        return FrontRibbonCard(
          countryCodes: codes,
          travelerLevel: 'Explorer',
        );
    }
  }

  // ── Date label ──────────────────────────────────────────────────────────────

  static String _computeDateLabel(List<TripRecord> trips) {
    if (trips.isEmpty) return '';
    final years = trips.map((t) => t.startedOn.year).toSet();
    final minYear = years.reduce(math.min);
    final maxYear = years.reduce(math.max);
    return minYear == maxYear ? '$minYear' : '$minYear\u2013$maxYear';
  }

  // ── Share action ────────────────────────────────────────────────────────────

  Future<void> _onShare(
    BuildContext context,
    List<String> codes,
    List<TripRecord> trips,
    String dateLabel,
  ) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _previewKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
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
          templateType: widget.templateType,
          countryCodes: codes,
          countryCount: codes.length,
          createdAt: DateTime.now().toUtc(),
        );
        unawaited(
            TravelCardService(FirebaseFirestore.instance).create(card));
      }

      if (!context.mounted) return;
      final size = MediaQuery.sizeOf(context);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My Roavvy travel card',
        sharePositionOrigin: Rect.fromLTWH(
            size.width / 2 - 22, size.height - 88, 44, 44),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ── Print action ────────────────────────────────────────────────────────────

  void _onPrint(
    BuildContext context,
    List<String> codes,
    List<String> allCodes,
    List<TripRecord> trips,
    RangeValues? effectiveRange,
    bool showDateSlider,
  ) {
    if (_sharing || _printing) return;
    unawaited(
        _navigateToPrint(context, codes, allCodes, trips, effectiveRange, showDateSlider));
  }

  Future<void> _navigateToPrint(
    BuildContext context,
    List<String> codes,
    List<String> allCodes,
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
      templateType: widget.templateType,
      countryCodes: codes,
      aspectRatio: _aspectRatio,
      entryOnly: _entryOnly,
      order: _order,
      yearStart: yearStart,
      yearEnd: yearEnd,
      titleOverride: _titleOverride,
      stampLayoutSeed: _stampLayoutSeed,
      stampSizeMultiplier: _stampSizeMultiplier,
      stampJitterFactor: _stampJitterFactor,
    );

    // Same params → skip re-render (ADR-103).
    if (currentParams == _lastConfirmedParams &&
        _artworkImageBytes != null) {
      if (!context.mounted) return;
      _goToProductBrowser(context, codes, allCodes);
      return;
    }

    // Capture artwork. For passport, grab directly from the RepaintBoundary
    // so the printed image is pixel-for-pixel what the user sees (WYSIWYG).
    // For all other templates, use CardImageRenderer for forPrint layout.
    setState(() => _printing = true);
    Uint8List? capturedBytes;
    try {
      if (!context.mounted) return;

      if (widget.templateType == CardTemplateType.passport) {
        // WYSIWYG: capture from the live preview boundary (ADR-133).
        final boundary = _previewKey.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 3.5);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          capturedBytes = byteData?.buffer.asUint8List();
        }
      } else {
        final dateLabel = _computeDateLabel(trips);
        final renderCodes = widget.templateType == CardTemplateType.grid
            ? HeartLayoutEngine.sortCodes(codes, _order, trips,
                shuffleSeed: _gridShuffleSeed)
            : codes;
        final result = await CardImageRenderer.render(
          context,
          widget.templateType,
          codes: renderCodes,
          trips: trips,
          forPrint: true,
          entryOnly: _entryOnly,
          cardAspectRatio: _aspectRatio,
          heartOrder: _order,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
          stampColor: null,
          dateColor: null,
          transparentBackground: widget.templateType == CardTemplateType.grid,
          stampSeed: _stampLayoutSeed,
          stampSizeMultiplier: _stampSizeMultiplier,
          stampJitterFactor: _stampJitterFactor,
        );
        capturedBytes = result.bytes;
      }
    } catch (_) {
      capturedBytes = null;
    } finally {
      if (mounted) setState(() => _printing = false);
    }

    if (capturedBytes == null || !context.mounted) return;

    setState(() {
      _lastConfirmedParams = currentParams;
      _artworkImageBytes = capturedBytes;
      _lastConfirmedTrips = trips;
    });

    if (!context.mounted) return;
    _goToProductBrowser(context, codes, allCodes);
  }

  void _goToProductBrowser(BuildContext context, List<String> codes, List<String> allCodes) {
    final uid = ref.read(currentUidProvider);
    String? cardId;
    if (uid != null) {
      cardId = 'card-${DateTime.now().microsecondsSinceEpoch}';
      final card = TravelCard(
        cardId: cardId,
        userId: uid,
        templateType: widget.templateType,
        countryCodes: codes,
        countryCount: codes.length,
        createdAt: DateTime.now().toUtc(),
      );
      unawaited(
          TravelCardService(FirebaseFirestore.instance).create(card));
    }

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LocalMockupPreviewScreen(
        selectedCodes: codes,
        allCodes: allCodes,
        trips: _lastConfirmedTrips ?? const [],
        artworkImageBytes: _artworkImageBytes!,
        artworkConfirmationId: null,
        initialTemplate: widget.templateType,
        confirmedAspectRatio: _aspectRatio,
        confirmedEntryOnly: _entryOnly,
        cardId: cardId,
        titleOverride: _titleOverride,
        stampColor: null,
        dateColor: null,
        transparentBackground: widget.templateType == CardTemplateType.grid,
        stampSizeMultiplier: _stampSizeMultiplier,
        stampJitterFactor: _stampJitterFactor,
        stampLayoutSeed: _stampLayoutSeed,
      ),
    ));
  }
}

const _kAmber = Color(0xFFD4A017);

// ── Control strip ──────────────────────────────────────────────────────────────

class _ControlStrip extends StatelessWidget {
  const _ControlStrip({
    required this.titleController,
    required this.titleOverride,
    required this.defaultTitle,
    required this.portrait,
    required this.isTitleGenerating,
    required this.showOrientationToggle,
    required this.showShuffleButton,
    required this.onTitleChanged,
    required this.onTitleCleared,
    required this.onGenerateTitle,
    required this.onOrientationToggle,
    required this.onShuffleStamps,
  });

  final TextEditingController titleController;
  final String? titleOverride;
  final String defaultTitle;
  final bool portrait;
  final bool isTitleGenerating;
  final bool showOrientationToggle;
  final bool showShuffleButton;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onTitleCleared;
  final VoidCallback onGenerateTitle;
  final VoidCallback onOrientationToggle;
  final VoidCallback onShuffleStamps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          // Auto-generate button
          IconButton(
            onPressed: isTitleGenerating ? null : onGenerateTitle,
            icon: const Icon(Icons.auto_awesome, size: 18),
            tooltip: 'Generate title',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: defaultTitle,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.white24),
                  ),
                  suffixIcon: isTitleGenerating
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : titleOverride != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: onTitleCleared,
                              padding: EdgeInsets.zero,
                            )
                          : null,
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: onTitleChanged,
              ),
            ),
          ),
          if (showShuffleButton) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onShuffleStamps,
              icon: const Icon(Icons.shuffle_rounded, size: 15),
              label: const Text('Shuffle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kAmber,
                side: const BorderSide(color: _kAmber, width: 1.5),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 0),
                minimumSize: const Size(0, 38),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (showOrientationToggle) ...[
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: onOrientationToggle,
              icon: Icon(
                portrait
                    ? Icons.stay_current_portrait
                    : Icons.stay_current_landscape,
                size: 20,
              ),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(38, 38),
              ),
              tooltip: portrait ? 'Switch to landscape' : 'Switch to portrait',
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sort order picker (Grid + Heart) ──────────────────────────────────────────

class _SortOrderPicker extends StatelessWidget {
  const _SortOrderPicker({
    required this.order,
    required this.onChanged,
  });

  final HeartFlagOrder order;
  final ValueChanged<HeartFlagOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _SortChip(
            label: 'Shuffle',
            icon: Icons.shuffle_outlined,
            selected: order == HeartFlagOrder.randomized,
            onTap: () => onChanged(HeartFlagOrder.randomized),
          ),
          const SizedBox(width: 6),
          _SortChip(
            label: 'By Date',
            icon: Icons.calendar_today_outlined,
            selected: order == HeartFlagOrder.chronological,
            onTap: () => onChanged(HeartFlagOrder.chronological),
          ),
          const SizedBox(width: 6),
          _SortChip(
            label: 'A \u2192 Z',
            icon: Icons.sort_by_alpha,
            selected: order == HeartFlagOrder.alphabetical,
            onTap: () => onChanged(HeartFlagOrder.alphabetical),
          ),
          const SizedBox(width: 6),
          _SortChip(
            label: 'By Region',
            icon: Icons.public_outlined,
            selected: order == HeartFlagOrder.geographic,
            onTap: () => onChanged(HeartFlagOrder.geographic),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? onSurface.withValues(alpha: 0.7)
                : onSurface.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(6),
          color: selected
              ? onSurface.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected
                  ? onSurface.withValues(alpha: 0.9)
                  : onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? onSurface.withValues(alpha: 0.9)
                    : onSurface.withValues(alpha: 0.55),
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Passport full-screen overlays ─────────────────────────────────────────────

/// Frosted-glass top overlay — title, shuffle, size/scatter sliders, and
/// optional year + country controls. All float over the card image.
class _PassportTopOverlay extends StatelessWidget {
  const _PassportTopOverlay({
    required this.titleController,
    required this.titleOverride,
    required this.defaultTitle,
    required this.isTitleGenerating,
    required this.onTitleChanged,
    required this.onTitleCleared,
    required this.onGenerateTitle,
    required this.onShuffleStamps,
    required this.stampSizeMultiplier,
    required this.stampJitterFactor,
    required this.onSizeChanged,
    required this.onJitterChanged,
    required this.showDateSlider,
    required this.yearMin,
    required this.yearMax,
    required this.effectiveRange,
    required this.countryCount,
    required this.onYearChanged,
    required this.onYearChangeEnd,
    required this.displayedCodes,
    required this.deselectedCodes,
    required this.onCountryToggle,
    required this.onDismiss,
  });

  final TextEditingController titleController;
  final String? titleOverride;
  final String defaultTitle;
  final bool isTitleGenerating;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onTitleCleared;
  final VoidCallback onGenerateTitle;
  final VoidCallback onShuffleStamps;
  final double stampSizeMultiplier;
  final double stampJitterFactor;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<double> onJitterChanged;
  final bool showDateSlider;
  final double? yearMin;
  final double? yearMax;
  final RangeValues? effectiveRange;
  final int countryCount;
  final ValueChanged<RangeValues> onYearChanged;
  final ValueChanged<RangeValues> onYearChangeEnd;
  final List<String> displayedCodes;
  final Set<String> deselectedCodes;
  final ValueChanged<String> onCountryToggle;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title row + shuffle + dismiss ────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 2),
                child: Row(
                  children: [
                    // Auto-generate
                    IconButton(
                      onPressed: isTitleGenerating ? null : onGenerateTitle,
                      icon: const Icon(Icons.auto_awesome, size: 17),
                      tooltip: 'Generate title',
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 4),
                    // Title field
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: defaultTitle,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            suffixIcon: isTitleGenerating
                                ? const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : titleOverride != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14),
                                        onPressed: onTitleCleared,
                                        padding: EdgeInsets.zero,
                                      )
                                    : null,
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: onTitleChanged,
                        ),
                      ),
                    ),
                    // Shuffle
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: onShuffleStamps,
                      icon: const Icon(Icons.shuffle_rounded, size: 13),
                      label: const Text('Shuffle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kAmber,
                        side: const BorderSide(color: _kAmber, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 32),
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Dismiss
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.expand_less_rounded, size: 18),
                      tooltip: 'Hide controls',
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),
              // ── Size + scatter sliders ───────────────────────────────
              _PassportSlidersRow(
                stampSizeMultiplier: stampSizeMultiplier,
                stampJitterFactor: stampJitterFactor,
                onSizeChanged: onSizeChanged,
                onJitterChanged: onJitterChanged,
              ),
              // ── Year slider (conditional) ────────────────────────────
              if (showDateSlider &&
                  effectiveRange != null &&
                  yearMin != null &&
                  yearMax != null) ...[
                const SizedBox(height: 2),
                _YearSlider(
                  yearMin: yearMin!,
                  yearMax: yearMax!,
                  values: effectiveRange!,
                  countryCount: countryCount,
                  onChanged: onYearChanged,
                  onChangeEnd: onYearChangeEnd,
                ),
              ],
              // ── Country chips (conditional) ──────────────────────────
              if (displayedCodes.length > 1) ...[
                const SizedBox(height: 2),
                _CountryFilterRow(
                  availableCodes: displayedCodes,
                  deselectedCodes: deselectedCodes,
                  onToggle: onCountryToggle,
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass bottom action bar anchored over the card.
class _PassportBottomBar extends StatelessWidget {
  const _PassportBottomBar({
    required this.sharing,
    required this.printing,
    required this.bottomPadding,
    required this.onShare,
    required this.onPrint,
  });

  final bool sharing;
  final bool printing;
  final double bottomPadding;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (sharing || printing) ? null : onShare,
                  icon: sharing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (sharing || printing) ? null : onPrint,
                  icon: printing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Passport stamp sliders (size + scatter, compact horizontal strip) ──────────

class _PassportSlidersRow extends StatelessWidget {
  const _PassportSlidersRow({
    required this.stampSizeMultiplier,
    required this.stampJitterFactor,
    required this.onSizeChanged,
    required this.onJitterChanged,
  });

  final double stampSizeMultiplier;
  final double stampJitterFactor;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<double> onJitterChanged;

  static String _sizeLabel(double v) =>
      v == 1.0 ? 'Default' : v < 1.0 ? 'Smaller' : 'Larger';

  static String _scatterLabel(double v) =>
      v < 0.3 ? 'Grid' : v < 1.2 ? 'Natural' : v < 2.0 ? 'Scattered' : 'Max';

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: _kAmber,
      thumbColor: _kAmber,
      inactiveTrackColor: Colors.white12,
      overlayColor: _kAmber.withValues(alpha: 0.15),
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Stamp size ───────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_size_select_small,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 5),
                      const Text('Size',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        _sizeLabel(stampSizeMultiplier),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      value: stampSizeMultiplier,
                      min: 0.3,
                      max: 2.0,
                      divisions: 17,
                      onChanged: onSizeChanged,
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white12,
            ),
            // ── Scatter ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.scatter_plot_outlined,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 5),
                      const Text('Scatter',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        _scatterLabel(stampJitterFactor),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      value: stampJitterFactor,
                      min: 0.0,
                      max: 2.5,
                      divisions: 25,
                      onChanged: onJitterChanged,
                    ),
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

// ── Year slider ────────────────────────────────────────────────────────────────

class _YearSlider extends StatelessWidget {
  const _YearSlider({
    required this.yearMin,
    required this.yearMax,
    required this.values,
    required this.countryCount,
    required this.onChanged,
    this.onChangeEnd,
  });

  final double yearMin;
  final double yearMax;
  final RangeValues values;
  final int countryCount;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<RangeValues>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final startYear = values.start.round();
    final endYear = values.end.round();
    final isFullRange =
        startYear == yearMin.round() && endYear == yearMax.round();
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.date_range_outlined,
                  size: 13,
                  color: onSurface.withValues(alpha: 0.35)),
              const SizedBox(width: 6),
              Text(
                isFullRange ? 'All time' : '$startYear \u2013 $endYear',
                style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.55)),
              ),
              const Spacer(),
              Text(
                '$countryCount '
                '${countryCount == 1 ? 'country' : 'countries'}',
                style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          RangeSlider(
            values: values,
            min: yearMin,
            max: yearMax,
            divisions: (yearMax - yearMin).round(),
            labels: RangeLabels(
                startYear.toString(), endYear.toString()),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: (sharing || printing) ? null : onShare,
              icon: sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (sharing || printing) ? null : onPrint,
              icon: printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: const Text('Print'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Country filter row (M74-T3) ────────────────────────────────────────────────

class _CountryFilterRow extends StatelessWidget {
  const _CountryFilterRow({
    required this.availableCodes,
    required this.deselectedCodes,
    required this.onToggle,
  });

  final List<String> availableCodes;
  final Set<String> deselectedCodes;
  final ValueChanged<String> onToggle;

  static String _flagEmoji(String code) {
    if (code.length != 2) return '\u{1F30D}';
    final up = code.toUpperCase();
    final a = up.codeUnitAt(0) - 65 + 0x1F1E6;
    final b = up.codeUnitAt(1) - 65 + 0x1F1E6;
    if (a < 0x1F1E6 || a > 0x1F1FF || b < 0x1F1E6 || b > 0x1F1FF) {
      return '\u{1F30D}';
    }
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  static String _shortName(String code) {
    final name = kCountryNames[code] ?? code;
    return name.length > 11 ? '${name.substring(0, 9)}\u2026' : name;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = availableCodes.where((c) => !deselectedCodes.contains(c)).length;
    final hasDeselected = deselectedCodes.isNotEmpty;

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
                    ? '$activeCount of ${availableCodes.length} countries'
                    : '${availableCodes.length} countries',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableCodes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final code = availableCodes[i];
                final isSelected = !deselectedCodes.contains(code);
                return GestureDetector(
                  onTap: () => onToggle(code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
}
