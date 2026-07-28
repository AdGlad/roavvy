import 'package:shared_models/shared_models.dart';

import '../merch_preset.dart';
import '../merch_template_ranker.dart';
import 'travel_profile.dart';

/// Derives a [TravelProfile] from a user's trips (M197). Pure + deterministic —
/// no I/O, no randomness — so it is isolate-safe and trivially testable.
class TravelProfileAnalyzer {
  const TravelProfileAnalyzer._();

  /// Window (days) that counts as "recent" for recency-heavy classification.
  static const int _recentWindowDays = 365;

  static TravelProfile analyze(List<TripRecord> trips, {DateTime? now}) {
    final clock = now ?? DateTime.now();

    if (trips.isEmpty) {
      return const TravelProfile(
        allCodes: [],
        density: MerchDensityClass.solo,
        continents: {},
        dominantContinent: null,
        candidateSets: [],
        earliest: null,
        latest: null,
        isRecencyHeavy: false,
        signatureCountries: [],
        persona: TravelPersona.homebodyPlusOne,
      );
    }

    // Aggregate per country.
    final photosByCode = <String, int>{};
    final continentByCode = <String, String>{};
    final continentCount = <String, int>{};
    DateTime? earliest;
    DateTime? latest;
    TripRecord? recentTrip;
    int recentPhotos = 0;
    int totalPhotos = 0;

    for (final t in trips) {
      final code = t.countryCode.toUpperCase();
      photosByCode.update(code, (v) => v + t.photoCount,
          ifAbsent: () => t.photoCount);
      final continent = kCountryContinent[code] ?? kCountryContinent[t.countryCode];
      if (continent != null) {
        continentByCode[code] = continent;
      }
      earliest = (earliest == null || t.startedOn.isBefore(earliest))
          ? t.startedOn
          : earliest;
      latest =
          (latest == null || t.endedOn.isAfter(latest)) ? t.endedOn : latest;
      if (recentTrip == null || t.endedOn.isAfter(recentTrip.endedOn)) {
        recentTrip = t;
      }
      totalPhotos += t.photoCount;
      if (clock.difference(t.endedOn).inDays <= _recentWindowDays) {
        recentPhotos += (t.photoCount + 1); // +1 so photo-less trips still count
      }
    }

    final allCodes = photosByCode.keys.toList();
    for (final c in continentByCode.values) {
      continentCount.update(c, (v) => v + 1, ifAbsent: () => 1);
    }
    final continents = continentByCode.values.toSet();
    final dominantContinent = _dominant(continentCount);

    final density = MerchTemplateRanker.densityFor(allCodes.length);

    final totalWithPad = totalPhotos + trips.length;
    final isRecencyHeavy =
        totalWithPad > 0 && (recentPhotos / totalWithPad) >= 0.5;

    final signatureCountries = allCodes.toList()
      ..sort((a, b) => (photosByCode[b] ?? 0).compareTo(photosByCode[a] ?? 0));

    final candidateSets = _candidateSets(
      allCodes: allCodes,
      trips: trips,
      recentTrip: recentTrip,
      signatureCountries: signatureCountries,
      continentByCode: continentByCode,
      dominantContinent: dominantContinent,
      clock: clock,
    );

    final persona = _persona(
      countryCount: allCodes.length,
      continentCount: continents.length,
      dominantShare: dominantContinent == null || allCodes.isEmpty
          ? 0.0
          : (continentCount[dominantContinent] ?? 0) / allCodes.length,
      isRecencyHeavy: isRecencyHeavy,
    );

    return TravelProfile(
      allCodes: allCodes,
      density: density,
      continents: continents,
      dominantContinent: dominantContinent,
      candidateSets: candidateSets,
      earliest: earliest,
      latest: latest,
      isRecencyHeavy: isRecencyHeavy,
      signatureCountries: signatureCountries,
      persona: persona,
    );
  }

  static String? _dominant(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    String? best;
    int bestN = -1;
    for (final e in counts.entries) {
      if (e.value > bestN) {
        best = e.key;
        bestN = e.value;
      }
    }
    return best;
  }

  static List<CountrySetOption> _candidateSets({
    required List<String> allCodes,
    required List<TripRecord> trips,
    required TripRecord? recentTrip,
    required List<String> signatureCountries,
    required Map<String, String> continentByCode,
    required String? dominantContinent,
    required DateTime clock,
  }) {
    final sets = <CountrySetOption>[];

    // All-time — always present.
    sets.add(CountrySetOption(
      source: MerchCountrySource.allTime,
      label: 'All Countries',
      codes: allCodes,
    ));

    // This year.
    final thisYear = trips
        .where((t) => t.endedOn.year == clock.year)
        .map((t) => t.countryCode.toUpperCase())
        .toSet()
        .toList();
    if (thisYear.isNotEmpty && thisYear.length != allCodes.length) {
      sets.add(CountrySetOption(
        source: MerchCountrySource.thisYear,
        label: 'This Year',
        codes: thisYear,
      ));
    }

    // Recent trip (its country).
    if (recentTrip != null) {
      final code = recentTrip.countryCode.toUpperCase();
      if (allCodes.length > 1) {
        sets.add(CountrySetOption(
          source: MerchCountrySource.recentTrip,
          label: 'Recent Trip',
          codes: [code],
        ));
      }
    }

    // Signature single country (most photos), if distinct from the above.
    if (allCodes.length > 1 && signatureCountries.isNotEmpty) {
      final top = signatureCountries.first;
      final already = sets.any((s) => s.codes.length == 1 && s.codes.first == top);
      if (!already) {
        sets.add(CountrySetOption(
          source: MerchCountrySource.singleCountry,
          label: top,
          codes: [top],
          scopeKey: top.toLowerCase(),
        ));
      }
    }

    // Dominant continent.
    if (dominantContinent != null) {
      final codes = continentByCode.entries
          .where((e) => e.value == dominantContinent)
          .map((e) => e.key)
          .toList();
      if (codes.length >= 3 && codes.length != allCodes.length) {
        sets.add(CountrySetOption(
          source: MerchCountrySource.allTime,
          label: 'Your $dominantContinent',
          codes: codes,
          scopeKey: _continentKey(dominantContinent),
        ));
      }
    }

    return sets;
  }

  /// Normalises a continent display name to the lowercase_snake key used by the
  /// continent-outline clip (e.g. "North America" → "north_america").
  static String _continentKey(String continent) =>
      continent.toLowerCase().trim().replaceAll(RegExp(r'[\s&]+'), '_');

  static TravelPersona _persona({
    required int countryCount,
    required int continentCount,
    required double dominantShare,
    required bool isRecencyHeavy,
  }) {
    if (countryCount <= 1) return TravelPersona.soloDeepDive;
    if (countryCount >= 25 || continentCount >= 5) {
      return TravelPersona.globeTrotter;
    }
    if (continentCount >= 3) return TravelPersona.continentHopper;
    if (isRecencyHeavy && countryCount <= 6) {
      return TravelPersona.recentAdventurer;
    }
    if (dominantShare >= 0.6 && countryCount >= 4) {
      return TravelPersona.regionExplorer;
    }
    return TravelPersona.homebodyPlusOne;
  }
}
