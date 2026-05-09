import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'merch_option_list_widgets.dart';
import 'pulse_merch_option.dart';

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

    return MerchContext(
      codes: codes,
      trips: trips,
      scopeTitle: _scopeTitle(achievement, codes),
      scopeDescription: _scopeDescription(achievement, codes),
      allCodes: allCodes,
      allTrips: allTrips,
      achievement: achievement,
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
  /// Template ordering varies by achievement type for maximum relevance:
  /// - Country milestones: passport → flags → tour dates
  /// - Continent achievements: flags → passport → tour dates
  /// - Trip achievements: tour dates → passport → flags (timeline first)
  /// - Year achievements: flags → passport → tour dates
  List<MerchOptionListItem> buildItems() {
    final ach = achievement;
    if (ach == null) return _buildGenericItems();

    // Continent-explorer: scoped to a single continent's countries.
    if (ach.continentScope != null) return _buildContinentExplorerItems();

    // Region: scoped to a sub-continental region's countries.
    if (ach.regionScope != null) return _buildRegionItems();

    // Passport milestone: trip achievement with stamp-focused merch.
    if (ach.category == AchievementCategory.trips &&
        ach.merch == MerchTriggerType.passportStamp) {
      return _buildPassportMilestoneItems();
    }

    return switch (ach.category) {
      AchievementCategory.countries when ach.progressTarget == 1 =>
        _buildFirstCountryItems(),
      AchievementCategory.countries => _buildCountryItems(),
      AchievementCategory.continents => _buildContinentItems(),
      AchievementCategory.trips => _buildTripItems(),
      AchievementCategory.thisYear => _buildYearItems(),
    };
  }

  // ── First Country (progressTarget == 1) ───────────────────────────────────

  List<MerchOptionListItem> _buildFirstCountryItems() {
    final countryName =
        kCountryNames[codes.firstOrNull ?? ''] ?? codes.firstOrNull ?? '';
    final items = <MerchOptionListItem>[];

    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$countryName Entry Stamp',
      scopedDesc: 'Your first ever passport stamp',
    );

    _addGroup(
      items,
      label: 'Explorer Badge',
      template: CardTemplateType.badge,
      scopedTitle: countryName,
      scopedDesc: 'A commemorative badge for your first country',
    );

    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$countryName Flag',
      scopedDesc: 'Where it all began',
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$countryName Heart',
      scopedDesc: 'A heart made from your first flag',
    );

    _addGroup(
      items,
      label: 'Typography',
      template: CardTemplateType.typography,
      scopedTitle: countryName,
      scopedDesc: 'Your first country, typographically',
    );

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: 'My First Country — $countryName',
      scopedDesc: 'The trip that started everything',
    );

    return items;
  }

  // ── Country milestones (progressTarget > 1) ────────────────────────────────

  List<MerchOptionListItem> _buildCountryItems() {
    final n = achievement!.progressTarget;
    final isFirstN = codes.length <= 25;
    final prefix = isFirstN ? 'First $n Countries' : '$n Countries';
    final items = <MerchOptionListItem>[];

    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$prefix — Stamps',
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$prefix — Flags',
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$prefix — Heart',
      scopedDesc: 'Your countries as a heart of flags',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Typography',
      template: CardTemplateType.typography,
      scopedTitle: prefix,
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    // Badge suits smaller country sets only — too cluttered beyond 15.
    if (codes.length <= 15) {
      _addGroup(
        items,
        label: 'Explorer Badge',
        template: CardTemplateType.badge,
        scopedTitle: prefix,
        scopedDesc: '${codes.length} countries in your collection',
      );
    }

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: isFirstN ? prefix : '$n Countries World Tour',
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    return items;
  }

  // ── Continent achievements ─────────────────────────────────────────────────

  List<MerchOptionListItem> _buildContinentItems() {
    final n = achievement!.progressTarget;
    final continentLabel = n >= 6 ? 'All Six Continents' : '$n Continents';
    final countDesc = '${codes.length} countries across $n continents';
    final items = <MerchOptionListItem>[];

    // Flags lead for continent achievements — the breadth of coverage is
    // the story, and a flag grid communicates that best.
    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$continentLabel — Flags',
      scopedDesc: countDesc,
    );

    _addGroup(
      items,
      label: 'Typography',
      template: CardTemplateType.typography,
      scopedTitle: continentLabel,
      scopedDesc: countDesc,
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$continentLabel — Heart',
      scopedDesc: 'Your world in a heart of flags',
    );

    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: 'World Tour — Stamps',
      scopedDesc: countDesc,
    );

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: '$continentLabel World Tour',
      scopedDesc: scopeDescription,
    );

    return items;
  }

  // ── Trip achievements ──────────────────────────────────────────────────────

  List<MerchOptionListItem> _buildTripItems() {
    final n = achievement!.progressTarget;
    final tripLabel = n == 1 ? 'First Trip' : '$n Trips';
    final tripCountDesc = trips.isNotEmpty
        ? '${trips.length} trips, ${codes.length} countries'
        : '${codes.length} countries';
    final items = <MerchOptionListItem>[];

    // Timeline/tour dates lead for trip achievements.
    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: '$tripLabel — Timeline',
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$tripLabel — Stamps',
      scopedDesc: tripCountDesc,
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$tripLabel — Flags',
      scopedDesc: '${codes.length} countries across $n trips',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$tripLabel — Heart',
      scopedDesc: 'Your trip countries as a heart of flags',
      includeWorldCollection: _hasWorldCollection,
    );

    return items;
  }

  // ── Year achievements ──────────────────────────────────────────────────────

  List<MerchOptionListItem> _buildYearItems() {
    final year = DateTime.now().year;
    final items = <MerchOptionListItem>[];

    // Flags lead for year achievements — year recaps are about breadth.
    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$year Travels — Flags',
      scopedDesc: '${codes.length} countries in $year',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Typography',
      template: CardTemplateType.typography,
      scopedTitle: '$year World Tour',
      scopedDesc: '${codes.length} countries in $year',
      includeWorldCollection: false,
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$year Travels — Heart',
      scopedDesc: 'Your $year countries as a heart of flags',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$year Travels — Stamps',
      scopedDesc: '$year trips and stamps',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: '$year World Tour',
      scopedDesc: 'Your $year travel recap',
      includeWorldCollection: _hasWorldCollection,
    );

    return items;
  }

  // ── Continent-explorer achievements ────────────────────────────────────────

  List<MerchOptionListItem> _buildContinentExplorerItems() {
    final continentName = achievement!.continentScope!;
    final countDesc = '${codes.length} countries in $continentName';
    final items = <MerchOptionListItem>[];

    // Flags lead for continent-explorer achievements — breadth is the story.
    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$continentName — Flags',
      scopedDesc: countDesc,
      includeWorldCollection: _hasWorldCollection,
    );

    // Badge suits continent-explorer achievements well.
    if (codes.length <= 15) {
      _addGroup(
        items,
        label: 'Explorer Badge',
        template: CardTemplateType.badge,
        scopedTitle: '$continentName Explorer',
        scopedDesc: countDesc,
        includeWorldCollection: false,
      );
    }

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$continentName — Heart',
      scopedDesc: 'Your $continentName countries as a heart of flags',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Typography',
      template: CardTemplateType.typography,
      scopedTitle: '$continentName Explorer',
      scopedDesc: countDesc,
      includeWorldCollection: false,
    );

    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$continentName Tour — Stamps',
      scopedDesc: countDesc,
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: '$continentName World Tour',
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    return items;
  }

  // ── Region achievements ─────────────────────────────────────────────────────

  List<MerchOptionListItem> _buildRegionItems() {
    final regionName = subRegionDisplayName(achievement!.regionScope!);
    final countDesc = '${codes.length} countries in the $regionName';
    final items = <MerchOptionListItem>[];

    // Passport leads for region achievements — stamps feel like travel mementos.
    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$regionName — Stamps',
      scopedDesc: countDesc,
      includeWorldCollection: _hasWorldCollection,
    );

    if (codes.length <= 15) {
      _addGroup(
        items,
        label: 'Explorer Badge',
        template: CardTemplateType.badge,
        scopedTitle: '$regionName Explorer',
        scopedDesc: countDesc,
        includeWorldCollection: false,
      );
    }

    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$regionName — Flags',
      scopedDesc: countDesc,
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Typography',
      template: CardTemplateType.typography,
      scopedTitle: '$regionName Explorer',
      scopedDesc: countDesc,
      includeWorldCollection: false,
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$regionName — Heart',
      scopedDesc: 'Your $regionName countries as a heart of flags',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: '$regionName Tour',
      scopedDesc: scopeDescription,
      includeWorldCollection: _hasWorldCollection,
    );

    return items;
  }

  // ── Passport stamp milestone achievements ───────────────────────────────────

  List<MerchOptionListItem> _buildPassportMilestoneItems() {
    final stampCount = achievement!.progressTarget * 2;
    final items = <MerchOptionListItem>[];

    // Passport leads — the achievement is about stamps.
    _addGroup(
      items,
      label: 'Passport',
      template: CardTemplateType.passport,
      scopedTitle: '$stampCount Stamps — Passport',
      scopedDesc: 'Your passport stamps across all your travels',
      includeWorldCollection: false,
    );

    _addGroup(
      items,
      label: 'Tour Dates',
      template: CardTemplateType.timeline,
      scopedTitle: '$stampCount Stamps — Tour Dates',
      scopedDesc: 'Every destination, timeline style',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Flags',
      template: CardTemplateType.grid,
      scopedTitle: '$stampCount Stamps — Flags',
      scopedDesc: '${codes.length} countries across all your stamps',
      includeWorldCollection: _hasWorldCollection,
    );

    _addGroup(
      items,
      label: 'Heart Flags',
      template: CardTemplateType.heart,
      scopedTitle: '$stampCount Stamps — Heart',
      scopedDesc: 'Your stamped countries as a heart of flags',
      includeWorldCollection: _hasWorldCollection,
    );

    return items;
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
    bool includeWorldCollection = false,
  }) {
    items.add(MerchOptionHeaderItem(label));

    if (codes.isNotEmpty) {
      final isPassport = template == CardTemplateType.passport;
      final tune = isPassport
          ? merchAutoTuneStamps(trips.length * 2)
          : merchAutoTuneCodes(codes.length);

      final suggestedColour = merchSuggestShirtColor(template);

      items.add(MerchOptionEntry(PulseMerchOption(
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
      )));

      if (includeWorldCollection && allCodes.isNotEmpty) {
        final allTune = isPassport
            ? merchAutoTuneStamps(allTrips.length * 2)
            : merchAutoTuneCodes(allCodes.length);
        items.add(MerchOptionEntry(PulseMerchOption(
          id: '${template.name}_world_${achievement?.id ?? 'ctx'}',
          title: '${merchTemplateLabel(template)} — World Collection',
          description:
              '${allCodes.length} countries across all your travels',
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
