import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'merch_drop.dart';
import 'merch_option_list_widgets.dart';
import 'merch_story.dart';
import 'merch_template_ranker.dart';
import 'pulse_merch_option.dart';
import 'travel_identity.dart';

/// The resolved travel data and display labels for a merch generation session.
///
/// Acts as the shared merch context layer (ADR-150). All merch entry points
/// (Memory Pulse, Achievements, Trips, Year Recaps) reduce their travel data
/// into this object, which drives consistent [MerchOptionListItem] generation
/// through [buildItems].
///
/// Context resolution is pure (no providers, no async). The caller supplies
/// fully-loaded [allVisits] and [allTrips] lists; [fromAchievement] resolves
/// the appropriate subset and builds titles from them.
///
/// Usage:
/// ```dart
/// final ctx = MerchContext.fromAchievement(
///   achievement: achievement,
///   allVisits: allVisits,
///   allTrips: allTrips,
/// );
/// final items = ctx.buildItems();
/// ```
class MerchContext {
  const MerchContext({
    required this.codes,
    required this.trips,
    required this.scopeTitle,
    required this.scopeDescription,
    required this.allCodes,
    required this.allTrips,
    this.achievement,
    this.identity,
  });

  /// Country codes in scope for this context (may be a subset of [allCodes]).
  final List<String> codes;

  /// Trips in scope for this context (may be a subset of [allTrips]).
  final List<TripRecord> trips;

  /// Short scope label shown in option titles (e.g. "First 5 Countries",
  /// "2026 Travels").
  final String scopeTitle;

  /// Longer description shown in option subtitles (e.g. "Your first five
  /// countries").
  final String scopeDescription;

  /// All visited country codes — used for "World Collection" options.
  final List<String> allCodes;

  /// All trips — used for "World Collection" options.
  final List<TripRecord> allTrips;

  /// The achievement that triggered this context, if applicable.
  final Achievement? achievement;

  /// The travel identity resolved from the achievement context (ADR-155).
  ///
  /// Used to personalise section labels, story copy, and the celebration
  /// header in [AchievementMerchOptionScreen].
  final TravelIdentityInfo? identity;

  // ── Factory: from Achievement ──────────────────────────────────────────────

  /// Resolves country codes and trips appropriate for [achievement]'s category
  /// and [progressTarget], then populates display strings.
  static MerchContext fromAchievement({
    required Achievement achievement,
    required List<EffectiveVisitedCountry> allVisits,
    required List<TripRecord> allTrips,
  }) {
    // Sort by firstSeen so "first N" picks the chronologically earliest.
    final byDate = allVisits
        .where((v) => v.firstSeen != null)
        .toList()
      ..sort((a, b) => a.firstSeen!.compareTo(b.firstSeen!));

    final allCodes = allVisits.map((v) => v.countryCode).toList();

    final codes = _resolveCodes(achievement, byDate, allVisits, allTrips);
    final trips = _resolveTrips(achievement, allTrips, codes);

    final identity = TravelIdentityInfo.forContext(
      achievement: achievement,
      codes: codes,
      tripCount: allTrips.length,
      stampCount: allTrips.length * 2,
    );

    return MerchContext(
      codes: codes,
      trips: trips,
      scopeTitle: _scopeTitle(achievement, codes),
      scopeDescription: _scopeDescription(achievement, codes),
      allCodes: allCodes,
      allTrips: allTrips,
      achievement: achievement,
      identity: identity,
    );
  }

  // ── Resolution helpers ─────────────────────────────────────────────────────

  static List<String> _resolveCodes(
    Achievement achievement,
    List<EffectiveVisitedCountry> byDate,
    List<EffectiveVisitedCountry> allVisits,
    List<TripRecord> allTrips,
  ) {
    final allCodes = allVisits.map((v) => v.countryCode).toList();

    // Continent-explorer: filter to only countries in the specified continent.
    if (achievement.continentScope != null) {
      return allVisits
          .where((v) =>
              kCountryContinent[v.countryCode] == achievement.continentScope)
          .map((v) => v.countryCode)
          .toList();
    }

    // Region: filter to only countries in the specified sub-region.
    if (achievement.regionScope != null) {
      return allVisits
          .where((v) =>
              kCountrySubRegion[v.countryCode] == achievement.regionScope)
          .map((v) => v.countryCode)
          .toList();
    }

    return switch (achievement.category) {
      AchievementCategory.countries when achievement.progressTarget == 1 =>
        byDate.isNotEmpty ? [byDate.first.countryCode] : [],
      AchievementCategory.countries when achievement.progressTarget <= 25 =>
        byDate
            .take(achievement.progressTarget)
            .map((v) => v.countryCode)
            .toList(),
      // For large country milestones and all continent achievements, the scope
      // is every visited country — the achievement is about breadth, not a
      // specific subset.
      AchievementCategory.countries || AchievementCategory.continents =>
        allCodes,
      AchievementCategory.trips =>
        _codesForFirstNTrips(allTrips, achievement.progressTarget),
      AchievementCategory.thisYear => allVisits
          .where((v) =>
              v.firstSeen != null &&
              v.firstSeen!.year == DateTime.now().year)
          .map((v) => v.countryCode)
          .toList(),
    };
  }

