import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/globe_overlay.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../challenge/daily_challenge_service.dart';
import '../globe_replay/globe_replay_widget.dart';
import '../memory/app_open_tracker.dart';
import '../journal/journal_screen.dart';
import '../journal/trip_detail_screen.dart';
import '../map/country_detail_sheet.dart';
import '../map/map_screen.dart';
import '../merch/merch_cart_screen.dart';
import '../merch/merch_shop_screen.dart';
import '../scan/scan_screen.dart';
import '../stats/stats_screen.dart';

/// Bottom navigation shell with four tabs: Map · Journal · Stats · Shop.
///
/// Tab index contract (ADR-052):
///   0 — Map
///   1 — Journal
///   2 — Stats
///   3 — Shop (Cart + Orders)
///
/// Scan is no longer a nav tab. It is accessible via the Scan button on the
/// Map screen (top-right floating button) and from Journal/Map empty states.
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
  const MainShell({super.key, this.initialTab = 0, this.openScanOnLoad = false});

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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _lastKnownDate = _todayLocal();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onAppResume,
    );
    _scheduleMidnightRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openScanOnLoad) _goToScan(autoStart: true, forceFullScan: true);
      _handleLaunchNotification();
      // Schedule the full anniversary batch on every app open so notifications
      // keep firing even if the app is never opened again (M118).
      ref
          .read(memoryPulseServiceProvider)
          .scheduleAnniversaryNotifications(DateTime.now());
      // Pre-generate today's daily challenge so the document exists in
      // Firestore before the user opens the screen (avoids cold-start spinner).
      const DailyChallengeService().prefetch();
    });
    NotificationService.instance.pendingTabIndex.addListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.addListener(_onPendingMemoryTripId);
    NotificationService.instance.pendingMemoryCountryCode.addListener(_onPendingMemoryCountryCode);
    AppOpenTracker.recordNow();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _lifecycleListener.dispose();
    NotificationService.instance.pendingTabIndex.removeListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.removeListener(_onPendingMemoryTripId);
    NotificationService.instance.pendingMemoryCountryCode.removeListener(_onPendingMemoryCountryCode);
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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
      );
    }
  }

  /// Navigates to the country detail screen for [isoCode]. Switches to the
  /// Map tab first so the sheet sits above the correct context.
  void _navigateToCountry(String isoCode) {
    setState(() => _selectedIndex = 0); // switch to Map
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryDetailSheet(isoCode: isoCode),
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
    if (autoStart) {
      setState(() => _selectedIndex = 0); // ensure Map tab is visible
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) => ScanScreen(
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
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              MapScreen(
                onNavigateToScan: () =>
                    _goToScan(autoStart: true, forceFullScan: true),
                onNavigateToScanFull: () =>
                    _goToScan(autoStart: true, forceFullScan: true),
                onNavigateToScanPartial: () =>
                    _goToScan(autoStart: true, forceFullScan: false),
              ),
              JournalScreen(
                onNavigateToScan: () =>
                    _goToScan(autoStart: true, forceFullScan: true),
              ),
              const StatsScreen(),
              const MerchShopScreen(),
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
                // For replay mode, use MainShell's own ref so hide() is always
                // reachable regardless of whether the entry sheet is disposed.
                onScanComplete: overlay.isReplayMode
                    ? () => ref.read(globeOverlayProvider.notifier).hide()
                    : overlay.onScanComplete,
                // Always call hide() on cancel so the overlay is never stuck.
                // For scan mode, also invoke onScanComplete to clean up the
                // scan controller; for replay mode hide() is already enough.
                onClose: () {
                  if (overlay.isScanMode) overlay.onScanComplete?.call();
                  ref.read(globeOverlayProvider.notifier).hide();
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0D2137),
        indicatorColor: const Color(0xFF1B3A5C),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Journal',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: _CartBadgeIcon(
              icon: Icons.storefront_outlined,
              cartCount: ref.watch(merchCartCountProvider),
            ),
            selectedIcon: _CartBadgeIcon(
              icon: Icons.storefront,
              cartCount: ref.watch(merchCartCountProvider),
            ),
            label: 'Shop',
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
    return Badge(
      isLabelVisible: true,
      child: Icon(icon),
    );
  }
}
