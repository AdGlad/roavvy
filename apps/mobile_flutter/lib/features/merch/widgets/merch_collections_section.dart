import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/providers.dart';
import '../../../data/db/roavvy_database.dart';
import '../local_mockup_preview_screen.dart';
import '../merch_preset.dart';
import '../merch_template_ranker.dart';

/// Dynamic collections section shown in the Shop tab (M145, ADR-177).
///
/// Generates up to 5 collections from the user's travel data:
/// - All Countries (always)
/// - [Year] Travels (if current year has any travel)
/// - [Continent] (if ≥3 countries in continent, up to 2 continents)
/// - [Achievement Name] (most recent unlocked merch achievement)
///
/// Tapping a collection navigates to [LocalMockupPreviewScreen].
class MerchCollectionsSection extends ConsumerWidget {
  const MerchCollectionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final tripsAsync = ref.watch(tripListProvider);

    if (visitsAsync.isLoading || tripsAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final allVisits = visitsAsync.valueOrNull ?? const [];
    final allTrips = tripsAsync.valueOrNull ?? const [];

    if (allVisits.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<UnlockedAchievementRow>>(
      future: ref.read(achievementRepositoryProvider).loadAllRows(),
      builder: (context, snap) {
        final collections = _buildCollections(
          allVisits: allVisits,
          allTrips: allTrips,
          unlockedRows: snap.data ?? [],
        );
        if (collections.isEmpty) return const SizedBox.shrink();
        return _buildContent(context, collections);
      },
    );
  }

  Widget _buildContent(BuildContext context, List<_Collection> collections) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Collections',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...collections.map((c) => _CollectionRow(collection: c)),
        ],
      ),
    );
  }

  List<_Collection> _buildCollections({
    required List<EffectiveVisitedCountry> allVisits,
    required List<TripRecord> allTrips,
    required List<UnlockedAchievementRow> unlockedRows,
  }) {
    final collections = <_Collection>[];
    final allCodes = allVisits.map((v) => v.countryCode).toList();

    // 1. All Countries (always)
    collections.add(
      _Collection(
        emoji: '🌍',
        label: 'All Countries',
        countryCount: allCodes.length,
        codes: allCodes,
        allCodes: allCodes,
        trips: allTrips,
        template: _topTemplate(allCodes.length),
      ),
    );

    // 2. This-year travels
    final thisYear = DateTime.now().year;
    final yearCodes = allVisits
        .where((v) => v.firstSeen?.year == thisYear)
        .map((v) => v.countryCode)
        .toList();
    if (yearCodes.isNotEmpty) {
      collections.add(
        _Collection(
          emoji: '📅',
          label: '$thisYear Travels',
          countryCount: yearCodes.length,
          codes: yearCodes,
          allCodes: allCodes,
          trips: allTrips,
          template: _topTemplate(yearCodes.length),
        ),
      );
    }

    // 3. Continents with ≥3 countries (up to 2)
    final byContinent = <String, List<String>>{};
    for (final v in allVisits) {
      final continent = kCountryContinent[v.countryCode];
      if (continent == null) continue;
      byContinent.putIfAbsent(continent, () => []).add(v.countryCode);
    }
    final eligibleContinents =
        byContinent.entries
            .where((e) => e.value.length >= 3)
            .toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in eligibleContinents.take(2)) {
      if (collections.length >= 4) break;
      final codes = entry.value;
      collections.add(
        _Collection(
          emoji: _continentEmoji(entry.key),
          label: entry.key,
          countryCount: codes.length,
          codes: codes,
          allCodes: allCodes,
          trips: allTrips,
          template: _topTemplate(codes.length),
        ),
      );
    }

    // 4. Most recent unlocked merch achievement
    if (collections.length < 5 && unlockedRows.isNotEmpty) {
      final sorted = [...unlockedRows]
        ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
      for (final row in sorted) {
        final a = kAchievements
            .where((a) => a.id == row.achievementId && a.merch != null)
            .firstOrNull;
        if (a == null) continue;
        final codes = _codesForAchievement(a, allVisits);
        if (codes.isEmpty) continue;
        collections.add(
          _Collection(
            emoji: '🏆',
            label: a.title,
            countryCount: codes.length,
            codes: codes,
            allCodes: allCodes,
            trips: allTrips,
            template: _topTemplate(codes.length, achievement: a),
          ),
        );
        break;
      }
    }

    return collections.take(5).toList();
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

  String _continentEmoji(String continent) => switch (continent) {
    'Europe' => '🇪🇺',
    'Asia' => '🌏',
    'Africa' => '🌍',
    'North America' || 'South America' => '🌎',
    'Oceania' => '🦘',
    _ => '🗺️',
  };
}

// ── Collection model ──────────────────────────────────────────────────────────

class _Collection {
  const _Collection({
    required this.emoji,
    required this.label,
    required this.countryCount,
    required this.codes,
    required this.allCodes,
    required this.trips,
    required this.template,
  });

  final String emoji;
  final String label;
  final int countryCount;
  final List<String> codes;
  final List<String> allCodes;
  final List<TripRecord> trips;
  final CardTemplateType template;
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.collection});

  final _Collection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => LocalMockupPreviewScreen(
                selectedCodes: collection.codes,
                allCodes: collection.allCodes,
                trips: collection.trips,
                initialTemplate: collection.template,
                initialPreset: MerchPreset(
                  id: 'collection',
                  label: collection.label,
                  config: MerchPresetConfig(
                    layout: collection.template,
                    source: MerchCountrySource.allTime,
                    jitter: 0.4,
                    density: MerchDensity.balanced,
                    stampMode: MerchStampMode.entryExit,
                  ),
                ),
              ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(collection.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${collection.countryCount} '
                    '${collection.countryCount == 1 ? "country" : "countries"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
