/// Mapping of ISO 3166-1 alpha-2 country codes to landmark icon names.
///
/// Icons are sourced from Tabler (MIT License) and stored in
/// assets/landmarks/ as SVGs.
const Map<String, String> kCountryLandmarks = {
  'FR': 'eiffel_tower',
  'GB': 'big_ben',
  'IT': 'colosseum',
  'US': 'statue_of_liberty',
  'EG': 'pyramids',
  'IN': 'taj_mahal',
  'JP': 'torii_gate',
  'CN': 'great_wall',
  'AU': 'opera_house',
  'BR': 'christ_redeemer',
  'GR': 'parthenon',
  'RU': 'basils_cathedral',
  'ES': 'sagrada_familia',
  'DE': 'brandenburg_gate',
  'NL': 'windmill',
  'PE': 'machu_picchu',
  'MX': 'pyramid',
  'CA': 'cn_tower',
  'JO': 'petra',
  'AE': 'burj_khalifa',
  'SG': 'merlion',
  'KH': 'angkor_wat',
  'TH': 'wat_arun',
  'KR': 'seoul_tower',
  'TR': 'hagiasophia',
};

/// Returns the primary landmark icon path for a country code, or null if none.
String? getLandmarkPath(String isoCode) {
  final name = kCountryLandmarks[isoCode.toUpperCase()];
  if (name == null) return null;
  return 'assets/landmarks/$name.svg';
}
