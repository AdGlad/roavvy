import 'package:drift/drift.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/country_names.dart';
import '../../core/notification_service.dart';
import '../../data/db/roavvy_database.dart';
import '../scan/hero_image_repository.dart';
import 'app_open_tracker.dart';
import 'memory_anniversary_photo.dart';

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

/// Maximum number of assets fetched from the photo library per anniversary check.
const int _kPhotoCheckPageSize = 2000;

/// Maximum number of assets fetched for notification scheduling.
const int _kNotificationPageSize = 5000;

/// On-device travel anniversary service (M91, M114, ADR-136).
///
/// - [checkTodayFromPhotoLibrary] queries photo_manager for anniversary photos,
///   resolves country + trip from Drift, and returns up to 3 results.
/// - [scheduleNextAnniversaryNotification] schedules the next 9 AM pulse using
///   the photo library to find the nearest future anniversary date.
/// - [buildCopy] generates label-driven notification copy locally.
///
/// The legacy [checkToday] method (HeroImage-based) is kept for compatibility
/// but is no longer called by providers (M114).
class MemoryPulseService {
  const MemoryPulseService({
    required HeroImageRepository heroRepo,
    required NotificationService notifications,
    required RoavvyDatabase db,
  })  : _heroRepo = heroRepo,
        _notifications = notifications,
        _db = db;

  final HeroImageRepository _heroRepo;
  final NotificationService _notifications;
  final RoavvyDatabase _db;

  // ── M114 photo-library-based anniversary check ────────────────────────────

  /// Returns up to 3 [MemoryAnniversaryPhoto] records whose capture date
  /// matches today's month+day in a past year (at least 365 days ago).
  ///
  /// Requests photo library permission (read-only). Returns empty list if
  /// permission is denied or no matching photos exist.
  Future<List<MemoryAnniversaryPhoto>> checkTodayFromPhotoLibrary(
      DateTime today) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return const [];

    final cutoff = today.subtract(const Duration(days: 365));
    final assets = await _fetchRecentAssets(_kPhotoCheckPageSize, maxDate: cutoff);
    if (assets.isEmpty) return const [];

    final matching = _filterByMonthDay(assets, today);
    if (matching.isEmpty) return const [];

    final byYear = _groupByYear(matching);
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    final allIds = matching.map((a) => a.id).toList();
    final countryByAssetId = await _lookupCountryCodes(allIds);
    final tripByAssetId = await _lookupTripIds(allIds);

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(today);

