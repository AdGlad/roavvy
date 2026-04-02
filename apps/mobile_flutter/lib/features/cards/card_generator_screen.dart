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
import 'card_templates.dart';
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
    this.yearStart,
    this.yearEnd,
  });

  final CardTemplateType templateType;
  final List<String> countryCodes;
  final double aspectRatio;
  final bool entryOnly;
  final int? yearStart;
  final int? yearEnd;

  @override
  bool operator ==(Object other) {
    if (other is! _CardParams) return false;
    return templateType == other.templateType &&
        listEquals(countryCodes, other.countryCodes) &&
        aspectRatio == other.aspectRatio &&
        entryOnly == other.entryOnly &&
        yearStart == other.yearStart &&
        yearEnd == other.yearEnd;
  }

  @override
  int get hashCode =>
      Object.hash(templateType, Object.hashAll(countryCodes), aspectRatio,
          entryOnly, yearStart, yearEnd);
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
  bool _portrait = false;
  RangeValues? _yearSelection; // null = full range

  final _previewKey = GlobalKey();
  final _transformController = TransformationController();
  bool _sharing = false;

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
                  countryCount: displayedCodes.length,
                  onChanged: (v) => setState(() => _yearSelection = v),
                ),
              ],
              const SizedBox(height: 8),
              // Card preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1.0,
                      maxScale: 6.0,
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: _buildTemplate(displayedCodes, filteredTrips),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionBar(
                sharing: _sharing,
                onShare: () => _onShare(context, displayedCodes),
                onPrint: () => _onPrint(
                  context,
                  displayedCodes,
                  filteredTrips,
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
        );
      case CardTemplateType.heart:
        return HeartFlagsCard(
          countryCodes: codes,
          trips: trips,
          flagOrder: _heartOrder,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
        );
      case CardTemplateType.passport:
        return PassportStampsCard(
          countryCodes: codes,
          trips: trips,
          entryOnly: _entryOnly,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
        );
      case CardTemplateType.timeline:
        return TimelineCard(
          trips: trips,
          countryCodes: codes,
          aspectRatio: _aspectRatio,
          dateLabel: dateLabel,
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
    if (_sharing) return;
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
      yearStart: yearStart,
      yearEnd: yearEnd,
    );

    // M51-E3: same params — skip re-confirmation (ADR-103)
    if (currentParams == _lastConfirmedParams &&
        _artworkConfirmationId != null) {
      if (!context.mounted) return;
      _goToProductBrowser(context, codes);
      return;
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

    // M55-E: Push LocalMockupPreviewScreen (replaces MerchProductBrowserScreen).
    // artworkImageBytes and artworkConfirmationId are always non-null here —
    // guarded by _navigateToPrint which sets them before calling this method.
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LocalMockupPreviewScreen(
        selectedCodes: codes,
        trips: _lastConfirmedTrips ?? const [],
        artworkImageBytes: _artworkImageBytes!,
        artworkConfirmationId: _artworkConfirmationId!,
        initialTemplate: _selected,
        cardId: cardId,
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

// ── Action bar ─────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.sharing,
    required this.onShare,
    required this.onPrint,
  });

  final bool sharing;
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
              onPressed: sharing ? null : onShare,
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
              onPressed: sharing ? null : onPrint,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print your card'),
            ),
          ),
        ],
      ),
    );
  }
}
