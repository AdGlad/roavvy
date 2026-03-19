import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/map/country_detail_sheet.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Wraps [child] in a [ProviderScope] that overrides [tripRepositoryProvider]
/// and [regionRepositoryProvider] with the supplied repos (or empty in-memory
/// repos if not provided).
Widget _wrap(
  Widget child, {
  TripRepository? tripRepo,
  RegionRepository? regionRepo,
}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
      tripRepositoryProvider.overrideWithValue(tripRepo ?? TripRepository(db)),
      regionRepositoryProvider
          .overrideWithValue(regionRepo ?? RegionRepository(db)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

EffectiveVisitedCountry _inferredVisit({
  String code = 'GB',
  int photoCount = 5,
  DateTime? firstSeen,
  DateTime? lastSeen,
}) =>
    EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
      photoCount: photoCount,
      firstSeen: firstSeen ?? DateTime.utc(2019),
      lastSeen: lastSeen ?? DateTime.utc(2023),
    );

EffectiveVisitedCountry _manualVisit({String code = 'GB'}) =>
    EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: false,
    );

TripRecord _trip({
  String countryCode = 'GB',
  DateTime? startedOn,
  DateTime? endedOn,
  int photoCount = 10,
  bool isManual = false,
}) {
  final s = startedOn ?? DateTime.utc(2023, 7, 14);
  final e = endedOn ?? DateTime.utc(2023, 7, 28);
  return TripRecord(
    id: '${countryCode}_${s.toIso8601String()}',
    countryCode: countryCode,
    startedOn: s,
    endedOn: e,
    photoCount: photoCount,
    isManual: isManual,
  );
}

/// Creates a [TripRepository] pre-populated with [trips].
Future<TripRepository> _repoWith(List<TripRecord> trips) async {
  final repo = TripRepository(_makeDb());
  await repo.upsertAll(trips);
  return repo;
}

/// Creates a [RegionRepository] pre-populated with [visits].
Future<RegionRepository> _regionRepoWith(List<RegionVisit> visits) async {
  final repo = RegionRepository(_makeDb());
  await repo.upsertAll(visits);
  return repo;
}

