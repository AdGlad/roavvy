import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'merch_option_list_widgets.dart';
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
    final prefix = merchTemplateLabel(template);
    final isPassport = template == CardTemplateType.passport;

    ({double jitter, double size}) tune(
        List<TripRecord> trips, List<String> codes) {
      if (isPassport) return merchAutoTuneStamps(trips.length * 2);
      return merchAutoTuneCodes(codes.length);
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

  List<MerchOptionListItem> _buildItems() {
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
      items.add(MerchOptionCustomiseEntry(
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
                  MerchOptionHeaderItem() =>
                    MerchOptionSectionHeader(item.label),
                  MerchOptionEntry() => MerchOptionCard(
                      option: item.option,
                      allCodes: allCodes,
                    ),
                  MerchOptionCustomiseEntry() => MerchOptionCustomCard(
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
