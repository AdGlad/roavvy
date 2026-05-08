import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'merch_option_list_widgets.dart';
import 'pulse_merch_option.dart';

/// T-shirt option selection screen entered from an unlocked achievement.
///
/// Reads [effectiveVisitsProvider] and [tripListProvider] directly so the
/// caller only needs to pass [achievement]. Resolves country codes and trips
/// appropriate for the achievement's category and progressTarget, then
/// generates a grouped list of [PulseMerchOption] items rendered by the shared
/// [MerchOptionCard] widgets (ADR-149).
///
/// Converges on [LocalMockupPreviewScreen] → [MerchOrderConfirmationScreen]
/// → Shopify checkout — the same downstream pipeline as [PulseMerchOptionScreen].
class AchievementMerchOptionScreen extends ConsumerWidget {
  const AchievementMerchOptionScreen({
    super.key,
    required this.achievement,
  });

  final Achievement achievement;

  // ── Scope resolution ──────────────────────────────────────────────────────────

  /// Returns the country codes relevant for this achievement.
  static List<String> _resolveCodes(
    Achievement achievement,
    List<EffectiveVisitedCountry> allVisits,
    List<TripRecord> allTrips,
  ) {
    final allCodes = allVisits
        .where((v) => v.firstSeen != null)
        .toList()
      ..sort((a, b) => a.firstSeen!.compareTo(b.firstSeen!));

    return switch (achievement.category) {
      AchievementCategory.countries when achievement.progressTarget == 1 =>
        allCodes.isNotEmpty ? [allCodes.first.countryCode] : [],
      AchievementCategory.countries
          when achievement.progressTarget <= 25 =>
        allCodes
            .take(achievement.progressTarget)
            .map((v) => v.countryCode)
            .toList(),
      AchievementCategory.countries ||
      AchievementCategory.continents =>
        allVisits.map((v) => v.countryCode).toList(),
      AchievementCategory.trips => _codesForFirstNTrips(
          allTrips,
          achievement.progressTarget,
        ),
      AchievementCategory.thisYear => allVisits
          .where((v) =>
              v.firstSeen != null &&
              v.firstSeen!.year == DateTime.now().year)
          .map((v) => v.countryCode)
          .toList(),
    };
  }

  /// Returns the trips relevant for this achievement.
  static List<TripRecord> _resolveTrips(
    Achievement achievement,
    List<TripRecord> allTrips,
    List<String> resolvedCodes,
  ) {
    return switch (achievement.category) {
      AchievementCategory.trips => (allTrips.toList()
            ..sort((a, b) => a.startedOn.compareTo(b.startedOn)))
          .take(achievement.progressTarget)
          .toList(),
      AchievementCategory.thisYear => allTrips
          .where((t) => t.startedOn.year == DateTime.now().year)
          .toList(),
      _ => allTrips
          .where((t) => resolvedCodes.contains(t.countryCode))
          .toList(),
    };
  }

