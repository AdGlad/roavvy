import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../../core/theme/roavvy_colours.dart';

// ── Colour palette ────────────────────────────────────────────────────────────

const _kOcean = Color(0xFF0D2137);
const _kUnvisited = Color(0xFF1E3A5F);
const _kUnvisitedBorder = Color(0xFF2A4F7A);
const _kContinentGlow = Color(0xFF0A7EA4); // fallback if continent not in map
const _kCountryGold = Color(0xFFD4A017);
const _kCountryBorder = Color(0xFFFFD700);

// ── Continent colours for the progress chips ──────────────────────────────────

const _continentColors = {
  'Africa': Color(0xFFFF8C42),
  'Asia': Color(0xFFE74C3C),
  'Europe': Color(0xFF3498DB),
  'North America': Color(0xFF27AE60),
  'South America': Color(0xFF8E44AD),
  'Oceania': Color(0xFF16A085),
};

const _continentIcons = {
  'Africa': Icons.local_fire_department_outlined,
  'Asia': Icons.temple_buddhist_outlined,
  'Europe': Icons.account_balance_outlined,
  'North America': Icons.forest_outlined,
  'South America': Icons.grass_outlined,
  'Oceania': Icons.water_outlined,
};

// ── Screen ────────────────────────────────────────────────────────────────────

/// World map highlighting visited continents (teal) and visited countries (gold).
///
/// Tapping the Continents stat card on the Stats screen opens this screen.
/// Rewarding design: gold countries glow against teal-lit continents on a dark
/// navy ocean.
class ContinentExplorerScreen extends ConsumerWidget {
  const ContinentExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polygons = ref.watch(polygonsProvider);
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final visits = visitsAsync.valueOrNull ?? const [];

    final visitedIsoCodes = {for (final v in visits) v.countryCode};
    final visitedContinents = {
      for (final code in visitedIsoCodes)
        if (kCountryContinent.containsKey(code)) kCountryContinent[code]!,
    };

    // Count countries per continent for the bottom panel.
    final countriesPerContinent = <String, int>{};
    for (final code in visitedIsoCodes) {
      final continent = kCountryContinent[code];
      if (continent != null) {
        countriesPerContinent[continent] =
            (countriesPerContinent[continent] ?? 0) + 1;
      }
    }

    // Total countries per continent (for progress denominator).
    final totalPerContinent = <String, int>{};
    for (final continent in kCountryContinent.values) {
      totalPerContinent[continent] =
          (totalPerContinent[continent] ?? 0) + 1;
    }

    final continentCount = visitedContinents.length;
    final countryCount = visitedIsoCodes.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kOcean,
        body: Stack(
          children: [
            // ── Map ──────────────────────────────────────────────────────────
            FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(20, 10),
                initialZoom: 1.8,
                minZoom: 1.0,
                maxZoom: 6.0,
                backgroundColor: _kOcean,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                _ContinentPolygonLayer(
                  polygons: polygons,
                  visitedIsoCodes: visitedIsoCodes,
                  visitedContinents: visitedContinents,
                ),
              ],
            ),

            // ── App bar ──────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Continent Explorer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$continentCount of 6 continents · $countryCount countries',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Legend ───────────────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              right: 12,
              child: _Legend(),
            ),

            // ── Bottom continent panel ────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ContinentPanel(
                visitedContinents: visitedContinents,
                countriesPerContinent: countriesPerContinent,
                totalPerContinent: totalPerContinent,
                countryCount: countryCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Polygon layer ─────────────────────────────────────────────────────────────

class _ContinentPolygonLayer extends StatefulWidget {
  const _ContinentPolygonLayer({
    required this.polygons,
    required this.visitedIsoCodes,
    required this.visitedContinents,
  });

  final List<CountryPolygon> polygons;
  final Set<String> visitedIsoCodes;
  final Set<String> visitedContinents;

  @override
  State<_ContinentPolygonLayer> createState() => _ContinentPolygonLayerState();
}

