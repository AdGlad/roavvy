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
class TripRecord {
  const TripRecord({
    required this.id,
    required this.countryCode,
    required this.startedOn,
    required this.endedOn,
    required this.photoCount,
    required this.isManual,
  });

  final String id;
  final String countryCode;
  final DateTime startedOn;
  final DateTime endedOn;
  final int photoCount;

  /// True for trips created or edited by the user; false for inferred trips.
  final bool isManual;

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
          isManual == other.isManual;

  @override
  int get hashCode =>
      Object.hash(id, countryCode, startedOn, endedOn, photoCount, isManual);

  @override
  String toString() => 'TripRecord(id: $id, countryCode: $countryCode, '
      'startedOn: $startedOn, endedOn: $endedOn, '
      'photoCount: $photoCount, isManual: $isManual)';
}
