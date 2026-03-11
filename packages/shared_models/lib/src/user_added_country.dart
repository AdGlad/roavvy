/// A country the user has explicitly added via the review screen.
///
/// User intent takes precedence over scan results: an [UserAddedCountry]
/// will appear in the effective set even if no photo evidence exists.
///
/// A subsequent [UserRemovedCountry] for the same code suppresses it.
class UserAddedCountry {
  const UserAddedCountry({
    required this.countryCode,
    required this.addedAt,
  });

  /// ISO 3166-1 alpha-2 code, e.g. `"GB"`, `"JP"`.
  final String countryCode;

  /// UTC timestamp when the user confirmed the addition.
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is UserAddedCountry &&
      other.countryCode == countryCode &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(countryCode, addedAt);

  @override
  String toString() => 'UserAddedCountry($countryCode, addedAt=$addedAt)';
}
