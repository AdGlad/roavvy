import 'package:flutter/material.dart';

import '../journal/journal_screen.dart';
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
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

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
