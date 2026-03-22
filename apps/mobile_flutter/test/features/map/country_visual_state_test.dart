import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/map/country_visual_state.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

EffectiveVisitedCountry _visit(
  String code, {
  DateTime? firstSeen,
  DateTime? lastSeen,
}) =>
    EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
    );

ProviderContainer _container({
  List<EffectiveVisitedCountry> visits = const [],
}) {
  return ProviderContainer(
    overrides: [
      effectiveVisitsProvider.overrideWith((ref) async => visits),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('countryVisualStateProvider', () {
    test('unvisited when code not in effective visits', () async {
      final container = _container(visits: []);
      addTearDown(container.dispose);

      await container.read(effectiveVisitsProvider.future);
      expect(
        container.read(countryVisualStateProvider('GB')),
        CountryVisualState.unvisited,
      );
    });

    test('visited when code in effective visits (multi-day range)', () async {
      final first = DateTime(2023, 1, 1);
      final last = DateTime(2023, 6, 15);
      final container = _container(visits: [_visit('GB', firstSeen: first, lastSeen: last)]);
      addTearDown(container.dispose);

      await container.read(effectiveVisitsProvider.future);
      expect(
        container.read(countryVisualStateProvider('GB')),
        CountryVisualState.visited,
      );
    });

    test('reviewed when code in effective visits and firstSeen == lastSeen (same day)', () async {
      final day = DateTime(2023, 5, 20);
      final container = _container(visits: [_visit('FR', firstSeen: day, lastSeen: day)]);
      addTearDown(container.dispose);

      await container.read(effectiveVisitsProvider.future);
      expect(
        container.read(countryVisualStateProvider('FR')),
        CountryVisualState.reviewed,
      );
    });

    test('newlyDiscovered overrides visited when code in recentDiscoveriesProvider', () async {
      final first = DateTime(2020);
      final last = DateTime(2023);
      final container = _container(visits: [_visit('JP', firstSeen: first, lastSeen: last)]);
      addTearDown(container.dispose);

      await container.read(effectiveVisitsProvider.future);

      // Mark JP as recently discovered.
      await container.read(recentDiscoveriesProvider.notifier).add('JP');

      expect(
        container.read(countryVisualStateProvider('JP')),
        CountryVisualState.newlyDiscovered,
      );
    });

    test('newlyDiscovered overrides reviewed when code in recentDiscoveriesProvider', () async {
      final day = DateTime(2023, 8, 1);
      final container = _container(visits: [_visit('DE', firstSeen: day, lastSeen: day)]);
      addTearDown(container.dispose);

      await container.read(effectiveVisitsProvider.future);
      await container.read(recentDiscoveriesProvider.notifier).add('DE');

      expect(
        container.read(countryVisualStateProvider('DE')),
        CountryVisualState.newlyDiscovered,
      );
    });

    test('visited when firstSeen is null (manually added country)', () async {
      final container = _container(visits: [
        const EffectiveVisitedCountry(
          countryCode: 'AU',
          hasPhotoEvidence: false,
        ),
      ]);
      addTearDown(container.dispose);

      await container.read(effectiveVisitsProvider.future);
      expect(
        container.read(countryVisualStateProvider('AU')),
        CountryVisualState.visited,
      );
    });
  });

  group('RecentDiscoveriesNotifier', () {
    test('starts empty', () {
      final container = _container();
      addTearDown(container.dispose);
      expect(container.read(recentDiscoveriesProvider), isEmpty);
    });

    test('add() adds a code and persists to SharedPreferences', () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(recentDiscoveriesProvider.notifier).add('GB');

      expect(container.read(recentDiscoveriesProvider), contains('GB'));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('recent_discoveries_v1');
      expect(raw, isNotNull);
      final list = jsonDecode(raw!) as List;
      expect(list.any((e) => e['isoCode'] == 'GB'), isTrue);
    });

    test('addAll() adds multiple codes', () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(recentDiscoveriesProvider.notifier).addAll(['US', 'CA', 'MX']);

      final state = container.read(recentDiscoveriesProvider);
      expect(state, containsAll(['US', 'CA', 'MX']));
    });

    test('loads persisted codes from SharedPreferences on init', () async {
      // Pre-populate SharedPreferences with a recent entry.
      final recentTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues({
        'recent_discoveries_v1': jsonEncode([
          {'isoCode': 'IT', 'discoveredAt': recentTime.toIso8601String()},
        ]),
      });

      final container = _container();
      addTearDown(container.dispose);

      await container.read(recentDiscoveriesProvider.notifier).ready;

      expect(container.read(recentDiscoveriesProvider), contains('IT'));
    });

    test('filters out entries older than 24 h on load', () async {
      final oldTime = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      SharedPreferences.setMockInitialValues({
        'recent_discoveries_v1': jsonEncode([
          {'isoCode': 'ES', 'discoveredAt': oldTime.toIso8601String()},
        ]),
      });

      final container = _container();
      addTearDown(container.dispose);

      await container.read(recentDiscoveriesProvider.notifier).ready;

      expect(container.read(recentDiscoveriesProvider), isNot(contains('ES')));
    });

    test('clear() empties state and removes SharedPreferences key', () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(recentDiscoveriesProvider.notifier).add('NL');
      expect(container.read(recentDiscoveriesProvider), contains('NL'));

      await container.read(recentDiscoveriesProvider.notifier).clear();

      expect(container.read(recentDiscoveriesProvider), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('recent_discoveries_v1'), isNull);
    });
  });
}
