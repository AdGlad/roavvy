// T2.4 — TravelIdentityInfo unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/travel_identity.dart';
import 'package:shared_models/shared_models.dart';

Achievement _achievement({
  AchievementCategory category = AchievementCategory.countries,
  int progressTarget = 5,
  String? continentScope,
  String? regionScope,
  MerchTriggerType? merch,
}) =>
    Achievement(
      id: 'test',
      title: 'Test',
      description: '',
      category: category,
      progressTarget: progressTarget,
      continentScope: continentScope,
      regionScope: regionScope,
      merch: merch,
    );

void main() {
  group('TravelIdentityInfo.forContext — no achievement', () {
    test('empty codes, 0 trips, 0 stamps → adventurer', () {
      final info = TravelIdentityInfo.forContext(
        codes: [],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.adventurer));
    });

    test('49 countries → adventurer (below world traveller threshold)', () {
      final info = TravelIdentityInfo.forContext(
        codes: List.generate(49, (i) => 'C$i'),
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.adventurer));
    });

    test('50 countries → worldTraveller', () {
      final info = TravelIdentityInfo.forContext(
        codes: List.generate(50, (i) => 'C$i'),
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.worldTraveller));
    });

    test('9 trips → adventurer (below frequentFlyer threshold)', () {
      final info = TravelIdentityInfo.forContext(
        codes: ['GB'],
        tripCount: 9,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.adventurer));
    });

    test('10 trips → frequentFlyer', () {
      final info = TravelIdentityInfo.forContext(
        codes: ['GB'],
        tripCount: 10,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.frequentFlyer));
    });

    test('9 stamps → adventurer (below passportCollector threshold)', () {
      final info = TravelIdentityInfo.forContext(
        codes: ['GB'],
        tripCount: 0,
        stampCount: 9,
      );
      expect(info.identity, equals(TravelIdentity.adventurer));
    });

    test('10 stamps → passportCollector', () {
      final info = TravelIdentityInfo.forContext(
        codes: ['GB'],
        tripCount: 0,
        stampCount: 10,
      );
      expect(info.identity, equals(TravelIdentity.passportCollector));
    });

    test('50 countries takes priority over 10 trips (worldTraveller)', () {
      final info = TravelIdentityInfo.forContext(
        codes: List.generate(50, (i) => 'C$i'),
        tripCount: 15,
        stampCount: 20,
      );
      expect(info.identity, equals(TravelIdentity.worldTraveller));
    });
  });

  group('TravelIdentityInfo.forContext — continent achievement', () {
    test('Europe continent scope → europeExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'Europe'),
        codes: ['GB', 'FR'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.europeExplorer));
    });

    test('Asia continent scope → asiaExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'Asia'),
        codes: ['JP'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.asiaExplorer));
    });

    test('Africa continent scope → africaExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'Africa'),
        codes: ['ZA'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.africaExplorer));
    });

    test('North America continent scope → americasExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'North America'),
        codes: ['US'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.americasExplorer));
    });

    test('South America continent scope → americasExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'South America'),
        codes: ['BR'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.americasExplorer));
    });

    test('Oceania continent scope → oceaniaExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'Oceania'),
        codes: ['AU'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.oceaniaExplorer));
    });

    test('unknown continent scope → adventurer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(continentScope: 'Antarctica'),
        codes: [],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.adventurer));
    });
  });

  group('TravelIdentityInfo.forContext — region achievement', () {
    test('Mediterranean region → mediterraneanExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(regionScope: 'Mediterranean'),
        codes: ['IT', 'GR'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.mediterraneanExplorer));
    });

    test('SoutheastAsia region → islandExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(regionScope: 'SoutheastAsia'),
        codes: ['TH'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.islandExplorer));
    });

    test('unknown region → adventurer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(regionScope: 'MiddleEast'),
        codes: [],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.adventurer));
    });
  });

  group('TravelIdentityInfo.forContext — passport milestone achievement', () {
    test('trips category + passportStamp merch → passportCollector', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(
          category: AchievementCategory.trips,
          merch: MerchTriggerType.passportStamp,
        ),
        codes: ['GB'],
        tripCount: 1,
        stampCount: 5,
      );
      expect(info.identity, equals(TravelIdentity.passportCollector));
    });
  });

  group('TravelIdentityInfo.forContext — continents achievement', () {
    test('continents category + progressTarget >= 4 → globalExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(
          category: AchievementCategory.continents,
          progressTarget: 4,
        ),
        codes: ['GB', 'JP', 'ZA', 'US'],
        tripCount: 0,
        stampCount: 0,
      );
      expect(info.identity, equals(TravelIdentity.globalExplorer));
    });

    test('continents category + progressTarget < 4 → does not trigger globalExplorer', () {
      final info = TravelIdentityInfo.forContext(
        achievement: _achievement(
          category: AchievementCategory.continents,
          progressTarget: 3,
        ),
        codes: ['GB'],
        tripCount: 0,
        stampCount: 0,
      );
      // Falls through to code/trip/stamp checks → adventurer
      expect(info.identity, equals(TravelIdentity.adventurer));
    });
  });

  group('kTravelIdentityInfo', () {
    test('every TravelIdentity has a metadata entry', () {
      for (final identity in TravelIdentity.values) {
        expect(kTravelIdentityInfo.containsKey(identity), isTrue,
            reason: '${identity.name} missing from kTravelIdentityInfo');
      }
    });

    test('every entry has non-empty displayName, tagline, and emoji', () {
      for (final info in kTravelIdentityInfo.values) {
        expect(info.displayName, isNotEmpty,
            reason: '${info.identity.name} has empty displayName');
        expect(info.tagline, isNotEmpty,
            reason: '${info.identity.name} has empty tagline');
        expect(info.emoji, isNotEmpty,
            reason: '${info.identity.name} has empty emoji');
      }
    });
  });
}
