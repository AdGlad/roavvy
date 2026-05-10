import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/country_names.dart';
import '../../core/notification_service.dart';
import '../scan/hero_image_repository.dart';
import 'app_open_tracker.dart';

/// Structured copy for a memory pulse notification and card.
class MemoryPulseCopy {
  const MemoryPulseCopy({required this.title, required this.body});

  final String title;
  final String body;
}

/// SharedPreferences key prefix for dismissed memory cards (ADR-136).
const String _kDismissedPrefix = 'memoryPulse:dismissed:';

/// SharedPreferences keys for structured state + dedup (M95).
const String _kLastShownDateKey = 'memoryPulse:lastShownDate';
const String _kLastNotificationDateKey = 'memoryPulse:lastNotificationDate';
const String _kRevealedPrefix = 'memoryPulse:revealed:';

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

  /// Marks a memory as revealed (written on first expand of MemoryRevealSheet).
  Future<void> markRevealed(String tripId, DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kRevealedPrefix$tripId:${_dateKey(today)}';
    if (!prefs.containsKey(key)) {
      await prefs.setBool(key, true);
    }
  }

  /// Writes today as the last date memories were shown in the post-scan tray.
  Future<void> markShownToday(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastShownDateKey, _dateKey(today));
  }

  /// Returns true if the post-scan memory tray was already shown today.
  Future<bool> wasShownToday(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastShownDateKey) == _dateKey(today);
  }

  /// Clears the "shown today" flag so [wasShownToday] returns false.
  ///
  /// Used by the debug memory-pulse toggle to allow forced regeneration
  /// on demand regardless of whether the tray was already shown.
  Future<void> clearShownState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastShownDateKey);
  }

  /// Schedules the next anniversary notification using smart timing.
  ///
  /// Skips if a notification was already scheduled today (dedup guard).
  /// Delivery hour is determined by [AppOpenTracker.preferredHour].
  /// Runs at most once per app launch from [MapScreen] (fire-and-forget).
  Future<void> scheduleNextAnniversaryNotification(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kLastNotificationDateKey) == _dateKey(today)) return;

    final allHeroes = await _getAllRank1Heroes();
    if (allHeroes.isEmpty) return;

    final next = _nextAnniversary(allHeroes, today);
    if (next == null) return;

    final utc = today.toUtc();
    final yearsAgo = utc.year - next.capturedAt.year;
    if (yearsAgo <= 0) return;

    final copy = buildCopy(next, yearsAgo);
    final hour = await AppOpenTracker.preferredHour();
    final deliverAt = _deliverAtHour(next.capturedAt, utc.year, hour);
    if (deliverAt.isBefore(DateTime.now())) return;

    await _notifications.scheduleMemoryPulse(
      title: copy.title,
      body: copy.body,
      tripId: next.tripId,
      deliverAt: deliverAt,
    );

    await prefs.setString(_kLastNotificationDateKey, _dateKey(today));
  }

  /// Builds question-style notification copy (M95).
  ///
  /// Title: question text + 👀 emoji (e.g. "Where were you 2 years ago today? 👀").
  /// Body: existing label-driven copy (unchanged from M91).
  MemoryPulseCopy buildCopy(HeroImage hero, int yearsAgo) {
    final country = kCountryNames[hero.countryCode] ?? hero.countryCode;
    final yearsWord = yearsAgo == 1 ? 'year' : 'years';

    final title = '${buildQuestion(hero, yearsAgo)} 👀';

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

  /// Generates a curiosity-first question for a memory card (M95).
  ///
  /// Template priority:
  /// 1. yearsAgo == 1 → "Do you remember where you were exactly one year ago?"
  /// 2. yearsAgo == 5 or 10 → "Can you believe it's been {X} years since {country}?"
  /// 3. landmark label → "Remember visiting {landmark} in {country}?"
  /// 4. beach/island/mountain in primaryScene or mood → "Do you remember this {scene} in {country}?"
  /// 5. default → "Where were you {X} years ago today?"
  ///
  /// Result: short, natural, no trailing full stop, no emoji in the string.
  String buildQuestion(HeroImage hero, int yearsAgo) {
    final country = kCountryNames[hero.countryCode] ?? hero.countryCode;

    if (yearsAgo == 1) {
      return 'Do you remember where you were exactly one year ago?';
    }

    if (yearsAgo == 5 || yearsAgo == 10) {
      return "Can you believe it's been $yearsAgo years since $country?";
    }

    if (hero.landmark != null && hero.landmark!.isNotEmpty) {
      return 'Remember visiting ${hero.landmark} in $country?';
    }

    const kSceneKeywords = {'beach', 'island', 'mountain'};
    final primaryScene = hero.primaryScene;
    if (primaryScene != null && kSceneKeywords.contains(primaryScene)) {
      return 'Do you remember this $primaryScene in $country?';
    }
    final moodScene = hero.mood.where(kSceneKeywords.contains).firstOrNull;
    if (moodScene != null) {
      return 'Do you remember this $moodScene in $country?';
    }

    return 'Where were you $yearsAgo years ago today?';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
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

  /// Returns a DateTime for [hour]:00 UTC on the same month/day as [capturedAt].
  DateTime _deliverAtHour(DateTime capturedAt, int year, int hour) {
    return DateTime.utc(year, capturedAt.month, capturedAt.day, hour, 0, 0);
  }

  Future<List<HeroImage>> _getAllRank1Heroes() =>
      _heroRepo.getHeroesForRank1();
}