class _ContinentPolygonLayerState extends State<_ContinentPolygonLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 0.80).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unvisitedPolygons = <Polygon>[];
    final continentPolygons = <Polygon>[];
    final countryPolygons = <Polygon>[];

    const suppressed = {'AQ'};

    for (final p in widget.polygons) {
      if (suppressed.contains(p.isoCode)) continue;
      final points = [for (final (lat, lng) in p.vertices) LatLng(lat, lng)];

      if (widget.visitedIsoCodes.contains(p.isoCode)) {
        // Visited country — gold
        countryPolygons.add(
          Polygon(
            points: points,
            color: _kCountryGold.withValues(alpha: 0.88),
            borderColor: _kCountryBorder,
            borderStrokeWidth: 0.9,
          ),
        );
      } else {
        final continent = kCountryContinent[p.isoCode];
        if (continent != null &&
            widget.visitedContinents.contains(continent)) {
          // Country in a visited continent — use that continent's colour
          final continentColor =
              _continentColors[continent] ?? _kContinentGlow;
          continentPolygons.add(
            Polygon(
              points: points,
              color: continentColor.withValues(alpha: 0.42),
              borderColor: continentColor.withValues(alpha: 0.30),
              borderStrokeWidth: 0.5,
            ),
          );
        } else {
          // Unvisited continent
          unvisitedPolygons.add(
            Polygon(
              points: points,
              color: _kUnvisited.withValues(alpha: 0.9),
              borderColor: _kUnvisitedBorder,
              borderStrokeWidth: 0.4,
            ),
          );
        }
      }
    }

    // Gold countries pulse gently to draw attention.
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Stack(
        children: [
          PolygonLayer(polygonCulling: true, polygons: unvisitedPolygons),
          PolygonLayer(polygonCulling: true, polygons: continentPolygons),
          PolygonLayer(
            polygonCulling: true,
            polygons: [
              for (final poly in countryPolygons)
                Polygon(
                  points: poly.points,
                  color: _kCountryGold.withValues(alpha: _pulseAnim.value),
                  borderColor: _kCountryBorder,
                  borderStrokeWidth: 0.9,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: _kCountryGold, label: 'Visited'),
          const SizedBox(height: 5),
          // Multi-colour dot row for continents
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: _continentColors.values.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                )).toList(),
              ),
              const SizedBox(width: 6),
              const Text(
                'Continent',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _LegendItem(color: _kUnvisited, label: 'Not yet'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    ],
  );
}

// ── Bottom continent panel ────────────────────────────────────────────────────

class _ContinentPanel extends StatelessWidget {
  const _ContinentPanel({
    required this.visitedContinents,
    required this.countriesPerContinent,
    required this.totalPerContinent,
    required this.countryCount,
  });

  final Set<String> visitedContinents;
  final Map<String, int> countriesPerContinent;
  final Map<String, int> totalPerContinent;
  final int countryCount;

  @override
  Widget build(BuildContext context) {
    final continents = [
      'Europe',
      'Asia',
      'North America',
      'South America',
      'Africa',
      'Oceania',
    ];

    final allVisited = visitedContinents.length == 6;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.92),
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Headline ─────────────────────────────────────────────────
          if (allVisited)
            const Text(
              'All 6 continents conquered!',
              style: TextStyle(
                color: RoavvyColours.roavvyGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              visitedContinents.isEmpty
                  ? 'Start your journey — visit your first continent'
                  : '${visitedContinents.length} of 6 continents explored',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 12),

          // ── Continent chips ───────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: continents.map((continent) {
              final visited = visitedContinents.contains(continent);
              final count = countriesPerContinent[continent] ?? 0;
              final total = totalPerContinent[continent] ?? 1;
              final color =
                  _continentColors[continent] ?? Colors.white;
              final icon =
                  _continentIcons[continent] ?? Icons.public_outlined;
              final progress = count / total;

              return _ContinentChip(
                continent: continent,
                visited: visited,
                count: count,
                total: total,
                progress: progress,
                color: color,
                icon: icon,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ContinentChip extends StatelessWidget {
  const _ContinentChip({
    required this.continent,
    required this.visited,
    required this.count,
    required this.total,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final String continent;
  final bool visited;
  final int count;
  final int total;
  final double progress;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: visited
            ? color.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: visited
              ? color.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: visited ? color : Colors.white38),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                continent,
                style: TextStyle(
                  color: visited ? color : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (visited) ...[
                const SizedBox(height: 3),
                SizedBox(
                  width: 80,
                  child: Stack(
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count / $total',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ] else
                Text(
                  'Not visited',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
