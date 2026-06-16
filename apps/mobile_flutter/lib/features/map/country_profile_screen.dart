import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../heritage/heritage_detail_sheet.dart';
import '../scan/hero_providers.dart';
import '../shared/hero_image_view.dart';
import '../visits/trip_edit_sheet.dart';
import 'country_region_map_screen.dart';
import 'country_stats.dart';
import 'photo_gallery_screen.dart';

// ── Colour helpers ────────────────────────────────────────────────────────────

Color _continentColor(String? continent) => switch (continent) {
      'Europe' => const Color(0xFF2563EB),
      'Asia' => const Color(0xFF7C3AED),
      'North America' => const Color(0xFF059669),
      'South America' => const Color(0xFFD97706),
      'Africa' => const Color(0xFFDC2626),
      'Oceania' => const Color(0xFF0891B2),
      _ => const Color(0xFF374151),
    };

String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + isoCode.codeUnitAt(0) - 65) +
      String.fromCharCode(base + isoCode.codeUnitAt(1) - 65);
}

Future<Uint8List?> _fetchThumb(String assetId) async {
  final entity = await AssetEntity.fromId(assetId);
  return entity?.thumbnailDataWithSize(const ThumbnailSize.square(120));
}

// ── CountryProfileScreen ──────────────────────────────────────────────────────

/// Full-screen destination profile for a visited country.
///
/// Pushed from the map, countries list, and notification tap handler whenever
/// [visit] is non-null. Unvisited countries continue to use the lightweight
/// bottom sheet (ADR-009 revised).
class CountryProfileScreen extends ConsumerStatefulWidget {
  const CountryProfileScreen({
    super.key,
    required this.isoCode,
    this.visit,
  });

  final String isoCode;
  final EffectiveVisitedCountry? visit;

  @override
  ConsumerState<CountryProfileScreen> createState() =>
      _CountryProfileScreenState();
}

class _CountryProfileScreenState extends ConsumerState<CountryProfileScreen> {
  bool _contentVisible = false;
  bool _unescoCelebrated = false;

  void _reload() => ref.invalidate(countryDetailProvider(widget.isoCode));

  static EffectiveVisitedCountry _emptyVisit(String isoCode) =>
      EffectiveVisitedCountry(
        countryCode: isoCode,
        hasPhotoEvidence: false,
      );

