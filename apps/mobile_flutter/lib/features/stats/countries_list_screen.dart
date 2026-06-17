import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/continent_emoji.dart';
import '../../core/country_names.dart';
import '../map/country_profile_screen.dart';

enum _SortOrder { alphabetical, firstVisited, lastVisited, mostPhotos }

const _kSortLabels = {
  _SortOrder.alphabetical: 'A–Z',
  _SortOrder.firstVisited: 'First visited',
  _SortOrder.lastVisited: 'Last visited',
  _SortOrder.mostPhotos: 'Most photos',
};

const _kContinentColors = {
  'Africa': Color(0xFFFF8C42),
  'Asia': Color(0xFFE74C3C),
  'Europe': Color(0xFF3498DB),
  'North America': Color(0xFF27AE60),
  'South America': Color(0xFF8E44AD),
  'Oceania': Color(0xFF16A085),
  'Antarctica': Color(0xFF95A5A6),
};

/// Full-screen list of all visited countries with continent grouping and sort.
class CountriesListScreen extends StatefulWidget {
  const CountriesListScreen({super.key, required this.visits});

  final List<EffectiveVisitedCountry> visits;

  @override
  State<CountriesListScreen> createState() => _CountriesListScreenState();
}

class _CountriesListScreenState extends State<CountriesListScreen> {
  _SortOrder _sortOrder = _SortOrder.alphabetical;

  @override
  Widget build(BuildContext context) {
    final count = widget.visits.length;
    final title = '$count ${count == 1 ? 'country' : 'countries'} visited';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          _SortBar(
            selected: _sortOrder,
            onSelected: (s) => setState(() => _sortOrder = s),
          ),
          Expanded(
            child: _sortOrder == _SortOrder.alphabetical
                ? _ContinentGroupedList(visits: widget.visits)
                : _FlatSortedList(visits: widget.visits, sortOrder: _sortOrder),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort bar
// ---------------------------------------------------------------------------

class _SortBar extends StatelessWidget {
  const _SortBar({required this.selected, required this.onSelected});

  final _SortOrder selected;
  final ValueChanged<_SortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _SortOrder.values.map((order) {
          final isSelected = order == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_kSortLabels[order]!),
              selected: isSelected,
              onSelected: (_) => onSelected(order),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continent-grouped view (alphabetical)
// ---------------------------------------------------------------------------

class _ContinentGroupedList extends StatelessWidget {
  const _ContinentGroupedList({required this.visits});

  final List<EffectiveVisitedCountry> visits;

  @override
  Widget build(BuildContext context) {
    // Group by continent, sorted alphabetically within each continent.
    final grouped = <String, List<EffectiveVisitedCountry>>{};
    for (final v in visits) {
      final continent = kCountryContinent[v.countryCode] ?? 'Other';
      grouped.putIfAbsent(continent, () => []).add(v);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final na = kCountryNames[a.countryCode] ?? a.countryCode;
        final nb = kCountryNames[b.countryCode] ?? b.countryCode;
        return na.compareTo(nb);
      });
    }
    final continents = grouped.keys.toList()..sort();

    final slivers = <Widget>[];
    for (final continent in continents) {
      final items = grouped[continent]!;
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _ContinentHeaderDelegate(
            continent: continent,
            count: items.length,
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _CountryTile(visit: items[i]),
            childCount: items.length,
          ),
        ),
      );
    }

    return CustomScrollView(slivers: slivers);
  }
}

class _ContinentHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ContinentHeaderDelegate({required this.continent, required this.count});

  final String continent;
  final int count;

  static const double _height = 40;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final color =
        _kContinentColors[continent] ?? const Color(0xFF95A5A6);
    final emoji = kContinentEmoji[continent] ?? '';

    return Container(
      height: _height,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Container(width: 4, height: _height, color: color),
          const SizedBox(width: 12),
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              continent,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ContinentHeaderDelegate old) =>
      old.continent != continent || old.count != count;
}

// ---------------------------------------------------------------------------
// Flat sorted view
// ---------------------------------------------------------------------------

class _FlatSortedList extends StatelessWidget {
  const _FlatSortedList({required this.visits, required this.sortOrder});

  final List<EffectiveVisitedCountry> visits;
  final _SortOrder sortOrder;

  @override
  Widget build(BuildContext context) {
    final sorted = [...visits];
    switch (sortOrder) {
      case _SortOrder.firstVisited:
        sorted.sort((a, b) {
          if (a.firstSeen == null && b.firstSeen == null) return 0;
          if (a.firstSeen == null) return 1;
          if (b.firstSeen == null) return -1;
          return a.firstSeen!.compareTo(b.firstSeen!);
        });
      case _SortOrder.lastVisited:
        sorted.sort((a, b) {
          if (a.lastSeen == null && b.lastSeen == null) return 0;
          if (a.lastSeen == null) return 1;
          if (b.lastSeen == null) return -1;
          return b.lastSeen!.compareTo(a.lastSeen!);
        });
      case _SortOrder.mostPhotos:
        sorted.sort((a, b) => b.photoCount.compareTo(a.photoCount));
      case _SortOrder.alphabetical:
        break;
    }

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, i) => _CountryTile(visit: sorted[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Country tile
// ---------------------------------------------------------------------------

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.visit});

  final EffectiveVisitedCountry visit;

  @override
  Widget build(BuildContext context) {
    final name = kCountryNames[visit.countryCode] ?? visit.countryCode;
    final flag = _flagEmoji(visit.countryCode);
    final subtitle = _buildSubtitle();
    final photoCount = visit.photoCount;

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 32)),
      title: Text(name),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: visit.hasPhotoEvidence && photoCount > 0
          ? _PhotoBadge(count: photoCount)
          : visit.hasPhotoEvidence
              ? null
              : const Icon(Icons.add_circle_outline, size: 18, color: Colors.grey),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CountryProfileScreen(
            isoCode: visit.countryCode,
            visit: visit,
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    if (!visit.hasPhotoEvidence) return 'Added manually';
    final first = visit.firstSeen;
    final last = visit.lastSeen;
    if (first == null) return visit.countryCode;
    if (last != null && last.year != first.year) {
      return '${first.year} – ${last.year}';
    }
    return 'Since ${first.year}';
  }

  static String _flagEmoji(String code) {
    if (code.length != 2) return '🏳';
    final a = 0x1F1E6 + code.codeUnitAt(0) - 0x41;
    final b = 0x1F1E6 + code.codeUnitAt(1) - 0x41;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.photo_camera_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