    final results = <MemoryAnniversaryPhoto>[];
    for (final year in years) {
      if (results.length >= 3) break;
      final yearAssets = byYear[year]!;
      final best = _pickBestPhoto(yearAssets, countryByAssetId);
      if (best == null) continue;
      if (prefs.containsKey('$_kDismissedPrefix${best.id}:$todayKey')) continue;

      results.add(MemoryAnniversaryPhoto(
        assetId: best.id,
        capturedAt: best.createDateTime,
        countryCode: countryByAssetId[best.id],
        tripId: tripByAssetId[best.id],
      ));
    }
    return results;
  }

  // ── Legacy hero-image check (deprecated, not deleted per M114 spec) ───────

  /// Returns up to 3 [HeroImage] records whose trip anniversaries fall today.
  ///
  /// Deprecated in favour of [checkTodayFromPhotoLibrary] (M114). Kept to
  /// avoid breaking callers that have not yet been migrated.
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

  // ── Dismissal / state ─────────────────────────────────────────────────────

  /// Dismisses a memory card for today using [id] as the key.
  ///
  /// For photo-library cards, [id] is the [MemoryAnniversaryPhoto.assetId].
  /// For legacy hero cards, [id] is the trip ID.
  Future<void> dismiss(String id, DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      '$_kDismissedPrefix$id:${_dateKey(today)}',
      true,
    );
  }

  /// Marks a memory as revealed (written on first expand of MemoryRevealSheet).
  Future<void> markRevealed(String id, DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kRevealedPrefix$id:${_dateKey(today)}';
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
  Future<void> clearShownState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastShownDateKey);
  }

  // ── Notification scheduling ───────────────────────────────────────────────

  /// Schedules notifications for ALL upcoming anniversary dates in the next
  /// year (up to 30), each carrying the country code of the best photo for
  /// that day. Replaces the previous batch atomically.
  ///
  /// Runs once per calendar day (dedup guard). Safe to call on every app open.
  /// This means notifications keep firing even when the app is closed for
  /// months, because they are pre-scheduled in advance (M118).
  Future<void> scheduleAnniversaryNotifications(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kLastNotificationDateKey) == _dateKey(today)) return;

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return;

    final assets = await _fetchRecentAssets(_kNotificationPageSize);
    if (assets.isEmpty) return;

    final utcNow = today.toUtc();
    final oneYearAgoMs =
        utcNow.subtract(const Duration(days: 365)).millisecondsSinceEpoch;

    // Build map: MM-DD → best asset for that day (oldest photos = more memorable).
    final mmddToAssets = <String, List<AssetEntity>>{};
    for (final a in assets) {
      if (a.createDateTime.millisecondsSinceEpoch < oneYearAgoMs) {
        mmddToAssets.putIfAbsent(_mmdd(a.createDateTime), () => []).add(a);
      }
    }
    if (mmddToAssets.isEmpty) return;

    // Look up country codes for all candidate assets.
    final allIds = mmddToAssets.values.expand((l) => l).map((a) => a.id).toList();
    final countryByAssetId = await _lookupCountryCodes(allIds);

    final hour = await AppOpenTracker.preferredHour();

    // Find the next 30 upcoming anniversary dates and build notification entries.
    final anniversaries =
        <({DateTime deliverAt, String countryCode, String title, String body})>[];

    for (var offset = 1; offset <= 366 && anniversaries.length < 30; offset++) {
      final candidate = utcNow.add(Duration(days: offset));
      final key = _mmdd(candidate);
      final dayAssets = mmddToAssets[key];
      if (dayAssets == null) continue;

      final best = _pickBestPhoto(dayAssets, countryByAssetId);
      if (best == null) continue;

      final countryCode = countryByAssetId[best.id];
      if (countryCode == null) continue;

      final deliverAt = _deliverAtHour(candidate, candidate.year, hour);
      if (deliverAt.isBefore(DateTime.now())) continue;

      final yearsAgo = candidate.year - best.createDateTime.year;
      final countryName = kCountryNames[countryCode] ?? countryCode;
      final (title, body) = _buildBatchCopy(countryName, yearsAgo);

      anniversaries.add((
        deliverAt: deliverAt,
        countryCode: countryCode,
        title: title,
        body: body,
      ));
    }

    if (anniversaries.isEmpty) return;

    await _notifications.scheduleMemoryPulseBatch(anniversaries);
    await prefs.setString(_kLastNotificationDateKey, _dateKey(today));
  }

  /// Generates notification copy for a scheduled anniversary (M118).
  (String, String) _buildBatchCopy(String countryName, int yearsAgo) {
    final yearsWord = yearsAgo == 1 ? 'year' : 'years';
    if (yearsAgo == 1) {
      return (
        'Do you remember where you were exactly one year ago? 👀',
        'You were in $countryName',
      );
    }
    if (yearsAgo == 5 || yearsAgo == 10) {
      return (
        "Can you believe it's been $yearsAgo years since $countryName? 👀",
        'Tap to relive the memory',
      );
    }
    return (
      'Where were you $yearsAgo $yearsWord ago? 👀',
      'You were in $countryName — tap to see your photos',
    );
  }

  /// Schedules the next anniversary notification from the photo library.
  ///
  /// Deprecated: replaced by [scheduleAnniversaryNotifications] (M118) which
  /// schedules the full annual batch. Kept for call-site compatibility.
  @Deprecated('Use scheduleAnniversaryNotifications instead')
  Future<void> scheduleNextAnniversaryNotification(DateTime today) =>
      scheduleAnniversaryNotifications(today);

  // ── Copy generation ───────────────────────────────────────────────────────

  /// Builds question-style notification copy for a [MemoryAnniversaryPhoto] (M95, M114).
  MemoryPulseCopy buildCopy(MemoryAnniversaryPhoto photo, int yearsAgo) {
    final country = photo.countryCode != null
        ? (kCountryNames[photo.countryCode] ?? photo.countryCode!)
        : null;
    final yearsWord = yearsAgo == 1 ? 'year' : 'years';
    final title = '${buildQuestion(photo, yearsAgo)} 👀';
    final body = country != null
        ? '$yearsAgo $yearsWord ago in $country'
        : '$yearsAgo $yearsWord ago today';
    return MemoryPulseCopy(title: title, body: body);
  }

  /// Generates a curiosity-first question for a [MemoryAnniversaryPhoto] card (M95, M114).
  ///
  /// Template priority:
  /// 1. yearsAgo == 1 → "Do you remember where you were exactly one year ago?"
  /// 2. yearsAgo == 5 or 10 + country known → "Can you believe it's been X years since Y?"
  /// 3. country known → "Where were you X years ago in Y?"
  /// 4. default → "Where were you X years ago today?"
  String buildQuestion(MemoryAnniversaryPhoto photo, int yearsAgo) {
    final country = photo.countryCode != null
        ? (kCountryNames[photo.countryCode] ?? photo.countryCode!)
        : null;

    if (yearsAgo == 1) {
      return 'Do you remember where you were exactly one year ago?';
    }

    if ((yearsAgo == 5 || yearsAgo == 10) && country != null) {
      return "Can you believe it's been $yearsAgo years since $country?";
    }

    if (country != null) {
      return 'Where were you $yearsAgo years ago in $country?';
    }

    return 'Where were you $yearsAgo years ago today?';
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _dateKey(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  String _mmdd(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Fetches up to [pageSize] image assets from the photo library ordered
  /// newest-first. When [maxDate] is provided, only assets created on or
  /// before that date are returned — used to restrict anniversary queries to
  /// photos taken at least 365 days ago so recent photos do not crowd them out.
  Future<List<AssetEntity>> _fetchRecentAssets(int pageSize, {DateTime? maxDate}) async {
    final filterOption = maxDate != null
        ? FilterOptionGroup(
            createTimeCond: DateTimeCond(
              min: DateTime(2000),
              max: maxDate,
            ),
            orders: [
              const OrderOption(type: OrderOptionType.createDate, asc: false),
            ],
          )
        : FilterOptionGroup(
            orders: [
              const OrderOption(type: OrderOptionType.createDate, asc: false),
            ],
          );
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: filterOption,
    );
    if (albums.isEmpty) return const [];

    // Prefer the "All Photos" album.
    final album = albums.firstWhere(
      (a) => a.isAll,
      orElse: () => albums.first,
    );

    final total = await album.assetCountAsync;
    if (total == 0) return const [];

    final count = total < pageSize ? total : pageSize;
    return album.getAssetListRange(start: 0, end: count);
  }

  /// Filters [assets] to those whose create date matches [today]'s month+day
  /// and were taken at least 365 days before [today].
  List<AssetEntity> _filterByMonthDay(List<AssetEntity> assets, DateTime today) {
    final todayMmdd = _mmdd(today);
    final oneYearAgoMs =
        today.toUtc().subtract(const Duration(days: 365)).millisecondsSinceEpoch;
    return assets.where((a) {
      final dt = a.createDateTime;
      return _mmdd(dt) == todayMmdd &&
          dt.millisecondsSinceEpoch < oneYearAgoMs;
    }).toList();
  }

  Map<int, List<AssetEntity>> _groupByYear(List<AssetEntity> assets) {
    final result = <int, List<AssetEntity>>{};
    for (final a in assets) {
      result.putIfAbsent(a.createDateTime.year, () => []).add(a);
    }
    return result;
  }

  /// Selects the best photo from [yearAssets] using the priority criteria:
  /// 1. Country known + isFavorite
  /// 2. Country known + highest pixel area
  /// 3. Country known + any
  /// 4. isFavorite (no country match)
  /// 5. Highest pixel area (no country match)
  AssetEntity? _pickBestPhoto(
    List<AssetEntity> yearAssets,
    Map<String, String> countryByAssetId,
  ) {
    if (yearAssets.isEmpty) return null;

    final withCountry =
        yearAssets.where((a) => countryByAssetId.containsKey(a.id)).toList();

    if (withCountry.isNotEmpty) {
      final favWithCountry =
          withCountry.where((a) => a.isFavorite).toList();
      if (favWithCountry.isNotEmpty) return favWithCountry.first;
      return withCountry
          .reduce((a, b) => (a.width * a.height) >= (b.width * b.height) ? a : b);
    }

    // No country match: prefer favourites, then largest.
    final favs = yearAssets.where((a) => a.isFavorite).toList();
    if (favs.isNotEmpty) return favs.first;
    return yearAssets
        .reduce((a, b) => (a.width * a.height) >= (b.width * b.height) ? a : b);
  }

  /// Queries [photo_date_records] for matching assetIds, returning assetId → countryCode.
  Future<Map<String, String>> _lookupCountryCodes(List<String> assetIds) async {
    if (assetIds.isEmpty) return const {};
    final placeholders = List.filled(assetIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT asset_id, country_code FROM photo_date_records '
          'WHERE asset_id IN ($placeholders)',
          variables: assetIds.map(Variable.withString).toList(),
          readsFrom: {_db.photoDateRecords},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('asset_id'): r.read<String>('country_code'),
    };
  }

  /// Queries [hero_images] (rank=1) for matching assetIds, returning assetId → tripId.
  Future<Map<String, String>> _lookupTripIds(List<String> assetIds) async {
    if (assetIds.isEmpty) return const {};
    final placeholders = List.filled(assetIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT asset_id, trip_id FROM hero_images '
          'WHERE asset_id IN ($placeholders) AND rank = 1',
          variables: assetIds.map(Variable.withString).toList(),
          readsFrom: {_db.heroImages},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('asset_id'): r.read<String>('trip_id'),
    };
  }

  /// Returns a DateTime for [hour]:00 UTC on the same month/day as [date].
  DateTime _deliverAtHour(DateTime date, int year, int hour) {
    return DateTime.utc(year, date.month, date.day, hour, 0, 0);
  }
}