  @override
  Widget build(BuildContext context) {
    final isoCode = widget.isoCode;
    final continent = kCountryContinent[isoCode];
    final accentColor = _continentColor(continent);
    final countryName = kCountryNames[isoCode] ?? isoCode;
    final flag = _flagEmoji(isoCode);
    final heroAsync = ref.watch(bestHeroForCountryProvider(isoCode));
    final heroAssetId = heroAsync.valueOrNull?.assetId;
    final detailAsync = ref.watch(countryDetailProvider(isoCode));

    // Fade in content once data arrives.
    if (detailAsync.hasValue && !_contentVisible) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? setState(() => _contentVisible = true) : null,
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor:
                accentColor,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: heroAssetId != null
                  ? HeroImageView(
                      assetId: heroAssetId,
                      fallbackColor: accentColor,
                      height: 240,
                      useFullResolution: false,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: const _WorldGridPainterWidget(),
                    ),
              title: Text(
                '$flag  $countryName',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 12,
              ),
            ),
            actions: [
              if (detailAsync.hasValue)
                IconButton(
                  icon: const Icon(Icons.ios_share, color: Colors.white),
                  onPressed: () => _share(detailAsync.value!, countryName, flag),
                ),
            ],
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: _contentVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: detailAsync.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load: $e'),
                ),
                data: (detail) => _Body(
                  isoCode: isoCode,
                  countryName: countryName,
                  visit: widget.visit ?? _emptyVisit(isoCode),
                  detail: detail,
                  accentColor: accentColor,
                  continent: continent,
                  onTripChanged: _reload,
                  celebrated: _unescoCelebrated,
                  onCelebrated: () => setState(() => _unescoCelebrated = true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _share(
    CountryDetailState detail,
    String countryName,
    String flag,
  ) {
    final s = detail.stats;
    final tripLine =
        '${s.tripCount} ${s.tripCount == 1 ? 'trip' : 'trips'}';
    final daysLine = s.totalDays > 0 ? '  ·  ${s.totalDays} days' : '';
    final photosLine =
        s.totalPhotos > 0 ? '  ·  ${s.totalPhotos} photos' : '';
    final regionsLine = s.visitedRegions > 0
        ? '\n${s.visitedRegions} regions explored'
        : '';
    final unescoLine = s.visitedHeritageSites > 0
        ? '\n${s.visitedHeritageSites} of ${s.totalHeritageSites} UNESCO World Heritage Sites visited'
        : '';

    final text = '$flag $countryName — My Roavvy Story\n\n'
        '$tripLine$daysLine$photosLine'
        '$regionsLine'
        '$unescoLine'
        '\n\nTrack your travels: roavvy.app';

    Share.share(text);
  }
}

// ── _Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.isoCode,
    required this.countryName,
    required this.visit,
    required this.detail,
    required this.accentColor,
    required this.continent,
    required this.onTripChanged,
    required this.celebrated,
    required this.onCelebrated,
  });

  final String isoCode;
  final String countryName;
  final EffectiveVisitedCountry visit;
  final CountryDetailState detail;
  final Color accentColor;
  final String? continent;
  final VoidCallback onTripChanged;
  final bool celebrated;
  final VoidCallback onCelebrated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Continent chip + visit years header
        _Header(
          continent: continent,
          accentColor: accentColor,
          firstYear: detail.stats.firstVisitYear,
          lastYear: detail.stats.lastVisitYear,
        ),
        // Personal narrative
        _NarrativeCard(
          text: detail.stats.narrativeText(countryName),
          accentColor: accentColor,
        ),
        const SizedBox(height: 4),
        // Stats strip
        _StatsStrip(stats: detail.stats, accentColor: accentColor),
        const SizedBox(height: 16),
        // Region map card
        if (detail.totalRegions > 0)
          _RegionMapCard(
            isoCode: isoCode,
            visitedRegions: detail.stats.visitedRegions,
            totalRegions: detail.totalRegions,
            accentColor: accentColor,
          ),
        // UNESCO heritage section
        if (detail.allSitesInCountry.isNotEmpty)
          _HeritageSitesSection(
            visitedSites: detail.visitedSites,
            unvisitedSites: detail.unvisitedSites,
            allSitesInCountry: detail.allSitesInCountry,
            accentColor: accentColor,
            countryName: countryName,
            celebrated: celebrated,
            onCelebrated: onCelebrated,
          ),
        // Photo strip
        if (detail.photoAssetIds.isNotEmpty)
          _PhotoStrip(
            assetIds: detail.photoAssetIds,
            isoCode: isoCode,
          ),
        // Trip timeline
        _VisitTimeline(
          isoCode: isoCode,
          trips: detail.trips,
          visit: visit,
          accentColor: accentColor,
          onTripChanged: onTripChanged,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── _Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.continent,
    required this.accentColor,
    required this.firstYear,
    required this.lastYear,
  });

  final String? continent;
  final Color accentColor;
  final int? firstYear;
  final int? lastYear;

  @override
  Widget build(BuildContext context) {
    final yearText = _yearText();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          if (continent != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                continent!,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (continent != null && yearText != null)
            const SizedBox(width: 10),
          if (yearText != null)
            Text(
              yearText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
        ],
      ),
    );
  }

  String? _yearText() {
    if (firstYear == null) return null;
    if (lastYear != null && lastYear != firstYear) {
      return 'First visited $firstYear  ·  Last visit $lastYear';
    }
    return 'First visited $firstYear';
  }
}

// ── _NarrativeCard ────────────────────────────────────────────────────────────

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.text, required this.accentColor});

  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _StatsStrip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats, required this.accentColor});

  final CountryStats stats;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (stats.tripCount, 'Trips', false),
      (stats.totalDays, 'Days', stats.totalDays == 0),
      (stats.totalPhotos, 'Photos', stats.totalPhotos == 0),
      (stats.visitedRegions, 'Regions', false),
      (stats.visitedHeritageSites, 'UNESCO', false),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          children: tiles.asMap().entries.map((entry) {
            final i = entry.key;
            final (value, label, isDash) = entry.value;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      value: value,
                      label: label,
                      isDash: isDash,
                      accentColor: accentColor,
                      delay: Duration(milliseconds: i * 80),
                    ),
                  ),
                  if (i < tiles.length - 1)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.5),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.isDash,
    required this.accentColor,
    required this.delay,
  });

  final int value;
  final String label;
  final bool isDash;
  final Color accentColor;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final displayNum = isDash
        ? const Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 800) + delay,
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(
              v.round().toString(),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        displayNum,
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }
}

// ── _RegionMapCard ────────────────────────────────────────────────────────────

class _RegionMapCard extends StatelessWidget {
  const _RegionMapCard({
    required this.isoCode,
    required this.visitedRegions,
    required this.totalRegions,
    required this.accentColor,
  });

