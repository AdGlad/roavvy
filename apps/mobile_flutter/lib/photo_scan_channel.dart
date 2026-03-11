import 'package:flutter/services.dart';

// ── Channel ──────────────────────────────────────────────────────────────────

const _channel = MethodChannel('roavvy/photo_scan');

Future<PhotoPermissionStatus> requestPhotoPermission() async {
  final int raw = await _channel.invokeMethod('requestPermission');
  return PhotoPermissionStatus.fromRaw(raw);
}

/// Scans up to [limit] photo assets and returns geocoded country results.
///
/// [sinceDate]: when non-null, only assets created after this date are fetched.
/// Pass the timestamp of the previous scan for an incremental rescan,
/// or null for a full scan (first launch or user-initiated reset).
Future<ScanResult> scanPhotos({int limit = 100, DateTime? sinceDate}) async {
  final args = <String, dynamic>{'limit': limit};
  if (sinceDate != null) args['sinceDate'] = sinceDate.toUtc().toIso8601String();
  final Map raw = await _channel.invokeMethod('scanPhotos', args);
  return ScanResult.fromMap(Map<String, dynamic>.from(raw));
}

// ── Types ─────────────────────────────────────────────────────────────────────

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

class ScanStats {
  const ScanStats({
    required this.inspected,
    required this.withLocation,
    required this.geocodeSuccesses,
  });

  factory ScanStats.fromMap(Map<String, dynamic> m) => ScanStats(
        inspected: m['inspected'] as int? ?? 0,
        withLocation: m['withLocation'] as int? ?? 0,
        geocodeSuccesses: m['geocodeSuccesses'] as int? ?? 0,
      );

  final int inspected;
  final int withLocation;
  int get withoutLocation => inspected - withLocation;

  final int geocodeSuccesses;
  int get geocodeFailures => withLocation - geocodeSuccesses;
}

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
