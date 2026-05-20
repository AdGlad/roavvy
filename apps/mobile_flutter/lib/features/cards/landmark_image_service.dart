import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'landmark_painter.dart';

// ── LandmarkImageService (M116) ───────────────────────────────────────────────
//
// Dart-side wrapper for the roavvy/landmark_image MethodChannel.
//
// Workflow:
//   1. Call isAvailable() once — returns true on iOS 18.1+ with Image Playground.
//   2. Call loadCachedIcon(isoCode) to restore previously generated icons from
//      the app's Documents directory without triggering native generation.
//   3. Call generateIcon(isoCode, countryName) to open the Image Playground sheet.
//      Returns PNG bytes on confirmation, null on cancel/error.
//   4. The caller is responsible for caching via saveToDisk().

/// Known landmark names by ISO code — used to seed Image Playground concepts.
const Map<String, String> _kLandmarkNames = {
  'FR': 'Eiffel Tower',
  'GB': 'Big Ben',
  'IT': 'Colosseum',
  'US': 'Statue of Liberty',
  'EG': 'Pyramids of Giza',
  'IN': 'Taj Mahal',
  'JP': 'Torii Gate',
  'CN': 'Great Wall of China',
  'AU': 'Sydney Opera House',
  'BR': 'Christ the Redeemer',
  'GR': 'Parthenon',
  'RU': "St Basil's Cathedral",
  'ES': 'Sagrada Família',
  'DE': 'Brandenburg Gate',
  'NL': 'Dutch Windmill',
  'PE': 'Machu Picchu',
  'MX': 'Chichen Itza',
  'CA': 'CN Tower',
  'JO': 'Petra',
  'AE': 'Burj Khalifa',
  'SG': 'Merlion',
  'KH': 'Angkor Wat',
  'TH': 'Wat Arun',
  'KR': 'N Seoul Tower',
  'TR': 'Hagia Sophia',
};

class LandmarkImageService {
  static const _channel = MethodChannel('roavvy/landmark_image');

  static bool? _available;

  /// Returns true if Image Playground is available (iOS 18.1+ with Apple
  /// Intelligence). Cached after the first call.
  static Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    if (!Platform.isIOS) {
      _available = false;
      return false;
    }
    try {
      _available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Opens the Image Playground sheet for [isoCode].
  ///
  /// Returns PNG bytes when the user confirms, or null if cancelled/unavailable.
  static Future<Uint8List?> generateIcon(
    String isoCode,
    String countryName,
  ) async {
    final code = isoCode.toUpperCase();
    final landmarkName = _kLandmarkNames[code];
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'generateLandmarkIcon',
        {
          'isoCode': code,
          'countryName': countryName,
          if (landmarkName != null) 'landmarkName': landmarkName,
        },
      );
      if (result != null) {
        await saveToDisk(code, result);
      }
      return result;
    } on PlatformException {
      return null;
    }
  }

  /// Reads a previously generated icon from disk, or null if not found.
  static Future<Uint8List?> loadCachedIcon(String isoCode) async {
    // Skip disk IO for countries that have procedural shapes — never cached.
    if (LandmarkShapePainter.supports(isoCode)) return null;
    try {
      final file = await _cacheFile(isoCode);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }

  /// Persists [bytes] as the cached icon for [isoCode].
  static Future<void> saveToDisk(String isoCode, Uint8List bytes) async {
    try {
      final file = await _cacheFile(isoCode);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  /// Deletes the cached icon for [isoCode] if it exists.
  static Future<void> clearCachedIcon(String isoCode) async {
    try {
      final file = await _cacheFile(isoCode);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<File> _cacheFile(String isoCode) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/landmark_ai_${isoCode.toLowerCase()}.png');
  }
}
