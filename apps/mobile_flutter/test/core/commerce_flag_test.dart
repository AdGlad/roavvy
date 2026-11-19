import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/commerce/commerce_flag.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:shared_models/shared_models.dart';

/// ADR-180: one commerce switch = build capability && remote kill switch.
void main() {
  ProviderContainer container({bool? build, bool? remote}) {
    final c = ProviderContainer(
      overrides: [
        if (build != null) commerceBuildProvider.overrideWithValue(build),
        if (remote != null) commerceRemoteSwitchProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a build without ROAVVY_COMMERCE has no commerce', () {
    expect(kCommerceBuild, isFalse);
    expect(container().read(commerceEnabledProvider), isFalse);
  });

  test('the remote switch cannot turn commerce on in a commerce-off build', () {
    expect(
      container(build: false, remote: true).read(commerceEnabledProvider),
      isFalse,
    );
  });

  test('the remote switch turns commerce off in a commerce build', () {
    expect(
      container(build: true, remote: false).read(commerceEnabledProvider),
      isFalse,
    );
  });

  test('commerce build + remote on = commerce on', () {
    expect(
      container(build: true, remote: true).read(commerceEnabledProvider),
      isTrue,
    );
  });

  test('every derived purchasing flag is off when commerce is off', () {
    // No Firebase in tests: these must short-circuit before Remote Config.
    final c = container(build: false);
    expect(c.read(purchasingEnabledProvider), isFalse);
    expect(c.read(studioV2FulfilmentEnabledProvider), isFalse);
    for (final t in CardTemplateType.values) {
      expect(c.read(purchasingEnabledForTemplateProvider(t)), isFalse,
          reason: '$t');
    }
  });
}
