import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../memory/memory_anniversary_photo.dart';
import 'local_mockup_preview_screen.dart';
import 'merch_exclusive_design.dart';
import 'merch_preset.dart';
import 'merch_option_list_widgets.dart';
import 'merch_title_wordbank.dart';
import 'pulse_merch_option.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Shown between "Print on a t-shirt" (Daily Memory Pulse) and
/// [LocalMockupPreviewScreen].
///
/// Displays ~15 pre-scoped merch options grouped by card type (Passport, Flags,
/// Tour Dates), each pre-rendered with matching front + back shirt mockups.
/// Each option uses a consistent scope for both artwork sides, fixing the
/// scope-mismatch bug.
///
/// Rendering widgets are shared with [AchievementMerchOptionScreen] via
/// [merch_option_list_widgets.dart] (ADR-149).
class PulseMerchOptionScreen extends ConsumerStatefulWidget {
  const PulseMerchOptionScreen({
    super.key,
    required this.hero,
    required this.allTrips,
    required this.allVisits,
  });

  final MemoryAnniversaryPhoto hero;
  final List<TripRecord> allTrips;
  final List<EffectiveVisitedCountry> allVisits;

  @override
  ConsumerState<PulseMerchOptionScreen> createState() =>
      _PulseMerchOptionScreenState();
}

