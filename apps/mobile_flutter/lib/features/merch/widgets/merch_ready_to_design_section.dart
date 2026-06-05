import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/providers.dart';
import '../../../data/db/roavvy_database.dart';
import '../local_mockup_preview_screen.dart';
import '../merch_template_ranker.dart';

/// Horizontally scrollable row of 2–3 personalised design recommendations
/// shown in the Shop tab (M145, ADR-177).
///
/// Recommendations are generated client-side from existing providers:
/// 1. Most recently unlocked merch-eligible achievement scope.
/// 2. This-year travel (current-year firstSeen countries).
/// 3. All-time collection (all countries).
///
/// Duplicate country sets are skipped. Shows shimmer placeholders while loading.
class MerchReadyToDesignSection extends ConsumerWidget {
  const MerchReadyToDesignSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    if (visitsAsync.isLoading || tripsAsync.isLoading) {
      return _buildShimmer(context);
    }

    final allVisits = visitsAsync.valueOrNull ?? const [];
    final allTrips = tripsAsync.valueOrNull ?? const [];

    return FutureBuilder<List<UnlockedAchievementRow>>(
      future: ref.read(achievementRepositoryProvider).loadAllRows(),
      builder: (context, snap) {
        if (!snap.hasData) return _buildShimmer(context);
        final rows = snap.data!;
        final recs = _buildRecommendations(
          allVisits: allVisits,
          allTrips: allTrips,
          unlockedRows: rows,
        );
        if (recs.isEmpty) return const SizedBox.shrink();
        return _buildContent(context, recs);
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 10),
            child: Text(
              'Ready to design',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder:
                  (_, __) => Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<_Rec> recs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 10),
            child: Text(
              'Ready to design',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12),
              itemCount: recs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _InspiredDesignCard(rec: recs[i]),
            ),
          ),
        ],
      ),
    );
  }

  List<_Rec> _buildRecommendations({
    required List<EffectiveVisitedCountry> allVisits,
    required List<TripRecord> allTrips,
    required List<UnlockedAchievementRow> unlockedRows,
  }) {
    final recs = <_Rec>[];
    final seenCodeSets = <Set<String>>[];

    bool isDupe(List<String> codes) {
      final s = codes.toSet();
      for (final seen in seenCodeSets) {
        if (seen.length == s.length && seen.containsAll(s)) return true;
      }
      return false;
    }

    void addRec(_Rec rec) {
      if (rec.codes.isEmpty) return;
      if (isDupe(rec.codes)) return;
      seenCodeSets.add(rec.codes.toSet());
      recs.add(rec);
    }

    // 1. Most recently unlocked merch-eligible achievement
    final sortedRows = [...unlockedRows]
      ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    for (final row in sortedRows) {
      final a = kAchievements.where((a) => a.id == row.achievementId).firstOrNull;
      if (a == null || a.merch == null) continue;
      final codes = _codesForAchievement(a, allVisits);
      final template = _topTemplate(codes.length, achievement: a);
      addRec(
        _Rec(
          title: a.title,
          scopeLabel: '${codes.length} ${codes.length == 1 ? "country" : "countries"}',
          codes: codes,
          allCodes: allVisits.map((v) => v.countryCode).toList(),
          allTrips: allTrips,
          template: template,
          gradient: const [Color(0xFF2D5016), Color(0xFF1A3310)],
          emoji: '🏆',
        ),
      );
      break;
    }

    // 2. This-year travel
    final thisYear = DateTime.now().year;
    final yearCodes = allVisits
        .where((v) => v.firstSeen?.year == thisYear)
        .map((v) => v.countryCode)
        .toList();
    if (yearCodes.isNotEmpty) {
      final template = _topTemplate(yearCodes.length);
      addRec(
        _Rec(
          title: '$thisYear Travels',
          scopeLabel: '${yearCodes.length} ${yearCodes.length == 1 ? "country" : "countries"}',
          codes: yearCodes,
          allCodes: allVisits.map((v) => v.countryCode).toList(),
          allTrips: allTrips,
          template: template,
          gradient: const [Color(0xFF1A2E4A), Color(0xFF0E1A2B)],
          emoji: '📅',
        ),
      );
    }

    // 3. All-time collection
    final allCodes = allVisits.map((v) => v.countryCode).toList();
    if (allCodes.isNotEmpty) {
      final template = _topTemplate(allCodes.length);
      addRec(
        _Rec(
          title: 'Grand Tour',
          scopeLabel: '${allCodes.length} ${allCodes.length == 1 ? "country" : "countries"}',
          codes: allCodes,
          allCodes: allCodes,
          allTrips: allTrips,
          template: template,
          gradient: const [Color(0xFF2B1A40), Color(0xFF1A0E28)],
          emoji: '🌍',
        ),
      );
    }

    return recs;
  }

  List<String> _codesForAchievement(
    Achievement a,
    List<EffectiveVisitedCountry> allVisits,
  ) {
    if (a.continentScope != null) {
      return allVisits
          .where((v) => kCountryContinent[v.countryCode] == a.continentScope)
          .map((v) => v.countryCode)
          .toList();
    }
    if (a.regionScope != null) {
      return allVisits
          .where((v) => kCountrySubRegion[v.countryCode] == a.regionScope)
          .map((v) => v.countryCode)
          .toList();
    }
    return allVisits.map((v) => v.countryCode).toList();
  }

  CardTemplateType _topTemplate(int count, {Achievement? achievement}) {
    final ranks = MerchTemplateRanker.rankFor(
      codeCount: count,
      achievement: achievement,
    );
    return ranks.firstWhere((r) => !r.exclude, orElse: () => ranks.first).template;
  }
}

// ── Recommendation model ──────────────────────────────────────────────────────

class _Rec {
  const _Rec({
    required this.title,
    required this.scopeLabel,
    required this.codes,
    required this.allCodes,
    required this.allTrips,
    required this.template,
    required this.gradient,
    required this.emoji,
  });

  final String title;
  final String scopeLabel;
  final List<String> codes;
  final List<String> allCodes;
  final List<TripRecord> allTrips;
  final CardTemplateType template;
  final List<Color> gradient;
  final String emoji;
}

// ── Inspired design card ──────────────────────────────────────────────────────

class _InspiredDesignCard extends StatelessWidget {
  const _InspiredDesignCard({required this.rec});

  final _Rec rec;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => LocalMockupPreviewScreen(
                selectedCodes: rec.codes,
                allCodes: rec.allCodes,
                trips: rec.allTrips,
                initialTemplate: rec.template,
              ),
        ),
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: rec.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.emoji, style: const TextStyle(fontSize: 24)),
            const Spacer(),
            Text(
              rec.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              rec.scopeLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              'Design →',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
