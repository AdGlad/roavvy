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

/// Rich landmark descriptions by ISO code.
/// Used as the primary Image Playground concept — specific name + city context
/// produces far better results than a bare landmark name.
const Map<String, String> _kLandmarkDescriptions = {
  'FR': 'Eiffel Tower iron lattice structure, Paris, France',
  'GB': 'Big Ben clock tower at the Palace of Westminster, London',
  'IT': 'Roman Colosseum ancient amphitheatre, Rome, Italy',
  'US': 'Statue of Liberty copper torch, New York',
  'EG': 'Great Pyramids of Giza with sphinx, Egypt desert',
  'IN': 'Taj Mahal white marble mausoleum with minarets, Agra, India',
  'JP': 'Shinto torii gate at Fushimi Inari shrine, Kyoto, Japan',
  'CN': 'Great Wall of China winding across mountain ridges',
  'AU': 'Sydney Opera House sail roof, Sydney Harbour',
  'BR': 'Christ the Redeemer statue on Corcovado mountain, Rio de Janeiro',
  'GR': 'Parthenon ancient temple on the Acropolis, Athens, Greece',
  'RU': "Saint Basil's Cathedral colourful onion domes, Red Square Moscow",
  'ES': 'Sagrada Família cathedral organic stone spires, Barcelona',
  'DE': 'Brandenburg Gate neoclassical columns, Berlin',
  'NL': 'Traditional Dutch windmill in tulip fields, Netherlands',
  'PE': 'Machu Picchu Inca citadel stone ruins in the Andes mountains',
  'MX': 'Chichen Itza El Castillo pyramid, Mexico',
  'CA': 'CN Tower concrete observation tower, Toronto skyline',
  'JO': 'Petra rose-red rock-carved Treasury facade, Jordan',
  'AE': 'Burj Khalifa tallest skyscraper, Dubai cityscape',
  'SG': 'Merlion fountain statue, Marina Bay Singapore',
  'KH': 'Angkor Wat temple towers reflected in water, Cambodia',
  'TH': 'Wat Arun Temple of Dawn with spires on Chao Phraya river, Bangkok',
  'KR': 'N Seoul Tower on Namsan mountain, Seoul South Korea',
  'TR': 'Hagia Sophia dome and minarets, Istanbul',
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
    final description = _kLandmarkDescriptions[code];
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'generateLandmarkIcon',
        {
          'isoCode': code,
          'countryName': countryName,
          // description is the rich prompt; absent for unknown countries
          if (description != null) 'description': description,
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

  // ── Collage (single full-bleed image for all landmarks) ──────────────────

  /// Opens the Image Playground sheet once, building a concept list from all
  /// known landmark descriptions in [isoCodes].
  ///
  /// Returns PNG bytes on confirmation, null if cancelled/unavailable.
  static Future<Uint8List?> generateCollage(List<String> isoCodes) async {
    final codes = isoCodes.map((c) => c.toUpperCase()).toList()..sort();
    final descriptions = codes
        .map((c) => _kLandmarkDescriptions[c])
        .whereType<String>()
        .toList();
    if (descriptions.isEmpty) return null;
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'generateLandmarkCollage',
        {'descriptions': descriptions},
      );
      if (result != null) {
        await _saveCollageToDisk(codes, result);
      }
      return result;
    } on PlatformException {
      return null;
    }
  }

  /// Reads a previously generated collage from disk, or null if not found.
  static Future<Uint8List?> loadCachedCollage(List<String> isoCodes) async {
    try {
      final file = await _collageFile(isoCodes);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }

  /// Deletes the cached collage for [isoCodes] if it exists.
  static Future<void> clearCachedCollage(List<String> isoCodes) async {
    try {
      final file = await _collageFile(isoCodes);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> _saveCollageToDisk(
      List<String> sortedCodes, Uint8List bytes) async {
    try {
      final file = await _collageFile(sortedCodes);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  /// Cache file for the collage — keyed on the sorted, joined set of codes
  /// so that different country selections never collide.
  static Future<File> _collageFile(List<String> isoCodes) async {
    final key =
        (isoCodes.map((c) => c.toLowerCase()).toList()..sort()).join('_');
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/landmark_collage_$key.png');
  }
}
