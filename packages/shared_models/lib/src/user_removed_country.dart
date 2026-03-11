/// A permanent tombstone expressing the user's intent: "I did not visit here."
///
/// Suppresses any [InferredCountryVisit] or [UserAddedCountry] for the same
/// country code — including future scan results. The country will not re-appear
/// after subsequent scans until the user explicitly un-removes it (which
/// replaces this record with a new [UserAddedCountry]).
///
/// This is the only record type that can suppress an inferred visit. Auto-
/// detection can never tombstone a country — only user action can.
class UserRemovedCountry {
  const UserRemovedCountry({
    required this.countryCode,
    required this.removedAt,
  });

  /// ISO 3166-1 alpha-2 code, e.g. `"GB"`, `"JP"`.
  final String countryCode;

  /// UTC timestamp when the user confirmed the removal.
  final DateTime removedAt;

  @override
  bool operator ==(Object other) =>
      other is UserRemovedCountry &&
      other.countryCode == countryCode &&
      other.removedAt == removedAt;

  @override
  int get hashCode => Object.hash(countryCode, removedAt);

  @override
  String toString() => 'UserRemovedCountry($countryCode, removedAt=$removedAt)';
}
