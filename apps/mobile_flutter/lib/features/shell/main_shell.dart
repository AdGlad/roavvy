import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/globe_overlay.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../../core/remote_config_service.dart';
import '../challenge/daily_challenge_service.dart';
import '../globe_replay/globe_replay_widget.dart';
import '../memory/app_open_tracker.dart';
// ignore: unused_import — kept for Journal tab reinstatement
import '../journal/journal_screen.dart';
import '../journal/trip_detail_screen.dart';
import '../map/country_profile_screen.dart';
import '../map/map_screen.dart';
import '../merch/merch_cart_screen.dart';
import '../merch/merch_shop_screen.dart';
import '../scan/scan_screen.dart';
import '../stats/stats_screen.dart';
import '../travel_timeline/travel_timeline_screen.dart';
import '../world_leap/presentation/screens/world_leap_lobby_screen.dart';

/// Bottom navigation shell with tabs: Map · Journey · Stats · Shop · Play.
///
/// Tab index contract (ADR-052):
///   0 — Map
///   1 — Journey (travel timeline)
///   2 — Stats
///   3 — Shop (Cart + Orders)
///   4 — Play (World Leap)
///
/// Journal tab is retained in code (JournalScreen import + commented stack entry)
/// for possible reinstatement.
///
/// Scan is no longer a nav tab. It is accessible via the Scan button on the
/// Map screen (top-right floating button) and from Map empty states.
///
/// Uses [IndexedStack] to keep all screens alive, preserving scroll position
/// and map state on tab switch. After a scan completes, [ScanScreen] calls
/// [_goToMap] to return to Map (index 0).
///
/// [initialTab] sets the selected tab on first render (default 0 = Map).
/// [openScanOnLoad] — when true, the scan modal is pushed automatically after
/// the first frame. Used by [_OnboardingGate] when the user tapped "Scan my
/// photos" during onboarding (Scan is no longer a nav tab — ADR-052).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = 0,
    this.openScanOnLoad = false,
  });

  final int initialTab;
  final bool openScanOnLoad;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

String _todayLocal() => DateFormat('yyyy-MM-dd').format(DateTime.now());

