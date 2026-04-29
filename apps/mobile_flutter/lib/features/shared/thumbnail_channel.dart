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
}
