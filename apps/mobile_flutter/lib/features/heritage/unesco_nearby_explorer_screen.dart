import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'unesco_nearby_notifier.dart';
import 'unesco_nearby_site_card.dart';
import 'unesco_nearby_site_sheet.dart';

/// UNESCO Nearby Explorer — shows UNESCO World Heritage Sites within a
/// user-configurable radius of the device's current location.
///
/// Location permission is requested on first build via [UnescoNearbyNotifier].
/// The radius slider (5–500 km) uses a 300 ms debounce to avoid redundant
/// refiltering while the user is dragging.
class UnescoNearbyExplorerScreen extends ConsumerStatefulWidget {
  const UnescoNearbyExplorerScreen({super.key});

  @override
  ConsumerState<UnescoNearbyExplorerScreen> createState() =>
      _UnescoNearbyExplorerScreenState();
}

class _UnescoNearbyExplorerScreenState
    extends ConsumerState<UnescoNearbyExplorerScreen> {
  /// Slider value shown in the UI (before debounce fires).
  double _sliderValue = UnescoNearbyState.defaultRadiusKm;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Sync slider with whatever the notifier's current radius is once loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(unescoNearbyProvider).valueOrNull;
      if (state != null && mounted) {
        setState(() => _sliderValue = state.radiusKm);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    setState(() => _sliderValue = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(unescoNearbyProvider.notifier).setRadius(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(unescoNearbyProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UNESCO Nearby'),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(onRetry: _retry),
        data: (state) {
          if (state.permissionDenied) {
            return const _PermissionDeniedBody();
          }
          if (state.locationError) {
            return _ErrorBody(onRetry: _retry);
          }
          return Column(
            children: [
              // ── Radius slider ──────────────────────────────────────────
              _RadiusSlider(
                value: _sliderValue,
                onChanged: _onSliderChanged,
                siteCount: state.sites.length,
              ),
              Divider(
                  height: 1,
                  color: cs.onSurface.withValues(alpha: 0.08)),
              // ── Site list ──────────────────────────────────────────────
              Expanded(
                child: state.sites.isEmpty
                    ? _EmptyBody(radiusKm: state.radiusKm)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: state.sites.length,
                        itemBuilder: (context, i) {
                          final result = state.sites[i];
                          return UnescoNearbySiteCard(
                            result: result,
                            onTap: () => showUnescoNearbySiteSheet(
                              context,
                              result,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _retry() {
    ref.read(unescoNearbyProvider.notifier).retry();
  }
}

// ── Radius slider ─────────────────────────────────────────────────────────────

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({
    required this.value,
    required this.onChanged,
    required this.siteCount,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final int siteCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radiusLabel = value < 10
        ? '${value.round()} km'
        : value < 100
            ? '${value.round()} km'
            : '${value.round()} km';
    final countLabel =
        siteCount == 1 ? '1 site' : '$siteCount sites';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Within $radiusLabel',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                countLabel,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: value,
              min: 5,
              max: 500,
              divisions: 99,
              label: radiusLabel,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.radiusKm});

  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏛', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No UNESCO sites within ${radiusKm.round()} km',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try increasing the radius using the slider above.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission denied ─────────────────────────────────────────────────────────

class _PermissionDeniedBody extends StatelessWidget {
  const _PermissionDeniedBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Location Access Required',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enable location permission in Settings to discover '
              'UNESCO World Heritage Sites near you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location / load error ─────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.signal_wifi_statusbar_connected_no_internet_4_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Could Not Determine Location',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check that location services are enabled and try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
