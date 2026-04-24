// Tests for assetId-based incremental scan deduplication (ADR-129, M77-T3).
//
// Coverage:
// 1. Repository method loadAllKnownAssetIds returns correct set.
// 2. Filter logic: null assetId always passes through.
// 3. Filter logic: known assetId is excluded.
// 4. Filter logic: unknown assetId passes through.
// 5. Filter logic: mix of known, unknown, and null assetIds.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

VisitRepository _makeRepo() =>
    VisitRepository(RoavvyDatabase(NativeDatabase.memory()));

/// Replicates the filter expression used in scan_screen.dart `_scan()`.
List<PhotoRecord> _filterPhotos(
    List<PhotoRecord> photos, Set<String> knownAssetIds) {
  return photos
      .where(
          (p) => p.assetId == null || !knownAssetIds.contains(p.assetId))
      .toList();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('VisitRepository.loadAllKnownAssetIds', () {
    test('returns empty set when no photo date records exist', () async {
      final repo = _makeRepo();
      final ids = await repo.loadAllKnownAssetIds();
      expect(ids, isEmpty);
    });

    test('returns only non-null assetIds', () async {
      final repo = _makeRepo();
      final t = DateTime.utc(2024, 1, 1);
      // One record with assetId, one without.
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'GB', capturedAt: t, assetId: 'asset-001'),
        PhotoDateRecord(
            countryCode: 'FR',
            capturedAt: t.add(const Duration(hours: 1)),
            assetId: null),
      ]);
      final ids = await repo.loadAllKnownAssetIds();
      expect(ids, {'asset-001'});
    });

    test('returns all non-null assetIds across multiple countries', () async {
      final repo = _makeRepo();
      final t = DateTime.utc(2024, 6, 1);
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'DE', capturedAt: t, assetId: 'asset-DE-1'),
        PhotoDateRecord(
            countryCode: 'DE',
            capturedAt: t.add(const Duration(minutes: 1)),
            assetId: 'asset-DE-2'),
        PhotoDateRecord(
            countryCode: 'JP', capturedAt: t, assetId: 'asset-JP-1'),
      ]);
      final ids = await repo.loadAllKnownAssetIds();
      expect(ids, {'asset-DE-1', 'asset-DE-2', 'asset-JP-1'});
    });

    test('clearAll also clears known assetIds', () async {
      final repo = _makeRepo();
      final t = DateTime.utc(2024, 1, 1);
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'US', capturedAt: t, assetId: 'asset-US-1'),
      ]);
      await repo.clearAll();
      final ids = await repo.loadAllKnownAssetIds();
      expect(ids, isEmpty);
    });
  });

  group('assetId dedup filter logic', () {
    final known = {'known-1', 'known-2', 'known-3'};

    test('photo with null assetId always passes through', () {
      final photos = [
        const PhotoRecord(lat: 51.5, lng: -0.1, assetId: null),
      ];
      expect(_filterPhotos(photos, known), hasLength(1));
    });

    test('photo with known assetId is excluded', () {
      final photos = [
        const PhotoRecord(lat: 48.8, lng: 2.3, assetId: 'known-1'),
      ];
      expect(_filterPhotos(photos, known), isEmpty);
    });

    test('photo with unknown assetId passes through', () {
      final photos = [
        const PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'new-asset'),
      ];
      expect(_filterPhotos(photos, known), hasLength(1));
    });

    test('empty knownAssetIds passes all photos through', () {
      final photos = [
        const PhotoRecord(lat: 0, lng: 0, assetId: 'any-asset'),
        const PhotoRecord(lat: 1, lng: 1, assetId: null),
      ];
      expect(_filterPhotos(photos, {}), hasLength(2));
    });

    test('mixed batch: filters known, passes unknown and null', () {
      final photos = [
        const PhotoRecord(lat: 51.5, lng: -0.1, assetId: 'known-1'),   // excluded
        const PhotoRecord(lat: 48.8, lng: 2.3,  assetId: 'known-2'),   // excluded
        const PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'new-1'),    // included
        const PhotoRecord(lat: 40.7, lng: -74.0, assetId: null),       // included
        const PhotoRecord(lat: 52.5, lng: 13.4,  assetId: 'known-3'), // excluded
        const PhotoRecord(lat: 55.7, lng: 37.6,  assetId: 'new-2'),    // included
      ];
      final result = _filterPhotos(photos, known);
      expect(result, hasLength(3));
      expect(result.map((p) => p.assetId).toList(),
          containsAll(['new-1', null, 'new-2']));
    });

    test('order of remaining photos is preserved', () {
      final photos = [
        const PhotoRecord(lat: 0, lng: 0, assetId: 'known-1'),  // excluded
        const PhotoRecord(lat: 1, lng: 1, assetId: 'alpha'),
        const PhotoRecord(lat: 2, lng: 2, assetId: 'known-2'),  // excluded
        const PhotoRecord(lat: 3, lng: 3, assetId: 'beta'),
      ];
      final result = _filterPhotos(photos, known);
      expect(result.map((p) => p.assetId).toList(), ['alpha', 'beta']);
    });
  });
}
