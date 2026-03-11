/// A country detected from photo GPS metadata by the scan pipeline.
///
/// One record is produced per country per scan run. If the same country
/// appears in multiple scan runs, the merge function combines the records
/// (earliest [firstSeen], latest [lastSeen], summed [photoCount]).
///
/// This type is produced only by the scan pipeline, never by user action.
/// It carries no precedence over user intent — a [UserRemovedCountry] for
/// the same code always suppresses it.
class InferredCountryVisit {
  const InferredCountryVisit({
    required this.countryCode,
    required this.inferredAt,
    required this.photoCount,
    this.firstSeen,
    this.lastSeen,
  });

  /// ISO 3166-1 alpha-2 code, e.g. `"GB"`, `"JP"`.
  final String countryCode;

  /// UTC timestamp when this inference was produced (i.e. when the scan ran).
  final DateTime inferredAt;

  /// Number of geotagged photos that contributed GPS evidence for this country
  /// in this scan run.
  final int photoCount;

  /// Earliest photo capture date found in this country during this scan.
  ///
  /// Null in the current spike because the Swift bridge does not yet surface
  /// per-photo timestamps — only country-level aggregates are returned.
  /// Will become non-nullable once the bridge is extended.
  final DateTime? firstSeen;

  /// Most recent photo capture date. Null for the same reason as [firstSeen].
  final DateTime? lastSeen;

  @override
  bool operator ==(Object other) =>
      other is InferredCountryVisit &&
      other.countryCode == countryCode &&
      other.inferredAt == inferredAt &&
      other.photoCount == photoCount &&
      other.firstSeen == firstSeen &&
      other.lastSeen == lastSeen;

  @override
  int get hashCode =>
      Object.hash(countryCode, inferredAt, photoCount, firstSeen, lastSeen);

  @override
  String toString() =>
      'InferredCountryVisit($countryCode, photos=$photoCount, inferredAt=$inferredAt)';
}
