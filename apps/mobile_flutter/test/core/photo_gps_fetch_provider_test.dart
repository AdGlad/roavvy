import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/map/photo_gps_fetch_service.dart';

class _CountingFetch implements PhotoGpsFetchService {
  int calls = 0;
  @override
  Future<void> fetchAndCache() async => calls++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// M189 QA: on a fresh install the map opens before the first scan, so the
/// GPS fetch found nothing and, with the map tab kept alive, never ran again.
void main() {
  test('photo GPS fetch re-runs when the visits change after a scan', () async {
    final fetch = _CountingFetch();
    final scans = StateProvider<int>((_) => 0);
    final container = ProviderContainer(
      overrides: [
        photoGpsFetchServiceProvider.overrideWithValue(fetch),
        effectiveVisitsProvider.overrideWith((ref) async {
          ref.watch(scans);
          return [];
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(photoGpsFetchProvider, (_, __) {});
    addTearDown(sub.close);

    await container.read(photoGpsFetchProvider.future);
    expect(fetch.calls, 1);

    // A scan finishes: visits refresh.
    container.read(scans.notifier).state++;
    await container.read(photoGpsFetchProvider.future);
    expect(fetch.calls, 2);
  });
}
