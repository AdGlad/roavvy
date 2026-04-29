import 'package:shared_preferences/shared_preferences.dart';

import 'hero_analysis_channel.dart';
import 'hero_image_repository.dart';

/// Validates that all persisted hero assetIds still exist on the device
/// and tombstones any that have been deleted (M89, ADR-134).
///
/// Runs at most once per calendar day (keyed by ISO date in SharedPreferences).
/// Non-blocking — safe to call fire-and-forget on app launch.
class HeroCacheValidator {
  const HeroCacheValidator({
    required HeroImageRepository repository,
    HeroAnalysisChannel? channel,
  })  : _repository = repository,
        _channel = channel;

  final HeroImageRepository _repository;
  final HeroAnalysisChannel? _channel;

  static const _kLastValidatedKey = 'hero_cache_validated_date';

  /// Checks if we need to run today and, if so, validates all persisted heroes.
  ///
  /// Skips if already run today. Safe to call from initState.
  Future<void> validateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastRun = prefs.getString(_kLastValidatedKey);
    if (lastRun == today) return;

    await _validate();

    await prefs.setString(_kLastValidatedKey, today);
  }

  Future<void> _validate() async {
    final allAssetIds = await _repository.getAllActiveAssetIds();
    if (allAssetIds.isEmpty) return;

    // Batch check existence via MethodChannel (Swift PHAsset.fetchAssets).
    final channel = _channel ?? HeroAnalysisChannel();
    final existingIds = await channel.checkAssetsExist(allAssetIds);
    final existingSet = existingIds.toSet();

    // Tombstone any IDs that are no longer present.
    for (final assetId in allAssetIds) {
      if (!existingSet.contains(assetId)) {
        // Find the hero row id for this assetId and tombstone it.
        await _tombstoneByAssetId(assetId);
      }
    }
  }

  Future<void> _tombstoneByAssetId(String assetId) async {
    // Retrieve all rows for this assetId (could be rank 1/2/3 across trips).
    final heroes = await _repository.getCandidatesForAssetId(assetId);
    for (final hero in heroes) {
      await _repository.tombstone(hero.id);
    }
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
