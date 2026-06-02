// T3.12 — HeritageRepository service tests

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/heritage_repository.dart';
import 'package:shared_models/shared_models.dart';

HeritageRepository _makeRepo() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return HeritageRepository(RoavvyDatabase(NativeDatabase.memory()));
}

final _firstSeen = DateTime.utc(2024, 3, 1);
final _lastSeen = DateTime.utc(2024, 6, 15);

VisitedHeritageSite _site({
  String siteId = '208',
  String name = 'Taj Mahal',
  String countryCode = 'IN',
  String category = 'cultural',
  double latitude = 27.175,
  double longitude = 78.042,
  int inscriptionYear = 1983,
  DateTime? firstSeen,
  DateTime? lastSeen,
  int photoCount = 1,
  String confidence = 'strong',
  double nearestDistanceKm = 0.5,
}) =>
    VisitedHeritageSite(
      siteId: siteId,
      name: name,
      countryCode: countryCode,
      category: category,
      latitude: latitude,
      longitude: longitude,
      inscriptionYear: inscriptionYear,
      firstSeen: firstSeen ?? _firstSeen,
      lastSeen: lastSeen ?? _lastSeen,
      photoCount: photoCount,
      confidence: confidence,
      nearestDistanceKm: nearestDistanceKm,
    );

void main() {
  // ── upsertAll / loadAll ───────────────────────────────────────────────────

  group('HeritageRepository.upsertAll / loadAll', () {
    test('empty upsert is a no-op', () async {
      final repo = _makeRepo();
      await repo.upsertAll([]);
      expect(await repo.loadAll(), isEmpty);
    });

    test('inserts a single site and loadAll returns it', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_site()]);
      final all = await repo.loadAll();
      expect(all, hasLength(1));
      expect(all.first.siteId, '208');
      expect(all.first.name, 'Taj Mahal');
    });

    test('inserts multiple sites', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _site(siteId: '208', name: 'Taj Mahal', countryCode: 'IN'),
        _site(siteId: '1', name: 'Galápagos', countryCode: 'EC', category: 'natural'),
      ]);
      final all = await repo.loadAll();
      expect(all, hasLength(2));
      expect(all.map((s) => s.siteId), containsAll(['208', '1']));
    });

    test('round-trips all fields', () async {
      final repo = _makeRepo();
      final site = _site(
        siteId: '42',
        name: 'Great Barrier Reef',
        countryCode: 'AU',
        category: 'natural',
        latitude: -18.286,
        longitude: 147.7,
        inscriptionYear: 1981,
        photoCount: 5,
        confidence: 'nearby',
        nearestDistanceKm: 12.3,
      );
      await repo.upsertAll([site]);
      final loaded = (await repo.loadAll()).first;
      expect(loaded.siteId, '42');
      expect(loaded.countryCode, 'AU');
      expect(loaded.category, 'natural');
      expect(loaded.latitude, closeTo(-18.286, 0.001));
      expect(loaded.inscriptionYear, 1981);
      expect(loaded.photoCount, 5);
      expect(loaded.confidence, 'nearby');
      expect(loaded.nearestDistanceKm, closeTo(12.3, 0.001));
    });
  });

  // ── loadByCountry ─────────────────────────────────────────────────────────

  group('HeritageRepository.loadByCountry', () {
    test('returns empty list when no sites for country', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_site(countryCode: 'IN')]);
      expect(await repo.loadByCountry('GB'), isEmpty);
    });

    test('returns only sites for the requested country', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _site(siteId: '1', countryCode: 'IN', name: 'Taj Mahal'),
        _site(siteId: '2', countryCode: 'GB', name: 'Stonehenge'),
        _site(siteId: '3', countryCode: 'IN', name: 'Agra Fort'),
      ]);

      final inSites = await repo.loadByCountry('IN');
      expect(inSites, hasLength(2));
      expect(inSites.map((s) => s.name), containsAll(['Taj Mahal', 'Agra Fort']));

      final gbSites = await repo.loadByCountry('GB');
      expect(gbSites, hasLength(1));
      expect(gbSites.first.name, 'Stonehenge');
    });

    test('returns empty list when no sites at all', () async {
      final repo = _makeRepo();
      expect(await repo.loadByCountry('FR'), isEmpty);
    });
  });

  // ── upsert merge logic ────────────────────────────────────────────────────

  group('HeritageRepository — upsert merge logic', () {
    test('second upsert with same siteId accumulates photoCount', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_site(photoCount: 3)]);
      await repo.upsertAll([_site(photoCount: 5)]);
      final all = await repo.loadAll();
      expect(all, hasLength(1));
      expect(all.first.photoCount, 8);
    });

    test('merge keeps earliest firstSeen', () async {
      final repo = _makeRepo();
      final early = DateTime.utc(2023, 1, 1);
      final late = DateTime.utc(2024, 6, 1);
      await repo.upsertAll([_site(firstSeen: late)]);
      await repo.upsertAll([_site(firstSeen: early)]);
      expect((await repo.loadAll()).first.firstSeen.toUtc(), early);
    });

    test('merge keeps latest lastSeen', () async {
      final repo = _makeRepo();
      final early = DateTime.utc(2023, 1, 1);
      final late = DateTime.utc(2024, 6, 1);
      await repo.upsertAll([_site(lastSeen: early)]);
      await repo.upsertAll([_site(lastSeen: late)]);
      expect((await repo.loadAll()).first.lastSeen.toUtc(), late);
    });

    test('merge keeps minimum nearestDistanceKm', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_site(nearestDistanceKm: 5.0)]);
      await repo.upsertAll([_site(nearestDistanceKm: 1.2)]);
      expect((await repo.loadAll()).first.nearestDistanceKm, closeTo(1.2, 0.001));
    });

    test('confidence upgrades from nearby to strong, never downgrades', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_site(confidence: 'nearby')]);
      await repo.upsertAll([_site(confidence: 'strong')]);
      expect((await repo.loadAll()).first.confidence, 'strong');
    });

    test('confidence does not downgrade from strong to nearby', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_site(confidence: 'strong')]);
      await repo.upsertAll([_site(confidence: 'nearby')]);
      expect((await repo.loadAll()).first.confidence, 'strong');
    });
  });

  // ── loadVisitedCount ──────────────────────────────────────────────────────

  group('HeritageRepository.loadVisitedCount', () {
    test('returns 0 when no sites', () async {
      final repo = _makeRepo();
      expect(await repo.loadVisitedCount(), 0);
    });

    test('returns count of all visited sites', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _site(siteId: '1'),
        _site(siteId: '2', countryCode: 'GB'),
        _site(siteId: '3', countryCode: 'AU'),
      ]);
      expect(await repo.loadVisitedCount(), 3);
    });
  });

  // ── loadVisitedCountByCategory ────────────────────────────────────────────

  group('HeritageRepository.loadVisitedCountByCategory', () {
    test('returns empty map when no sites', () async {
      final repo = _makeRepo();
      expect(await repo.loadVisitedCountByCategory(), isEmpty);
    });

    test('counts sites correctly per category', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _site(siteId: '1', category: 'cultural'),
        _site(siteId: '2', category: 'cultural'),
        _site(siteId: '3', category: 'natural'),
        _site(siteId: '4', category: 'mixed'),
      ]);
      final counts = await repo.loadVisitedCountByCategory();
      expect(counts['cultural'], 2);
      expect(counts['natural'], 1);
      expect(counts['mixed'], 1);
    });
  });
}