  final String isoCode;
  final int visitedRegions;
  final int totalRegions;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final fraction =
        totalRegions > 0 ? visitedRegions / totalRegions : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CountryRegionMapScreen(countryCode: isoCode),
            ),
          ),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Decorative arc progress indicator
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        fraction: fraction,
                        color: accentColor,
                      ),
                      child: Center(
                        child: Text(
                          visitedRegions.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$visitedRegions of $totalRegions regions visited',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Explore the regional map',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: accentColor,
                            ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(
                    Icons.chevron_right,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const strokeWidth = 5.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (fraction <= 0) return;

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ── _WorldGridPainterWidget ───────────────────────────────────────────────────

class _WorldGridPainterWidget extends StatelessWidget {
  const _WorldGridPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WorldGridPainter());
  }
}

class _WorldGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;
    const lines = 8;
    for (var i = 0; i <= lines; i++) {
      final x = size.width * i / lines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height * i / lines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_WorldGridPainter _) => false;
}

// ── _HeritageSitesSection ─────────────────────────────────────────────────────

class _HeritageSitesSection extends StatefulWidget {
  const _HeritageSitesSection({
    required this.visitedSites,
    required this.unvisitedSites,
    required this.allSitesInCountry,
    required this.accentColor,
    required this.countryName,
    required this.celebrated,
    required this.onCelebrated,
  });

  final List<VisitedHeritageSite> visitedSites;
  final List<WorldHeritageSite> unvisitedSites;
  final List<WorldHeritageSite> allSitesInCountry;
  final Color accentColor;
  final String countryName;
  final bool celebrated;
  final VoidCallback onCelebrated;

  @override
  State<_HeritageSitesSection> createState() => _HeritageSitesSectionState();
}

class _HeritageSitesSectionState extends State<_HeritageSitesSection> {
  static const _gold = Color(0xFFF2C94C);
  static const _mint = Color(0xFF2ED8B6);
  static const _coral = Color(0xFFFF6B6B);

  Color _categoryColor(String category) => switch (category.toLowerCase()) {
        'natural' => _mint,
        'mixed' => _coral,
        _ => _gold,
      };

  String _categoryIcon(String category) => switch (category.toLowerCase()) {
        'natural' => '🌿',
        'mixed' => '✨',
        _ => '🏛',
      };

  @override
  Widget build(BuildContext context) {
    final total = widget.allSitesInCountry.length;
    final visited = widget.visitedSites.length;
    final allVisited = widget.visitedSites.isNotEmpty &&
        widget.unvisitedSites.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Text(
                'UNESCO World Heritage Sites',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '$visited of $total visited',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress dots (max 20)
          if (total > 0) _ProgressDots(visited: visited, total: total),

          const SizedBox(height: 12),

          // All-visited celebration
          if (allVisited) ...[
            _AllVisitedBanner(countryName: widget.countryName),
            const SizedBox(height: 12),
          ],

          // Horizontal site cards
          if (visited > 0 || widget.unvisitedSites.isNotEmpty)
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Visited sites first
                  for (final site in widget.visitedSites)
                    _HeritageSiteCard(
                      name: site.name,
                      category: site.category,
                      year: site.inscriptionYear,
                      isVisited: true,
                      distanceKm: site.nearestDistanceKm,
                      confidence: site.confidence,
                      categoryColor: _categoryColor(site.category),
                      categoryIcon: _categoryIcon(site.category),
                      onTap: () => showHeritageDetailSheet(context, site),
                    ),
                  // Then unvisited
                  for (final site in widget.unvisitedSites)
                    _HeritageSiteCard(
                      name: site.name,
                      category: site.category,
                      year: site.inscriptionYear,
                      isVisited: false,
                      categoryColor: _categoryColor(site.category),
                      categoryIcon: _categoryIcon(site.category),
                      onTap: () =>
                          showHeritageDetailSheetForSite(context, site),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.visited, required this.total});

  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final shown = math.min(total, 20);
    final extra = total > 20 ? total - 20 : 0;

    return Row(
      children: [
        ...List.generate(shown, (i) {
          final isVisited = i < visited;
          return Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isVisited
                  ? const Color(0xFFF2C94C)
                  : Colors.transparent,
              border: Border.all(
                color: isVisited
                    ? const Color(0xFFF2C94C)
                    : Theme.of(context).dividerColor,
                width: 1.5,
              ),
            ),
          );
        }),
        if (extra > 0)
          Text(
            '+$extra',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
      ],
    );
  }
}

class _AllVisitedBanner extends StatelessWidget {
  const _AllVisitedBanner({required this.countryName});

