import 'package:design_forge/design_forge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/host/bundle_asset_resolver.dart';

/// M1 — the mobile bundle [AssetResolver] must resolve the app's bundled assets
/// on-device (via rootBundle), with no repo-filesystem dependency. In
/// `flutter test`, rootBundle serves the assets declared in pubspec.yaml.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final resolver = createBundleAssetResolver();

  test('resolves a bundled flag (assets/flags/svg/ad.svg)', () async {
    final img = await resolver.resolveFlag('ad', width: 64, height: 64);
    expect(img.width, greaterThan(0));
    expect(img.height, greaterThan(0));
  });

  test('resolves a bundled silhouette mask (assets/silhouettes/…)', () async {
    final mask = await resolver.resolveClipMask(
      ClipShape.animalSilhouette,
      'ad_pyrenean_chamois',
      width: 64,
      height: 64,
    );
    expect(mask, isNotNull);
    expect(mask!.width, greaterThan(0));
  });

  test('a missing flag asset surfaces an error (no silent success)', () async {
    await expectLater(
      resolver.resolveFlag('zznotarealcountry', width: 64, height: 64),
      throwsA(anything),
    );
  });
}
