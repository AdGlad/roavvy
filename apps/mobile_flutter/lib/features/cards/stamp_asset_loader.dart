import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

// ── StampDateSpec ─────────────────────────────────────────────────────────────

/// Position and typography spec for the date overlay, in native image coords.
class StampDateSpec {
  const StampDateSpec({
    required this.x,
    required this.y,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
  });

  /// Horizontal centre position in the native image coordinate space.
  final double x;

  /// Vertical centre position in the native image coordinate space.
  final double y;

  final double fontSize;
  final int fontWeight;
  final double letterSpacing;

  factory StampDateSpec.fromJson(Map<String, dynamic> json) => StampDateSpec(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        fontSize: (json['font_size'] as num).toDouble(),
        fontWeight: (json['font_weight'] as num).toInt(),
        letterSpacing: (json['letter_spacing'] as num).toDouble(),
      );
}

// ── StampMetadata ─────────────────────────────────────────────────────────────

/// Metadata loaded from a stamp's `.json` config file.
class StampMetadata {
  const StampMetadata({
    required this.name,
    required this.pngAsset,
    required this.imageWidth,
    required this.imageHeight,
    required this.dateSpec,
    this.visualScale = 1.0,
  });

  final String name;

  /// Filename of the PNG (e.g. `"denmark-dk-entry.png"`).
  final String pngAsset;

  /// Native width of the stamp image in pixels (typically 400).
  final double imageWidth;

  /// Native height of the stamp image in pixels (typically 267).
  final double imageHeight;

  /// Spec for the date text overlay.
  final StampDateSpec dateSpec;

  /// Optional visual size multiplier (default 1.0).
  ///
  /// Set this in the JSON file (`"visual_scale": 1.2`) to compensate for
  /// stamps whose PNG assets have more whitespace/padding than others, so
  /// that all stamps appear at a broadly similar visual size on the card.
  final double visualScale;

  factory StampMetadata.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as Map<String, dynamic>;
    return StampMetadata(
      name: json['name'] as String,
      pngAsset: json['png_asset'] as String,
      imageWidth: (image['width'] as num).toDouble(),
      imageHeight: (image['height'] as num).toDouble(),
      dateSpec: StampDateSpec.fromJson(json['date'] as Map<String, dynamic>),
      visualScale: json.containsKey('visual_scale')
          ? (json['visual_scale'] as num).toDouble()
          : 1.0,
    );
  }
}

// ── StampAsset ────────────────────────────────────────────────────────────────

/// A fully loaded stamp asset: decoded PNG + its JSON metadata.
class StampAsset {
  const StampAsset({required this.image, required this.metadata});

  final ui.Image image;
  final StampMetadata metadata;
}

// ── StampAssetLoader ──────────────────────────────────────────────────────────

/// Loads and caches stamp PNG assets and JSON metadata from the app bundle.
///
/// The manifest at `assets/mobile_meta/stamp_manifest.json` maps keys of the
/// form `"DK-entry"` to filename bases like `"denmark-dk-entry"`. Adding a new
/// country's stamp assets only requires placing the files and updating the
/// manifest — no Dart changes needed.
///
/// Assets are decoded on first request and held for the app's lifetime.
class StampAssetLoader {
  StampAssetLoader._();

  static final StampAssetLoader instance = StampAssetLoader._();

  static const _manifestPath = 'assets/mobile_meta/stamp_manifest.json';
  static const _metaDir = 'assets/mobile_meta/';
  static const _pngDir = 'assets/mobile_png/';

  Map<String, String>? _manifest;
  final Map<String, StampAsset?> _cache = {};

  /// Returns the manifest key for [countryCode] + [isEntry].
  ///
  /// Example: `assetKey('DK', true)` → `"DK-entry"`.
  static String assetKey(String countryCode, bool isEntry) =>
      '${countryCode.toUpperCase()}-${isEntry ? 'entry' : 'exit'}';

  /// Ensures the manifest JSON has been loaded from the bundle.
  ///
  /// Safe to call multiple times; subsequent calls return immediately.
  Future<void> ensureManifestLoaded() async {
    if (_manifest != null) return;
    try {
      final raw = await rootBundle.loadString(_manifestPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _manifest = decoded.cast<String, String>();
    } catch (_) {
      _manifest = {};
    }
  }

  /// Loads the [StampAsset] for [countryCode] + [isEntry].
  ///
  /// Returns `null` if no entry exists in the manifest or if loading fails.
  /// Results are cached; subsequent calls return immediately from cache.
  Future<StampAsset?> load(String countryCode, bool isEntry) async {
    await ensureManifestLoaded();
    final key = assetKey(countryCode, isEntry);
    if (_cache.containsKey(key)) return _cache[key];

    final base = _manifest?[key];
    if (base == null) {
      _cache[key] = null;
      return null;
    }

    try {
      final metaRaw = await rootBundle.loadString('$_metaDir$base.json');
      final meta = StampMetadata.fromJson(
        jsonDecode(metaRaw) as Map<String, dynamic>,
      );
      final byteData = await rootBundle.load('$_pngDir${meta.pngAsset}');
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      final asset = StampAsset(image: frame.image, metadata: meta);
      _cache[key] = asset;
      return asset;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }
}
