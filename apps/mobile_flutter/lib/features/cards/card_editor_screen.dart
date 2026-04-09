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

import '../../core/providers.dart';
import '../merch/local_mockup_preview_screen.dart';
import 'artwork_confirmation_screen.dart';
import 'artwork_confirmation_service.dart';
import 'card_image_renderer.dart';
import 'card_templates.dart';
import 'front_ribbon_card.dart';
import 'heart_layout_engine.dart';
import 'timeline_card.dart';
import 'travel_card_service.dart';

// ── Passport colour mode ───────────────────────────────────────────────────────

/// Stamp colour mode for the Passport card template (ADR-119).
enum PassportColorMode { multicolor, black, white }

extension _PassportParams on PassportColorMode {
  Color? get stampColor => switch (this) {
        PassportColorMode.multicolor => null,
        PassportColorMode.black => const Color(0xFF1A1A1A),
        PassportColorMode.white => Colors.white,
      };

  Color? get dateColor => switch (this) {
        PassportColorMode.multicolor => null,
        PassportColorMode.black => const Color(0xFF1A1A1A),
        PassportColorMode.white => Colors.white,
      };

  bool get transparentBackground => this == PassportColorMode.white;
}

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
    required this.passportColorMode,
    this.yearStart,
    this.yearEnd,
    this.titleOverride,
  });

  final CardTemplateType templateType;
  final List<String> countryCodes;
  final double aspectRatio;
  final bool entryOnly;
  final HeartFlagOrder order;
  final PassportColorMode passportColorMode;
  final int? yearStart;
  final int? yearEnd;
  final String? titleOverride;

  @override
  bool operator ==(Object other) {
    if (other is! _CardParams) return false;
    return templateType == other.templateType &&
        listEquals(countryCodes, other.countryCodes) &&
        aspectRatio == other.aspectRatio &&
        entryOnly == other.entryOnly &&
        order == other.order &&
        passportColorMode == other.passportColorMode &&
        yearStart == other.yearStart &&
        yearEnd == other.yearEnd &&
        titleOverride == other.titleOverride;
  }

  @override
  int get hashCode => Object.hash(
        templateType,
        Object.hashAll(countryCodes),
        aspectRatio,
        entryOnly,
        order,
        passportColorMode,
        yearStart,
        yearEnd,
        titleOverride,
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
  bool _entryOnly = false;
  bool _portrait = true;
  RangeValues? _yearSelection;
  late TextEditingController _titleController;
  String? _titleOverride;
  PassportColorMode _passportColorMode = PassportColorMode.multicolor;
  bool _sharing = false;
  bool _printing = false;

  // Confirmation state (ADR-103)
  _CardParams? _lastConfirmedParams;
  String? _artworkConfirmationId;
  Uint8List? _artworkImageBytes;
  List<TripRecord>? _lastConfirmedTrips;

  final _previewKey = GlobalKey();
  final _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
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

          final dateLabel = _computeDateLabel(filteredTrips);
          final defaultTitle =
              '${displayedCodes.length} Countries'
              '${dateLabel.isNotEmpty ? ' \u00B7 $dateLabel' : ''}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Control strip ──────────────────────────────────────────
              _ControlStrip(
                titleController: _titleController,
                titleOverride: _titleOverride,
                defaultTitle: defaultTitle,
                portrait: _portrait,
                onTitleChanged: (v) =>
                    setState(() => _titleOverride = v.isEmpty ? null : v),
                onTitleCleared: () {
                  setState(() => _titleOverride = null);
                  _titleController.clear();
                },
                onOrientationToggle: () => setState(() {
                  _portrait = !_portrait;
                  _resetZoom();
                }),
              ),
              // ── Passport: entry/exit toggle ────────────────────────────
              if (widget.templateType == CardTemplateType.passport)
                _EntryExitToggle(
                  entryOnly: _entryOnly,
                  onChanged: (v) => setState(() => _entryOnly = v),
                ),
              // ── Sort order (Grid + Heart) ──────────────────────────────
              if (widget.templateType == CardTemplateType.grid ||
                  widget.templateType == CardTemplateType.heart) ...[
                const SizedBox(height: 4),
                _SortOrderPicker(
                  order: _order,
                  onChanged: (o) => setState(() => _order = o),
                ),
              ],
              // ── Stamp colour (Passport) ────────────────────────────────
              if (widget.templateType == CardTemplateType.passport) ...[
                const SizedBox(height: 4),
                _PassportColorPicker(
                  mode: _passportColorMode,
                  onChanged: (m) => setState(() => _passportColorMode = m),
                ),
              ],
              // ── Year range slider ──────────────────────────────────────
              if (showDateSlider && effectiveRange != null) ...[
                const SizedBox(height: 4),
                _YearSlider(
                  yearMin: yearMin,
                  yearMax: yearMax,
                  values: effectiveRange,
                  countryCount: displayedCodes.length,
                  onChanged: (v) =>
                      setState(() => _yearSelection = v),
                ),
              ],
              const SizedBox(height: 8),
              // ── Card preview ───────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 340),
                      child: InteractiveViewer(
                        transformationController:
                            _transformController,
                        minScale: 1.0,
                        maxScale: 6.0,
                        child: _buildCardPreview(
                          displayedCodes,
                          filteredTrips,
                          dateLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Action bar ─────────────────────────────────────────────
              _ActionBar(
                sharing: _sharing,
                printing: _printing,
                onShare: () =>
                    _onShare(context, displayedCodes, filteredTrips, dateLabel),
                onPrint: () => _onPrint(
                  context,
                  displayedCodes,
                  filteredTrips,
                  effectiveRange,
                  showDateSlider,
                ),
              ),
              SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        },
      ),
    );
  }

  // ── Template builder ────────────────────────────────────────────────────────

  Widget _buildCardPreview(
    List<String> displayedCodes,
    List<TripRecord> filteredTrips,
    String dateLabel,
  ) {
    final template = _buildTemplate(displayedCodes, filteredTrips, dateLabel);

    // White stamp mode: wrap the card in a black container so white stamps are
    // visible. RepaintBoundary sits OUTSIDE the black container so that the
    // share capture includes the black background (share = visible on any
    // surface). Print uses CardImageRenderer with transparentBackground: true,
    // so the POD product receives white ink on transparent (ADR-119).
    final child =
        (widget.templateType == CardTemplateType.passport &&
                _passportColorMode == PassportColorMode.white)
            ? ColoredBox(color: Colors.black, child: template)
            : template;

    return RepaintBoundary(key: _previewKey, child: child);
  }

  Widget _buildTemplate(
    List<String> codes,
    List<TripRecord> trips,
    String dateLabel,
  ) {
    switch (widget.templateType) {
      case CardTemplateType.grid:
        // Apply sort order to codes before passing to the stateless widget.
        final sortedCodes =
            HeartLayoutEngine.sortCodes(codes, _order, trips);
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
          forPrint: true,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
          titleOverride: _titleOverride,
          stampColor: _passportColorMode.stampColor,
          dateColor: _passportColorMode.dateColor,
          transparentBackground:
              _passportColorMode.transparentBackground,
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
    List<TripRecord> trips,
    RangeValues? effectiveRange,
    bool showDateSlider,
  ) {
    if (_sharing || _printing) return;
    unawaited(
        _navigateToPrint(context, codes, trips, effectiveRange, showDateSlider));
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
      templateType: widget.templateType,
      countryCodes: codes,
      aspectRatio: _aspectRatio,
      entryOnly: _entryOnly,
      order: _order,
      passportColorMode: _passportColorMode,
      yearStart: yearStart,
      yearEnd: yearEnd,
      titleOverride: _titleOverride,
    );

    // Same params → skip re-confirmation (ADR-103).
    if (currentParams == _lastConfirmedParams &&
        _artworkConfirmationId != null) {
      if (!context.mounted) return;
      _goToProductBrowser(context, codes);
      return;
    }

    // Pre-render card before pushing ArtworkConfirmationScreen (ADR-112).
    setState(() => _printing = true);
    CardRenderResult? preRender;
    try {
      if (!context.mounted) return;
      final dateLabel = _computeDateLabel(trips);
      preRender = await CardImageRenderer.render(
        context,
        widget.templateType,
        codes: codes,
        trips: trips,
        forPrint: widget.templateType == CardTemplateType.passport,
        entryOnly: _entryOnly,
        cardAspectRatio: _aspectRatio,
        heartOrder: _order,
        dateLabel: dateLabel,
        titleOverride: _titleOverride,
        stampColor: _passportColorMode.stampColor,
        dateColor: _passportColorMode.dateColor,
        transparentBackground: _passportColorMode.transparentBackground,
      );
    } catch (_) {
      preRender = null;
    } finally {
      if (mounted) setState(() => _printing = false);
    }

    final showUpdatedBanner = _artworkConfirmationId != null;
    final dateRangeStart =
        yearStart != null ? DateTime(yearStart) : null;
    final dateRangeEnd =
        yearEnd != null ? DateTime(yearEnd, 12, 31) : null;

    if (!context.mounted) return;
    final result = await Navigator.of(context)
        .push<ArtworkConfirmResult?>(
      MaterialPageRoute(
        builder: (_) => ArtworkConfirmationScreen(
          templateType: widget.templateType,
          countryCodes: codes,
          filteredTrips: trips,
          dateRangeStart: dateRangeStart,
          dateRangeEnd: dateRangeEnd,
          aspectRatio: _aspectRatio,
          entryOnly: _entryOnly,
          showUpdatedBanner: showUpdatedBanner,
          preRenderedResult: preRender,
          titleOverride: _titleOverride,
          stampColor: _passportColorMode.stampColor,
          dateColor: _passportColorMode.dateColor,
          transparentBackground:
              _passportColorMode.transparentBackground,
        ),
      ),
    );

    if (result == null || !mounted) return;

    // Archive superseded confirmation (ADR-106).
    final priorId = _artworkConfirmationId;
    if (priorId != null && priorId != result.confirmationId) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        unawaited(
          ArtworkConfirmationService(FirebaseFirestore.instance)
              .archive(uid, priorId),
        );
      }
    }

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
        trips: _lastConfirmedTrips ?? const [],
        artworkImageBytes: _artworkImageBytes!,
        artworkConfirmationId: _artworkConfirmationId!,
        initialTemplate: widget.templateType,
        confirmedAspectRatio: _aspectRatio,
        confirmedEntryOnly: _entryOnly,
        cardId: cardId,
        titleOverride: _titleOverride,
        stampColor: _passportColorMode.stampColor,
        dateColor: _passportColorMode.dateColor,
        transparentBackground:
            _passportColorMode.transparentBackground,
      ),
    ));
  }
}

