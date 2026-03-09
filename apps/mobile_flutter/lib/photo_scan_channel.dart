import 'package:flutter/services.dart';

// ── Channel ──────────────────────────────────────────────────────────────────

const _channel = MethodChannel('roavvy/photo_scan');

Future<PhotoPermissionStatus> requestPhotoPermission() async {
  final int raw = await _channel.invokeMethod('requestPermission');
  return PhotoPermissionStatus.fromRaw(raw);
}

Future<List<DetectedCountry>> scanPhotos({int limit = 100}) async {
  final List raw = await _channel.invokeMethod('scanPhotos', {'limit': limit});
  return raw
      .cast<Map>()
      .map((m) => DetectedCountry.fromMap(Map<String, dynamic>.from(m)))
      .toList();
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
