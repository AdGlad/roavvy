/// A discrete visit to a country, inferred from photo timestamps or manually created.
///
/// **Identity (ADR-047):**
/// - Inferred trips: `id = "${countryCode}_${startedOn.toIso8601String()}"`
///   (natural key — stable across incremental scans because `startedOn` is
///   always the earliest photo in the cluster and new photos only extend `endedOn`).
/// - Manual trips: `id = "manual_${8-char random hex}"`
///   (the `"manual_"` prefix prevents collision with inferred keys).
///
/// The `id` doubles as the Firestore document ID (`users/{uid}/trips/{id}`).
///
/// **GPS endpoints (ADR-157):** [firstLat]/[firstLng] and [lastLat]/[lastLng]
/// are the GPS coordinates of the first and last geotagged photo in this trip
/// segment. Null for manual trips, trips from pre-v12 scans, or trips where no
/// photo had GPS. Never synced to Firestore; stored on-device only.
class TripRecord {
  const TripRecord({
    required this.id,
    required this.countryCode,
    required this.startedOn,
    required this.endedOn,
    required this.photoCount,
    required this.isManual,
    this.firstLat,
    this.firstLng,
    this.lastLat,
    this.lastLng,
  });

  final String id;
  final String countryCode;
  final DateTime startedOn;
  final DateTime endedOn;
  final int photoCount;

  /// True for trips created or edited by the user; false for inferred trips.
  final bool isManual;

  /// GPS of the first geotagged photo in this trip. Null when unavailable.
  final double? firstLat;
  final double? firstLng;

  /// GPS of the last geotagged photo in this trip. Null when unavailable.
  final double? lastLat;
  final double? lastLng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          countryCode == other.countryCode &&
          startedOn == other.startedOn &&
          endedOn == other.endedOn &&
          photoCount == other.photoCount &&
          isManual == other.isManual &&
          firstLat == other.firstLat &&
          firstLng == other.firstLng &&
          lastLat == other.lastLat &&
          lastLng == other.lastLng;

  @override
  int get hashCode => Object.hash(
      id, countryCode, startedOn, endedOn, photoCount, isManual,
      firstLat, firstLng, lastLat, lastLng);

  @override
  String toString() => 'TripRecord(id: $id, countryCode: $countryCode, '
      'startedOn: $startedOn, endedOn: $endedOn, '
      'photoCount: $photoCount, isManual: $isManual, '
      'firstGps: ($firstLat,$firstLng), lastGps: ($lastLat,$lastLng))';
}
