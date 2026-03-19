/// Per-photo country + timestamp record produced during scanning.
///
/// Stores [countryCode], [capturedAt], and optional [regionCode] —
/// no GPS coordinates (ADR-002).
/// One row per geotagged photo in the Drift `photo_date_records` table.
/// Used by the trip inference engine to cluster photos into trips.
class PhotoDateRecord {
  const PhotoDateRecord({
    required this.countryCode,
    required this.capturedAt,
    this.regionCode,
  });

  final String countryCode;
  final DateTime capturedAt;

  /// ISO 3166-2 region code (e.g. "US-CA", "GB-ENG"), or null when the
  /// coordinate falls in open water, a micro-state with no admin1 divisions,
  /// or when region resolution was not performed.
  final String? regionCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoDateRecord &&
          runtimeType == other.runtimeType &&
          countryCode == other.countryCode &&
          capturedAt == other.capturedAt &&
          regionCode == other.regionCode;

  @override
  int get hashCode => Object.hash(countryCode, capturedAt, regionCode);

  @override
  String toString() =>
      'PhotoDateRecord(countryCode: $countryCode, capturedAt: $capturedAt, regionCode: $regionCode)';
}
