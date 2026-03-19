import 'photo_date_record.dart';
import 'region_visit.dart';
import 'trip_record.dart';

/// Groups [records] into trips using a geographic sequence model.
///
/// Algorithm:
/// 1. Sort all [PhotoDateRecord]s by [PhotoDateRecord.capturedAt] across all
///    countries.
/// 2. Walk the sorted list: whenever the country code changes, close the
///    current trip and open a new one.
/// 3. Trip `startedOn` = first photo's `capturedAt` in the run;
///    `endedOn` = last photo's `capturedAt` in the run.
/// 4. `id` = `"${countryCode}_${startedOn.toIso8601String()}"` (ADR-047).
///
/// A sequence JP → US → JP produces **two** separate JP trips and one US trip.
/// Photos with the same timestamp may appear in any order within that instant.
///
/// This function is **pure**: no I/O, no side effects, deterministic output.
/// Callers should not pass manual trips into this function; it only produces
/// `isManual = false` records.
List<TripRecord> inferTrips(List<PhotoDateRecord> records) {
  if (records.isEmpty) return [];

  // Sort all records by capturedAt ascending.
  final sorted = [...records]
    ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

  final result = <TripRecord>[];

  var currentCountry = sorted.first.countryCode;
  var runStart = sorted.first.capturedAt;
  var runEnd = sorted.first.capturedAt;
  var count = 1;

  for (var i = 1; i < sorted.length; i++) {
    final r = sorted[i];
    if (r.countryCode == currentCountry) {
      runEnd = r.capturedAt;
      count++;
    } else {
      result.add(_makeTrip(currentCountry, runStart, runEnd, count));
      currentCountry = r.countryCode;
      runStart = r.capturedAt;
      runEnd = r.capturedAt;
      count = 1;
    }
  }
  result.add(_makeTrip(currentCountry, runStart, runEnd, count));

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