// ── Control strip ──────────────────────────────────────────────────────────────

class _ControlStrip extends StatelessWidget {
  const _ControlStrip({
    required this.titleController,
    required this.titleOverride,
    required this.defaultTitle,
    required this.portrait,
    required this.onTitleChanged,
    required this.onTitleCleared,
    required this.onOrientationToggle,
  });

  final TextEditingController titleController;
  final String? titleOverride;
  final String defaultTitle;
  final bool portrait;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onTitleCleared;
  final VoidCallback onOrientationToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
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
                  suffixIcon: titleOverride != null
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
      ),
    );
  }
}

// ── Entry/Exit toggle (Passport only) ─────────────────────────────────────────

class _EntryExitToggle extends StatelessWidget {
  const _EntryExitToggle({
    required this.entryOnly,
    required this.onChanged,
  });

  final bool entryOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Entry + Exit',
            selected: !entryOnly,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _ToggleChip(
            label: 'Entry only',
            selected: entryOnly,
            onTap: () => onChanged(true),
          ),
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

// ── Passport colour picker ────────────────────────────────────────────────────

class _PassportColorPicker extends StatelessWidget {
  const _PassportColorPicker({
    required this.mode,
    required this.onChanged,
  });

  final PassportColorMode mode;
  final ValueChanged<PassportColorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ColorModeButton(
            label: 'Multicolor',
            swatch: null,
            mode: PassportColorMode.multicolor,
            selected: mode == PassportColorMode.multicolor,
            onTap: () => onChanged(PassportColorMode.multicolor),
          ),
          const SizedBox(width: 8),
          _ColorModeButton(
            label: 'Black',
            swatch: const Color(0xFF1A1A1A),
            mode: PassportColorMode.black,
            selected: mode == PassportColorMode.black,
            onTap: () => onChanged(PassportColorMode.black),
          ),
          const SizedBox(width: 8),
          _ColorModeButton(
            label: 'White',
            swatch: Colors.white,
            mode: PassportColorMode.white,
            selected: mode == PassportColorMode.white,
            onTap: () => onChanged(PassportColorMode.white),
          ),
        ],
      ),
    );
  }
}

class _ColorModeButton extends StatelessWidget {
  const _ColorModeButton({
    required this.label,
    required this.swatch,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? swatch; // null → rainbow/multicolor indicator
  final PassportColorMode mode;
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
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: swatch ?? Colors.transparent,
                border: Border.all(
                  color: onSurface.withValues(alpha: 0.3),
                ),
              ),
              child: swatch == null
                  ? const Icon(Icons.palette_outlined,
                      size: 8, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

// ── Generic toggle chip ────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? onSurface.withValues(alpha: 0.9)
                : onSurface.withValues(alpha: 0.55),
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
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
