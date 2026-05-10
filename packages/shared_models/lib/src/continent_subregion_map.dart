/// Maps ISO 3166-1 alpha-2 country codes to sub-continental region keys.
///
/// Sub-regions are named string keys used by [Achievement.regionScope] to
/// scope merchandise generation to a specific geographic region smaller than
/// a continent. Entries here are authoritative — countries absent from this
/// map are silently excluded from region-scoped merchandise options.
///
/// Keys used here must match the `regionScope` values on achievements in
/// [kAchievements].
const Map<String, String> kCountrySubRegion = {
  // ── Mediterranean ─────────────────────────────────────────────────────────
  // Coastal and island nations of the Mediterranean basin.
  'ES': 'Mediterranean', // Spain
  'FR': 'Mediterranean', // France
  'IT': 'Mediterranean', // Italy
  'GR': 'Mediterranean', // Greece
  'HR': 'Mediterranean', // Croatia
  'AL': 'Mediterranean', // Albania
  'ME': 'Mediterranean', // Montenegro
  'SI': 'Mediterranean', // Slovenia
  'MT': 'Mediterranean', // Malta
  'MC': 'Mediterranean', // Monaco
  'CY': 'Mediterranean', // Cyprus
  'MA': 'Mediterranean', // Morocco
  'DZ': 'Mediterranean', // Algeria
  'TN': 'Mediterranean', // Tunisia
  'LY': 'Mediterranean', // Libya
  'EG': 'Mediterranean', // Egypt
  'IL': 'Mediterranean', // Israel
  'LB': 'Mediterranean', // Lebanon
  'SY': 'Mediterranean', // Syria
  'TR': 'Mediterranean', // Turkey
  'PS': 'Mediterranean', // Palestine

  // ── Southeast Asia ────────────────────────────────────────────────────────
  'TH': 'SoutheastAsia', // Thailand
  'VN': 'SoutheastAsia', // Vietnam
  'KH': 'SoutheastAsia', // Cambodia
  'LA': 'SoutheastAsia', // Laos
  'MM': 'SoutheastAsia', // Myanmar
  'MY': 'SoutheastAsia', // Malaysia
  'SG': 'SoutheastAsia', // Singapore
  'ID': 'SoutheastAsia', // Indonesia
  'PH': 'SoutheastAsia', // Philippines
  'BN': 'SoutheastAsia', // Brunei
  'TL': 'SoutheastAsia', // Timor-Leste
};

/// Human-readable display label for a sub-region key.
String subRegionDisplayName(String regionScope) => switch (regionScope) {
      'Mediterranean' => 'Mediterranean',
      'SoutheastAsia' => 'Southeast Asia',
      _ => regionScope,
    };
