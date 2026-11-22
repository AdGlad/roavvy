import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/travel_timeline/travel_timeline_screen.dart';
import 'package:shared_models/shared_models.dart';

TripRecord _trip(String id, String countryCode, int year) => TripRecord(
  id: id,
  countryCode: countryCode,
  startedOn: DateTime.utc(year, 6),
  endedOn: DateTime.utc(year, 6, 14),
  photoCount: 3,
  isManual: false,
);

/// M189 QA: the year headers animate in with the other nodes. A header that
/// returned a bare Positioned threw "Incorrect use of ParentDataWidget" on
/// every entry frame once it was wrapped in Opacity/Transform.
void main() {
  testWidgets('timeline entry animation renders year headers cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripListProvider.overrideWith(
            (ref) async => [
              _trip('a', 'JP', 2016),
              _trip('b', 'FR', 2017),
              _trip('c', 'IT', 2017),
            ],
          ),
          unlockedAchievementIdsProvider.overrideWith((ref) async => {}),
        ],
        child: const MaterialApp(home: TravelTimelineScreen()),
      ),
    );
    // Step through the staggered entry, where nodes are mid-animation.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2017'), findsWidgets);
  });
}
