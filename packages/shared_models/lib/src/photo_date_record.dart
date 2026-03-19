/// Per-photo country + timestamp record produced during scanning.
///
/// Stores [countryCode], [capturedAt], optional [regionCode], and optional
/// [assetId] — no GPS coordinates (ADR-002).
/// One row per geotagged photo in the Drift `photo_date_records` table.
/// Used by the trip inference engine to cluster photos into trips.
class PhotoDateRecord {
  const PhotoDateRecord({
    required this.countryCode,
    required this.capturedAt,
    this.regionCode,
    this.assetId,
  });

  final String countryCode;
  final DateTime capturedAt;

  /// ISO 3166-2 region code (e.g. "US-CA", "GB-ENG"), or null when the
  /// coordinate falls in open water, a micro-state with no admin1 divisions,
  /// or when region resolution was not performed.
  final String? regionCode;

  /// PHAsset.localIdentifier — opaque on-device UUID.
  /// Stored in local SQLite only; never written to Firestore (ADR-060).
  /// Null for rows created before schema v9 or when assetId was unavailable.
  final String? assetId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoDateRecord &&
          runtimeType == other.runtimeType &&
          countryCode == other.countryCode &&
          capturedAt == other.capturedAt &&
          regionCode == other.regionCode &&
          assetId == other.assetId;

  @override
  int get hashCode => Object.hash(countryCode, capturedAt, regionCode, assetId);

  @override
  String toString() =>
      'PhotoDateRecord(countryCode: $countryCode, capturedAt: $capturedAt, '
      'regionCode: $regionCode, assetId: $assetId)';
}
