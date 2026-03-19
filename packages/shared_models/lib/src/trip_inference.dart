import 'photo_date_record.dart';
import 'region_visit.dart';
import 'trip_record.dart';

/// Groups [records] into trips by clustering per-country photo timestamps.
///
/// Algorithm:
/// 1. Group records by [PhotoDateRecord.countryCode].
/// 2. Sort each group ascending by [PhotoDateRecord.capturedAt].
/// 3. Walk the sorted list: whenever the gap between consecutive photos
///    exceeds [gap] (default 30 days), start a new cluster.
/// 4. Each cluster becomes one [TripRecord] with:
///    - `startedOn` = earliest photo in the cluster
///    - `endedOn`   = latest photo in the cluster
///    - `photoCount` = number of photos in the cluster
///    - `isManual`   = false
///    - `id`         = `"${countryCode}_${startedOn.toIso8601String()}"` (ADR-047)
///
/// Photos with null `capturedAt` must have been filtered out before calling
/// this function — only non-null [PhotoDateRecord] values are accepted here.
///
/// Returns an empty list for empty input.
///
/// This function is **pure**: no I/O, no side effects, deterministic output.
/// Callers should not pass manual trips into this function; it only produces
/// `isManual = false` records.
List<TripRecord> inferTrips(
  List<PhotoDateRecord> records, {
  Duration gap = const Duration(days: 30),
}) {
  if (records.isEmpty) return [];

  // Group by country code.
  final byCountry = <String, List<DateTime>>{};
  for (final r in records) {
    byCountry.putIfAbsent(r.countryCode, () => []).add(r.capturedAt);
  }

  final result = <TripRecord>[];

  for (final entry in byCountry.entries) {
    final countryCode = entry.key;
    final dates = entry.value..sort();

    // Walk the sorted dates, splitting on gaps >= [gap].
    var clusterStart = dates.first;
    var clusterEnd = dates.first;
    var count = 1;

    for (var i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(clusterEnd);
      if (diff >= gap) {
        // Flush the current cluster.
        result.add(_makeTrip(countryCode, clusterStart, clusterEnd, count));
        clusterStart = dates[i];
        clusterEnd = dates[i];
        count = 1;
      } else {
        clusterEnd = dates[i];
        count++;
      }
    }
    // Flush the final cluster.
    result.add(_makeTrip(countryCode, clusterStart, clusterEnd, count));
  }

  return result;
}

/// Groups [records] by (tripId × regionCode) to produce [RegionVisit] aggregates.
///
/// Algorithm:
/// 1. Exclude records whose [PhotoDateRecord.regionCode] is null.
/// 2. For each remaining record, find the first trip in [trips] whose
///    [TripRecord.countryCode] matches and whose startedOn..endedOn window
///    contains [PhotoDateRecord.capturedAt] (inclusive).
/// 3. Group matched records by `(tripId, regionCode)`, accumulating
///    [firstSeen] (earliest), [lastSeen] (latest), and [photoCount].
/// 4. Records that do not fall within any trip window are silently excluded —
///    this can happen for bootstrap trips derived from aggregate firstSeen/lastSeen
///    rather than individual photo timestamps.
///
/// This function is **pure**: no I/O, no side effects, deterministic output.
List<RegionVisit> inferRegionVisits(
  List<PhotoDateRecord> records,
  List<TripRecord> trips,
) {
  if (records.isEmpty || trips.isEmpty) return [];

  // Index trips by country code for O(k) lookup per photo.
  final tripsByCountry = <String, List<TripRecord>>{};
  for (final t in trips) {
    tripsByCountry.putIfAbsent(t.countryCode, () => []).add(t);
  }

  // Key: (tripId, regionCode) → _RegionAccum
  final accum = <(String, String), _RegionAccum>{};

  for (final r in records) {
    final regionCode = r.regionCode;
    if (regionCode == null) continue;

    final candidates = tripsByCountry[r.countryCode];
    if (candidates == null) continue;

    // Find the trip whose window contains this photo's timestamp.
    TripRecord? matched;
    for (final t in candidates) {
      if (!r.capturedAt.isBefore(t.startedOn) &&
          !r.capturedAt.isAfter(t.endedOn)) {
        matched = t;
        break;
      }
    }
    if (matched == null) continue;

    final key = (matched.id, regionCode);
    final existing = accum[key];
    accum[key] = existing == null
        ? _RegionAccum(
            tripId: matched.id,
            countryCode: r.countryCode,
            regionCode: regionCode,
            firstSeen: r.capturedAt,
            lastSeen: r.capturedAt,
            photoCount: 1,
          )
        : existing.merge(r.capturedAt);
  }

  return accum.values
      .map((a) => RegionVisit(
            tripId: a.tripId,
            countryCode: a.countryCode,
            regionCode: a.regionCode,
            firstSeen: a.firstSeen,
            lastSeen: a.lastSeen,
            photoCount: a.photoCount,
          ))
      .toList();
}

class _RegionAccum {
  const _RegionAccum({
    required this.tripId,
    required this.countryCode,
    required this.regionCode,
    required this.firstSeen,
    required this.lastSeen,
    required this.photoCount,
  });

  final String tripId;
  final String countryCode;
  final String regionCode;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int photoCount;

  _RegionAccum merge(DateTime capturedAt) => _RegionAccum(
        tripId: tripId,
        countryCode: countryCode,
        regionCode: regionCode,
        firstSeen: capturedAt.isBefore(firstSeen) ? capturedAt : firstSeen,
        lastSeen: capturedAt.isAfter(lastSeen) ? capturedAt : lastSeen,
        photoCount: photoCount + 1,
      );
}

TripRecord _makeTrip(
  String countryCode,
  DateTime startedOn,
  DateTime endedOn,
  int photoCount,
) =>
    TripRecord(
      id: '${countryCode}_${startedOn.toUtc().toIso8601String()}',
      countryCode: countryCode,
      startedOn: startedOn.toUtc(),
      endedOn: endedOn.toUtc(),
      photoCount: photoCount,
      isManual: false,
    );