class _MainShellState extends ConsumerState<MainShell> {
  late int _selectedIndex;
  late String _lastKnownDate;
  late AppLifecycleListener _lifecycleListener;
  Timer? _midnightTimer;
  StreamSubscription<void>? _rcUpdateSub;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _lastKnownDate = _todayLocal();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResume);
    _scheduleMidnightRefresh();
    _rcUpdateSub = RemoteConfigService.onUpdate.stream.listen((_) {
      if (mounted) {
        ref.invalidate(purchasingEnabledProvider);
        ref.invalidate(purchasingEnabledForTemplateProvider);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openScanOnLoad)
        _goToScan(autoStart: true, forceFullScan: true);
      _handleLaunchNotification();
      // Schedule the full anniversary batch on every app open so notifications
      // keep firing even if the app is never opened again (M118).
      ref
          .read(memoryPulseServiceProvider)
          .scheduleAnniversaryNotifications(DateTime.now());
      // Pre-generate today's daily challenge so the document exists in
      // Firestore before the user opens the screen (avoids cold-start spinner).
      try {
        const DailyChallengeService().prefetch();
      } catch (_) {
        // Swallow — prefetch is a background optimisation and may fail if
        // Firebase is not yet initialised (e.g. in widget tests).
      }
    });
    NotificationService.instance.pendingTabIndex.addListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.addListener(
      _onPendingMemoryTripId,
    );
    NotificationService.instance.pendingMemoryCountryCode.addListener(
      _onPendingMemoryCountryCode,
    );
    AppOpenTracker.recordNow();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _rcUpdateSub?.cancel();
    _lifecycleListener.dispose();
    NotificationService.instance.pendingTabIndex.removeListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.removeListener(
      _onPendingMemoryTripId,
    );
    NotificationService.instance.pendingMemoryCountryCode.removeListener(
      _onPendingMemoryCountryCode,
    );
    super.dispose();
  }

  /// Schedules a one-shot timer that fires just after the next UTC midnight,
  /// invalidating the daily challenge providers so the new day's challenge
  /// loads without requiring the user to restart or background the app.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // Add a 2-second buffer so Firestore has a moment to write the new doc.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 2);
    _midnightTimer = Timer(delay, _onDayRollover);
  }

  /// Called when the app returns to the foreground. If the UTC date has rolled
  /// over since the last foreground session, invalidate providers and
  /// reschedule the midnight timer for the new day.
  void _onAppResume() {
    final today = _todayLocal();
    if (today != _lastKnownDate) {
      _onDayRollover();
      // Pre-generate the new day's challenge document.
      const DailyChallengeService().prefetch();
    }
    // Always reschedule — the timer may have been paused while backgrounded.
    _scheduleMidnightRefresh();
    // Re-fetch Remote Config so the purchase killswitch propagates within ~60 s.
    unawaited(RemoteConfigService.refresh().then((_) {
      if (mounted) {
        ref.invalidate(purchasingEnabledProvider);
        ref.invalidate(purchasingEnabledForTemplateProvider);
      }
    }));
  }

  /// Invalidates daily challenge providers so they re-fetch with today's date.
  void _onDayRollover() {
    if (!mounted) return;
    _lastKnownDate = _todayLocal();
    // Both providers are autoDispose — invalidating forces them to re-fetch
    // with the new local date if the challenge screen happens to be open.
    ref.invalidate(dailyChallengeProvider);
  }

  /// Handles the cold-start case: app launched by tapping a notification.
  Future<void> _handleLaunchNotification() async {
    final tab = await NotificationService.instance.getLaunchTab();
    if (tab != null && mounted) setState(() => _selectedIndex = tab);

    final countryCode =
        await NotificationService.instance.getLaunchMemoryCountryCode();
    if (countryCode != null && mounted) {
      _navigateToCountry(countryCode);
      return;
    }

    final tripId = await NotificationService.instance.getLaunchMemoryTripId();
    if (tripId != null && mounted) {
      _navigateToTrip(tripId);
    }
  }

  /// Handles foreground / background notification taps for tabs.
  void _onPendingTab() {
    final tab = NotificationService.instance.pendingTabIndex.value;
    if (tab != null && mounted) {
      setState(() => _selectedIndex = tab);
      NotificationService.instance.pendingTabIndex.value = null;
    }
  }

  /// Handles foreground / background notification taps for memory pulses (legacy).
  void _onPendingMemoryTripId() {
    final tripId = NotificationService.instance.pendingMemoryTripId.value;
    if (tripId != null && mounted) {
      _navigateToTrip(tripId);
      NotificationService.instance.pendingMemoryTripId.value = null;
    }
  }

  /// Handles foreground / background memory pulse taps with country code (M118).
  void _onPendingMemoryCountryCode() {
    final code = NotificationService.instance.pendingMemoryCountryCode.value;
    if (code != null && mounted) {
      _navigateToCountry(code);
      NotificationService.instance.pendingMemoryCountryCode.value = null;
    }
  }

  Future<void> _navigateToTrip(String tripId) async {
    final trip = await ref.read(tripRepositoryProvider).loadById(tripId);
    if (trip != null && mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)));
    }
  }

  /// Navigates to the country profile screen for [isoCode]. Switches to the
  /// Map tab first so the screen sits above the correct context.
  void _navigateToCountry(String isoCode) {
    setState(() => _selectedIndex = 0); // switch to Map
    final visits = ref.read(effectiveVisitsProvider).valueOrNull ?? [];
    final visit = visits.where((v) => v.countryCode == isoCode).firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryProfileScreen(isoCode: isoCode, visit: visit),
      ),
    );
  }

  void _goToMap() => setState(() => _selectedIndex = 0);

  /// Starts a scan.
  ///
  /// When [autoStart] is true (called from the MapScreen action bar), the
  /// screen switches to the Map tab first, then pushes [ScanScreen] with
  /// [autoStart:true] so it runs invisibly as a headless scan orchestrator.
  /// The animation is shown via the [GlobeReplayWidget] overlay in [build].
  ///
  /// When [autoStart] is false (called from Journal empty state / prompt gate),
  /// the legacy full-screen [ScanScreen] UI is pushed.
  void _goToScan({bool autoStart = false, bool forceFullScan = false}) {
    // ignore: avoid_print
    print('[roavvy-scan] go-to-scan autoStart=$autoStart full=$forceFullScan');
    if (autoStart) {
      setState(() => _selectedIndex = 0); // ensure Map tab is visible
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder:
              (_, __, ___) => ScanScreen(
                onScanComplete: _goToMap,
                autoStart: true,
                initialForceFullScan: forceFullScan,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScanScreen(onScanComplete: _goToMap),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay = ref.watch(globeOverlayProvider);
    final cartCount = ref.watch(merchCartCountProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final body = Stack(
      children: [
        IndexedStack(
          index: _selectedIndex,
          children: [
            MapScreen(
              onNavigateToScan:
                  () => _goToScan(autoStart: true, forceFullScan: true),
              onNavigateToScanFull:
                  () => _goToScan(autoStart: true, forceFullScan: true),
              onNavigateToScanPartial:
                  () => _goToScan(autoStart: true, forceFullScan: false),
            ),
            // Journal — kept for possible reinstatement:
            // JournalScreen(onNavigateToScan: () => _goToScan(autoStart: true, forceFullScan: true)),
            const TravelTimelineScreen(),
            const StatsScreen(),
            const MerchShopScreen(),
            const WorldLeapLobbyScreen(),
          ],
        ),
        // M134: Globe animation overlay — shown in-place so replay and scan
        // animations appear on the main-screen globe without route transitions.
        if (overlay.isActive)
          Positioned.fill(
            child: GlobeReplayWidget(
              embedded: true,
              script: overlay.replayScript,
              dataSource: overlay.scanSource,
              initialCollectedCodes: overlay.initialCollectedCodes,
              onScanComplete:
                  overlay.isReplayMode
                      ? () => ref.read(globeOverlayProvider.notifier).hide()
                      : overlay.onScanComplete,
              onClose: () {
                if (overlay.isScanMode) overlay.onScanComplete?.call();
                ref.read(globeOverlayProvider.notifier).hide();
              },
            ),
          ),
        // Cancel button — only shown during active scan, not replay.
        if (overlay.isActive && overlay.isScanMode)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: FilledButton.tonal(
              onPressed: () {
                overlay.onScanComplete?.call();
                ref.read(globeOverlayProvider.notifier).hide();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Cancel scan',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
      ],
    );

    if (isLandscape) {
      // Landscape: NavigationRail on the left, content fills the rest.
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainer,
              indicatorColor:
                  Theme.of(context).colorScheme.primaryContainer,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: Text('Map'),
                ),
                // Journal — kept for possible reinstatement:
                // const NavigationRailDestination(
                //   icon: Icon(Icons.list_alt_outlined),
                //   selectedIcon: Icon(Icons.list_alt),
                //   label: Text('Journal'),
                // ),
                const NavigationRailDestination(
                  icon: Icon(Icons.route_outlined),
                  selectedIcon: Icon(Icons.route),
                  label: Text('Journey'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.leaderboard_outlined),
                  selectedIcon: Icon(Icons.leaderboard),
                  label: Text('Stats'),
                ),
                NavigationRailDestination(
                  icon: _CartBadgeIcon(
                    icon: Icons.storefront_outlined,
                    cartCount: cartCount,
                  ),
                  selectedIcon: _CartBadgeIcon(
                    icon: Icons.storefront,
                    cartCount: cartCount,
                  ),
                  label: const Text('Shop'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.sports_esports_outlined),
                  selectedIcon: Icon(Icons.sports_esports),
                  label: Text('Play'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Portrait: NavigationBar at the bottom.
    return Scaffold(
      body: body,
      // DEV-ONLY: remove before shipping
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'dev_quokka',
        backgroundColor: const Color(0xFFf5c842),
        onPressed: () => context.go('/dev/quokka'),
        child: const Text('🐨', style: TextStyle(fontSize: 18)),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          // Journal — kept for possible reinstatement:
          // const NavigationDestination(
          //   icon: Icon(Icons.list_alt_outlined),
          //   selectedIcon: Icon(Icons.list_alt),
          //   label: 'Journal',
          // ),
          const NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Journey',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: _CartBadgeIcon(
              icon: Icons.storefront_outlined,
              cartCount: cartCount,
            ),
            selectedIcon: _CartBadgeIcon(
              icon: Icons.storefront,
              cartCount: cartCount,
            ),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Play',
          ),
        ],
      ),
    );
  }
}

// ── Cart badge icon ───────────────────────────────────────────────────────────

/// Navigation icon with a small dot badge when there are active cart items.
class _CartBadgeIcon extends StatelessWidget {
  const _CartBadgeIcon({required this.icon, required this.cartCount});

  final IconData icon;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    if (cartCount == 0) return Icon(icon);
    return Badge(isLabelVisible: true, child: Icon(icon));
  }
}
