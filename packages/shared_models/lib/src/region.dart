/// The six standard global continents used as regions in Roavvy (ADR-068).
///
/// Values map directly to the continent strings in [kCountryContinent]:
/// 'Africa', 'Asia', 'Europe', 'North America', 'South America', 'Oceania'.
enum Region {
  africa,
  asia,
  europe,
  northAmerica,
  southAmerica,
  oceania;

  /// Parses the continent string value used in [kCountryContinent].
  ///
  /// Returns `null` for any unrecognised string (e.g. Antarctica).
  static Region? fromContinentString(String value) {
    switch (value) {
      case 'Africa':
        return Region.africa;
      case 'Asia':
        return Region.asia;
      case 'Europe':
        return Region.europe;
      case 'North America':
        return Region.northAmerica;
      case 'South America':
        return Region.southAmerica;
      case 'Oceania':
        return Region.oceania;
      default:
        return null;
    }
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case Region.africa:
        return 'Africa';
      case Region.asia:
        return 'Asia';
      case Region.europe:
        return 'Europe';
      case Region.northAmerica:
        return 'North America';
      case Region.southAmerica:
        return 'South America';
      case Region.oceania:
        return 'Oceania';
    }
  }
}
