import 'dart:async';
import 'dart:typed_data';

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
import 'package:mobile_flutter/features/map/photo_gallery_screen.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('PhotoGalleryScreen — empty state', () {
    testWidgets('shows empty state message when assetIds is empty',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PhotoGalleryScreen(assetIds: [])),
      ));
      expect(find.text('No photos with location data'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('PhotoGalleryScreen — grid', () {
    testWidgets('shows GridView with loading indicators then broken_image icons',
        (tester) async {
      final completers = {
        'id1': Completer<Uint8List?>(),
        'id2': Completer<Uint8List?>(),
        'id3': Completer<Uint8List?>(),
      };
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PhotoGalleryScreen(
            assetIds: const ['id1', 'id2', 'id3'],
            thumbnailFetcher: (id) => completers[id]!.future,
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(3));

      for (final c in completers.values) {
        c.complete(null);
      }
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(3));
    });

    testWidgets('shows broken_image icon after fetcher returns null',
        (tester) async {
      final completers = {
        'id1': Completer<Uint8List?>(),
        'id2': Completer<Uint8List?>(),
      };
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PhotoGalleryScreen(
            assetIds: const ['id1', 'id2'],
            thumbnailFetcher: (id) => completers[id]!.future,
          ),
        ),
      ));
      await tester.pump();

      for (final c in completers.values) {
        c.complete(null);
      }
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(2));
    });
  });

  group('CountryDetailSheet — Photos tab', () {
    testWidgets('Photos tab is present in the tab bar', (tester) async {
      final db = RoavvyDatabase(NativeDatabase.memory());

      await tester.pumpWidget(ProviderScope(
        overrides: [
          visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
          tripRepositoryProvider.overrideWithValue(TripRepository(db)),
          regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CountryDetailSheet(
              isoCode: 'GB',
              visit: const EffectiveVisitedCountry(
                countryCode: 'GB',
                hasPhotoEvidence: true,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });
  });
}
