import 'package:flutter/services.dart';
import 'package:shared_models/shared_models.dart';

/// Dart wrapper for the `roavvy/hero_analysis` MethodChannel.
///
/// Calls the Swift [HeroImageAnalyzer] to fetch 800×800 px images and run
/// VNClassifyImageRequest, VNGenerateAttentionBasedSaliencyImageRequest, and
/// VNDetectFaceRectanglesRequest on candidate assetIds (M89, ADR-134).
///
/// Local assets are analysed without network access; iCloud assets are fetched
/// only when local candidates are insufficient (ADR-134 extended).
class HeroAnalysisChannel {
  HeroAnalysisChannel({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('roavvy/hero_analysis');

  final MethodChannel _channel;

  /// Analyses [assetIds] (PHAsset local identifiers) for the given [tripId].
  ///
  /// Returns a list of [HeroAnalysisResult] objects. Assets that are
  /// unavailable, iCloud-only, or produce no labels are omitted from the
  /// result (never throw).
  ///
  /// Returns an empty list on any platform error.
  Future<List<HeroAnalysisResult>> analyseHeroCandidates({
    required String tripId,
    required List<String> assetIds,
  }) async {
    if (assetIds.isEmpty) return const [];

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'analyseHeroCandidates',
        {'tripId': tripId, 'assetIds': assetIds},
      );

      if (raw == null) return const [];

      return raw
          .whereType<Map<Object?, Object?>>()
          .map(HeroAnalysisResult.fromJson)
          .toList();
    } on PlatformException catch (_) {
      // Degrade gracefully — hero analysis is non-critical.
      return const [];
    } on MissingPluginException catch (_) {
      // Running on a non-iOS platform or in tests without the plugin.
      return const [];
    }
  }

  /// Checks which [assetIds] still exist on the device.
  ///
  /// Returns only the assetIds that are still present in the photo library.
  /// Used by [HeroCacheValidator] to tombstone deleted assets.
  Future<List<String>> checkAssetsExist(List<String> assetIds) async {
    if (assetIds.isEmpty) return const [];

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'checkAssetsExist',
        {'assetIds': assetIds},
      );
      return raw?.whereType<String>().toList() ?? const [];
    } on PlatformException catch (_) {
      return const [];
    } on MissingPluginException catch (_) {
      return const [];
    }
  }
}
