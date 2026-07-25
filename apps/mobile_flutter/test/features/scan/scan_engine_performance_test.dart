// M185 — Scan engine performance.
//
// Covers the two pieces of resolveBatch/scan_screen.dart that are pure and
// directly unit-testable without spinning up the real isolate or platform
// channel: the knownAssetIds filter (T2 — single-pass GPS collection) and
// the incremental trip-inference helpers (T3), verified against the
// existing full-history inferTrips as a differential parity test per the
// milestone's explicit requirement. ScanResolverIsolate (T1) itself is
// exercised end-to-end by the existing scan_screen widget tests, which all
// go through the widget.batchResolver seam — those passing unchanged is the
// T5 regression guard for this milestone.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/scan/scan_screen.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  group('resolveBatch — knownAssetIds (M185 T2, single-pass GPS)', () {
    test('excludes known-assetId photos from accum/photoDates', () {
      final photos = [
        PhotoRecord(
          lat: 51.5,
          lng: -0.1,
          capturedAt: DateTime.utc(2023, 1, 1),
          assetId: 'known-1',
        ),
        PhotoRecord(
          lat: 51.6,
          lng: -0.2,
          capturedAt: DateTime.utc(2023, 2, 1),
          assetId: 'new-1',
        ),
      ];
      final result = resolveBatch(
        photos,
        (_, __) => 'GB',
        null,
        {'known-1'},
      );

      expect(result.accum['GB']!.photoCount, 1);
      expect(result.photoDates, hasLength(1));
      expect(result.photoDates.single.assetId, 'new-1');
    });

    test(
      'still collects GPS for known-assetId photos (ADR-157 exemption)',
      () {
        final photos = [
          PhotoRecord(
            lat: 51.5,
            lng: -0.1,
            capturedAt: DateTime.utc(2023, 1, 1),
            assetId: 'known-1',
          ),
          PhotoRecord(
            lat: 51.6,
            lng: -0.2,
            capturedAt: DateTime.utc(2023, 2, 1),
            assetId: 'new-1',
          ),
        ];
        final result = resolveBatch(
          photos,
          (_, __) => 'GB',
          null,
          {'known-1'},
        );

        // Both photos resolved to GB with a capturedAt, so GPS covers both —
        // unlike accum/photoDates, which only reflect the new one.
        expect(result.photoGps, hasLength(2));
        expect(result.accum['GB']!.photoCount, 1);
      },
    );

    test('null knownAssetIds behaves exactly as before (nothing filtered)', () {
      final photos = [
        PhotoRecord(
          lat: 51.5,
          lng: -0.1,
          capturedAt: DateTime.utc(2023, 1, 1),
          assetId: 'a',
        ),
      ];
      final result = resolveBatch(photos, (_, __) => 'GB');

      expect(result.accum['GB']!.photoCount, 1);
      expect(result.photoDates, hasLength(1));
      expect(result.photoGps, hasLength(1));
    });

    test('a photo with a null assetId is never treated as known', () {
      final photos = [
        PhotoRecord(lat: 51.5, lng: -0.1, capturedAt: DateTime.utc(2023, 1, 1)),
      ];
      // knownAssetIds is non-empty but the photo's assetId is null, so it
      // can never match — must not be excluded.
      final result = resolveBatch(photos, (_, __) => 'GB', null, {'x'});

      expect(result.accum['GB']!.photoCount, 1);
      expect(result.photoDates, hasLength(1));
    });
  });

  group(
    'extendOpenTripRun / tripsIncludingOpenTail — parity with inferTrips '
    '(M185 T3)',
    () {
      PhotoDateRecord d(String code, DateTime t) =>
          PhotoDateRecord(countryCode: code, capturedAt: t);

      test('single-country run matches inferTrips', () {
        final dates = [
          d('JP', DateTime.utc(2023, 1, 1)),
          d('JP', DateTime.utc(2023, 1, 3)),
          d('JP', DateTime.utc(2023, 1, 5)),
        ];

        final stableTrips = <TripRecord>[];
        final openRunDates = <PhotoDateRecord>[];
        extendOpenTripRun(dates, stableTrips, openRunDates);

        expect(
          tripsIncludingOpenTail(stableTrips, openRunDates),
          inferTrips(dates),
        );
      });

      test(
        'multi-country sequence fed as one batch matches inferTrips',
        () {
          final dates = [
            d('JP', DateTime.utc(2023, 1, 1)),
            d('JP', DateTime.utc(2023, 1, 3)),
            d('US', DateTime.utc(2023, 2, 1)),
            d('US', DateTime.utc(2023, 2, 4)),
            d('FR', DateTime.utc(2023, 3, 1)),
          ];

          final stableTrips = <TripRecord>[];
          final openRunDates = <PhotoDateRecord>[];
          extendOpenTripRun(dates, stableTrips, openRunDates);

          expect(
            tripsIncludingOpenTail(stableTrips, openRunDates),
            inferTrips(dates),
          );
        },
      );

      test(
        'differential parity: incremental per-batch extension matches a '
        'full inferTrips recompute at every step, across many batches with '
        'country revisits (JP -> US -> JP)',
        () {
          final allDates = [
            d('JP', DateTime.utc(2023, 1, 1)),
            d('JP', DateTime.utc(2023, 1, 2)),
            d('JP', DateTime.utc(2023, 1, 3)),
            d('US', DateTime.utc(2023, 2, 1)),
            d('US', DateTime.utc(2023, 2, 2)),
            d('FR', DateTime.utc(2023, 3, 1)),
            d('FR', DateTime.utc(2023, 3, 5)),
            d('FR', DateTime.utc(2023, 3, 9)),
            d('JP', DateTime.utc(2023, 4, 1)), // revisit — separate trip
            d('DE', DateTime.utc(2023, 5, 1)),
          ];

          // Split into small, unevenly-sized "batches" the way real scan
          // batches would arrive — some straddle a country boundary, some
          // don't, some are single records.
          final batches = <List<PhotoDateRecord>>[
            allDates.sublist(0, 2), // JP, JP
            allDates.sublist(2, 4), // JP, US  (boundary mid-batch)
            allDates.sublist(4, 5), // US
            allDates.sublist(5, 8), // FR, FR, FR
            allDates.sublist(8, 9), // JP (revisit)
            allDates.sublist(9, 10), // DE
          ];

          final stableTrips = <TripRecord>[];
          final openRunDates = <PhotoDateRecord>[];
          final seenSoFar = <PhotoDateRecord>[];

          for (final batch in batches) {
            extendOpenTripRun(batch, stableTrips, openRunDates);
            seenSoFar.addAll(batch);

            final incremental = tripsIncludingOpenTail(
              stableTrips,
              openRunDates,
            );
            final fullRecompute = inferTrips(seenSoFar);

            expect(
              incremental,
              fullRecompute,
              reason:
                  'mismatch after batch ending at ${batch.last.capturedAt}',
            );
          }

          // Final state also matches a full recompute over everything.
          expect(
            tripsIncludingOpenTail(stableTrips, openRunDates),
            inferTrips(allDates),
          );
          // Sanity: JP appears twice as separate trips (not merged with the
          // revisit), matching inferTrips' documented country-alternation
          // behaviour.
          final jpTrips = inferTrips(allDates).where(
            (t) => t.countryCode == 'JP',
          );
          expect(jpTrips.length, 2);
        },
      );

      test(
        'randomised differential parity across many batch splits (fixed seed)',
        () {
          final rand = Random(42);
          const codes = ['JP', 'US', 'FR', 'DE', 'AU'];
          var t = DateTime.utc(2023, 1, 1);
          final allDates = <PhotoDateRecord>[];
          String? lastCode;
          for (var i = 0; i < 60; i++) {
            // Bias toward staying in the same country so runs of >1 happen,
            // like real travel data, while still alternating sometimes.
            final code =
                (lastCode != null && rand.nextDouble() < 0.6)
                    ? lastCode
                    : codes[rand.nextInt(codes.length)];
            lastCode = code;
            t = t.add(Duration(hours: 1 + rand.nextInt(48)));
            allDates.add(d(code, t));
          }

          // Random batch boundaries.
          final batches = <List<PhotoDateRecord>>[];
          var i = 0;
          while (i < allDates.length) {
            final size = 1 + rand.nextInt(5);
            final end = (i + size).clamp(0, allDates.length);
            batches.add(allDates.sublist(i, end));
            i = end;
          }

          final stableTrips = <TripRecord>[];
          final openRunDates = <PhotoDateRecord>[];
          final seenSoFar = <PhotoDateRecord>[];
          for (final batch in batches) {
            extendOpenTripRun(batch, stableTrips, openRunDates);
            seenSoFar.addAll(batch);
            expect(
              tripsIncludingOpenTail(stableTrips, openRunDates),
              inferTrips(seenSoFar),
            );
          }
        },
      );

      test('empty input produces empty trips', () {
        final stableTrips = <TripRecord>[];
        final openRunDates = <PhotoDateRecord>[];
        expect(tripsIncludingOpenTail(stableTrips, openRunDates), isEmpty);
      });
    },
  );

  group('T4 — benchmark: incremental vs. full-history recompute per batch', () {
    test(
      'incremental extension is substantially faster than the old '
      'per-batch full-history inferTrips recompute on a large synthetic '
      'library (target: >=30% reduction on the resolve+infer portion, '
      'per the milestone Definition of Done)',
      () {
        // 25k synthetic photo dates across ~500 country-alternating runs —
        // representative of a large real library (many short stays).
        final rand = Random(7);
        const codes = [
          'JP', 'US', 'FR', 'DE', 'AU', 'GB', 'IT', 'ES', 'CA', 'BR',
        ];
        var t = DateTime.utc(2010, 1, 1);
        final allDates = <PhotoDateRecord>[];
        String? lastCode;
        for (var i = 0; i < 25000; i++) {
          final code =
              (lastCode != null && rand.nextDouble() < 0.9)
                  ? lastCode
                  : codes[rand.nextInt(codes.length)];
          lastCode = code;
          t = t.add(Duration(minutes: 1 + rand.nextInt(120)));
          allDates.add(
            PhotoDateRecord(countryCode: code, capturedAt: t),
          );
        }

        // Batches of ~100 photos, matching a typical native scan batch size.
        const batchSize = 100;
        final batches = <List<PhotoDateRecord>>[];
        for (var i = 0; i < allDates.length; i += batchSize) {
          batches.add(
            allDates.sublist(i, (i + batchSize).clamp(0, allDates.length)),
          );
        }

        // OLD behaviour: full inferTrips(allPhotoDates) recompute every
        // batch (O(n) work per batch, O(n²) across the scan).
        final oldSw = Stopwatch()..start();
        final seenSoFar = <PhotoDateRecord>[];
        for (final batch in batches) {
          seenSoFar.addAll(batch);
          inferTrips(seenSoFar);
        }
        oldSw.stop();

        // NEW behaviour: incremental extension (O(batch size) per batch).
        final newSw = Stopwatch()..start();
        final stableTrips = <TripRecord>[];
        final openRunDates = <PhotoDateRecord>[];
        for (final batch in batches) {
          extendOpenTripRun(batch, stableTrips, openRunDates);
          tripsIncludingOpenTail(stableTrips, openRunDates);
        }
        newSw.stop();

        // Both must agree on the final result — speed without correctness
        // isn't the win this milestone asks for.
        expect(
          tripsIncludingOpenTail(stableTrips, openRunDates),
          inferTrips(allDates),
        );

        // ignore: avoid_print — deliberate benchmark output for CI logs.
        print(
          '[M185 benchmark] old=${oldSw.elapsedMicroseconds}us '
          'new=${newSw.elapsedMicroseconds}us '
          'speedup=${(oldSw.elapsedMicroseconds / newSw.elapsedMicroseconds).toStringAsFixed(1)}x',
        );

        expect(
          newSw.elapsedMicroseconds,
          lessThan((oldSw.elapsedMicroseconds * 0.7).round()),
          reason:
              'incremental trip extension should be at least 30% faster '
              'than a full-history recompute per batch on a 25k-photo '
              'library',
        );
      },
    );
  });
}