  static List<TripRecord> _resolveTrips(
    Achievement achievement,
    List<TripRecord> allTrips,
    List<String> resolvedCodes,
  ) {
    // For continent/region scoped achievements, filter trips to the scoped codes.
    if (achievement.continentScope != null || achievement.regionScope != null) {
      return allTrips
          .where((t) => resolvedCodes.contains(t.countryCode))
          .toList();
    }

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

  static String _scopeTitle(Achievement achievement, List<String> codes) {
    final n = achievement.progressTarget;
    final year = DateTime.now().year;
    final firstName =
        kCountryNames[codes.firstOrNull ?? ''] ?? codes.firstOrNull ?? '';
    return switch (achievement.category) {
      AchievementCategory.countries when n == 1 => '$firstName Stamp',
      AchievementCategory.countries when n <= 25 => 'First $n Countries',
      AchievementCategory.countries => '$n Countries',
      AchievementCategory.continents when n >= 6 => 'All Six Continents',
      AchievementCategory.continents => '$n Continents',
      AchievementCategory.trips when n == 1 => 'First Trip',
      AchievementCategory.trips => '$n Trips',
      AchievementCategory.thisYear => '$year Travels',
    };
  }

  static String _scopeDescription(
      Achievement achievement, List<String> codes) {
    final n = achievement.progressTarget;
    final year = DateTime.now().year;
    final firstName =
        kCountryNames[codes.firstOrNull ?? ''] ?? codes.firstOrNull ?? '';
    return switch (achievement.category) {
      AchievementCategory.countries when n == 1 =>
        '$firstName — your first country',
      AchievementCategory.countries when n <= 25 => 'Your first $n countries',
      AchievementCategory.countries => '$n-country milestone',
      AchievementCategory.continents when n >= 6 =>
        '${codes.length} countries across all six inhabited continents',
      AchievementCategory.continents =>
        '${codes.length} countries across $n continents',
      AchievementCategory.trips when n == 1 => 'Your first trip',
      AchievementCategory.trips => '$n trips around the world',
      AchievementCategory.thisYear => '$n countries visited in $year',
    };
  }

  // ── Option building ────────────────────────────────────────────────────────

  /// True when the scoped [codes] are a strict subset of [allCodes] — i.e.
  /// a "World Collection" option would add more countries.
  bool get _hasWorldCollection => allCodes.length > codes.length;

  /// Generates the full list of [MerchOptionListItem]s for display.
  ///
  /// Delegates to [_buildFromRankedTemplates] which calls
  /// [MerchTemplateRanker.rankFor] and [MerchStory.forOption] for each
  /// template (ADR-154).
  List<MerchOptionListItem> buildItems() {
    final ach = achievement;
    final contextLabel = _buildContextLabel(ach);
    if (ach == null) return _buildGenericItems();
    return _buildFromRankedTemplates(contextLabel: contextLabel);
  }

  /// Builds a curated, ranked list of option groups using [MerchTemplateRanker]
  /// and [MerchStory].
  List<MerchOptionListItem> _buildFromRankedTemplates({String? contextLabel}) {
    final density = MerchTemplateRanker.densityFor(codes.length);
    final maxN = MerchTemplateRanker.maxForDensity(density);
    final year = DateTime.now().year;

    final ranked = MerchTemplateRanker.rankFor(
      achievement: achievement,
      codeCount: codes.length,
      tripCount: trips.length,
      stampCount: trips.length * 2,
    );

    final items = <MerchOptionListItem>[];
    var count = 0;
    final ach = achievement!;

    for (final rank in ranked) {
      if (rank.exclude) continue;
      if (count >= maxN) break;

      final story = MerchStory.forOption(
        template: rank.template,
        achievement: ach,
        codes: codes,
        density: density,
        year: year,
        identity: identity,
      );

      // Badge and typography are scoped — don't offer a "World Collection"
      // variant for these templates.
      final includeWorld = _hasWorldCollection &&
          rank.template != CardTemplateType.badge;

      // Prefix the section label with any active drop badge.
      final drop = MerchDrop.forTemplate(rank.template);
      final label = drop != null ? '${drop.badge} ${rank.label}' : rank.label;

      _addGroup(
        items,
        label: label,
        template: rank.template,
        scopedTitle: story.title,
        scopedDesc: _scopeDescription(ach, codes),
        artworkSubtitle: story.subtitle,
        includeWorldCollection: includeWorld,
        contextLabel: contextLabel,
        isFeatured: count == 0,
      );
      count++;
    }

    return items;
  }

  /// Generates a short label explaining the source of this merch context.
  static String? _buildContextLabel(Achievement? ach) {
    if (ach == null) return null;
    if (ach.continentScope != null) {
      return 'Based on your ${ach.continentScope} Explorer achievement';
    }
    if (ach.regionScope != null) {
      return 'Based on your ${subRegionDisplayName(ach.regionScope!)} achievement';
    }
    if (ach.category == AchievementCategory.thisYear) {
      return 'Generated from your ${DateTime.now().year} travels';
    }
    if (ach.category == AchievementCategory.trips &&
        ach.merch == MerchTriggerType.passportStamp) {
      return 'Celebrating ${ach.progressTarget * 2} passport stamps';
    }
    if (ach.progressTarget <= 25) {
      return 'Built from your first ${ach.progressTarget} countries';
    }
    return 'Based on your ${ach.progressTarget} countries achievement';
  }

  // ── Generic (non-achievement entry points) ─────────────────────────────────

  List<MerchOptionListItem> _buildGenericItems() {
    const groups = [
      (label: 'Passport', template: CardTemplateType.passport),
      (label: 'Flags', template: CardTemplateType.grid),
      (label: 'Heart Flags', template: CardTemplateType.heart),
      (label: 'Tour Dates', template: CardTemplateType.timeline),
    ];
    final items = <MerchOptionListItem>[];
    for (final g in groups) {
      _addGroup(
        items,
        label: g.label,
        template: g.template,
        scopedTitle: '${merchTemplateLabel(g.template)} — $scopeTitle',
        scopedDesc: scopeDescription,
        includeWorldCollection: _hasWorldCollection,
      );
    }
    return items;
  }

  // ── Shared group builder ───────────────────────────────────────────────────

  void _addGroup(
    List<MerchOptionListItem> items, {
    required String label,
    required CardTemplateType template,
    required String scopedTitle,
    required String scopedDesc,
    String? artworkSubtitle,
    bool includeWorldCollection = false,
    String? contextLabel,
    bool isFeatured = false,
  }) {
    items.add(MerchOptionHeaderItem(label));

    if (codes.isNotEmpty) {
      final isPassport = template == CardTemplateType.passport;
      final density = MerchTemplateRanker.densityFor(codes.length);
      final tune = isPassport
          ? merchAutoTuneStamps(trips.length * 2)
          : merchAutoTuneCodes(codes.length);

      final suggestedColour =
          merchSuggestShirtColor(template, density: density);

      final option = PulseMerchOption(
        id: '${template.name}_scoped_${achievement?.id ?? 'ctx'}',
        title: scopedTitle,
        description: scopedDesc,
        scope: PulseMerchScope.allTime,
        template: template,
        codes: codes,
        trips: trips,
        jitter: tune.jitter,
        stampSizeMultiplier: tune.size,
        suggestedShirtColor: suggestedColour,
        contextLabel: contextLabel,
        artworkSubtitle: artworkSubtitle,
      );
      items.add(isFeatured
          ? MerchOptionFeaturedEntry(option)
          : MerchOptionEntry(option));

      if (includeWorldCollection && allCodes.isNotEmpty) {
        final allTune = isPassport
            ? merchAutoTuneStamps(allTrips.length * 2)
            : merchAutoTuneCodes(allCodes.length);
        items.add(MerchOptionEntry(PulseMerchOption(
          id: '${template.name}_world_${achievement?.id ?? 'ctx'}',
          title: '${merchTemplateLabel(template)} \u2014 World Collection',
          description: '${allCodes.length} countries across all your travels',
          scope: PulseMerchScope.allTime,
          template: template,
          codes: allCodes,
          trips: allTrips,
          jitter: allTune.jitter,
          stampSizeMultiplier: allTune.size,
          suggestedShirtColor: suggestedColour,
        )));
      }
    }

    items.add(MerchOptionCustomiseEntry(
      template: template,
      label: 'Customise ${merchTemplateLabel(template)}',
    ));
  }
}
