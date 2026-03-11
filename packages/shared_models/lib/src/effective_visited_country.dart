/// The resolved, display-ready record for a single visited country.
///
/// Produced by [effectiveVisitedCountries] — one per country code in the
/// effective set. Countries suppressed by a [UserRemovedCountry] are never
/// present here.
///
/// This is a **read model**: it is computed on demand from the three input
/// collections and is never stored directly. The underlying input records
/// ([InferredCountryVisit], [UserAddedCountry], [UserRemovedCountry]) are
/// the durable state.
class EffectiveVisitedCountry {
  const EffectiveVisitedCountry({
    required this.countryCode,
    required this.hasPhotoEvidence,
    this.firstSeen,
    this.lastSeen,
    this.photoCount = 0,
  });

  /// ISO 3166-1 alpha-2 code, e.g. `"GB"`, `"JP"`.
  final String countryCode;

  /// True when at least one [InferredCountryVisit] contributed to this record.
  ///
  /// False for purely manual additions ([UserAddedCountry] with no matching
  /// inference). When false, [firstSeen], [lastSeen], and [photoCount] are
  /// meaningless and will be null / zero.
  final bool hasPhotoEvidence;

  /// Earliest photo capture date across all scan runs for this country.
  /// Null when [hasPhotoEvidence] is false, or when the scan pipeline has not
  /// yet surfaced per-photo timestamps (current spike limitation).
  final DateTime? firstSeen;

  /// Most recent photo capture date. Null for the same reasons as [firstSeen].
  final DateTime? lastSeen;

  /// Total number of geotagged photos contributing evidence for this country,
  /// accumulated across all scan runs. Zero when [hasPhotoEvidence] is false.
  final int photoCount;

  @override
  bool operator ==(Object other) =>
      other is EffectiveVisitedCountry &&
      other.countryCode == countryCode &&
      other.hasPhotoEvidence == hasPhotoEvidence &&
      other.firstSeen == firstSeen &&
      other.lastSeen == lastSeen &&
      other.photoCount == photoCount;

  @override
  int get hashCode =>
      Object.hash(countryCode, hasPhotoEvidence, firstSeen, lastSeen, photoCount);

  @override
  String toString() =>
      'EffectiveVisitedCountry($countryCode, photoEvidence=$hasPhotoEvidence, '
      'photos=$photoCount)';
}
