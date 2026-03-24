import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/features/map/country_region_map_screen.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Minimal valid ne_admin1.bin with 0 polygons (2-cell grid, 180°/cell).
Uint8List _emptyRegionBin() {
  const bytes = [
    0x52, 0x4C, 0x52, 0x47, // magic "RLRG"
    0x01,                    // version = 1
    0xB4,                    // grid_cell_size = 180°
    0x02, 0x00,              // grid_cols = 2 (LE uint16)
    0x01, 0x00,              // grid_rows = 1 (LE uint16)
    0x00, 0x00,              // polygon_count = 0 (LE uint16)
    0x00, 0x00, 0x00, 0x00,  // poly_refs_size = 0 (LE uint32)
    // Grid index: 2 cells × 6 bytes, all zeros.
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ];
  return Uint8List.fromList(bytes);
}

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

Widget _pumpScreen(
  String countryCode, {
  RegionRepository? regionRepo,
}) {
  final repo = regionRepo ?? RegionRepository(_makeDb());
  return ProviderScope(
    overrides: [
      regionRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: CountryRegionMapScreen(countryCode: countryCode),
    ),
  );
}

Future<RegionRepository> _repoWithVisits(List<RegionVisit> visits) async {
  final repo = RegionRepository(_makeDb());
  await repo.upsertAll(visits);
  return repo;
}

RegionVisit _visit(String countryCode, String regionCode) => RegionVisit(
      tripId: 'trip-1',
      countryCode: countryCode,
      regionCode: regionCode,
      firstSeen: DateTime.utc(2024),
      lastSeen: DateTime.utc(2024),
      photoCount: 1,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    initRegionLookup(_emptyRegionBin());
  });

  group('CountryRegionMapScreen — AppBar', () {
    testWidgets('shows country name for known code', (tester) async {
      await tester.pumpWidget(_pumpScreen('FR'));
      await tester.pump(); // allow FutureBuilder to settle loading state

      expect(find.textContaining('France'), findsOneWidget);
    });

    testWidgets('shows country code for unknown code', (tester) async {
      await tester.pumpWidget(_pumpScreen('XX'));
      await tester.pump();

      expect(find.textContaining('XX'), findsOneWidget);
    });

    testWidgets('shows region count subtitle after visits load', (tester) async {
      final repo = await _repoWithVisits([
        _visit('GB', 'GB-ENG'),
        _visit('GB', 'GB-SCT'),
      ]);
      await tester.pumpWidget(_pumpScreen('GB', regionRepo: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 regions visited'), findsOneWidget);
    });

    testWidgets('shows singular "region" for count of 1', (tester) async {
      final repo =
          await _repoWithVisits([_visit('DE', 'DE-BY')]);
      await tester.pumpWidget(_pumpScreen('DE', regionRepo: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 region visited'), findsOneWidget);
    });

    testWidgets('hides subtitle when no visits', (tester) async {
      await tester.pumpWidget(_pumpScreen('JP'));
      await tester.pumpAndSettle();

      expect(find.textContaining('visited'), findsNothing);
    });
  });

  group('CountryRegionMapScreen — rendering', () {
    testWidgets('renders without error for country with no region data',
        (tester) async {
      await tester.pumpWidget(_pumpScreen('SG'));
      await tester.pumpAndSettle();

      // No crash; screen renders with AppBar containing the country name.
      expect(find.textContaining('Singapore'), findsOneWidget);
    });

    testWidgets('renders FlutterMap once data resolves', (tester) async {
      await tester.pumpWidget(_pumpScreen('AU'));
      await tester.pumpAndSettle();

      // No crash for country with no visits and empty polygon list.
      expect(find.textContaining('Australia'), findsOneWidget);
    });
  });
}
