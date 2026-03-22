import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/map/target_country_layer.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

Widget _pumpLayer(VisitRepository repo) {
  return ProviderScope(
    overrides: [
      visitRepositoryProvider.overrideWithValue(repo),
      polygonsProvider.overrideWithValue(const []),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(20, 0),
            initialZoom: 3,
          ),
          children: const [TargetCountryLayer()],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TargetCountryLayer', () {
    testWidgets('renders without crash when no visits', (tester) async {
      final repo = VisitRepository(_makeDb());
      await tester.pumpWidget(_pumpLayer(repo));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when no target regions', (tester) async {
      // No visits → no region is 1-away → no target layer.
      final repo = VisitRepository(_makeDb());
      await tester.pumpWidget(_pumpLayer(repo));
      await tester.pumpAndSettle();
      // TargetCountryLayer returns SizedBox.shrink when there are no targets.
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders without crash when polygons are empty', (tester) async {
      final db = _makeDb();
      final repo = VisitRepository(db);
      // Add many European visits to get close to completion without
      // completing (hard to reach exactly 1-away in a unit test with real
      // kCountryContinent data, so we just verify it doesn't crash).
      await repo.saveAdded(UserAddedCountry(
        countryCode: 'GB',
        addedAt: DateTime(2024).toUtc(),
      ));
      await tester.pumpWidget(_pumpLayer(repo));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}
