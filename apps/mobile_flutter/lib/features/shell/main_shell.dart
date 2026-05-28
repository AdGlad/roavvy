import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/globe_overlay.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
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

class _MainShellState extends ConsumerState<MainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openScanOnLoad) _goToScan(autoStart: true, forceFullScan: true);
      _handleLaunchNotification();
      // Schedule the full anniversary batch on every app open so notifications
      // keep firing even if the app is never opened again (M118).
      ref
          .read(memoryPulseServiceProvider)
          .scheduleAnniversaryNotifications(DateTime.now());
    });
    NotificationService.instance.pendingTabIndex.addListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.addListener(_onPendingMemoryTripId);
    NotificationService.instance.pendingMemoryCountryCode.addListener(_onPendingMemoryCountryCode);
    AppOpenTracker.recordNow();
  }

  @override
  void dispose() {
    NotificationService.instance.pendingTabIndex.removeListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.removeListener(_onPendingMemoryTripId);
    NotificationService.instance.pendingMemoryCountryCode.removeListener(_onPendingMemoryCountryCode);
    super.dispose();
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
                onScanComplete: overlay.onScanComplete,
                onClose: () {
                  overlay.onScanComplete?.call();
                  if (overlay.onScanComplete == null) {
                    ref.read(globeOverlayProvider.notifier).hide();
                  }
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
