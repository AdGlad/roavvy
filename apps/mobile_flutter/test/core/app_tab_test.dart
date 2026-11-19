import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/app_tab.dart';

void main() {
  test('payloads are names', () {
    expect(AppTab.stats.payload, 'tab:stats');
    expect(AppTab.fromPayload('tab:shop'), AppTab.shop);
    expect(AppTab.fromPayload('tab:nope'), isNull);
    expect(AppTab.fromPayload('memoryPulse:x'), isNull);
    expect(AppTab.fromPayload(null), isNull);
  });

  test('legacy index payloads map to the five-tab layout', () {
    expect(AppTab.fromPayload('tab:2'), AppTab.stats);
    expect(AppTab.fromPayload('tab:3'), AppTab.shop);
    expect(AppTab.fromPayload('tab:4'), AppTab.play);
    expect(AppTab.fromPayload('tab:9'), isNull);
  });

  test('commerce off: four tabs, no Shop', () {
    expect(AppTab.visible(commerce: false), [
      AppTab.map,
      AppTab.journey,
      AppTab.stats,
      AppTab.play,
    ]);
  });

  test('commerce on: all five tabs in order', () {
    expect(AppTab.visible(commerce: true), AppTab.values);
  });

  test('a hidden tab resolves to Map; visible tabs resolve to themselves', () {
    expect(AppTab.resolve(AppTab.shop, commerce: false), AppTab.map);
    expect(AppTab.resolve(AppTab.stats, commerce: false), AppTab.stats);
    expect(AppTab.resolve(AppTab.play, commerce: false), AppTab.play);
    expect(AppTab.resolve(AppTab.shop, commerce: true), AppTab.shop);
  });
}
