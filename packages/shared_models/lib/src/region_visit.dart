/// A user's visit to an admin1 region (ISO 3166-2), inferred from photo timestamps.
///
/// Belongs to a single [TripRecord] (identified by [tripId]). Multiple
/// [RegionVisit]s may exist for one trip — e.g. a US road trip touching
/// CA, NV, and AZ each produces a separate [RegionVisit].
///
/// [firstSeen] and [lastSeen] are the earliest and latest [PhotoDateRecord]
/// timestamps whose [regionCode] matches and whose [capturedAt] falls within
/// the parent trip's startedOn..endedOn window.
class RegionVisit {
  const RegionVisit({
    required this.tripId,
    required this.countryCode,
    required this.regionCode,
    required this.firstSeen,
    required this.lastSeen,
    required this.photoCount,
  });

  final String tripId;
  final String countryCode;

  /// ISO 3166-2 code, e.g. `"US-CA"`, `"FR-IDF"`, `"GB-ENG"`.
  final String regionCode;

  final DateTime firstSeen;
  final DateTime lastSeen;
  final int photoCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegionVisit &&
          runtimeType == other.runtimeType &&
          tripId == other.tripId &&
          countryCode == other.countryCode &&
          regionCode == other.regionCode &&
          firstSeen == other.firstSeen &&
          lastSeen == other.lastSeen &&
          photoCount == other.photoCount;

  @override
  int get hashCode =>
      Object.hash(tripId, countryCode, regionCode, firstSeen, lastSeen, photoCount);

  @override
  String toString() =>
      'RegionVisit(tripId: $tripId, countryCode: $countryCode, '
      'regionCode: $regionCode, firstSeen: $firstSeen, '
      'lastSeen: $lastSeen, photoCount: $photoCount)';
}
