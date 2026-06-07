import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';

/// Full-screen flag mosaic (M148).
///
/// Shows all countries in a 7-column grid. Visited flags appear in full colour;
/// unvisited flags are greyscale + dimmed. Continent filter chips narrow the grid.
/// Tapping a visited flag opens a bottom sheet with visit date and photo count.
class FlagMosaicScreen extends ConsumerStatefulWidget {
  const FlagMosaicScreen({super.key});

  @override
  ConsumerState<FlagMosaicScreen> createState() => _FlagMosaicScreenState();
}

class _FlagMosaicScreenState extends ConsumerState<FlagMosaicScreen> {
  String? _continentFilter; // null = All

  static const _continents = [
    'Africa',
    'Asia',
    'Europe',
    'North America',
    'Oceania',
    'South America',
  ];

  static const _continentShort = {
    'North America': 'N. America',
    'South America': 'S. America',
  };

  static const List<double> _greyscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  static String _flagEmoji(String iso) {
    if (iso.length != 2) return '🏳️';
    const base = 0x1F1E6;
    return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
        String.fromCharCode(base + iso.codeUnitAt(1) - 65);
  }

  /// Returns all country codes from [kCountryNames], sorted by display name,
  /// optionally filtered to a single continent.
  List<String> _buildCountryCodes() {
    final all = kCountryNames.keys.toList()
      ..sort((a, b) => (kCountryNames[a] ?? a).compareTo(kCountryNames[b] ?? b));
    if (_continentFilter == null) return all;
    return all
        .where((c) => kCountryContinent[c] == _continentFilter)
        .toList();
  }

  void _showDetail(
    BuildContext context,
    String code,
    EffectiveVisitedCountry visit,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VisitDetailSheet(visit: visit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final visits = visitsAsync.valueOrNull ?? const [];
    final visitedMap = {for (final v in visits) v.countryCode: v};
    final visitedCodes = visitedMap.keys.toSet();

    final codes = _buildCountryCodes();
    final visibleVisited = codes.where(visitedCodes.contains).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Flag Wall  ·  $visibleVisited / ${codes.length}'),
            floating: true,
            snap: true,
          ),

          // ── Continent filter chips ──────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _ContinentChip(
                    label: 'All',
                    selected: _continentFilter == null,
                    onTap: () => setState(() => _continentFilter = null),
                  ),
                  for (final c in _continents) ...[
                    const SizedBox(width: 6),
                    _ContinentChip(
                      label: _continentShort[c] ?? c,
                      selected: _continentFilter == c,
                      onTap: () => setState(() => _continentFilter = c),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 6)),

          // ── Flag grid ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: codes.length,
              itemBuilder: (context, i) {
                final code = codes[i];
                final visit = visitedMap[code];
                final isVisited = visit != null;
                return _FlagTile(
                  emoji: _flagEmoji(code),
                  isVisited: isVisited,
                  onTap: isVisited
                      ? () => _showDetail(context, code, visit)
                      : null,
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Legend ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🌍', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'Visited',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
                    child: const Opacity(
                      opacity: 0.4,
                      child: Text('🌍', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Not yet visited',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flag tile ─────────────────────────────────────────────────────────────────

class _FlagTile extends StatelessWidget {
  const _FlagTile({
    required this.emoji,
    required this.isVisited,
    required this.onTap,
  });

  final String emoji;
  final bool isVisited;
  final VoidCallback? onTap;

  static const List<double> _greyscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    Widget flag = Center(
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );

    if (!isVisited) {
      flag = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Opacity(opacity: 0.30, child: flag),
      );
      return flag;
    }

    return GestureDetector(
      onTap: onTap,
      child: flag,
    );
  }
}

// ── Continent chip ────────────────────────────────────────────────────────────

class _ContinentChip extends StatelessWidget {
  const _ContinentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Visit detail bottom sheet ─────────────────────────────────────────────────

class _VisitDetailSheet extends StatelessWidget {
  const _VisitDetailSheet({required this.visit});

  final EffectiveVisitedCountry visit;

  static String _flag(String iso) {
    if (iso.length != 2) return '🏳️';
    const base = 0x1F1E6;
    return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
        String.fromCharCode(base + iso.codeUnitAt(1) - 65);
  }

  static String _fmtDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = kCountryNames[visit.countryCode] ?? visit.countryCode;
    final continent = kCountryContinent[visit.countryCode];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Flag + name
          Row(
            children: [
              Text(
                _flag(visit.countryCode),
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (continent != null)
                      Text(
                        continent,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Visit stats
          _StatRow(
            icon: Icons.calendar_today_outlined,
            label: 'First visited',
            value: visit.firstSeen != null
                ? _fmtDate(visit.firstSeen!)
                : 'Manually added',
          ),
          if (visit.lastSeen != null &&
              visit.lastSeen != visit.firstSeen) ...[
            const SizedBox(height: 10),
            _StatRow(
              icon: Icons.update_outlined,
              label: 'Last visited',
              value: _fmtDate(visit.lastSeen!),
            ),
          ],
          if (visit.photoCount > 0) ...[
            const SizedBox(height: 10),
            _StatRow(
              icon: Icons.photo_library_outlined,
              label: 'Photos',
              value: '${visit.photoCount} geotagged',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
