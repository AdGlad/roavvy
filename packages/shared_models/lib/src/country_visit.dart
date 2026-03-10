import 'visit_source.dart';

/// One record per country per user — the core domain entity.
///
/// [firstSeen] and [lastSeen] are nullable because a manually added visit
/// may have no associated photo evidence.
///
/// [isDeleted] is a domain tombstone, not a sync flag. It means the user
/// explicitly removed this country. A tombstone prevents automatic re-detection
/// from surfacing the country again.
///
/// Sync-only fields (isDirty, syncedAt) live in the Drift table definition
/// inside apps/mobile_flutter — they are not part of the shared domain model.
class CountryVisit {
  const CountryVisit({
    required this.countryCode,
    required this.source,
    required this.updatedAt,
    this.firstSeen,
    this.lastSeen,
    this.isDeleted = false,
  });

  /// ISO 3166-1 alpha-2 country code, e.g. `"GB"`, `"JP"`.
  final String countryCode;

  /// Earliest photo date in this country. Null for manually added visits
  /// without photo evidence.
  final DateTime? firstSeen;

  /// Most recent photo date in this country. Null for manually added visits
  /// without photo evidence.
  final DateTime? lastSeen;

  final VisitSource source;

  /// True when the user has explicitly removed this country.
  /// Tombstones are never removed by re-scanning — only by the user un-deleting.
  final bool isDeleted;

  /// UTC timestamp of the last local modification. Used for sync conflict
  /// resolution: among two records with the same [source], the later
  /// [updatedAt] wins.
  final DateTime updatedAt;

  bool get isActive => !isDeleted;

  CountryVisit copyWith({
    String? countryCode,
    DateTime? firstSeen,
    DateTime? lastSeen,
    VisitSource? source,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      CountryVisit(
        countryCode: countryCode ?? this.countryCode,
        firstSeen: firstSeen ?? this.firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
        source: source ?? this.source,
        isDeleted: isDeleted ?? this.isDeleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is CountryVisit &&
      other.countryCode == countryCode &&
      other.source == source &&
      other.firstSeen == firstSeen &&
      other.lastSeen == lastSeen &&
      other.isDeleted == isDeleted &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(countryCode, source, firstSeen, lastSeen, isDeleted, updatedAt);

  @override
  String toString() =>
      'CountryVisit($countryCode, $source, deleted=$isDeleted, updatedAt=$updatedAt)';
}
