import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../memory/app_open_tracker.dart';
import '../journal/journal_screen.dart';
import '../journal/trip_detail_screen.dart';
import '../map/map_screen.dart';
import '../scan/scan_screen.dart';
import '../stats/stats_screen.dart';

/// Bottom navigation shell with four tabs: Map · Journal · Stats · Scan.
///
/// Tab index contract (ADR-052):
///   0 — Map
///   1 — Journal
///   2 — Stats
///   3 — Scan
///
/// Uses [IndexedStack] to keep all screens alive, preserving scroll position
/// and map state on tab switch. After a scan completes, [ScanScreen] calls
/// [_goToMap] to return to Map (index 0).
///
/// [initialTab] sets the selected tab on first render (default 0 = Map).
/// Used by [_OnboardingGate] to open directly on the Scan tab when the user
/// taps "Scan my photos" in onboarding.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

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
      _handleLaunchNotification();
    });
    NotificationService.instance.pendingTabIndex.addListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.addListener(_onPendingMemoryTripId);
    AppOpenTracker.recordNow();
  }

  @override
  void dispose() {
    NotificationService.instance.pendingTabIndex.removeListener(_onPendingTab);
    NotificationService.instance.pendingMemoryTripId.removeListener(_onPendingMemoryTripId);
    super.dispose();
  }

  /// Handles the cold-start case: app launched by tapping a notification.
  Future<void> _handleLaunchNotification() async {
    final tab = await NotificationService.instance.getLaunchTab();
    if (tab != null && mounted) setState(() => _selectedIndex = tab);

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

  /// Handles foreground / background notification taps for memory pulses.
  void _onPendingMemoryTripId() {
    final tripId = NotificationService.instance.pendingMemoryTripId.value;
    if (tripId != null && mounted) {
      _navigateToTrip(tripId);
      NotificationService.instance.pendingMemoryTripId.value = null;
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

  void _goToMap() => setState(() => _selectedIndex = 0);
  void _goToScan() => setState(() => _selectedIndex = 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapScreen(onNavigateToScan: _goToScan),
          JournalScreen(onNavigateToScan: _goToScan),
          const StatsScreen(),
          ScanScreen(onScanComplete: _goToMap),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}
