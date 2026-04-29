import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/country_names.dart';
import '../../core/notification_service.dart';
import '../scan/hero_image_repository.dart';

/// Structured copy for a memory pulse notification and card.
class MemoryPulseCopy {
  const MemoryPulseCopy({required this.title, required this.body});

  final String title;
  final String body;
}

// Label → emoji mapping (ADR-136).
const Map<String, String> _kMoodEmoji = {
  'sunset': '🌅',
  'sunrise': '🌄',
  'golden_hour': '🌅',
  'night': '🌃',
  'beach': '🏖',
  'mountain': '⛰',
  'snow': '🌨',
  'city': '🏙',
  'forest': '🌲',
  'food': '🍽',
  'boat': '⛵',
  'hiking': '🥾',
  'people': '👥',
  'coast': '🏖',
  'island': '🏝',
  'lake': '🌊',
  'desert': '🏜',
};

/// SharedPreferences key prefix for dismissed memory cards (ADR-136).
const String _kDismissedPrefix = 'memoryPulse:dismissed:';

/// On-device travel anniversary service (M91, ADR-136).
///
/// - [checkToday] queries [HeroImageRepository] for anniversary trips,
///   filters dismissed entries, and returns up to 3 [HeroImage] results.
/// - [scheduleNextAnniversaryNotification] schedules the next 9 AM pulse.
/// - [buildCopy] generates label-driven notification copy locally.
class MemoryPulseService {
  const MemoryPulseService({
    required HeroImageRepository heroRepo,
    required NotificationService notifications,
  })  : _heroRepo = heroRepo,
        _notifications = notifications;

  final HeroImageRepository _heroRepo;
  final NotificationService _notifications;

  /// Returns up to 3 [HeroImage] records whose trip anniversaries fall today.
  ///
  /// Entries dismissed today (stored in SharedPreferences) are excluded.
  /// Pass [today] as the current moment; the method converts to UTC internally.
  Future<List<HeroImage>> checkToday(DateTime today) async {
    final heroes = await _heroRepo.getHeroesWithAnniversaryToday(today);
    if (heroes.isEmpty) return const [];

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(today);

    final undismissed = heroes
        .where((h) => !prefs.containsKey('$_kDismissedPrefix${h.tripId}:$todayKey'))
        .toList();

    return undismissed.take(3).toList();
  }

  /// Dismisses a memory card for today. Stored in SharedPreferences.
  Future<void> dismiss(String tripId, DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      '$_kDismissedPrefix$tripId:${_dateKey(today)}',
      true,
    );
  }

  /// Cancels the current memory pulse notification and schedules the next
  /// upcoming anniversary at 9:00 AM local time.
  ///
  /// Runs at most once per app launch from [MapScreen] (fire-and-forget).
  Future<void> scheduleNextAnniversaryNotification(DateTime today) async {
    final allHeroes = await _getAllRank1Heroes();
    if (allHeroes.isEmpty) return;

    final next = _nextAnniversary(allHeroes, today);
    if (next == null) return;

    final utc = today.toUtc();
    final yearsAgo = utc.year - next.capturedAt.year;
    if (yearsAgo <= 0) return;

    final copy = buildCopy(next, yearsAgo);
    final deliverAt = _nineAmOnDate(next.capturedAt, utc.year);
    if (deliverAt.isBefore(DateTime.now())) return;

    await _notifications.scheduleMemoryPulse(
      title: copy.title,
      body: copy.body,
      tripId: next.tripId,
      deliverAt: deliverAt,
    );
  }

  /// Builds notification/card copy from [hero]'s labels and [yearsAgo] count.
  ///
  /// Gracefully falls back to geography-only copy when no labels are available.
  MemoryPulseCopy buildCopy(HeroImage hero, int yearsAgo) {
    final country = kCountryNames[hero.countryCode] ?? hero.countryCode;
    final yearsWord = yearsAgo == 1 ? 'year' : 'years';

    final moodEmoji = _firstEmoji([...hero.mood, ...hero.activity, if (hero.primaryScene != null) hero.primaryScene!]);
    final emojiSuffix = moodEmoji != null ? ' $moodEmoji' : '';

    final title = 'On this day · $yearsAgo $yearsWord ago in $country$emojiSuffix';

    final sceneParts = <String>[
      if (hero.primaryScene != null) hero.primaryScene!,
      ...hero.mood.take(1),
      ...hero.activity.take(1),
    ];

    final body = sceneParts.isEmpty
        ? '$yearsAgo $yearsWord ago in $country'
        : '${_capitalise(sceneParts.first)} in $country — $yearsAgo $yearsWord ago';

    return MemoryPulseCopy(title: title, body: body);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  String? _firstEmoji(List<String> labels) {
    for (final label in labels) {
      final emoji = _kMoodEmoji[label];
      if (emoji != null) return emoji;
    }
    return null;
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Returns the next future anniversary for any hero, or null if none exists.
  HeroImage? _nextAnniversary(List<HeroImage> heroes, DateTime today) {
    final utcNow = today.toUtc();
    HeroImage? best;
    DateTime? bestDate;

    for (final hero in heroes) {
      final candidate = _nineAmOnDate(hero.capturedAt, utcNow.year);
      final deliverAt =
          candidate.isAfter(utcNow) ? candidate : _nineAmOnDate(hero.capturedAt, utcNow.year + 1);

      if (bestDate == null || deliverAt.isBefore(bestDate)) {
        best = hero;
        bestDate = deliverAt;
      }
    }
    return best;
  }

  /// Returns a DateTime for 9:00 AM UTC on the same month/day as [capturedAt]
  /// in the given [year].
  DateTime _nineAmOnDate(DateTime capturedAt, int year) {
    return DateTime.utc(year, capturedAt.month, capturedAt.day, 9, 0, 0);
  }

  Future<List<HeroImage>> _getAllRank1Heroes() =>
      _heroRepo.getHeroesForRank1();
}
