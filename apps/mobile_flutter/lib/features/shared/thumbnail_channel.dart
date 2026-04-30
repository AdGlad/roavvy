import 'package:flutter/services.dart';

/// Dart wrapper for the `roavvy/thumbnail` MethodChannel (M90, ADR-135).
///
/// Fetches JPEG thumbnail bytes for a local PHAsset identifier.
/// Returns null for assets that are unavailable or iCloud-only.
/// The underlying Swift implementation caches results in NSCache.
class ThumbnailChannel {
  const ThumbnailChannel();

  static const _channel = MethodChannel('roavvy/thumbnail');

  /// Returns JPEG bytes for [assetId] at [size]×[size] pixels, or null if
  /// the asset cannot be loaded (unavailable, iCloud-only, or permission denied).
  Future<Uint8List?> getThumbnail(String assetId, {int size = 300}) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'getThumbnail',
        {'assetId': assetId, 'size': size},
      );
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Returns full-resolution JPEG bytes for [assetId], or null if unavailable.
  ///
  /// Uses `PHImageManagerMaximumSize` with `highQualityFormat` delivery.
  /// iCloud-only assets may download to the device (network allowed on Swift side).
  /// Use for print/share compositing where pixel quality matters (M93, ADR-138).
  Future<Uint8List?> getFullResolutionImage(String assetId) =>
      getThumbnail(assetId, size: 0);
}
