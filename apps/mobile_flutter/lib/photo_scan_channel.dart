import 'package:flutter/services.dart';

const _methodChannel = MethodChannel('roavvy/photo_scan');
const _eventChannel = EventChannel('roavvy/photo_scan/events');

// ── Permission ────────────────────────────────────────────────────────────────

Future<PhotoPermissionStatus> requestPhotoPermission() async {
  final int raw = await _methodChannel.invokeMethod('requestPermission');
  return PhotoPermissionStatus.fromRaw(raw);
}

// ── Scan (event-channel streaming) ───────────────────────────────────────────

/// Starts a photo scan and streams raw GPS records to the caller.
///
/// Each [ScanBatchEvent] carries a list of [PhotoRecord]s — one per photo with
/// GPS metadata. The stream ends with a [ScanDoneEvent] containing aggregate
/// counters (total assets inspected, assets with location).
///
/// Country resolution is the Dart layer's responsibility; Swift sends only raw
/// coordinates and capture timestamps, with no network calls.
///
/// [sinceDate]: when non-null, only assets created after this date are included.
Stream<ScanEvent> startPhotoScan({int limit = 500, DateTime? sinceDate}) {
  final args = <String, dynamic>{'limit': limit};
  if (sinceDate != null) args['sinceDate'] = sinceDate.toUtc().toIso8601String();
  return _eventChannel
      .receiveBroadcastStream(args)
      .map((event) => ScanEvent.fromMap(Map<String, dynamic>.from(event as Map)));
}

// ── Permission type ───────────────────────────────────────────────────────────

enum PhotoPermissionStatus {
  notDetermined, // 0
  restricted, // 1
  denied, // 2
  authorized, // 3
  limited; // 4 (iOS 14+)

  static PhotoPermissionStatus fromRaw(int v) =>
      PhotoPermissionStatus.values[v.clamp(0, PhotoPermissionStatus.values.length - 1)];

  bool get canScan => this == authorized || this == limited;

  String get label => switch (this) {
        notDetermined => 'Not determined',
        restricted => 'Restricted',
        denied => 'Denied — open Settings',
        authorized => 'Authorised',
        limited => 'Limited access',
      };
}

// ── Scan event types ──────────────────────────────────────────────────────────

sealed class ScanEvent {
  const ScanEvent();

  factory ScanEvent.fromMap(Map<String, dynamic> m) {
    return switch (m['type'] as String?) {
      'batch' => ScanBatchEvent.fromMap(m),
      'done' => ScanDoneEvent.fromMap(m),
      final t => throw ArgumentError('Unknown scan event type: $t'),
    };
  }
}

/// A batch of raw per-photo GPS records streamed from Swift.
class ScanBatchEvent extends ScanEvent {
  const ScanBatchEvent({required this.photos});

  factory ScanBatchEvent.fromMap(Map<String, dynamic> m) => ScanBatchEvent(
        photos: (m['photos'] as List)
            .cast<Map>()
            .map((p) => PhotoRecord.fromMap(Map<String, dynamic>.from(p)))
            .toList(),
      );

  final List<PhotoRecord> photos;
}

/// Terminal event — sent once after all photo batches have been streamed.
class ScanDoneEvent extends ScanEvent {
  const ScanDoneEvent({required this.inspected, required this.withLocation});

  factory ScanDoneEvent.fromMap(Map<String, dynamic> m) => ScanDoneEvent(
        inspected: m['inspected'] as int? ?? 0,
        withLocation: m['withLocation'] as int? ?? 0,
      );

  final int inspected;
  final int withLocation;
}

/// Raw GPS record for a single photo. Country resolution is the Dart layer's
/// responsibility — Swift sends coordinates, not country codes.
class PhotoRecord {
  const PhotoRecord({required this.lat, required this.lng, this.capturedAt});

  factory PhotoRecord.fromMap(Map<String, dynamic> m) {
    final capturedAtStr = m['capturedAt'] as String?;
    return PhotoRecord(
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      capturedAt:
          capturedAtStr != null ? DateTime.tryParse(capturedAtStr)?.toUtc() : null,
    );
  }

  final double lat;
  final double lng;

  /// UTC capture time. Null when the asset has no creation date.
  final DateTime? capturedAt;
}

// ── Scan stats (displayed in the UI after a scan completes) ───────────────────

class ScanStats {
  const ScanStats({
    required this.inspected,
    required this.withLocation,
    required this.geocodeSuccesses,
  });

  /// Legacy factory kept for channel unit tests that parse spike-era payloads.
  factory ScanStats.fromMap(Map<String, dynamic> m) => ScanStats(
        inspected: m['inspected'] as int? ?? 0,
        withLocation: m['withLocation'] as int? ?? 0,
        geocodeSuccesses: m['geocodeSuccesses'] as int? ?? 0,
      );

  final int inspected;
  final int withLocation;
  int get withoutLocation => inspected - withLocation;

  /// Number of geotagged photos whose coordinates resolved to a country code.
  final int geocodeSuccesses;
  int get geocodeFailures => withLocation - geocodeSuccesses;
}

// ── Legacy types (spike-era; retired in Task 5) ───────────────────────────────

/// Aggregated scan result from the CLGeocoder-based spike bridge.
///
/// Kept for [scan_mapper.dart] legacy code and unit tests. Retired in Task 5
/// when the typed domain migration is complete.
class ScanResult {
  const ScanResult({required this.stats, required this.countries});

  factory ScanResult.fromMap(Map<String, dynamic> m) => ScanResult(
        stats: ScanStats.fromMap(m),
        countries: (m['countries'] as List? ?? [])
            .cast<Map>()
            .map((c) => DetectedCountry.fromMap(Map<String, dynamic>.from(c)))
            .toList(),
      );

  final ScanStats stats;
  final List<DetectedCountry> countries;
}

/// Country-level aggregate returned by the CLGeocoder-based spike bridge.
///
/// Kept for [scan_mapper.dart]. Retired in Task 5.
class DetectedCountry {
  const DetectedCountry({
    required this.code,
    required this.name,
    required this.photoCount,
  });

  factory DetectedCountry.fromMap(Map<String, dynamic> m) => DetectedCountry(
        code: m['code'] as String,
        name: m['name'] as String,
        photoCount: m['photoCount'] as int? ?? 0,
      );

  final String code;
  final String name;
  final int photoCount;
}