  static List<String> _codesForFirstNTrips(
      List<TripRecord> allTrips, int n) {
    final sorted = allTrips.toList()
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));
    return sorted.take(n).map((t) => t.countryCode).toSet().toList();
  }

  // ── Subtitle ─────────────────────────────────────────────────────────────────

  static String _subtitle(Achievement achievement) =>
      switch (achievement.category) {
        AchievementCategory.countries
            when achievement.progressTarget == 1 =>
          'Celebrating your first country',
        AchievementCategory.countries =>
          'Celebrating ${achievement.progressTarget} countries visited',
        AchievementCategory.continents =>
          'Celebrating ${achievement.progressTarget} continents explored',
        AchievementCategory.trips =>
          'Celebrating ${achievement.progressTarget} trips logged',
        AchievementCategory.thisYear =>
          'Celebrating ${achievement.progressTarget} countries'
              ' in ${DateTime.now().year}',
      };

  // ── Scope title / description ─────────────────────────────────────────────────

  static String _scopeTitle(
    Achievement achievement,
    List<String> resolvedCodes,
  ) {
    final n = achievement.progressTarget;
    final year = DateTime.now().year;
    return switch (achievement.category) {
      AchievementCategory.countries when n == 1 =>
        '${kCountryNames[resolvedCodes.firstOrNull ?? ''] ?? resolvedCodes.firstOrNull ?? ''} Stamp',
      AchievementCategory.countries when n <= 25 => 'First $n Countries',
      AchievementCategory.countries => '$n Countries',
      AchievementCategory.continents => '$n Continents',
      AchievementCategory.trips => '$n Trips',
      AchievementCategory.thisYear => '$year Travels',
    };
  }

  static String _scopeDescription(
    Achievement achievement,
    List<String> resolvedCodes,
  ) {
    final n = achievement.progressTarget;
    final year = DateTime.now().year;
    return switch (achievement.category) {
      AchievementCategory.countries when n == 1 => 'Your first country',
      AchievementCategory.countries when n <= 25 =>
        'Your first $n countries',
      AchievementCategory.countries => '$n-country milestone',
      AchievementCategory.continents =>
        'Countries across $n continents',
      AchievementCategory.trips => 'All your logged trips',
      AchievementCategory.thisYear =>
        '$n countries visited in $year',
    };
  }

  // ── Option building ───────────────────────────────────────────────────────────

  List<MerchOptionListItem> _buildItems(
    List<EffectiveVisitedCountry> allVisits,
    List<TripRecord> allTrips,
  ) {
    final resolvedCodes = _resolveCodes(achievement, allVisits, allTrips);
    final resolvedTrips = _resolveTrips(achievement, allTrips, resolvedCodes);
    final allCodes = allVisits.map((v) => v.countryCode).toList();

    final scopeTitle = _scopeTitle(achievement, resolvedCodes);
    final scopeDesc = _scopeDescription(achievement, resolvedCodes);

    const groups = [
      (label: 'Passport', template: CardTemplateType.passport),
      (label: 'Flags', template: CardTemplateType.grid),
      (label: 'Tour Dates', template: CardTemplateType.timeline),
    ];

    final items = <MerchOptionListItem>[];

    for (final g in groups) {
      items.add(MerchOptionHeaderItem(g.label));

      if (resolvedCodes.isNotEmpty) {
        // Option A — achievement-scoped
        final prefix = merchTemplateLabel(g.template);
        final isPassport = g.template == CardTemplateType.passport;
        final tune = isPassport
            ? merchAutoTuneStamps(resolvedTrips.length * 2)
            : merchAutoTuneCodes(resolvedCodes.length);

        items.add(MerchOptionEntry(PulseMerchOption(
          id: '${g.template.name}_achievement_${achievement.id}',
          title: '$prefix — $scopeTitle',
          description: scopeDesc,
          scope: PulseMerchScope.allTime,
          template: g.template,
          codes: resolvedCodes,
          trips: resolvedTrips,
          jitter: tune.jitter,
          stampSizeMultiplier: tune.size,
        )));

        // Option B — all-time world collection (when scope is narrower than all)
        if (allCodes.length > resolvedCodes.length) {
          final allTune = isPassport
              ? merchAutoTuneStamps(allTrips.length * 2)
              : merchAutoTuneCodes(allCodes.length);
          items.add(MerchOptionEntry(PulseMerchOption(
            id: '${g.template.name}_alltime_${achievement.id}',
            title: '$prefix — World Collection',
            description:
                '${allCodes.length} countries across all your travels',
            scope: PulseMerchScope.allTime,
            template: g.template,
            codes: allCodes,
            trips: allTrips,
            jitter: allTune.jitter,
            stampSizeMultiplier: allTune.size,
          )));
        }
      }

      items.add(MerchOptionCustomiseEntry(
        template: g.template,
        label: 'Customise ${merchTemplateLabel(g.template)}',
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    // Show loading until both providers resolve.
    if (visitsAsync.isLoading || tripsAsync.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          title: const Text('Your travel shirt ideas'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }

    if (visitsAsync.hasError || tripsAsync.hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          title: const Text('Your travel shirt ideas'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load travel data',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.invalidate(effectiveVisitsProvider);
                  ref.invalidate(tripListProvider);
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allVisits = visitsAsync.value ?? const [];
    final allTrips = tripsAsync.value ?? const [];
    final allCodes = allVisits.map((v) => v.countryCode).toList();
    final items = _buildItems(allVisits, allTrips);
    final subtitle = _subtitle(achievement);

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
              subtitle,
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
