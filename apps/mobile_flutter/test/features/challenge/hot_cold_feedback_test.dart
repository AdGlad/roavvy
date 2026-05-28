import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/challenge/hot_cold_feedback.dart';

void main() {
  group('distanceKm', () {
    test('same point returns 0', () {
      expect(distanceKm(51.5, -0.1, 51.5, -0.1), closeTo(0, 0.001));
    });

    test('London to Paris ~341 km', () {
      expect(distanceKm(51.5074, -0.1278, 48.8566, 2.3522), closeTo(341, 10));
    });

    test('London to Sydney ~16993 km', () {
      expect(distanceKm(51.5, -0.1, -33.9, 151.2), closeTo(16993, 100));
    });
  });

  group('bearingDeg', () {
    test('due north returns 0', () {
      expect(bearingDeg(0, 0, 10, 0), closeTo(0, 1));
    });

    test('due east returns 90', () {
      expect(bearingDeg(0, 0, 0, 10), closeTo(90, 1));
    });

    test('due south returns 180', () {
      expect(bearingDeg(10, 0, 0, 0), closeTo(180, 1));
    });

    test('due west returns 270', () {
      expect(bearingDeg(0, 10, 0, 0), closeTo(270, 1));
    });
  });

  group('cardinalDirection', () {
    test('0 → north', () => expect(cardinalDirection(0), 'north'));
    test('45 → north-east', () => expect(cardinalDirection(45), 'north-east'));
    test('90 → east', () => expect(cardinalDirection(90), 'east'));
    test('135 → south-east', () => expect(cardinalDirection(135), 'south-east'));
    test('180 → south', () => expect(cardinalDirection(180), 'south'));
    test('225 → south-west', () => expect(cardinalDirection(225), 'south-west'));
    test('270 → west', () => expect(cardinalDirection(270), 'west'));
    test('315 → north-west', () => expect(cardinalDirection(315), 'north-west'));
    test('359 → north', () => expect(cardinalDirection(359), 'north'));
  });

  group('hotColdRating', () {
    test('<= 250 km → On fire', () {
      expect(hotColdRating(250).label, 'On fire');
      expect(hotColdRating(100).label, 'On fire');
    });

    test('251–1000 km → Hot', () {
      expect(hotColdRating(251).label, 'Hot');
      expect(hotColdRating(1000).label, 'Hot');
    });

    test('1001–3000 km → Warm', () {
      expect(hotColdRating(1001).label, 'Warm');
      expect(hotColdRating(3000).label, 'Warm');
    });

    test('3001–7000 km → Cold', () {
      expect(hotColdRating(3001).label, 'Cold');
      expect(hotColdRating(7000).label, 'Cold');
    });

    test('> 7000 km → Freezing', () {
      expect(hotColdRating(7001).label, 'Freezing');
      expect(hotColdRating(20000).label, 'Freezing');
    });
  });
}