RegionVisit _region({
  String tripId = 'GB_2023-07-14T00:00:00.000Z',
  String countryCode = 'GB',
  required String regionCode,
}) =>
    RegionVisit(
      tripId: tripId,
      countryCode: countryCode,
      regionCode: regionCode,
      firstSeen: DateTime.utc(2023, 7, 14),
      lastSeen: DateTime.utc(2023, 7, 28),
      photoCount: 5,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('CountryDetailSheet — visited country', () {
    testWidgets('shows display name from kCountryNames', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit())),
      );
      await tester.pump();
      expect(find.text('United Kingdom'), findsOneWidget);
    });

    testWidgets('falls back to ISO code for unknown code', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'XX', visit: _inferredVisit(code: 'XX'))),
      );
      await tester.pump();
      expect(find.text('XX'), findsOneWidget);
    });

    testWidgets('shows trip count and first visited year', (tester) async {
      final repo = await _repoWith([_trip()]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(
            isoCode: 'GB',
            visit: _inferredVisit(firstSeen: DateTime.utc(2019)),
          ),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('1 trip · First visited 2019'), findsOneWidget);
    });

    testWidgets('shows plural trip count', (tester) async {
      final repo = await _repoWith([
        _trip(startedOn: DateTime.utc(2022, 1, 1), endedOn: DateTime.utc(2022, 1, 10)),
        _trip(startedOn: DateTime.utc(2023, 7, 14), endedOn: DateTime.utc(2023, 7, 28)),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(
            isoCode: 'GB',
            visit: _inferredVisit(firstSeen: DateTime.utc(2022)),
          ),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('2 trips · First visited 2022'), findsOneWidget);
    });

    testWidgets('shows — for first visited when firstSeen is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(
            isoCode: 'GB',
            visit: const EffectiveVisitedCountry(
              countryCode: 'GB',
              hasPhotoEvidence: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0 trips · First visited —'), findsOneWidget);
    });

    testWidgets('shows manually added badge when hasPhotoEvidence is false',
        (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _manualVisit())),
      );
      await tester.pump();
      expect(find.text('Added manually'), findsOneWidget);
    });

    testWidgets('does not show manually added badge for inferred visit',
        (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit())),
      );
      await tester.pump();
      // The header chip should not appear for photo-evidenced visits.
      // (Trip cards with isManual may show their own badge — tested separately.)
      expect(find.text('Added manually'), findsNothing);
    });

    testWidgets('does not show add button for visited country', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit())),
      );
      await tester.pump();
      expect(find.text('Add to my countries'), findsNothing);
    });
  });

  group('CountryDetailSheet — trip cards', () {
    testWidgets('renders date range on trip card (same year)', (tester) async {
      final repo = await _repoWith([
        _trip(
          startedOn: DateTime.utc(2023, 7, 14),
          endedOn: DateTime.utc(2023, 7, 28),
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('14 Jul – 28 Jul 2023'), findsOneWidget);
    });

    testWidgets('renders date range on trip card (cross-year)', (tester) async {
      final repo = await _repoWith([
        _trip(
          startedOn: DateTime.utc(2022, 12, 28),
          endedOn: DateTime.utc(2023, 1, 4),
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('28 Dec 2022 – 4 Jan 2023'), findsOneWidget);
    });

    testWidgets('renders duration', (tester) async {
      final repo = await _repoWith([
        _trip(
          startedOn: DateTime.utc(2023, 7, 14),
          endedOn: DateTime.utc(2023, 7, 27), // 14 days inclusive
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.textContaining('14 days'), findsOneWidget);
    });

    testWidgets('renders photo count', (tester) async {
      final repo = await _repoWith([_trip(photoCount: 43)]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.textContaining('43 photos'), findsOneWidget);
    });

    testWidgets('manual trip shows Added manually badge on card', (tester) async {
      final repo = await _repoWith([_trip(isManual: true)]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('Added manually'), findsOneWidget);
    });

    testWidgets('non-manual trip does not show Added manually badge on card',
        (tester) async {
      final repo = await _repoWith([_trip(isManual: false)]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('Added manually'), findsNothing);
    });
  });

  group('CountryDetailSheet — 0 trips empty state', () {
    testWidgets('shows empty-state copy when no trips', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _manualVisit())),
      );
      await tester.pump();
      expect(
        find.text('No trip data — add a trip manually'),
        findsOneWidget,
      );
    });

    testWidgets('shows Add trip manually button when no trips', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _manualVisit())),
      );
      await tester.pump();
      expect(find.text('Add trip manually'), findsOneWidget);
    });

    testWidgets('shows Add trip manually button even with trips present',
        (tester) async {
      final repo = await _repoWith([_trip()]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();
      expect(find.text('Add trip manually'), findsOneWidget);
    });
  });

  group('CountryDetailSheet — delete trip', () {
    testWidgets('long-pressing trip card shows delete confirmation dialog',
        (tester) async {
      final repo = await _repoWith([_trip()]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('Delete this trip?'), findsOneWidget);
    });

    testWidgets('cancelling delete dialog leaves trip in list', (tester) async {
      final repo = await _repoWith([_trip()]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(Card));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await repo.loadAll(), hasLength(1));
      expect(find.text('14 Jul – 28 Jul 2023'), findsOneWidget);
    });

    testWidgets('confirming delete removes trip from list', (tester) async {
      final repo = await _repoWith([_trip()]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(Card));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await repo.loadAll(), isEmpty);
      expect(find.text('No trip data — add a trip manually'), findsOneWidget);
    });
  });

  group('CountryDetailSheet — add trip flow', () {
    testWidgets('tapping Add trip manually opens TripEditSheet', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _manualVisit())),
      );
      await tester.pump();

      await tester.tap(find.text('Add trip manually'));
      await tester.pumpAndSettle();

      expect(find.text('Add trip'), findsOneWidget);
    });

    testWidgets('tapping card opens TripEditSheet in edit mode', (tester) async {
      final repo = await _repoWith([_trip()]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          tripRepo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('Edit trip'), findsOneWidget);
    });
  });

  group('CountryDetailSheet — region section', () {
    testWidgets('region count row is visible with correct count',
        (tester) async {
      final regionRepo = await _regionRepoWith([
        _region(regionCode: 'GB-ENG'),
        _region(regionCode: 'GB-SCT'),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          regionRepo: regionRepo,
        ),
      );
      await tester.pump();
      expect(find.text('2 regions visited'), findsOneWidget);
    });

    testWidgets('region count row is hidden when 0 regions', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit())),
      );
      await tester.pump();
      expect(find.textContaining('regions visited'), findsNothing);
      expect(find.textContaining('region visited'), findsNothing);
    });

    testWidgets('tapping region row shows sorted region name list',
        (tester) async {
      final regionRepo = await _regionRepoWith([
        _region(regionCode: 'GB-SCT'),
        _region(regionCode: 'GB-ENG'),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          regionRepo: regionRepo,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('2 regions visited'));
      await tester.pump();

      expect(find.text('England'), findsOneWidget);
      expect(find.text('Scotland'), findsOneWidget);
    });

    testWidgets('kRegionNames fallback: unknown code displayed as-is',
        (tester) async {
      final regionRepo = await _regionRepoWith([
        _region(regionCode: 'GB-ZZ'), // not in kRegionNames
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          regionRepo: regionRepo,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('1 region visited'));
      await tester.pump();

      expect(find.text('GB-ZZ'), findsOneWidget);
    });

    testWidgets('duplicate region across trips counts once', (tester) async {
      final regionRepo = await _regionRepoWith([
        _region(tripId: 'GB_2022-01-01T00:00:00.000Z', regionCode: 'GB-ENG'),
        _region(tripId: 'GB_2023-07-14T00:00:00.000Z', regionCode: 'GB-ENG'),
      ]);
      await tester.pumpWidget(
        _wrap(
          CountryDetailSheet(isoCode: 'GB', visit: _inferredVisit()),
          regionRepo: regionRepo,
        ),
      );
      await tester.pump();
      expect(find.text('1 region visited'), findsOneWidget);
    });
  });

  group('CountryDetailSheet — unvisited country', () {
    testWidgets('shows display name', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'JP', onAdd: () async {})),
      );
      await tester.pump();
      expect(find.text('Japan'), findsOneWidget);
    });

    testWidgets('shows add button', (tester) async {
      await tester.pumpWidget(
        _wrap(CountryDetailSheet(isoCode: 'JP', onAdd: () async {})),
      );
      await tester.pump();
      expect(find.text('Add to my countries'), findsOneWidget);
    });

    testWidgets('tapping add button calls onAdd and pops with true',
        (tester) async {
      bool? addCalled;
      bool? poppedWith;

      final db = _makeDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
            tripRepositoryProvider.overrideWithValue(TripRepository(db)),
            regionRepositoryProvider
                .overrideWithValue(RegionRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  poppedWith = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (_) => CountryDetailSheet(
                      isoCode: 'JP',
                      onAdd: () async {
                        addCalled = true;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to my countries'));
      await tester.pumpAndSettle();

      expect(addCalled, isTrue);
      expect(poppedWith, isTrue);
    });
  });
}
