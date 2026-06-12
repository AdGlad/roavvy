/// Static tourist-arrival rarity scores per country (M150).
///
/// Scores are normalised UNWTO arrival data on a 0.0–1.0 scale,
/// where **lower = rarer** to visit.
///
/// Thresholds:
/// - Ultra Rare : < 0.05   (~40 countries)
/// - Rare       : 0.05–0.20 (~80 countries)
/// - Uncommon   : 0.20–0.45
/// - Common     : ≥ 0.45   (not included here; absent keys default to 0.5)
///
/// Source: UNWTO Tourist Arrivals 2022, normalised and clamped.
const Map<String, double> kCountryRarity = {
  // ── Ultra Rare (< 0.05) ──────────────────────────────────────────────────
  'TV': 0.001, // Tuvalu
  'NR': 0.002, // Nauru
  'KI': 0.003, // Kiribati
  'MH': 0.004, // Marshall Islands
  'FM': 0.005, // Micronesia
  'PW': 0.010, // Palau
  'TO': 0.012, // Tonga
  'WS': 0.015, // Samoa
  'VU': 0.018, // Vanuatu
  'SB': 0.020, // Solomon Islands
  'ST': 0.022, // Sao Tome and Principe
  'KM': 0.025, // Comoros
  'GW': 0.027, // Guinea-Bissau
  'ER': 0.030, // Eritrea
  'CF': 0.033, // Central African Republic
  'TD': 0.036, // Chad
  'NE': 0.039, // Niger
  'ML': 0.041, // Mali
  'GN': 0.044, // Guinea
  'SL': 0.047, // Sierra Leone
  // ── Rare (0.05–0.20) ────────────────────────────────────────────────────
  'MR': 0.055, // Mauritania
  'CG': 0.058, // Congo (Republic)
  'CD': 0.062, // DR Congo
  'BT': 0.065, // Bhutan
  'DJ': 0.070, // Djibouti
  'LY': 0.075, // Libya
  'IQ': 0.080, // Iraq
  'SY': 0.085, // Syria
  'YE': 0.090, // Yemen
  'AF': 0.092, // Afghanistan
  'GQ': 0.095, // Equatorial Guinea
  'SS': 0.100, // South Sudan
  'BI': 0.108, // Burundi
  'SO': 0.112, // Somalia
  'MW': 0.118, // Malawi
  'MZ': 0.125, // Mozambique
  'AO': 0.132, // Angola
  'ZW': 0.138, // Zimbabwe
  'SD': 0.142, // Sudan
  'GM': 0.148, // Gambia
  'TG': 0.152, // Togo
  'BJ': 0.158, // Benin
  'BF': 0.163, // Burkina Faso
  'LR': 0.168, // Liberia
  'GA': 0.172, // Gabon
  'PG': 0.178, // Papua New Guinea
  'TL': 0.183, // Timor-Leste
  'MM': 0.192, // Myanmar
  // ── Uncommon (0.20–0.45) ────────────────────────────────────────────────
  'GH': 0.205, // Ghana
  'CM': 0.212, // Cameroon
  'LA': 0.218, // Laos
  'KH': 0.225, // Cambodia
  'MN': 0.232, // Mongolia
  'BD': 0.240, // Bangladesh
  'PK': 0.248, // Pakistan
  'NP': 0.258, // Nepal
  'ET': 0.272, // Ethiopia
  'UG': 0.280, // Uganda
  'TZ': 0.288, // Tanzania
  'ZM': 0.298, // Zambia
  'BO': 0.310, // Bolivia
  'PY': 0.322, // Paraguay
  'SV': 0.332, // El Salvador
  'HN': 0.342, // Honduras
  'GY': 0.350, // Guyana
  'SR': 0.360, // Suriname
  'TT': 0.370, // Trinidad and Tobago
  'KZ': 0.380, // Kazakhstan
  'UZ': 0.390, // Uzbekistan
  'TM': 0.400, // Turkmenistan
  'AZ': 0.410, // Azerbaijan
  'AM': 0.420, // Armenia
  'GE': 0.430, // Georgia
  'MD': 0.440, // Moldova
  'AL': 0.445, // Albania
};

/// Rarity tier for a given score.
enum RarityTier {
  ultraRare,
  rare,
  uncommon;

  /// Returns the display label for this tier.
  String get label => switch (this) {
    RarityTier.ultraRare => 'Ultra Rare',
    RarityTier.rare => 'Rare',
    RarityTier.uncommon => 'Uncommon',
  };

  /// Returns the tier for [score], or null if the country is common.
  static RarityTier? fromScore(double score) {
    if (score < 0.05) return RarityTier.ultraRare;
    if (score < 0.20) return RarityTier.rare;
    if (score < 0.45) return RarityTier.uncommon;
    return null;
  }
}

/// Returns the visited countries that are rarest (score < 0.45), sorted by
/// ascending rarity score (rarest first), capped at [limit].
///
/// Countries absent from [kCountryRarity] default to 0.5 and are excluded.
List<({String countryCode, double score, RarityTier tier})> rarestVisited(
  List<String> visitedCodes, {
  int limit = 3,
}) {
  final results = <({String countryCode, double score, RarityTier tier})>[];
  for (final code in visitedCodes) {
    final score = kCountryRarity[code];
    if (score == null) continue; // absent = common, skip
    final tier = RarityTier.fromScore(score);
    if (tier == null) continue; // common, skip
    results.add((countryCode: code, score: score, tier: tier));
  }
  results.sort((a, b) => a.score.compareTo(b.score));
  return results.take(limit).toList();
}