  final String countryName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2C94C).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF2C94C).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You've visited every UNESCO site in $countryName!",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB8860B),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeritageSiteCard extends StatelessWidget {
  const _HeritageSiteCard({
    required this.name,
    required this.category,
    required this.year,
    required this.isVisited,
    required this.categoryColor,
    required this.categoryIcon,
    required this.onTap,
    this.distanceKm,
    this.confidence,
  });

  final String name;
  final String category;
  final int? year;
  final bool isVisited;
  final Color categoryColor;
  final String categoryIcon;
  final VoidCallback onTap;
  final double? distanceKm;
  final String? confidence;

  @override
  Widget build(BuildContext context) {
    final borderColor = isVisited
        ? const Color(0xFFF2C94C)
        : Theme.of(context).dividerColor.withValues(alpha: 0.5);
    final cardOpacity = isVisited ? 1.0 : 0.45;

    return Opacity(
      opacity: cardOpacity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 190,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isVisited ? 1.8 : 1),
            color: Theme.of(context).cardColor,
            boxShadow: isVisited
                ? [
                    BoxShadow(
                      color: const Color(0xFFF2C94C).withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category icon + year
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(categoryIcon, style: const TextStyle(fontSize: 20)),
                  if (year != null)
                    Text(
                      year.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Site name
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              // Category label
              Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Distance/confidence (visited only)
              if (isVisited && distanceKm != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: confidence == 'strong'
                          ? const Color(0xFF2ED8B6)
                          : const Color(0xFFF2C94C),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${distanceKm!.toStringAsFixed(1)} km',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                    ),
                  ],
                ),
              ] else if (!isVisited) ...[
                const SizedBox(height: 4),
                Text(
                  'Not yet visited',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── _PhotoStrip ───────────────────────────────────────────────────────────────

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.assetIds, required this.isoCode});

  final List<String> assetIds;
  final String isoCode;

  @override
  Widget build(BuildContext context) {
    final preview = assetIds.take(20).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Text(
                  'Photos from here',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PhotoGalleryScreen(assetIds: assetIds),
                    ),
                  ),
                  child: Text('View all (${assetIds.length})'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) => _PhotoTile(assetId: preview[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({required this.assetId});

  final String assetId;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late final Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchThumb(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        height: 100,
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData || snap.data == null) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              );
            }
            return Image.memory(snap.data!, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}

// ── _VisitTimeline ────────────────────────────────────────────────────────────

class _VisitTimeline extends ConsumerWidget {
  const _VisitTimeline({
    required this.isoCode,
    required this.trips,
    required this.visit,
    required this.accentColor,
    required this.onTripChanged,
  });

  final String isoCode;
  final List<TripRecord> trips;
  final EffectiveVisitedCountry visit;
  final Color accentColor;
  final VoidCallback onTripChanged;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String _dateRange(TripRecord t) {
    final s = t.startedOn;
    final e = t.endedOn;
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '${_fmt(s)} ${s.year}';
    }
    if (s.year == e.year) return '${_fmt(s)} – ${_fmt(e)} ${e.year}';
    return '${_fmt(s)} ${s.year} – ${_fmt(e)} ${e.year}';
  }

  static String _duration(TripRecord t) {
    final days = t.endedOn.difference(t.startedOn).inDays + 1;
    return days == 1 ? '1 day' : '$days days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Visits',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No trip data — add a trip manually.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openAddTrip(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add visit manually'),
            ),
          ],
        ),
      );
    }

    final mostRecentId = trips
        .reduce((a, b) =>
            a.endedOn.isAfter(b.endedOn) ? a : b)
        .id;
    final firstId = trips
        .reduce((a, b) =>
            a.startedOn.isBefore(b.startedOn) ? a : b)
        .id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Visits',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          ...trips.asMap().entries.map((entry) {
            final i = entry.key;
            final trip = entry.value;
            final isFirst = trip.id == firstId && trips.length > 1;
            final isMostRecent = trip.id == mostRecentId && trips.length > 1;
            final isLast = i == trips.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline bar
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date + chips
                          Row(
                            children: [
                              Text(
                                _dateRange(trip),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              if (isMostRecent)
                                _Chip('MOST RECENT', const Color(0xFF2F80ED)),
                              if (isFirst)
                                _Chip('FIRST VISIT', const Color(0xFFF2C94C)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Duration + photos + edit
                          Row(
                            children: [
                              Text(
                                '${_duration(trip)}  ·  ${trip.photoCount} photos',
                                style:
                                    Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.55),
                                        ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _openEditTrip(context, ref, trip),
                                onLongPress: () =>
                                    _confirmDelete(context, ref, trip),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openAddTrip(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add visit manually'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddTrip(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TripEditSheet(countryCode: isoCode),
    );
    if (result == true) onTripChanged();
  }

  Future<void> _openEditTrip(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TripEditSheet(countryCode: isoCode, existingTrip: trip),
    );
    if (result == true) onTripChanged();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tripRepositoryProvider).delete(trip.id);
      onTripChanged();
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
