import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';
import 'unesco_nearby_service.dart';

/// State for the UNESCO Nearby Explorer feature.
class UnescoNearbyState {
  const UnescoNearbyState({
    required this.radiusKm,
    required this.sites,
    this.position,
    this.permissionDenied = false,
    this.locationError = false,
  });

  /// Default discovery radius on first open.
  static const double defaultRadiusKm = 50.0;

  final double radiusKm;
  final List<NearbySiteResult> sites;

  /// Current device position; null while loading or if permission denied.
  final Position? position;

  /// True when location permission was denied.
  final bool permissionDenied;

  /// True when location fetch failed for a non-permission reason.
  final bool locationError;

  UnescoNearbyState copyWith({
    double? radiusKm,
    List<NearbySiteResult>? sites,
    Position? position,
    bool? permissionDenied,
    bool? locationError,
  }) {
    return UnescoNearbyState(
      radiusKm: radiusKm ?? this.radiusKm,
      sites: sites ?? this.sites,
      position: position ?? this.position,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      locationError: locationError ?? this.locationError,
    );
  }
}

class UnescoNearbyNotifier extends AsyncNotifier<UnescoNearbyState> {
  static const _service = UnescoNearbyService();

  @override
  Future<UnescoNearbyState> build() async {
    return _load(UnescoNearbyState.defaultRadiusKm);
  }

  Future<UnescoNearbyState> _load(double radiusKm) async {
    // Check / request location permission.
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return UnescoNearbyState(
        radiusKm: radiusKm,
        sites: const [],
        permissionDenied: true,
      );
    }

    // Fetch position with a reasonable timeout.
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return UnescoNearbyState(
        radiusKm: radiusKm,
        sites: const [],
        locationError: true,
      );
    }

    // Load visited site IDs for badge display.
    final visitedSites = await ref.read(heritageRepositoryProvider).loadAll();
    final visitedIds = visitedSites.map((s) => s.siteId).toSet();

    // Filter and rank sites within radius.
    final sites = _service.sitesWithin(
      pos.latitude,
      pos.longitude,
      radiusKm,
      visitedIds,
    );

    return UnescoNearbyState(
      radiusKm: radiusKm,
      sites: sites,
      position: pos,
    );
  }

  /// Updates the search radius and re-filters sites without re-fetching location.
  Future<void> setRadius(double radiusKm) async {
    final current = state.valueOrNull;
    if (current == null || current.position == null) return;

    final visitedSites = await ref.read(heritageRepositoryProvider).loadAll();
    final visitedIds = visitedSites.map((s) => s.siteId).toSet();

    final pos = current.position!;
    final sites = _service.sitesWithin(
      pos.latitude,
      pos.longitude,
      radiusKm,
      visitedIds,
    );

    state = AsyncData(current.copyWith(radiusKm: radiusKm, sites: sites));
  }

  /// Retries location fetch (e.g. after user grants permission in Settings).
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(
        state.valueOrNull?.radiusKm ?? UnescoNearbyState.defaultRadiusKm,
      ),
    );
  }
}
