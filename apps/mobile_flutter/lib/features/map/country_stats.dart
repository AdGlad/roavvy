import 'package:shared_models/shared_models.dart';

/// Aggregated travel statistics for a single country, computed on demand from
/// local Drift tables. Not persisted — recomputed on each profile screen open.
class CountryStats {
  const CountryStats({
    required this.tripCount,
    required this.totalDays,
    required this.totalPhotos,
    required this.visitedRegions,
    required this.totalRegions,
    required this.visitedHeritageSites,
    required this.totalHeritageSites,
    this.firstVisitYear,
    this.lastVisitYear,
    this.firstTripStart,
  });

  final int tripCount;
  final int totalDays;
  final int totalPhotos;
  final int visitedRegions;
  final int totalRegions;
  final int visitedHeritageSites;
  final int totalHeritageSites;
  final int? firstVisitYear;
  final int? lastVisitYear;

  /// Start date of the earliest trip; used for season calculation in narrative.
  final DateTime? firstTripStart;

  /// True when the user has visited every UNESCO site in this country.
  /// False when [totalHeritageSites] is 0.
  bool get allSitesVisited =>
      totalHeritageSites > 0 && visitedHeritageSites >= totalHeritageSites;

  factory CountryStats.compute({
    required List<TripRecord> trips,
    required Set<String> visitedRegionCodes,
    required int totalRegions,
    required int visitedHeritageSites,
    required int totalHeritageSites,
    required EffectiveVisitedCountry? visit,
  }) {
    int days = 0;
    int photos = 0;
    DateTime? firstStart;
    DateTime? lastEnd;

    for (final t in trips) {
      days += t.endedOn.difference(t.startedOn).inDays + 1;
      photos += t.photoCount;
      if (firstStart == null || t.startedOn.isBefore(firstStart)) {
        firstStart = t.startedOn;
      }
      if (lastEnd == null || t.endedOn.isAfter(lastEnd)) {
        lastEnd = t.endedOn;
      }
    }

    final firstYear = firstStart?.year ?? visit?.firstSeen?.year;
    final lastYear = lastEnd?.year ?? visit?.lastSeen?.year;

    return CountryStats(
      tripCount: trips.length,
      totalDays: days,
      totalPhotos: photos,
      visitedRegions: visitedRegionCodes.length,
      totalRegions: totalRegions,
      visitedHeritageSites: visitedHeritageSites,
      totalHeritageSites: totalHeritageSites,
      firstVisitYear: firstYear,
      lastVisitYear: lastYear,
      firstTripStart: firstStart,
    );
  }

  /// A personalised sentence summarising the user's connection to this country.
  String narrativeText(String countryName) {
    if (tripCount == 0) {
      return "You've visited $countryName — add trips to see your full story.";
    }
    final dayStr = totalDays == 1 ? '1 day' : '$totalDays days';
    final season =
        firstTripStart != null ? _season(firstTripStart!.month) : null;
    final yearStr = firstVisitYear != null
        ? '${season != null ? "$season " : ""}$firstVisitYear'
        : null;

    String base;
    if (tripCount == 1) {
      base = "You've spent $dayStr in $countryName.";
      if (yearStr != null) base += ' First and only visit: $yearStr.';
    } else {
      base = "You've spent $dayStr in $countryName across $tripCount trips.";
      if (yearStr != null) base += ' First adventure: $yearStr.';
    }

    if (allSitesVisited) {
      base += " You've visited every UNESCO site here.";
    }

    return base;
  }

  static String _season(int month) {
    if (month == 12 || month <= 2) return 'Winter';
    if (month <= 5) return 'Spring';
    if (month <= 8) return 'Summer';
    return 'Autumn';
  }
}
