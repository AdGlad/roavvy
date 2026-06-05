import 'package:shared_models/shared_models.dart';

import 'merch_template_ranker.dart';
import 'pulse_merch_option.dart';
import 'travel_identity.dart';

/// All data needed to render a [TravelStoryScreen] (M146, ADR-178).
///
/// Constructed via [TravelStoryData.build] which aggregates year-filtered
/// travel stats from existing providers.
class TravelStoryData {
  const TravelStoryData({
    required this.year,
    required this.countryCodes,
    required this.continentCount,
    required this.tripCount,
    required this.topAchievement,
    required this.identity,
    required this.merchOption,
    required this.heroCountryCode,
  });

  /// The calendar year this story covers.
  final int year;

  /// Country codes visited in [year] (or all-time when built for scan entry).
  final List<String> countryCodes;

  final int continentCount;
  final int tripCount;

  /// Most impressive achievement unlocked in [year] with merch potential.
  /// Null when no achievement is eligible.
  final Achievement? topAchievement;

  final TravelIdentityInfo identity;

  /// Pre-built merch recommendation for the CTA page.
  final PulseMerchOption merchOption;

  /// Country code for the "hero" — last trip's country, or first code.
  final String heroCountryCode;

  /// Builds a [TravelStoryData] from raw provider data.
  ///
  /// When [yearFilter] is non-null, only visits whose [firstSeen] year matches
  /// are included. Pass `null` to include all visits (scan-summary entry point).
  static TravelStoryData build({
    required int year,
    required List<EffectiveVisitedCountry> allVisits,
    required List<TripRecord> allTrips,
    required Map<String, DateTime> unlockedAchievements,
    bool yearFilter = true,
  }) {
    // ── Filter visits ──────────────────────────────────────────────────────
    final visits = yearFilter
        ? allVisits.where((v) => v.firstSeen?.year == year).toList()
        : allVisits;

    final codes = visits.map((v) => v.countryCode).toList();
    final allCodes = allVisits.map((v) => v.countryCode).toList();

    // ── Continent count ────────────────────────────────────────────────────
    final continents = visits
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet();
    final continentCount = continents.length;

    // ── Trip count ─────────────────────────────────────────────────────────
    final trips = yearFilter
        ? allTrips
            .where((t) => t.startedOn.year == year || t.endedOn.year == year)
            .toList()
        : allTrips;
    final tripCount = trips.length;

    // ── Identity ───────────────────────────────────────────────────────────
    final identity = TravelIdentityInfo.forContext(
      codes: codes.isEmpty ? allCodes : codes,
      tripCount: trips.isEmpty ? allTrips.length : tripCount,
      stampCount: (trips.isEmpty ? allTrips.length : tripCount) * 2,
    );

    // ── Top achievement ────────────────────────────────────────────────────
    Achievement? topAchievement;
    if (unlockedAchievements.isNotEmpty) {
      // Rank by: continent > high country milestone > any merch achievement
      // Then filter to those unlocked in the target year (if yearFilter).
      final eligible = kAchievements.where((a) {
        if (a.merch == null) return false;
        final unlockedAt = unlockedAchievements[a.id];
        if (unlockedAt == null) return false;
        if (yearFilter && unlockedAt.year != year) return false;
        return true;
      }).toList();

      if (eligible.isNotEmpty) {
        // Priority: continentScope (most specific) > high progressTarget
        eligible.sort((a, b) {
          final aCont = a.continentScope != null ? 1 : 0;
          final bCont = b.continentScope != null ? 1 : 0;
          if (aCont != bCont) return bCont - aCont;
          return b.progressTarget.compareTo(a.progressTarget);
        });
        topAchievement = eligible.first;
      }
    }

    // ── Merch option ───────────────────────────────────────────────────────
    final effectiveCodes = codes.isEmpty ? allCodes : codes;
    final ranks = MerchTemplateRanker.rankFor(
      codeCount: effectiveCodes.length,
      achievement: topAchievement,
    );
    final bestTemplate =
        ranks.firstWhere((r) => !r.exclude, orElse: () => ranks.first).template;

    final n = effectiveCodes.length;
    final merchOption = PulseMerchOption(
      id: 'story_${year}_cta',
      title: '$year Travel Shirt',
      description:
          '$n ${n == 1 ? "country" : "countries"} · $continentCount ${continentCount == 1 ? "continent" : "continents"}',
      scope: PulseMerchScope.allTime,
      template: bestTemplate,
      codes: effectiveCodes,
      trips: trips.isEmpty ? allTrips : trips,
      artworkSubtitle: 'Roavvy: $n ${n == 1 ? "Country" : "Countries"} · $year',
    );

    // ── Hero country ───────────────────────────────────────────────────────
    String heroCountryCode = effectiveCodes.isNotEmpty ? effectiveCodes.first : 'US';
    if (trips.isNotEmpty) {
      final lastTrip = trips.reduce(
        (a, b) => a.endedOn.isAfter(b.endedOn) ? a : b,
      );
      if (effectiveCodes.contains(lastTrip.countryCode)) {
        heroCountryCode = lastTrip.countryCode;
      }
    }

    return TravelStoryData(
      year: year,
      countryCodes: effectiveCodes,
      continentCount: continentCount,
      tripCount: tripCount,
      topAchievement: topAchievement,
      identity: identity,
      merchOption: merchOption,
      heroCountryCode: heroCountryCode,
    );
  }
}