class _PulseMerchOptionScreenState
    extends ConsumerState<PulseMerchOptionScreen> {
  bool _showAll = false;

  // ── Option builder ────────────────────────────────────────────────────────────

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
    final isPassport = template == CardTemplateType.passport;

    ({double jitter, double size}) tune(
      List<TripRecord> trips,
      List<String> codes,
    ) {
      if (isPassport) return merchAutoTuneStamps(trips.length * 2);
      return merchAutoTuneCodes(codes.length);
    }

    final options = <PulseMerchOption>[];

    // 1. This trip
    final tripList = heroTrip != null ? [heroTrip] : const <TripRecord>[];
    final heroCountryCode = widget.hero.countryCode ?? '';
    final t1 = tune(tripList, [heroCountryCode]);
    options.add(
      PulseMerchOption(
        id: '${template.name}_trip',
        title: '$countryName $year',
        description: 'Your $countryName trip',
        scope: PulseMerchScope.pulseTrip,
        template: template,
        codes: [heroCountryCode],
        trips: tripList,
        jitter: t1.jitter,
        stampSizeMultiplier: t1.size,
        artworkSubtitle: MerchTitleWordbank.buildSubtitleLine(1, year: year),
      ),
    );

    // 2. Year in review (only when multiple countries that year)
    if (yearCodes.length > 1) {
      final t2 = tune(yearTrips, yearCodes);
      options.add(
        PulseMerchOption(
          id: '${template.name}_year',
          title: '$year Travels',
          description: '${yearCodes.length} countries visited in $year',
          scope: PulseMerchScope.pulseYear,
          template: template,
          codes: yearCodes,
          trips: yearTrips,
          jitter: t2.jitter,
          stampSizeMultiplier: t2.size,
          artworkSubtitle: MerchTitleWordbank.buildSubtitleLine(
            yearCodes.length,
            year: year,
          ),
        ),
      );
    }

    // 3. All visits to this country
    final t3 = tune(countryTrips, [heroCountryCode]);
    options.add(
      PulseMerchOption(
        id: '${template.name}_country',
        title: '$countryName Memories',
        description:
            countryTrips.isEmpty
                ? 'All your $countryName stamps'
                : '${countryTrips.length} '
                    '${countryTrips.length == 1 ? "trip" : "trips"} to $countryName',
        scope: PulseMerchScope.allVisitsToCountry,
        template: template,
        codes: [heroCountryCode],
        trips: countryTrips,
        jitter: t3.jitter,
        stampSizeMultiplier: t3.size,
        artworkSubtitle: MerchTitleWordbank.buildSubtitleLine(1),
      ),
    );

    // 4. All-time collection (only when more than one country exists)
    if (allCodes.length > 1) {
      final t4 = tune(widget.allTrips, allCodes);
      options.add(
        PulseMerchOption(
          id: '${template.name}_alltime',
          title: 'World Collection',
          description: '${allCodes.length} countries across all your travels',
          scope: PulseMerchScope.allTime,
          template: template,
          codes: allCodes,
          trips: widget.allTrips,
          jitter: t4.jitter,
          stampSizeMultiplier: t4.size,
          artworkSubtitle: MerchTitleWordbank.buildSubtitleLine(
            allCodes.length,
          ),
        ),
      );
    }

    return options;
  }

  List<MerchOptionListItem> _buildItems({required bool landmarkAvailable}) {
    final year = widget.hero.capturedAt.year;
    final heroCountryCode = widget.hero.countryCode ?? '';
    final countryName =
        heroCountryCode.isNotEmpty
            ? (kCountryNames[heroCountryCode] ?? heroCountryCode)
            : 'Your travels';
    final heroTrip =
        widget.hero.tripId != null
            ? widget.allTrips.where((t) => t.id == widget.hero.tripId).firstOrNull
            : null;
    final yearTrips = widget.allTrips.where((t) => t.startedOn.year == year).toList();
    final yearCodes = yearTrips.map((t) => t.countryCode).toSet().toList();
    final countryTrips =
        heroCountryCode.isNotEmpty
            ? widget.allTrips.where((t) => t.countryCode == heroCountryCode).toList()
            : const <TripRecord>[];
    final allCodes = widget.allVisits.map((v) => v.countryCode).toList();

    final groups = [
      (label: 'Passport', template: CardTemplateType.passport),
      (label: 'Flags', template: CardTemplateType.grid),
      (label: 'Heart Flags', template: CardTemplateType.heart),
      (label: 'Tour Dates', template: CardTemplateType.timeline),
      if (landmarkAvailable)
        (label: 'Landmarks', template: CardTemplateType.landmark),
    ];

    final items = <MerchOptionListItem>[];
    for (final g in groups) {
      items.add(MerchOptionHeaderItem(g.label));
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
        items.add(MerchOptionEntry(opt));
      }
      items.add(
        MerchOptionCustomiseEntry(
          template: g.template,
          label: 'Customise ${g.label}',
        ),
      );
    }
    return items;
  }

  ({List<PulseMerchOption> flatOptions, List<MerchOptionListItem> allItems})
  _buildData({required bool landmarkAvailable}) {
    final allItems = _buildItems(landmarkAvailable: landmarkAvailable);
    final flatOptions =
        allItems.whereType<MerchOptionEntry>().map((e) => e.option).toList();
    return (flatOptions: flatOptions, allItems: allItems);
  }

  @override
  Widget build(BuildContext context) {
    final landmarkAvailable =
        ref.watch(imagePlaygroundAvailableProvider).valueOrNull ?? false;
    final (:flatOptions, :allItems) =
        _buildData(landmarkAvailable: landmarkAvailable);
    final allCodes = widget.allVisits.map((v) => v.countryCode).toList();
    final year = widget.hero.capturedAt.year;
    final heroCountryCode = widget.hero.countryCode ?? '';
    final countryName =
        heroCountryCode.isNotEmpty
            ? (kCountryNames[heroCountryCode] ?? heroCountryCode)
            : 'Your travels';

    final featured = flatOptions.isNotEmpty ? flatOptions.first : null;
    final alternatives = flatOptions.skip(1).take(4).toList();

    final pmoCs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your travel shirt ideas'),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Subtitle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Inspired by $countryName · $year',
                style: TextStyle(color: pmoCs.onSurface.withValues(alpha: 0.54), fontSize: 13),
              ),
            ),
          ),

          // Featured card
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MerchOptionFeaturedCard(
                  option: featured,
                  allCodes: allCodes,
                ),
              ),
            ),

          // Alternatives strip
          if (alternatives.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 6),
                child: Text(
                  'OTHER STYLES',
                  style: TextStyle(
                    color: pmoCs.onSurface.withValues(alpha: 0.38),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: MerchOptionAlternativesStrip(
                options: alternatives,
                allCodes: allCodes,
              ),
            ),
          ],

          // "See all styles" toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextButton(
                onPressed:
                    _showAll ? null : () => setState(() => _showAll = true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  _showAll ? 'All styles' : 'See all styles ›',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),

          // Full list (shown when _showAll)
          if (_showAll) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.separated(
                itemCount: allItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final item = allItems[i];
                  return switch (item) {
                    MerchOptionHeaderItem() =>
                      MerchOptionSectionHeader(item.label),
                    MerchOptionFeaturedEntry() => MerchOptionFeaturedCard(
                      option: item.option,
                      allCodes: allCodes,
                    ),
                    MerchOptionEntry() => MerchOptionCard(
                      option: item.option,
                      allCodes: allCodes,
                      index: i,
                    ),
                    MerchOptionCustomiseEntry() => MerchOptionCustomCard(
                      template: item.template,
                      label: item.label,
                    ),
                  };
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _ExclusiveDesignsSection(
                allVisits: widget.allVisits,
                allTrips: widget.allTrips,
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Exclusive designs section ─────────────────────────────────────────────────

/// Shows near-miss locked designs and any already-unlocked exclusive designs
/// at the bottom of the expanded style list (M144).
class _ExclusiveDesignsSection extends StatelessWidget {
  const _ExclusiveDesignsSection({
    required this.allVisits,
    required this.allTrips,
  });

  final List<EffectiveVisitedCountry> allVisits;
  final List<TripRecord> allTrips;

  MerchUnlockContext _buildCtx() {
    final countryCount = allVisits.length;
    final continentCount = allVisits
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet()
        .length;
    return MerchUnlockContext(
      countryCount: countryCount,
      continentCount: continentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _buildCtx();
    const nearMissThreshold = 15;

    final toShow = kMerchExclusiveDesigns.where((d) {
      if (d.isUnlocked(ctx)) return true;
      final rem = d.remaining(ctx);
      return rem > 0 && rem <= nearMissThreshold;
    }).toList();

    if (toShow.isEmpty) return const SizedBox(height: 40);

    final allCodes = allVisits.map((v) => v.countryCode).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'EXCLUSIVE DESIGNS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...toShow.map(
            (d) => MerchLockedDesignCard(
              design: d,
              ctx: ctx,
              onUnlockedTap: d.isUnlocked(ctx)
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => LocalMockupPreviewScreen(
                                selectedCodes: allCodes,
                                allCodes: allCodes,
                                trips: allTrips,
                                initialTemplate: d.template,
                                initialPreset: MerchPreset(
                                  id: 'exclusive_design',
                                  label: d.label,
                                  config: MerchPresetConfig(
                                    layout: d.template,
                                    source: MerchCountrySource.allTime,
                                    jitter: 0.4,
                                    density: MerchDensity.balanced,
                                    stampMode: MerchStampMode.entryExit,
                                  ),
                                ),
                              ),
                        ),
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
