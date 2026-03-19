import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/bootstrap_service.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

(VisitRepository, TripRepository) _makeRepos() {
  final db = _makeDb();
  return (VisitRepository(db), TripRepository(db));
}

final _t0 = DateTime.utc(2022, 1, 1);
final _t1 = DateTime.utc(2022, 6, 30);

InferredCountryVisit _inferred(
  String code, {
  int photoCount = 5,
  DateTime? firstSeen,
  DateTime? lastSeen,
}) =>
    InferredCountryVisit(
      countryCode: code,
      inferredAt: _t0,
      photoCount: photoCount,
      firstSeen: firstSeen ?? _t0,
      lastSeen: lastSeen ?? _t1,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── Happy path ───────────────────────────────────────────────────────────

  test('creates one trip per inferred country when photoDates empty', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('GB'), _inferred('FR')]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    final trips = await tripRepo.loadAll();
    expect(trips, hasLength(2));
    expect(trips.map((t) => t.countryCode), containsAll(['GB', 'FR']));
  });

  test('trip startedOn = firstSeen, endedOn = lastSeen', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('DE', firstSeen: _t0, lastSeen: _t1)]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    final trips = await tripRepo.loadAll();
    expect(trips.first.startedOn, _t0);
    expect(trips.first.endedOn, _t1);
  });

  test('trip photoCount matches inferred visit photoCount', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('JP', photoCount: 42)]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    final trips = await tripRepo.loadAll();
    expect(trips.first.photoCount, 42);
  });

  test('trip isManual is false', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('AU')]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    expect((await tripRepo.loadAll()).first.isManual, isFalse);
  });

  test('sets bootstrapCompletedAt after running', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('GB')]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    expect(await visitRepo.loadBootstrapCompletedAt(), isNotNull);
  });

  test('endedOn falls back to firstSeen when lastSeen is null', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([
      InferredCountryVisit(
        countryCode: 'NZ',
        inferredAt: _t0,
        photoCount: 1,
        firstSeen: _t0,
        lastSeen: null,
      ),
    ]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    final trips = await tripRepo.loadAll();
    expect(trips.first.endedOn, _t0);
  });

  // ── Guard conditions ─────────────────────────────────────────────────────

  test('no-op when bootstrapCompletedAt already set', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('GB')]);
    await visitRepo.saveBootstrapCompletedAt(DateTime.utc(2024, 1, 1));

    await bootstrapExistingUser(visitRepo, tripRepo);

    expect(await tripRepo.loadAll(), isEmpty);
  });

  test('no-op when photoDates already exist', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('GB')]);
    await visitRepo.savePhotoDates([
      PhotoDateRecord(countryCode: 'GB', capturedAt: _t0),
    ]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    expect(await tripRepo.loadAll(), isEmpty);
    expect(await visitRepo.loadBootstrapCompletedAt(), isNull);
  });

  test('no-op when inferred visits are empty', () async {
    final (visitRepo, tripRepo) = _makeRepos();

    await bootstrapExistingUser(visitRepo, tripRepo);

    expect(await tripRepo.loadAll(), isEmpty);
    expect(await visitRepo.loadBootstrapCompletedAt(), isNull);
  });

  test('skips inferred visits with null firstSeen', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([
      _inferred('GB'), // has firstSeen
      InferredCountryVisit(
        countryCode: 'XX',
        inferredAt: _t0,
        photoCount: 1,
        firstSeen: null,
        lastSeen: null,
      ),
    ]);

    await bootstrapExistingUser(visitRepo, tripRepo);

    final trips = await tripRepo.loadAll();
    expect(trips, hasLength(1));
    expect(trips.first.countryCode, 'GB');
  });

  test('idempotent: second call is a no-op', () async {
    final (visitRepo, tripRepo) = _makeRepos();
    await visitRepo.saveAllInferred([_inferred('GB')]);

    await bootstrapExistingUser(visitRepo, tripRepo);
    await bootstrapExistingUser(visitRepo, tripRepo); // second call

    // Still only one trip (not doubled).
    expect(await tripRepo.loadAll(), hasLength(1));
  });
}
